# Python validation port

An independent reimplementation of the inhomogeneous-K population test
(`numpy`/`scipy`/`shapely`/`geopandas`), adapted from the validated Kcross
Python port. Its role is to **cross-check the R/`spatstat` reference engine** and
to run on platforms without R.

## Status

In progress. The Kcross port (cross-type K, CSR + inhomogeneous) is the
starting point; the adaptation here:

- replaces the KDE-estimated intensity with an **externally supplied population
  raster** (read with `rasterio`, normalized so `∫lambda = n`);
- switches the estimator from cross-type `Kcross.inhom` to the **univariate
  `Kinhom`** with that population intensity;
- simulates the null from `rpoispp(lambda)` over the raster grid (the
  `sim_inhomog` routine already exists in the Kcross port's `core.py`).

## Validation target

The R engine's `output/<kind>/<window>_envelope.csv` curves. The port should
match the **clustered/dispersed/consistent verdict** in every window and track
the observed `Kinhom(r)` shape closely; absolute scale may differ by a
normalization convention (documented in the Kcross port).

## Reference

Kcross Python port: <https://github.com/Matthew-R-Lehnert/Kcross/tree/main/python>
