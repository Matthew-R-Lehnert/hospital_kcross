# CLAUDE.md — hospital_kcross

Working notes for this repository. Goal: a **peer-reviewed publication**. The
repo is organized as a manuscript (`manuscript/`) plus supporting code (`code/`,
not submitted). This is the population analogue of the LIHTC-vs-crime `Kcross`
study, re-framed for hospital access.

## What the study does

Tests whether US hospital supply matches population, per **commuting zone**,
across three orthogonal axes, each under two population surfaces (ambient vs
residential):

- **Concentration** — is supply clumped beyond population? Inhomogeneous
  Ripley's K (`Kinhom`) with a population-proportional null intensity, for
  hospital locations and bed-weighted capacity. Needs >= 8 hospitals/zone.
- **Coverage** — are people far from care? Population-weighted distance to the
  nearest hospital vs the same null, crediting hospitals across a 50 km buffer.
  Runs for any zone with >= 1 hospital.
- **Sufficiency** — enough capacity per person? Beds per 1,000 vs US (~2.8) and
  OECD (~4.3) references. Every zone.

**What is permuted:** population is held FIXED; hospitals are resampled from
`rpoispp(lambda proportional to population)` (999 sims). Verdict via the
Myllymaki global ERL envelope test (GET package), corrected family-wise within
zones (over the r grid) and across zones (combined test). The three axes combine
into a per-zone diagnostic typology (shortage / maldistribution / geographic
gap / capacity shortfall / redundancy / well-matched).

**Headline result:** the demand surface reverses the conclusion. Hospitals look
over-concentrated vs residential population (15/261 zones) but not vs ambient
(0/261); ambient reveals 6 coverage deserts that residential hides. A WorldPop
control shows this is day/night timing, not raster modeling.

## Environment (important)

- **R is NOT on PATH.** Use the full path:
  `/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript`
  (R 4.4, with sf, spatstat, GET, terra, ggplot2, jsonlite, exactextractr).
- **Nextflow + Java** for the pipeline (not on PATH either):
  `export JAVA_HOME=/Users/matthew.lehnert/opt/jdk-21.0.11+10/Contents/Home`
  and add `$HOME/.local/bin` (nextflow) + `$JAVA_HOME/bin` to PATH.
- Python has geopandas/rasterio/scipy/shapely; `earthaccess` for GPW (needs
  ~/.netrc Earthdata creds, present). `aws` CLI authenticated (raw-data mirror).

## Layout

```
manuscript/  00_abstract .. 06_conclusion (.md), references.bib (style-agnostic),
             csl/, Makefile (pandoc + CSL), metadata.yaml, figures/
code/R/      hk_core.R (helpers), hk_combined.R (engine: 3 axes), global_across_zones.R
             (family-wise), power_analysis.R, threshold_sensitivity.R,
             buffer_sensitivity.R, national_map.R, zone_maps.R, calibration.R
code/scripts/ run_cz.R, run_all.R, list_zones.py, collate.py, typology.py,
             finalize.sh, verify_references.py, skipped_zones.py, beds_audit.py
code/acquire/ 01_hospitals .. 06_worldpop (data acquisition)
code/main.nf, code/nextflow.config   Nextflow pipeline (local/slurm/awsbatch)
data/        raw + derived inputs (GITIGNORED)
output/      results per surface (GITIGNORED); output_cbsa/ = CBSA robustness run
docs/        window_choice.md, skipped_zones.md, beds_missing.md, target_journals.md
```

## Data (all 2020; in data/, gitignored)

- `hospitals.gpkg` — HIFLD, 7,966 open (DataLumos 239108, via S3 mirror). 5.2% missing beds.
- `commuting_zones.gpkg` — 597 USDA 2020 CZs (TIGER counties + ERS crosswalk).
- `landscan/landscan-global-2020.tif` — ambient (S3 mirror).
- `gpw/gpw_v4_2020.tif` — residential (NASA SEDAC, earthaccess).
- `worldpop/worldpop_2020.tif` — modeled-residential control (US-only, no PR).
- `cbsa.gpkg` — 939 CBSA windows (robustness re-run).

## Common commands

