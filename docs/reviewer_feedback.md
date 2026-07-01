# Simulated peer review — open questions and next steps

Self-review of `manuscript/manuscript.pdf` conducted as if by journal referees
(2026-07-01), before submission. Organized as two referees + editor summary.
Items are grouped by severity; the **production defects** block must be cleared
before the manuscript goes to real reviewers.

Status legend: `[ ]` open · `[~]` in progress · `[x]` done.

## Editor summary

Clean, defensible core idea (inhomogeneous-K proportionality test with the
ambient-vs-residential demand surface as the object of study); robustness
scaffolding is stronger than most submissions. But the manuscript overclaims the
*interpretation* of the reversal, has one serious unaddressed endogeneity
threat, and carries production defects. Overall: **major revision**.

## Major — statistics / methods (Reviewer 1)

- [ ] **Ambient null is partly endogenous to hospitals.** LandScan allocates
  daytime population to workplaces and to hospitals themselves (staff,
  outpatients, visitors, ED throughput), so ambient population is inflated *near*
  hospitals *because* the hospital is there. This could mechanically explain why
  over-concentration vanishes under LandScan. **Action:** re-run with
  hospital/health-facility cells masked out of the ambient raster, OR quantify
  that induced population is negligible vs zone totals. Highest-priority threat
  to the headline.
- [ ] **Reversal may be mechanical, not a discovery.** Both hospitals and daytime
  activity concentrate in urban/commercial cores; residential population spreads
  to suburbs. "Over-concentrated vs residential, proportional vs ambient" may be
  ~a priori from raster geometry. **Action:** decomposition or illustration
  showing the reversal carries information beyond "LandScan is more
  urban-core-weighted than GPW."
- [ ] **Poisson vs conditioning on n.** Null resamples `rpoispp(λ)` (random N) but
  rescales ∫λ = n. Justify Poisson vs a fixed-n binomial null, or show it doesn't
  matter.
- [ ] **Coverage test power unquantified.** Concentration got a power analysis;
  coverage (the 6-desert headline) did not, and its null resamples only in-zone
  hospitals. **Action:** report coverage power the way concentration power is
  reported.

## Major — health geography / substance (Reviewer 2)

- [ ] **"Ambient is the better acute-demand surface" is asserted, not shown.**
  Many acute events (nocturnal MI, stroke, elderly falls) occur at/near home;
  admissions skew to populations at residence by day. **Action:** engage with
  evidence, or soften to "complementary surface that materially changes the
  verdict" rather than "more defensible."
- [ ] **Euclidean distance undermines the coverage finding.** Rural deserts are
  exactly where straight-line vs drive-time diverges most. **Action:** validate
  the 6 desert zones against road-network / drive-time distance; ideally the
  whole coverage axis.
- [ ] **Temporal misalignment.** Hospitals ~2024 HIFLD snapshot vs 2020
  population / CZ / rasters; 4 years spans rural closures. **Action:** use a
  2020-vintage hospital layer, or show flagged zones are insensitive to closures
  in that window.
- [ ] **Normative leap too strong.** Statistical over-concentration vs a
  Poisson-population null ≠ inequity/over-provision (agglomeration, tertiary
  referral, CON regulation). **Action:** rein in Implications language ("curbing
  urban over-provision").

## Minor

- [ ] Report **effect sizes** for flagged zones, not just "k of N, p = …".
- [ ] "Over-concentration and under-service never co-occur" is likely partly
  **structural** (concentration tested only in 261 dense/urban zones; deserts are
  rural) — reframe as expected, or defend.
- [ ] **Sufficiency is the weakest axis but the largest typology category**
  (capacity shortfall 76/102) and rests on an arbitrary threshold with no test.
  Flag the tested-vs-thresholded asymmetry; consider threshold sensitivity of the
  typology.
- [ ] Beds/1,000 is confounded by the same denominator issue (commuter-destination
  vs bedroom-community) — caveat it in the typology since it drives the largest
  cell.

## Production defects (clear before real reviewers)

- [ ] Page-1 title block renders `true` and a bare `2026` where authors/date
  belong — metadata/template bug in the PDF.
- [ ] Abstract build-fallback comment prints in the body ("(Abstract lives in
  00_abstract.md …)"). Remove from output.
- [ ] **Trauma contradiction:** Gap/Contribution + abstract claim a
  "trauma-center subset" contribution, but Data says trauma is "deferred to
  future work." Pick one.
- [ ] **Zone count inconsistency:** Data says 598 labor markets; Methods/Results
  use 597. Reconcile (PR? contiguity?) and state once.
- [ ] **Reproducibility gate:** repo is currently private; needs to be public and
  archived with a DOI (Zenodo/OSF) to satisfy data-availability policy.

## Overall verdict

Publishable core. Path to acceptance: (1) rule out hospital-induced ambient
population endogeneity; (2) show the reversal is more than mechanical urban-core
weighting; (3) validate rural deserts against travel time + a contemporaneous
hospital layer; (4) dial policy language back to what a proportionality test
licenses. Fix production defects first.
