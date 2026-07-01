# Skipped zones: the minimum-hospital inclusion criterion

*Reproducible: `python code/scripts/skipped_zones.py 8` regenerates the summary*
*below and `docs/skipped_zones.csv` (every zone, its hospital count, ambient*
*population, area, and included/skipped flag).*

## Why a minimum hospital count

The instrument is the **inhomogeneous K-function**, a **second-order** (pairwise)
summary of a point pattern. Estimating it requires enough points to form enough
pairs; with only a handful of hospitals a zone yields too few pairs, the
Monte-Carlo envelope becomes degenerate and uninformative, and the test has
essentially no power (a near-certain "consistent" verdict regardless of the true
arrangement). We therefore do not compute K_inhom for a zone below a minimum
hospital count, set to **8** (`min_hospitals` in `code/R/hk_core.R`). Eight is a
permissive floor: it is the lowest count at which the estimator is non-degenerate,
not a count at which it is highly powered. Verdicts for zones just above the
threshold should be read with that caveat, and we recommend a sensitivity check
at higher thresholds (e.g., 10 and 15) to confirm the headline verdicts are not
threshold-sensitive.

## These zones are not ignored: only the K test is gated

The minimum applies **only to the concentration (K) axis**. The **coverage** and
**sufficiency** axes are computed for *every* zone with at least one hospital,
including all the sparse ones below the threshold. This is deliberate: a zone
with few hospitals and substantial population is a candidate access desert, and
"are hospitals *clustered relative to population*" is the wrong question there
(there is no cluster structure to test), whereas "how far is the population from
the nearest hospital" (coverage) and "are there enough beds per person"
(sufficiency) remain well-defined and are exactly right. So the rural zones the
K test cannot speak to are precisely the ones coverage and sufficiency do cover.
Only concentration is restricted to the 262 zones with at least 8 hospitals.

## Summary (threshold = 8 hospitals, LandScan 2020 ambient population)

| | zones | share of ambient population |
|---|------:|----------------------------:|
| **Analyzed** (n_hospitals >= 8) | 262 | **91.2%** |
| **Skipped** (n_hospitals < 8)   | 336 | 8.8% |
| of which zero-hospital zones    | 12  | |
| **Total**                       | 598 | 100% |

So although a majority of *zones* (336 of 598) fall below the threshold, they
contain under 9% of the ambient population: the K-function analysis still speaks
to roughly **91% of where Americans are during the day**. Skipped zones are also
not simply "the largest rural ones" (skipped median area 8,438 km^2 vs analyzed
median 12,389 km^2); they are predominantly **low-population** zones, which is
exactly why they carry few hospitals and little population weight.

## Reproducibility

`docs/skipped_zones.csv` lists all 598 zones with `n_hospitals`, `ambient_pop`,
`area_km2`, and `included`. Regenerate with:

```bash
python code/scripts/skipped_zones.py 8     # threshold as first arg
```