```bash
RS=/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript
export JAVA_HOME=/Users/matthew.lehnert/opt/jdk-21.0.11+10/Contents/Home
export PATH="$HOME/.local/bin:$JAVA_HOME/bin:$PATH"

# one zone (all three axes), maps
$RS code/scripts/run_cz.R "San Diego, CA" 2020 ambient 999
$RS code/R/zone_maps.R "San Diego, CA" 2020 ambient        # desert + localK maps

# national run (background; CZ names contain commas so --zones is SEMICOLON-delimited)
nextflow run code/main.nf -profile local --rbin "$RS" --pop_kinds ambient,residential --nsim 999
# CBSA robustness re-run:
nextflow run code/main.nf -profile local --rbin "$RS" --windows "$PWD/data/cbsa.gpkg" \
    --outdir "$PWD/output_cbsa" --pop_kinds ambient,residential --nsim 999

# post-run: family-wise tests per axis/surface + diagnostic typology
bash code/scripts/finalize.sh
$RS code/R/national_map.R                                  # typology choropleths

# robustness
$RS code/R/calibration.R "Tucson, AZ" 300 199              # Type-I (~0.04)
$RS code/R/power_analysis.R "Tucson, AZ" 200 199 4 2500    # justify the >=8 floor
$RS code/R/threshold_sensitivity.R output/residential all

# ambient endogeneity: neutralize hospital cells, re-test concentration
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES \
  $RS code/scripts/run_masked_ambient.R 2020 999            # -> output/ambient_masked/
$RS code/R/global_across_zones.R output/ambient_masked all  # family-wise (expect 0/262)

# second-round reviewer robustness (2026-07-01)
$RS code/R/coverage_power.R "San Diego, CA" 200 199         # coverage-test power vs desert severity
$RS code/R/null_sensitivity.R residential 8 999             # Poisson vs fixed-N null
python3 code/scripts/effect_sizes.py                        # magnitudes for flagged zones
python3 code/scripts/reversal_decomposition.py              # reversal is structured, not mechanical
python3 code/scripts/typology.py 1.536                      # sufficiency threshold sensitivity (OECD cutoff)
python3 code/scripts/drivetime_deserts.py                   # OSRM road distance for the 6 deserts (needs network)

# quality gates
python3 code/scripts/verify_references.py manuscript/references.bib   # must be FAIL=0
cd manuscript && make styles && make STYLE=apa                        # build PDF
```

## Conventions and gotchas

- **Manuscript: no em dashes, no AI-writing quirks.** `grep -c '—' manuscript/*.md`
  must be 0. Bibliography is style-agnostic BibTeX; citation style is a CSL swap
  at build (`make STYLE=apa|chicago-author-date|vancouver`). Every reference must
  pass `verify_references.py` (Crossref DOI or live URL) before submission.
- **min_hospitals=8 gates ONLY concentration.** Coverage (>= 1 hospital) and
  sufficiency (all zones) run regardless, so rural/desert zones are covered.
- **Coverage buffer:** observed distance uses hospitals within zone + 50 km;
  the null resamples only in-zone hospitals, holding buffer neighbors fixed.
- **Beds:** missing (HIFLD -999) imputed with the zone median; 9 zones with
  >50% missing beds are flagged unreliable.
- **Saved sims** (`*_simfuns.rds`) store the grid as `x` (not `r`); the
  across-zone join keys on the normalized zone name from the filename.
- **WorldPop is US-only** (Puerto Rico absent) → ~257 concentration zones vs 261.
- `output/` and `data/` are gitignored; only `code/`, `manuscript/`, `docs/` are
  committed. Manuscript figures live in `manuscript/figures/` (committed).
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## Status (as of the current work)

**Analysis complete.** National commuting-zone run (598 zones x ambient +
residential x 999 sims) done + analyzed; family-wise corrected; diagnostic
typology built (`output/typology_*.csv`). Full robustness suite complete:
Type-I calibration (~0.04), power analysis (justifies the >=8 floor; ~0.67 power
at n=8, 0.80 at n=10), threshold sensitivity (headline stable at 8/10/15), buffer
sensitivity (deserts robust at 25/50/100 km), the WorldPop modeled-residential
control (`output/worldpop/`), the 939-CBSA windowing re-run (`output_cbsa/`), the
ambient-endogeneity control (`output/ambient_masked/`), coverage power
(`code/R/coverage_power.R`), Poisson-vs-fixed-N null sensitivity
(`code/R/null_sensitivity.R`), effect sizes (`code/scripts/effect_sizes.py`), the
reversal-is-structured decomposition (`code/scripts/reversal_decomposition.py`),
sufficiency threshold sensitivity, and OSRM drive-time validation of the deserts
(`code/scripts/drivetime_deserts.py`).

**Connecticut fix (2026-07-01):** the USDA crosswalk keys all of CT to its 2022
planning-region FIPS (09110-09190), absent from the 2020 TIGER county file, so
`acquire/02_commuting_zones.py` had silently dropped the whole state (the old
598-vs-597 gap). Fixed (CT counties -> CZ 70), rebuilt `commuting_zones.gpkg`
(598 zones), re-ran Hartford, recomputed family-wise + typology. Hartford is
consistent/well-matched on every axis, so denominators grew (261->262 conc,
585->586 coverage) but all numerators held.

**Key results (family-wise corrected, 598 zones):**
- Concentration: 0/262 zones over-concentrated vs ambient (p=0.475) but 15/262 vs
  residential (p=0.002); beds 13/262. Replicates on CBSAs (0/185, 15/185).
- Coverage: 6/586 under-served vs ambient (p=0.001), 0 vs residential (p=0.126).
  Deserts appear only with CZ windows (CBSAs omit the rural fringe).
