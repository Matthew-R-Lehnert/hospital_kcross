#!/usr/bin/env python3
"""
skipped_zones.py -- document commuting zones excluded from the K-function test
for having too few hospitals (default < 8).

Why a minimum: the inhomogeneous K-function is a SECOND-ORDER (pairwise) summary.
With only a handful of points there are too few pairs to estimate it; the
simulation envelope becomes degenerate/uninformative and the test has no power.
We therefore set a minimum hospital count below which K_inhom is not computed.
These zones are NOT ignored: they are reported here with their population so the
reader can see exactly what (and how much population) is set aside, and they are
the natural subject of a complementary coverage/distance access metric.

Outputs (committed, under docs/):
  docs/skipped_zones.csv  -- one row per zone: name, n_hospitals, ambient_pop,
                             area_km2, included (n >= threshold)
  prints a summary (counts + population share) for docs/skipped_zones.md.

Usage:
  python code/scripts/skipped_zones.py [min_hospitals=8] [landscan_tif]
"""
from __future__ import annotations

import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd

MIN = int(sys.argv[1]) if len(sys.argv) > 1 else 8
TIF = sys.argv[2] if len(sys.argv) > 2 else "data/landscan/landscan-global-2020.tif"
OUT = Path("docs/skipped_zones.csv")


def zone_population(cz: gpd.GeoDataFrame, tif: str) -> np.ndarray:
    """Ambient population sum per zone (LandScan 2020), negatives->0."""
    import rasterio
    from rasterio.mask import mask
    pops = []
    with rasterio.open(tif) as src:
        czr = cz.to_crs(src.crs)
        for geom in czr.geometry:
            try:
                arr, _ = mask(src, [geom], crop=True, filled=True, nodata=0)
                a = arr.astype("float64")
                a[a < 0] = 0.0
                pops.append(float(np.nansum(a)))
            except Exception:
                pops.append(float("nan"))
    return np.array(pops)


def main() -> int:
    cz = gpd.read_file("data/commuting_zones.gpkg")[["name", "geometry"]]
    h = gpd.read_file("data/hospitals.gpkg")[["geometry"]].to_crs(cz.crs)
    cnt = gpd.sjoin(h, cz.rename(columns={"name": "z"}), predicate="within") \
            .groupby("z").size()
    cz["n_hospitals"] = cz["name"].map(cnt).fillna(0).astype(int)
    cz["area_km2"] = cz.to_crs(5070).area / 1e6
    cz["ambient_pop"] = zone_population(cz, TIF)
    cz["included"] = cz["n_hospitals"] >= MIN

    out = cz[["name", "n_hospitals", "ambient_pop", "area_km2", "included"]] \
        .sort_values(["included", "n_hospitals", "name"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT, index=False)

    tot_pop = cz["ambient_pop"].sum()
    skip = cz[~cz["included"]]
    inc = cz[cz["included"]]
    print(f"threshold: n_hospitals >= {MIN}")
    print(f"zones total:    {len(cz)}")
    print(f"  included:     {len(inc)}  ({inc['ambient_pop'].sum()/tot_pop*100:.1f}% of ambient pop)")
    print(f"  skipped:      {len(skip)}  ({skip['ambient_pop'].sum()/tot_pop*100:.1f}% of ambient pop)")
    print(f"  of skipped, zero-hospital zones: {(skip['n_hospitals']==0).sum()}")
    print(f"  skipped median area: {skip['area_km2'].median():.0f} km2  "
          f"(included median: {inc['area_km2'].median():.0f} km2)")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
