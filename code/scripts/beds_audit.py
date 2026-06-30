#!/usr/bin/env python3
"""
beds_audit.py -- document missing hospital bed counts (HIFLD -999 sentinel).

Beds drive two things: SUFFICIENCY (beds per 1,000) and the bed-weighted K
(missing beds are imputed with the zone median). Missing beds therefore (a) make
the sufficiency numerator a LOWER BOUND and (b) make the bed verdict less
reliable in zones where most beds are unknown. This quantifies both, nationally
and per commuting zone.

Outputs:
  docs/beds_missing.csv  -- per zone: n_hospitals, n_missing_beds, frac_missing,
                            beds_known_sum
  prints a national summary + the zones where imputation dominates.

Usage: python code/scripts/beds_audit.py [high_missing_threshold=0.5]
"""
from __future__ import annotations

import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd

THRESH = float(sys.argv[1]) if len(sys.argv) > 1 else 0.5
OUT = Path("docs/beds_missing.csv")


def main() -> int:
    h = gpd.read_file("data/hospitals.gpkg")
    cz = gpd.read_file("data/commuting_zones.gpkg")[["name", "geometry"]]
    h = h.to_crs(cz.crs)
    h["missing"] = ~np.isfinite(h["beds"])

    n = len(h); n_missing = int(h["missing"].sum())
    print("=== national ===")
    print(f"open hospitals:        {n}")
    print(f"missing bed count:     {n_missing}  ({n_missing/n*100:.1f}%)")
    print(f"with known beds:       {n - n_missing}")
    print(f"total known beds:      {np.nansum(h['beds']):,.0f}")
    print(f"median known beds:     {np.nanmedian(h['beds']):.0f}")

    j = gpd.sjoin(h, cz.rename(columns={"name": "cz"}), predicate="within")
    g = j.groupby("cz").agg(
        n_hospitals=("beds", "size"),
        n_missing_beds=("missing", "sum"),
        beds_known_sum=("beds", lambda s: np.nansum(s)),
    ).reset_index()
    g["frac_missing"] = g["n_missing_beds"] / g["n_hospitals"]
    g = g.sort_values("frac_missing", ascending=False)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    g.rename(columns={"cz": "name"}).to_csv(OUT, index=False)

    hi = g[g["frac_missing"] >= THRESH]
    print(f"\nzones with >= {THRESH:.0%} of beds missing (bed verdict unreliable): "
          f"{len(hi)} of {len(g)}")
    print(f"zones with ANY missing beds: {(g['n_missing_beds'] > 0).sum()} of {len(g)}")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