- WorldPop (modeled residential) patterns with GPW, not LandScan -> the
  ambient/residential flip is day/night TIMING, not raster construction (18/258
  conc, 0/576 coverage).
- Ambient endogeneity ruled out: neutralizing hospital cells (replace with 5x5
  neighborhood background via `mask_hospital_cells`) leaves ambient at 0/262
  (p=0.446), same as unmasked. NB: must REPLACE not zero the cell -- zeroing
  divides Kinhom by lambda~0 at the points and spuriously flags 231/262.
- 44/598 zones change diagnosis between surfaces.

**Second-round robustness (2026-07-01, reviewer items):**
- Reversal is structured, not mechanical: normalized ambient/residential ratio at
  hospitals median 1.73 (251/262 >1; flipped zones 1.94) vs residential-weighted
  baseline 1.0 (the identity under any global reweighting).
- Coverage power: Type-I ~0.05; power is desert-geometry-dependent (San Diego
  0.99 at 20% stranded; Amarillo conservative). 6 deserts are strong detections.
- Null type: Poisson vs fixed-N binomial -> 8/8 verdict agreement.
- Effect sizes: concentration L_obs/L_null at 10 km median 2.9x (1.3-31x);
  coverage excess mean distance up to ~3 km, peak excess stranded frac 9-37 pts.
- Drive-time (OSRM): road >= Euclidean in all 6 deserts (ratio 1.13-2.62), so
  deserts are conservative to the Euclidean assumption.
- Sufficiency threshold sensitivity: capacity-shortfall count 38/102/277 at bed
  cutoffs 0.7x-US / US(2.8) / OECD(4.3); tested categories unchanged.
- Temporal: HIFLD confirmed 2024-vintage (S3 metadata + per-record SOURCEDATE);
  no 2020 layer available and no facility open/close dates, so handled as a
  bounded limitation (deserts conservative; over-conc is family-wise + large ES).

**Manuscript complete** (~7,400 words, 0 em dashes): all 7 sections written with
real results + full robustness (incl. the CT fix and ambient-endogeneity
control), 31 verified citations, national typology maps (regenerated with CT) +
Dallas exemplar figures. NOTE: the 2026-07-01 edits (CT + endogeneity + production
defects) are LOCAL to this working dir, which is not itself a git checkout; sync
them to the private repo (github.com/Matthew-R-Lehnert/hospital_kcross).

**Remaining to submission:** length/polish (Related Work ~1,666 is heavy; trim
abstract + Methods to a journal word limit), build the PDF
(`cd manuscript && make styles && make STYLE=apa`; pandoc+xelatex not on PATH in
the current env), pick the target journal (rec: Int. J. Health Geographics
primary; JAMA Network Open reach) and set the CSL style. Repo stays PRIVATE for
now (author decision); public + Zenodo/OSF DOI is a pre-submission action.
All reviewer statistics/substance/minor items now addressed (see
`docs/reviewer_feedback.md`); only the reproducibility gate (public + DOI) and
final length/polish remain. Optional: WorldPop excludes Puerto Rico.

Results/data live under `output/`, `output_cbsa/`, `data/` (all gitignored,
local-only, regenerable from `code/acquire/` + the pipeline).

## Next steps / open questions (pre-submission review)

A simulated peer review of `manuscript.pdf` (2026-07-01) surfaced open questions
to resolve before submission. Full list with actions and checkboxes in
**`docs/reviewer_feedback.md`**.

**Resolved 2026-07-01:**
- **Ambient endogeneity (was blocking):** ruled out. Quantified (hospital-cell
  ambient pop is 3.2% pooled, <=8.8% max) AND re-ran concentration on a
  hospital-neutralized ambient surface -> 0/262, p=0.446, same as unmasked. See
  Results robustness + `output/ambient_masked/`.
  Results robustness + `output/ambient_masked/`.
- **Production defects:** title block (author flattened, `date: "July 2026"`),
  leaked abstract comment (removed `abstract:` field), trauma contradiction
  (dropped from contributions), 598-vs-597 (Connecticut fix). All done.
- **Reversal is mechanical?** Resolved (decomposition; rho_hosp 1.73).
- **Euclidean vs drive-time:** resolved (OSRM; road >= Euclidean, deserts
  conservative).
- **Temporal mismatch:** bounded reasoned limitation (no 2020 layer / no facility
  dates; deserts conservative, over-conc family-wise + large ES).
- **Soften claims:** resolved (Data "complementary surface"; Implications no
  longer prescribes curbing capacity).
- **Effect sizes / null-type / coverage power / sufficiency asymmetry / beds
  denominator / structural co-occurrence:** all resolved (see reviewer_feedback).

**Still open:**
- **Repo public + DOI:** deferred (author wants private for now).
- **Length/polish + PDF build + git sync** (pandoc/xelatex not on PATH here; this
  dir is not a git checkout, so sync 2026-07-01 edits to the private repo).
