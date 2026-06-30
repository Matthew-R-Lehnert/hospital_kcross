# Conclusion

<!-- ~600-900 words. Restate what was tested and found (once results exist),
then limitations and implications. -->

## Summary

*To be completed after results.* We posed hospital access as a formal
point-process question — are hospitals distributed in proportion to the
population they serve? — and answered it nationally with an inhomogeneous
K-function whose null is population itself, using ambient population as the
demand surface.

## Limitations

- **Static hospital snapshot.** HIFLD is a single ~2024 cross-section; we test a
  fixed hospital geography against time-varying population, so we cannot speak
  to hospital openings/closings over time. A dated HIFLD/CMS panel would enable
  a true longitudinal design.
- **Ambient ≠ acute demand.** Ambient population is a better proxy than
  residential for where acute events occur, but it is still a proxy; true demand
  also depends on age structure, morbidity, and case mix, which a population
  surface does not capture.
- **Modeled-vs-areal confound.** The LandScan (ambient, modeled) vs. GPW
  (residential, areal) contrast mixes timing with construction; the WorldPop /
  LandScan-USA robustness check (if run) bounds this.
- **Window dependence.** Results are conditional on the commuting-zone
  partition; the CBSA re-run quantifies sensitivity to the windowing choice.
- **Distance, not travel time.** The K-function uses Euclidean distance; real
  access depends on roads, terrain, and traffic. The method answers a
  *spatial-distribution* question, complementary to (not a replacement for)
  travel-time accessibility models.
- **Containment.** A hospital just outside a zone boundary serves nearby
  in-zone population but is not counted in that zone.

## Implications

*To be completed.* The geography of population-relative over- and
under-provision — and the cases where the ambient framing changes the verdict —
speaks to where redundant capacity and genuine access gaps coexist, and to how
the choice of demand surface shapes equity conclusions.

## Reproducibility and data availability

All inputs are public (HIFLD via DataLumos; LandScan Global via ORNL; GPWv4.11
via NASA SEDAC; commuting zones via USDA ERS + Census TIGER). Code and exact
acquisition steps are in the project repository under `code/`.
