#!/usr/bin/env python3
"""
effect_sizes.py -- report effect-size magnitudes for the family-wise-flagged
zones, so the results carry more than a "k of N, p = ..." statement.

Concentration (over-concentrated residential zones): from each zone's saved
Kinhom envelope, the variance-stabilized L-function excess L_obs - L_null (km)
at the distance of peak exceedance, where L(r) = sqrt(K(r)/pi). We use L, not a
raw K ratio, because K near r = 0 has a near-zero denominator that makes ratios
explode; L is in distance units and interpretable as an excess clustering
radius. We also report L_obs / L_null at that distance.

Coverage (under-served ambient deserts): from each zone's coverage envelope
(population fraction beyond distance d), the EXCESS population-weighted mean
distance to the nearest hospital over the null (km), by integrating the
survival curve, plus the peak excess stranded-population fraction.

Inputs:  output/residential/<key>_residential_all_envelope.csv
         output/ambient/<key>_ambient_coverage_envelope.csv
         output/{residential,ambient}/_global_across_zones_{all,coverage}.csv
Outputs: docs/effect_sizes_concentration.csv, docs/effect_sizes_coverage.csv
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


def concentration_effects() -> pd.DataFrame:
    fw = pd.read_csv("output/residential/_global_across_zones_all.csv")
    zones = fw.loc[fw.fw_verdict == "over-concentrated", "window"]
    rows = []
    for key in zones:
        f = Path(f"output/residential/{key}_residential_all_envelope.csv")
        if not f.exists():
            continue
        d = pd.read_csv(f)
        d = d[(d.x > 0) & np.isfinite(d.obs) & np.isfinite(d.mmean) & (d.mmean > 0)].copy()
        # L-function ratio (variance-stabilized and scale-free): L = sqrt(K/pi),
        # so L_obs/L_null cancels the intensity-weighted absolute scale. Evaluate
        # at a fixed, interpretable distance (10 km, or the zone's max r if the
        # window is small), NOT at the peak, which sits at noisy small r.
        d["L_ratio"] = np.sqrt(d.obs / d.mmean)          # = L_obs / L_null
        eval_km = min(10.0, d.x.max() / 1000)
        row = d.iloc[(d.x - eval_km * 1000).abs().argmin()]
        # distance at which observed clustering first exceeds the null envelope
        exceed = d[d.obs > d.hi]
        first_km = round(exceed.x.min() / 1000, 1) if len(exceed) else np.nan
        rows.append(dict(zone=key,
                         L_ratio_at_10km=round(row.L_ratio, 2),
                         eval_distance_km=round(eval_km, 1),
                         first_exceed_km=first_km))
    return pd.DataFrame(rows).sort_values("L_ratio_at_10km", ascending=False)


def coverage_effects() -> pd.DataFrame:
    fw = pd.read_csv("output/ambient/_global_across_zones_coverage.csv")
    zones = fw.loc[fw.fw_verdict == "under-served", "window"]
    rows = []
    for key in zones:
        f = Path(f"output/ambient/{key}_ambient_coverage_envelope.csv")
        if not f.exists():
            continue
        d = pd.read_csv(f).sort_values("x")
        x = d.x.to_numpy()
        # mean distance = integral of P(dist > d) dd (survival-curve identity)
        mean_obs = np.trapz(d.obs.to_numpy(), x)
        mean_null = np.trapz(d.mmean.to_numpy(), x)
        excess = d.obs - d.mmean
        ipk = excess.to_numpy().argmax()
        rows.append(dict(zone=key,
                         excess_mean_dist_km=round((mean_obs - mean_null) / 1000, 1),
                         peak_excess_pop_frac=round(float(excess.iloc[ipk]), 3),
                         at_distance_km=round(x[ipk] / 1000, 1)))
    return pd.DataFrame(rows).sort_values("excess_mean_dist_km", ascending=False)


def main() -> int:
    conc = concentration_effects()
    cov = coverage_effects()
    conc.to_csv("docs/effect_sizes_concentration.csv", index=False)
    cov.to_csv("docs/effect_sizes_coverage.csv", index=False)
    print("=== Concentration (residential over-concentrated) ===")
    print(conc.to_string(index=False))
    print(f"\n  L_obs/L_null at 10 km: median {conc.L_ratio_at_10km.median():.2f}, "
          f"range {conc.L_ratio_at_10km.min():.2f}-{conc.L_ratio_at_10km.max():.2f}")
    print("\n=== Coverage (ambient deserts) ===")
    print(cov.to_string(index=False))
    print(f"\n  excess mean distance range {cov.excess_mean_dist_km.min():.1f}-"
          f"{cov.excess_mean_dist_km.max():.1f} km")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
