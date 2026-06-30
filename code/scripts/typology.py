#!/usr/bin/env python3
"""
typology.py -- combine the three axes into a per-zone diagnosis and tabulate it
nationally, per population surface, with the ambient-vs-residential flip set.

Inputs (produced after the national run):
  output/summary.csv                              per zone x layer: verdict,
                                                  global_p, beds_per_1000, etc.
  output/<kind>/_global_across_zones_all.csv      family-wise-corrected concentration
  output/<kind>/_global_across_zones_coverage.csv family-wise-corrected coverage
        (written by code/R/global_across_zones.R; if absent we fall back to the
         within-zone verdicts in summary.csv and say so)

The diagnosis is an explicit, transparent mapping of the three axis states; the
raw triple is also written so a reader can reclassify. "Low" sufficiency means
beds per 1,000 below the US national average (ratio_to_US < 1).

Outputs:
  output/typology_<kind>.csv      window, conc, cov, beds_per_1000, ratio_to_US,
                                  suff_low, diagnosis
  output/typology_flips.csv       zones whose diagnosis differs ambient vs residential
  prints the per-diagnosis counts for each surface.

Usage: python code/scripts/typology.py [suff_ratio_cutoff=1.0]
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

CUT = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0   # ratio_to_US below this = "low"
KINDS = ["ambient", "residential"]
DIAGNOSES = ["shortage", "maldistribution", "geographic gap",
             "capacity shortfall", "redundancy", "well-matched", "incomplete"]


def diagnose(conc: str, cov: str, suff_low: bool) -> str:
    """Map the three axis verdicts to one named diagnosis (priority order)."""
    if conc is None or cov is None:
        return "incomplete"                     # zone skipped on a point-pattern axis
    under = cov == "under-served"
    overc = conc == "over-concentrated"
    if suff_low and under:   return "shortage"          # too few AND people stranded
    if under and overc:      return "maldistribution"   # enough but clumped; fringe stranded
    if under:                return "geographic gap"    # stranded despite proportional/spread supply
    if suff_low:             return "capacity shortfall"  # thin supply, but people reachable
    if overc:                return "redundancy"        # clumped, adequately/over-covered
    return "well-matched"


def fw_map(kind: str, layer: str) -> dict | None:
    """Family-wise-corrected verdicts {window: verdict}, or None if not yet run."""
    f = Path(f"output/{kind}/_global_across_zones_{layer}.csv")
    if not f.exists():
        return None
    d = pd.read_csv(f)
    return dict(zip(d["window"], d["fw_verdict"]))


def build(kind: str, summ: pd.DataFrame) -> tuple[pd.DataFrame, str]:
    s = summ[summ["pop_kind"] == kind]
    conc_fw, cov_fw = fw_map(kind, "all"), fw_map(kind, "coverage")
    mode = "family-wise-corrected" if (conc_fw and cov_fw) else "within-zone (family-wise files not found)"
    rows = []
    for win, g in s.groupby("window"):
        by = g.set_index("layer")
        ratio = by["ratio_to_US"].dropna().iloc[0] if "ratio_to_US" in by and by["ratio_to_US"].notna().any() else None
        def verdict(layer, fw):
            if fw is not None and win in fw:
                return fw[win]
            return by.loc[layer, "verdict"] if layer in by.index and pd.notna(by.loc[layer, "verdict"]) else None
        conc = verdict("facilities", conc_fw)
        cov  = verdict("coverage", cov_fw)
        suff_low = (ratio is not None) and (ratio < CUT)
        rows.append(dict(window=win, conc=conc, cov=cov, beds_per_1000=by.get("beds_per_1000"),
                         ratio_to_US=ratio, suff_low=suff_low,
                         diagnosis=diagnose(conc, cov, suff_low)))
    return pd.DataFrame(rows), mode


def main() -> int:
    summ = pd.read_csv("output/summary.csv")
    results = {}
    for kind in KINDS:
        if not (summ["pop_kind"] == kind).any():
            continue
        df, mode = build(kind, summ)
        df.to_csv(f"output/typology_{kind}.csv", index=False)
        results[kind] = df
        counts = df["diagnosis"].value_counts().reindex(DIAGNOSES, fill_value=0)
        print(f"=== {kind} ({mode}); n_zones={len(df)} ===")
        for diag in DIAGNOSES:
            print(f"  {diag:20s} {counts[diag]:4d}")
        print()

    if "ambient" in results and "residential" in results:
        a = results["ambient"].set_index("window")["diagnosis"]
        r = results["residential"].set_index("window")["diagnosis"]
        common = a.index.intersection(r.index)
        flips = pd.DataFrame({"window": common, "ambient": a[common].values,
                              "residential": r[common].values})
        flips = flips[flips["ambient"] != flips["residential"]]
        flips.to_csv("output/typology_flips.csv", index=False)
        print(f"=== ambient vs residential: {len(flips)} of {len(common)} zones change diagnosis ===")
        print(flips.head(20).to_string(index=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
