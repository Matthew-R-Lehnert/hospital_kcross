# Missing bed counts (HIFLD `-999` sentinel)

*Reproducible: `python code/scripts/beds_audit.py` regenerates the summary below*
*and `docs/beds_missing.csv` (per-zone missing-bed counts).*

HIFLD records an unknown staffed-bed count as `-999`, which we mask to missing.
Missing beds affect two of the three axes:

- **Sufficiency** (beds per 1,000): the bed total is the numerator, so missing
  beds make each zone's ratio a **lower bound**. We sum only known beds and
  report the missing rate alongside.
- **Bed-weighted concentration**: missing beds are imputed with the zone median
  before the bed-K test, so a zone where most beds are unknown yields an
  imputation-dominated, **unreliable** bed verdict.

Coverage and facility concentration do not use beds and are unaffected.

## National summary

| | value |
|---|------:|
| open hospitals | 7,966 |
| missing bed count | **415 (5.2%)** |
| with known beds | 7,551 |
| total known beds | 1,087,608 |
| median known beds | 70 |

Missing beds are uncommon nationally (5.2%), so imputation barely moves most
zones. The exception is a small set of zones where unknowns dominate:

- **9 of 586** hospital-bearing zones have **>= 50%** of beds missing -> their
  bed verdict is imputation-driven and is **flagged unreliable** (reported but
  excluded from headline bed claims).
- **182 of 586** zones have at least one hospital with a missing bed count.

The per-zone file `docs/beds_missing.csv` (`name, n_hospitals, n_missing_beds,
frac_missing, beds_known_sum`) lets any zone's bed result be qualified by its
missing-bed share.
