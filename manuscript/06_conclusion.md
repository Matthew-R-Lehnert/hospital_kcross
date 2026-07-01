# Conclusion

## Summary

We characterized US hospital supply on three orthogonal axes, concentration,
coverage, and sufficiency, in every commuting zone, each against a
population-proportional null and contrasted between ambient and residential
population. The central result is that the demand surface reverses the
conclusion: against residential population the country shows significant hospital
over-concentration and no coverage gaps, while against ambient population the
over-concentration vanishes and genuine coverage gaps appear instead. Forty-four
zones change diagnosis between the two surfaces, and over-concentration and
under-service are not found together in the same zone (partly structural, since
concentration is tested only in the hospital-dense zones). The pattern holds up
under scrutiny: it is stable to the hospital-count threshold and the coverage
buffer, a WorldPop control shows the reversal is about day-versus-night timing
rather than raster construction, neutralizing the population LandScan places at
the hospital sites themselves leaves the ambient result unchanged, and a re-run
on CBSA windows reproduces the concentration result while confirming that the
coverage deserts live in the rural areas only the commuting-zone partition
captures.

## Limitations

- **Static hospital snapshot, and a vintage gap.** HIFLD is a single
  cross-section current to about mid-2024 (its records carry 2024 source dates),
  which we test against 2020 population, commuting zones, and rasters, a roughly
  four-year gap. The dataset carries no per-facility opening or closing date and
  no 2020-vintage layer was available to us, so we cannot re-run on a
  contemporaneous hospital geography. Two considerations bound the concern. The
  coverage deserts are conservative with respect to this gap: a hospital that
  opened between 2020 and 2024 and appears in our layer makes a zone look less
  deserted than it was in 2020, while a closure we cannot see would make it worse,
  so the six deserts are lower bounds. The over-concentration result is a
  family-wise finding across 262 zones with large effect sizes (a median tenfold-
  scale clustering ratio near three), which the low-single-digit-percent net
  change in the US hospital stock over four years cannot manufacture. A dated
  HIFLD or CMS panel would still enable a stronger, truly longitudinal design.
- **Ambient is not acute demand.** Ambient population is a better proxy than
  residential for where acute events occur, but it is still a proxy. True demand
  also depends on age structure, morbidity, and case mix, which a population
  surface does not capture.
- **Modeled versus areal construction.** The LandScan (ambient, modeled) versus
  GPW (residential, areal) contrast could in principle mix timing with raster
  construction. A WorldPop control (modeled but residential) resolves this: it
  behaves like the residential surface, so the effect tracks day-versus-night
  timing, not construction. A residual limitation is that WorldPop is US-only, so
  Puerto Rico is absent from that check.
- **Window dependence.** Results are conditional on the commuting-zone
  partition. The CBSA re-run shows the concentration finding is insensitive to
  the partition, but the coverage deserts are visible only with commuting zones,
  because CBSAs exclude the rural fringe where the under-served populations sit.
  The coverage conclusion is thus specific to a whole-country partition; a
  metropolitan-only windowing would miss it by construction.
- **Distance, not travel time.** All distances are Euclidean, whereas real
  access depends on roads, terrain, and traffic. The method answers a question
  about spatial distribution that complements, rather than replaces, travel-time
  accessibility models; the reported distance thresholds (10, 25, 35 miles) are
  straight-line approximations.
- **Containment.** The coverage axis credits hospitals within a 50 km buffer
  across zone boundaries, which removes false edge deserts, but concentration and
  sufficiency remain in-zone quantities, so a zone whose residents routinely use
  a neighbor's hospitals may still be mischaracterized on those two axes. The USDA
  commuting-zone design (built for self-containment) limits this, and the
  `CZContainment` measure flags the most exposed zones.
- **Beds missing for some hospitals.** 5.2% of hospitals lack a bed count;
  sufficiency is therefore a lower bound, and bed-concentration verdicts in the
  9 zones where most beds are unknown are imputation-driven and flagged.

## Implications

The choice of demand surface is not a technical detail; it reframes the policy
question. A residential denominator invites a reading of urban supply as
excessive, while an ambient denominator recasts the same metros as places with
daytime access gaps. We stop short of prescribing that capacity be removed:
statistical over-concentration relative to a population-proportional null is not
by itself evidence of inefficiency or inequity, since hospital location also
reflects agglomeration, tertiary-referral role, historical siting, and
certificate-of-need regulation, none of which this test observes. What the
analysis does license is narrower and, we think, more useful: that an
accessibility assessment can flip between "over-supplied" and "under-serving" for
the same place purely on the demand surface, so the ambient framing deserves
weight alongside the residential default in capacity and siting deliberations.
The diagnostic typology further separates the distinct failures, too little
capacity, capacity in the wrong place, and populations left far from care, each
of which calls for a different response.

## Reproducibility and data availability

All inputs are public (HIFLD via DataLumos; LandScan Global via ORNL; GPWv4.11
via NASA SEDAC; commuting zones via USDA ERS and Census TIGER). Code and the
exact acquisition steps are in the project repository under `code/`.
