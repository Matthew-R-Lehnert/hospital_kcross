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
$RS code/scripts/run_cz.R "CZ_19400" 2021 ambient

# national fan-out (all windows, both population kinds)
$RS code/scripts/run_all.R 2021 ambient 999 8
```

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
