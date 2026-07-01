# Results

All results use the 2020 vintage (LandScan ambient and GPWv4.11 residential
population, USDA 2020 commuting zones, HIFLD hospitals). Point-process tests use
999 simulations and the global extreme-rank-length (ERL) envelope, corrected for
family-wise error across zones. Numbers are generated from `output/summary.csv`
and the across-zone tests; per-zone diagnoses are in `output/typology_*.csv`.

## Sample

The 597 US commuting zones contain 7,966 open hospitals (1,087,608 known staffed
beds). Every zone receives a **sufficiency** value and, where it has at least one
hospital, a **coverage** test (585 zones); the 12 zones with no hospital are
reported separately. The second-order **concentration** test is computed for the
261 zones with at least 8 hospitals, which together hold about 91% of the
population. Each analysis is run twice, under ambient and residential population.

## Concentration

Whether hospital locations are more clustered than population depends entirely on
the population surface. Under **residential** population, **15 of 261** zones are
significantly over-concentrated on facilities (combined family-wise
$p = 0.002$) and **13 of 261** on beds ($p = 0.001$). Under **ambient**
population, the signal vanishes: **0 of 261** zones on either facilities
($p = 0.47$) or beds. In other words, hospital clustering that looks excessive
against where people sleep is fully consistent with where people are during the
day. The over-concentrated (residential) set is led by large and mid-size metros
(for example Dallas, San Diego, Philadelphia, Orlando, Las Vegas, New Orleans).

The bed-weighted test is not redundant with the facility test: capacity and
building count diverge. Of the residential-population zones flagged, 9 are
over-concentrated on both facilities and beds, 6 on facilities only (Brownsville,
Dallas, Dayton, Erie, Johnson City, San Diego, where many similarly sized
hospitals cluster without concentrating capacity), and 4 on beds only (Allentown,
Augusta, Jacksonville, Saginaw, where a few large hospitals concentrate capacity
even where building locations are not over-clustered). Measuring capacity
therefore flags zones a facility-count analysis would miss. The bed weighting
imputes the 5.2% of hospitals with an unknown bed count; the 9 zones where more
than half of beds are unknown are flagged and excluded from bed claims.

## Coverage

The pattern reverses on coverage. Under **ambient** population, **6 of 585**
zones have populations significantly farther from care than a population-
proportional placement would leave them (combined $p = 0.001$): Amarillo,
Dallas, Detroit, Houston, San Diego, and San Juan (PR). Under **residential**
population, **0 of 585** survive family-wise correction ($p = 0.126$). The
ambient lens reveals access gaps that the residential surface hides. Because
coverage credits hospitals within 50 km across zone boundaries, these are not
edge artifacts. <!-- Figure: fig_dallas_ambient_desert.png -->

## Sufficiency

Zone-level capacity is right-skewed: the median zone has 4.6 (ambient) / 4.4
(residential) staffed beds per 1,000, well above the US population-weighted
average of ~2.8 [@kff_beds_2020], because many low-population rural zones carry
high per-capita capacity while dense metros sit low, the documented rural-urban
capacity gradient [@hegland_owens_selden_2022]. Below the US reference fall **88** zones
under ambient and **114** under residential population; below the OECD reference
(~4.3), 251 and 289 respectively. The denominator matters: commuter-destination
zones look better supplied on residential population and worse on ambient, and
the reverse for bedroom communities.

## The diagnostic typology

Combining the three corrected axes classifies each zone (Table 1; Figures
fig_typology_ambient, fig_typology_residential).

| Diagnosis | Ambient | Residential |
|-----------|--------:|------------:|
| no hospital | 12 | 12 |
| shortage | 0 | 0 |
| maldistribution | 0 | 0 |
| geographic gap | 6 | 0 |
| capacity shortfall | 76 | 102 |
| redundancy | 0 | 13 |
| well-matched | 503 | 470 |

Two structural results stand out. First, **over-concentration and under-service
never co-occur** in the same zone (maldistribution = 0 under either surface),
because the two are driven by different population surfaces. Second, the
dominant flagged category flips with the demand surface: residential population
yields a **redundancy** story (13 zones, over-provision) and no coverage gaps,
whereas ambient population yields a **geographic-gap** story (6 zones) and no
redundancy.

## Ambient versus residential

**44 of 597 zones change diagnosis** between the two surfaces. The clearest
cases are metros that are simultaneously over-concentrated against residential
population and under-served against ambient population, so their diagnosis moves
from *redundancy* (residential) to *geographic gap* (ambient): Dallas, San
Diego, and Amarillo are in both flagged sets. Dallas is illustrative (Figures
fig_dallas_residential_concentration, fig_dallas_ambient_coverage,
fig_dallas_ambient_desert): its hospitals cluster beyond nighttime population yet
leave daytime population comparatively far from care. The demand surface does
not refine the conclusion; it reverses it.

This reversal is driven by the day-versus-night timing of the demand surface,
not by how the surface is built. LandScan (ambient) is a dasymetric, modeled
product while GPW (residential) is areal, so a modeled-versus-areal difference
could in principle confound the ambient-versus-residential contrast. We rule
that out with a third surface, WorldPop, which is modeled like LandScan but
residential like GPW. Under WorldPop, hospital concentration behaves like the
residential (GPW) surface, not the ambient one: 18 of 257 zones are
significantly over-concentrated on facilities (combined $p = 0.001$) and 17 on
beds, with 0 of 575 zones under-served on coverage ($p = 0.48$). Both
residential surfaces, whether areal (GPW) or modeled (WorldPop), yield
over-concentration and no coverage gaps, while the ambient surface yields the
reverse. The effect therefore tracks whether population is counted by day or by
night, not the construction of the raster. (WorldPop is US-only, so Puerto Rico
and a small number of coverage-gap zones are absent, leaving 257 rather than 261
concentration zones; this does not affect the comparison.)

## Validation and robustness

Type-I calibration by simulation (target 0.05) gives facilities 0.040, beds
0.043, and coverage 0.040, confirming the estimators, including the newer bed
and coverage constructions, are well behaved. A power analysis against an
inhomogeneous Thomas over-concentration alternative (cluster scale 2.5 km) shows
power rising from 0.67 at 8 hospitals to 0.80 at 10 and 0.99 at 30, with Type-I
near nominal throughout, so the 8-hospital floor is permissive rather than
lax. The concentration result is stable to that floor: re-running the residential
facility test at minimum 8, 10, and 15 hospitals flags 15, 14, and 9 zones
(combined $p = 0.002, 0.002, 0.028$) and the bed test 13, 12, and 9, so raising
the threshold only shrinks the eligible pool without overturning the finding.

The coverage (desert) results are invariant to the cross-border buffer distance.
Recomputing the coverage test for the ambient under-served zones at 25, 50, and
100 km buffers leaves every zone's verdict unchanged: Amarillo, Dallas, Detroit,
Houston, and San Juan remain significantly under-served at all three distances,
and San Diego remains borderline throughout. Crediting hospitals as far as 100 km
across zone boundaries therefore does not dissolve the deserts, so they are not
an artifact of the 50 km default.

<!-- TODO (running): CBSA-window re-run; WorldPop modeled-residential control. -->
