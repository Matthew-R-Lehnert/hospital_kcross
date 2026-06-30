# Hospital × Population — Inhomogeneous K-Function Analysis

Are U.S. hospitals spatially distributed *in proportion to the population they
serve*? This study tests, across every U.S. metropolitan and micropolitan area,
whether hospital locations follow population — flagging systematic
**over-concentration** (urban redundancy) and **under-served gaps** (access
deserts).

The instrument is an **inhomogeneous Ripley's K-function** of hospital point
locations whose null intensity is set **proportional to population**, evaluated
against a Monte-Carlo simulation envelope. The headline novelty is the use of
**ambient (24-hour) population** (ORNL LandScan) as the point-process null —
where people actually are during the day — contrasted against conventional
**residential** (nighttime) population, applied **nationally** with
family-wise-corrected formal hypothesis tests.

This is the population analogue of the [Kcross](https://github.com/Matthew-R-Lehnert/Kcross)
LIHTC × crime study, re-framed for healthcare access. Crucially, because the
intensity λ is supplied **externally** by a population raster rather than
kernel-estimated from sparse points, the entire bandwidth/floor/`eps` artifact
class that dominated Kcross **does not arise here**.

## Goal

A peer-reviewed publication. The repository is organized as a manuscript.

## Repository layout

```
manuscript/      The paper — one file per section (THIS is what gets submitted)
  00_abstract.md
  01_introduction.md
  02_related_work.md      (literature review)
  03_data.md
  04_methods.md
  05_results.md
  06_conclusion.md
  references.bib          (single, style-agnostic bibliography source of truth)
  csl/                    citation styles (APA / Chicago / Vancouver …)
  Makefile                pandoc build: `make STYLE=apa` etc.
  figures/

code/            All analysis code (NOT submitted with the manuscript)
  R/               canonical spatstat reference engine
  python/          independent validation port
  acquire/         data acquisition (hospitals, LandScan, CBSA windows)
  scripts/         per-CBSA and national runners
  requirements.txt

data/            raw + derived inputs (gitignored)
output/          results: envelopes, maps, tables (gitignored)
docs/            design notes, methodology working docs
```

## Reproduce

```bash
# 1. acquire data (AWS creds for the S3 raw mirror; internet for TIGER/SEDAC)
python code/acquire/01_hospitals.py
python code/acquire/02_commuting_zones.py
python code/acquire/03_landscan.py 2021       # ambient population (one year)
python code/acquire/04_gpw.py 2020            # residential population (contrast)

# 2. run one commuting zone (R/spatstat reference engine)
Rscript code/scripts/run_cz.R "Phoenix AZ" 2021 ambient

# 3. build the manuscript in a given citation style
cd manuscript && make STYLE=apa            # -> manuscript.pdf (APA refs)
cd manuscript && make STYLE=chicago-author-date
```

> **R is not on `PATH`** on the dev machine but is installed at
> `/Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/bin/Rscript`
> with the full `spatstat` stack. Add it to `PATH` or call it by full path.

## License

Code: MIT (see `LICENSE`). Manuscript text & figures: see `manuscript/LICENSE`
(CC-BY-4.0 proposed — confirm with target journal).
