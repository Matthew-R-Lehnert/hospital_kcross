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

**Analysis complete.** National commuting-zone run (597 zones x ambient +
residential x 999 sims) done + analyzed; family-wise corrected; diagnostic
typology built (`output/typology_*.csv`). Full robustness suite complete:
Type-I calibration (~0.04), power analysis (justifies the >=8 floor; ~0.67 power
at n=8, 0.80 at n=10), threshold sensitivity (headline stable at 8/10/15), buffer
sensitivity (deserts robust at 25/50/100 km), the WorldPop modeled-residential
control (`output/worldpop/`), and the 939-CBSA windowing re-run (`output_cbsa/`).

**Key results (family-wise corrected):**
- Concentration: 0/261 zones over-concentrated vs ambient (p=0.47) but 15/261 vs
  residential (p=0.002); beds 13/261. Replicates on CBSAs (0/185, 15/185).
- Coverage: 6/585 under-served vs ambient (p=0.001), 0 vs residential (p=0.13).
  Deserts appear only with CZ windows (CBSAs omit the rural fringe).
- WorldPop (modeled residential) patterns with GPW, not LandScan -> the
  ambient/residential flip is day/night TIMING, not raster construction.
- 44/597 zones change diagnosis between surfaces.

**Manuscript complete** (~7,300 words, 0 em dashes): all 7 sections written with
real results + full robustness, 31 verified citations, national typology maps +
Dallas exemplar figures. Everything committed and pushed (private repo).

**Remaining to submission:** length/polish (Related Work ~1,666 is heavy; trim
abstract + Methods to a journal word limit), build the PDF
(`cd manuscript && make styles && make STYLE=apa`), pick the target journal
(rec: Int. J. Health Geographics primary; JAMA Network Open reach) and set the
CSL style. Optional: WorldPop excludes Puerto Rico (US-only file).

Results/data live under `output/`, `output_cbsa/`, `data/` (all gitignored,
local-only, regenerable from `code/acquire/` + the pipeline).
