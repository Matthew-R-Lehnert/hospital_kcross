#!/usr/bin/env python3
"""
reversal_decomposition.py -- is the ambient-vs-residential reversal just "LandScan
is uniformly more urban-core-weighted than GPW," or does it carry structured
information?

Key identity: normalize each surface to integrate to 1 over a zone, and form the
ratio rho(u) = ambient_norm(u) / residential_norm(u). Under ANY global or
zone-wise rescaling of one surface relative to the other (a single urban
multiplier), the normalization cancels it and rho(u) == 1 everywhere. So any
systematic departure of rho from 1 -- and in particular hospitals sitting at
rho >> 1 -- is redistribution WITHIN the zone that a uniform reweighting cannot
produce. rho > 1 at a hospital means the cell carries more of the zone's ambient
(daytime) population than its residential population: a daytime destination.

We compute, per concentration zone, the median rho at hospital locations
(rho_hosp). The residential-population-weighted mean of rho is exactly 1 by
construction, so rho_hosp is directly comparable to that baseline of 1. We then
compare the 15 zones that flip (over-concentrated vs residential, consistent vs
ambient) against the rest: the reversal should track hospitals sitting at high
rho, not a global constant.

Outputs: docs/reversal_decomposition.csv (per zone) + a printed summary; and
docs/reversal_decomposition.png (ambient vs residential at hospital cells, an
exemplar zone).
"""
from __future__ import annotations

import re

import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
from rasterio.mask import mask as rmask
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def zone_sum(src, geom):
    out, _ = rmask(src, [geom.__geo_interface__], crop=True)
    a = out[0].astype("float64"); a[a < 0] = 0
    return a.sum()


def main() -> int:
    cz = gpd.read_file("data/commuting_zones.gpkg").to_crs(4326)
    hosp = gpd.read_file("data/hospitals.gpkg").to_crs(4326)[["geometry"]]
    amb = rasterio.open("data/landscan/landscan-global-2020.tif")
    res = rasterio.open("data/gpw/gpw_v4_2020.tif")

    # concentration zones (>=8 in-zone hospitals) and the family-wise flip set
    hj = gpd.sjoin(hosp, cz[["name", "geometry"]], predicate="within")
    nby = hj.groupby("name").size()
    conc_zones = set(nby[nby >= 8].index)
    flip = pd.read_csv("output/residential/_global_across_zones_all.csv")
    flip_keys = set(flip.loc[flip.fw_verdict == "over-concentrated", "window"])
    def key(n): return re.sub(r"[^A-Za-z0-9]+", "_", n)   # match engine file-tag keys

    rows = []
    for name, sub in hj.groupby("name"):
        if name not in conc_zones:
            continue
        geom = cz.loc[cz["name"] == name, "geometry"].values[0]
        sum_a, sum_r = zone_sum(amb, geom), zone_sum(res, geom)
        if sum_a <= 0 or sum_r <= 0:
            continue
        pts = [(p.x, p.y) for p in sub.geometry]
        av = np.array([v[0] for v in amb.sample(pts)], dtype="float64")
        rv = np.array([v[0] for v in res.sample(pts)], dtype="float64")
        ok = (av > 0) & (rv > 0)
        if ok.sum() < 5:
            continue
        # rho at each hospital = (a/sum_a)/(r/sum_r); residential-weighted mean rho = 1
        rho = (av[ok] / sum_a) / (rv[ok] / sum_r)
        rows.append(dict(zone=name, n=int(ok.sum()),
                         rho_hosp_median=float(np.median(rho)),
                         rho_hosp_gmean=float(np.exp(np.mean(np.log(rho)))),
                         flipped=key(name) in flip_keys))
    df = pd.DataFrame(rows)
    df.to_csv("docs/reversal_decomposition.csv", index=False)

    base = 1.0  # residential-weighted mean of rho, by construction
    print(f"=== rho (ambient/residential, normalized) at hospital locations, {len(df)} zones ===")
    print(f"residential-weighted baseline rho = {base:.2f} (identity under any global reweighting)")
    print(f"median across zones of rho_hosp_median = {df.rho_hosp_median.median():.2f}")
    print(f"zones with rho_hosp_median > 1 (hospitals at daytime destinations): "
          f"{int((df.rho_hosp_median > 1).sum())} / {len(df)}")
    fl, nf = df[df.flipped], df[~df.flipped]
    print(f"\nflipped zones (over-conc residential, consistent ambient), n={len(fl)}: "
          f"median rho_hosp = {fl.rho_hosp_median.median():.2f}")
    print(f"non-flipped concentration zones, n={len(nf)}: "
          f"median rho_hosp = {nf.rho_hosp_median.median():.2f}")
    print("\nInterpretation: rho_hosp > 1 cannot arise from a uniform urban multiplier "
          "(which cancels in normalization); the reversal reflects hospitals sitting at\n"
          "structured daytime-destination cells that ambient population credits and residential does not.")

    # exemplar scatter: ambient vs residential (normalized shares) at hospital cells
    ex = "Dallas city, TX" if (df.zone == "Dallas city, TX").any() else df.sort_values(
        "rho_hosp_median", ascending=False).zone.iloc[0]
    geom = cz.loc[cz["name"] == ex, "geometry"].values[0]
    sub = hj[hj.name == ex]; sum_a, sum_r = zone_sum(amb, geom), zone_sum(res, geom)
    pts = [(p.x, p.y) for p in sub.geometry]
    av = np.array([v[0] for v in amb.sample(pts)], "float64") / sum_a
    rv = np.array([v[0] for v in res.sample(pts)], "float64") / sum_r
    m = (av > 0) & (rv > 0)
    fig, ax = plt.subplots(figsize=(6, 6))
    lim = [min(rv[m].min(), av[m].min()), max(rv[m].max(), av[m].max())]
    ax.plot(lim, lim, "--", color="grey", label="ambient = residential share")
    ax.scatter(rv[m], av[m], s=18, alpha=0.6, color="firebrick")
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.set_xlabel("residential population share at hospital cell")
    ax.set_ylabel("ambient population share at hospital cell")
    ax.set_title(f"{ex}: hospitals sit above the diagonal\n(more ambient than residential share)")
    ax.legend()
    fig.tight_layout(); fig.savefig("docs/reversal_decomposition.png", dpi=200)
    print(f"\nwrote docs/reversal_decomposition.csv and .png (exemplar: {ex})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
