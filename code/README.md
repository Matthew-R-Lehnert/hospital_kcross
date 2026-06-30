# `code/` — analysis code (not part of the submitted manuscript)

Everything needed to reproduce the study. The submitted paper is `manuscript/`;
this directory is the supplementary/archival code.

## Engines

- **`R/` — canonical reference engine (R / `spatstat`).** `hk_core.R` implements
  the population-intensity inhomogeneous K test: read a window + hospitals + a
  population raster, build `lambda ∝ population` (normalized so `∫lambda = n`),
  compute `Kinhom`, and build a Monte-Carlo envelope of `rpoispp(lambda)`
  simulations. This is the publication engine.
- **`python/` — independent validation port** (`numpy`/`scipy`/`shapely`),
  adapted from the validated Kcross port. Cross-checks the R results on a
  platform without R. *(Port in progress — see `python/README.md`.)*

## Acquire (`acquire/`)

| Script | Produces | Source |
|--------|----------|--------|
| `01_hospitals.py`        | `data/hospitals.gpkg`        | HIFLD (DataLumos 239108) via S3 mirror |
| `02_commuting_zones.py`  | `data/commuting_zones.gpkg`  | Census TIGER counties ⨉ USDA CZ crosswalk |
| `03_landscan.py`         | `data/landscan/*.tif`        | LandScan Global ambient pop via S3 mirror |
| `04_gpw.py`              | `data/gpw/*.tif`             | NASA SEDAC GPWv4.11 residential pop |

## Run

```bash
RS=/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript

# sanity-check the engine with no external data (fabricated population + points)
$RS code/scripts/_selftest.R

# one commuting zone, ambient population
$RS code/scripts/run_cz.R "Tucson, AZ" 2020 ambient

# national fan-out, simple (all windows, parallel mclapply)
$RS code/scripts/run_all.R 2020 ambient 999 8
```

## Run (Nextflow, recommended for the national fan-out)

Fans every (zone x population-kind x subset x weighting) out as an independent,
resumable task, then collates `output/summary.csv`. R need not be on `PATH`;
pass its full path with `--rbin`.

```bash
export JAVA_HOME=/path/to/jdk; export PATH="$JAVA_HOME/bin:$PATH"
RS=/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript

# smoke: two zones, both population surfaces
nextflow run code/main.nf -profile local --rbin "$RS" --nsim 99 \
    --zones 'Tucson, AZ;San Diego, CA' --pop_kinds ambient,residential

# national: all 597 zones, ambient + residential, 999 sims
nextflow run code/main.nf -profile local --rbin "$RS" \
    --pop_kinds ambient,residential --nsim 999 -resume

# capacity + trauma variants
nextflow run code/main.nf -profile local --rbin "$RS" \
    --subsets all,trauma --weight_by none,beds

# cluster
nextflow run code/main.nf -profile slurm -resume
```

CZ names contain commas, so `--zones` is **semicolon**-delimited. Provenance
(report/timeline/trace) lands in `output/_nf/`.

## Quality gates

```bash
# every reference must resolve (Crossref DOI or live URL) before submission
python code/scripts/verify_references.py manuscript/references.bib
```

## Provenance

The method is the population analogue of the LIHTC × crime cross-K engine in
[Kcross](https://github.com/Matthew-R-Lehnert/Kcross). Key difference: the
intensity here is an **external population raster**, not a KDE of the points, so
the bandwidth/floor/`eps` artifact class from that project does not arise.
