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
under-service are never found together in the same zone. The pattern holds up
under scrutiny: it is stable to the hospital-count threshold and the coverage
buffer, a WorldPop control shows the reversal is about day-versus-night timing
rather than raster construction, and a re-run on CBSA windows reproduces the
concentration result while confirming that the coverage deserts live in the
rural areas only the commuting-zone partition captures.

## Limitations

- **Static hospital snapshot.** HIFLD is a single cross-section dated about
  2024. We test a fixed hospital geography against time-varying population, so we
  cannot speak to hospital openings or closings over time. A dated HIFLD or CMS
  panel would enable a true longitudinal design.
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

The choice of demand surface is not a technical detail; it determines the policy
story. A residential denominator points toward curbing urban over-provision,
while an ambient denominator points toward closing daytime access gaps in the
same metros. Because acute care is needed where people are when an emergency
occurs, not only where they sleep, the ambient framing deserves weight in
capacity and siting decisions. The diagnostic typology further separates the
distinct failures, too little capacity, capacity in the wrong place, and
populations left far from care, each of which calls for a different response.

## Reproducibility and data availability

All inputs are public (HIFLD via DataLumos; LandScan Global via ORNL; GPWv4.11
via NASA SEDAC; commuting zones via USDA ERS and Census TIGER). Code and the
exact acquisition steps are in the project repository under `code/`.
