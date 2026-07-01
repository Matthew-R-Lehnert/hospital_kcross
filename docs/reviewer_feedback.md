# Simulated peer review — open questions and next steps

Self-review of `manuscript/manuscript.pdf` conducted as if by journal referees
(2026-07-01), before submission. Organized as two referees + editor summary.
Items are grouped by severity; the **production defects** block must be cleared
before the manuscript goes to real reviewers.

Status legend: `[ ]` open · `[~]` in progress · `[x]` done.

## Editor summary

Clean, defensible core idea (inhomogeneous-K proportionality test with the
ambient-vs-residential demand surface as the object of study); robustness
scaffolding is stronger than most submissions. The original review found the
manuscript overclaimed the *interpretation* of the reversal, carried one serious
unaddressed endogeneity threat, and had production defects (initial verdict:
**major revision**). As of 2026-07-01 the endogeneity threat is ruled out, the
interpretation is softened, the reversal is shown to be structured, the deserts
are validated against drive-time, effect sizes and coverage power are reported,
and the production defects (including the dropped-Connecticut bug) are fixed. The
only remaining item is the reproducibility gate (public repo + DOI), deferred by
author choice. See the per-item status below and the Overall verdict.

## Major — statistics / methods (Reviewer 1)

- [x] **Ambient null is partly endogenous to hospitals.** RESOLVED, and it is not
  the explanation. (1) Quantified upper bound: the share of each concentration
  zone's ambient population sitting in the ~1 km cells that contain hospitals is
  median 2.7%, 90th pct 4.1%, max 8.8% (Rochester MN / Mayo), pooled 3.2% (and
  this over-counts, since those cells also hold ordinary residents/workers).
  (2) Definitive re-run: added `mask_hospital_cells` to `hk_core.R` and
  `code/scripts/run_masked_ambient.R`, re-ran the concentration axis for all 262
  zones (999 sims) on a hospital-NEUTRALIZED ambient surface, then
  `global_across_zones.R output/ambient_masked all`. Result: **0 of 262
  over-concentrated, combined p = 0.446** -- identical verdict and essentially the
  same p-value as unmasked ambient (0/262, p = 0.475). The reversal does not arise
  from hospital-induced ambient population. Written up in Results (robustness).
  METHOD NOTE: the neutralization REPLACES each hospital cell with its 5x5
  neighborhood-mean background, it does NOT zero it. A first attempt that zeroed
  the cells was invalid: Kinhom weights each hospital by 1/lambda at its own
  location, so lambda->0 there caused a divide-by-near-zero that spuriously flagged
  231/262. Replacing with local background keeps lambda positive and realistic.
- [x] **Reversal may be mechanical, not a discovery.** RESOLVED: added
  `code/scripts/reversal_decomposition.py`. After normalizing each surface to
  integrate to 1 over a zone, the ambient/residential ratio is identically 1
  under any global (or zone-wise) urban multiplier, so a departure from 1 refutes
  the "just more urban-core-weighted" reading. Result: the normalized ratio at
  hospital locations is median 1.73 (>1 in 251/262 zones; 1.94 in the 15 flipped
  zones) vs a residential-weighted baseline of exactly 1. Hospitals sit at
  daytime-destination cells; the reversal is structured, not raster geometry.
  Written into Results (robustness).
- [x] **Poisson vs conditioning on n.** RESOLVED: `code/R/null_sensitivity.R`
  re-runs 8 representative zones with a fixed-N binomial null (`rpoint(n, .)`) vs
  `rpoispp`. 8/8 verdicts agree; max |Delta p| = 0.16, only in zones far from the
  0.05 boundary. Conditioning on n is immaterial. In Results (robustness).
- [x] **Coverage test power unquantified.** RESOLVED: `code/R/coverage_power.R`
  (manufactured-desert alternative, stranded-population severity grid). Type-I
  ~0.05; power depends on desert geometry (San Diego 0.99 at 20% stranded;
  Amarillo conservative at 0.37 at 40%). Test is conservative -> the 6 flagged
  deserts are strong detections. In Results (robustness).

## Major — health geography / substance (Reviewer 2)

- [x] **"Ambient is the better acute-demand surface" is asserted, not shown.**
  RESOLVED: softened in Data ("a complementary demand surface ... we do not claim
  it is the single correct surface"), with the at-home-acute-event caveat
  (nocturnal MI, stroke, falls) engaged. Claim is now "materially changes the
  verdict," not "more defensible."
- [x] **Euclidean distance undermines the coverage finding.** RESOLVED:
  `code/scripts/drivetime_deserts.py` routes each desert's most-distant
  population decile to the nearest hospital on the OSM driving network (OSRM).
  Road distance exceeds Euclidean in all 6 (median ratio 1.13-2.62; Houston 2.6,
  Dallas 2.2), so drive-time makes deserts WORSE; stranded populations stay
  >=10 km (rural: 30-70 km) from care by road. Euclidean is conservative. In
  Results (robustness). NB a uniform circuity factor would cancel in the relative
  test, so real routing was required.
- [~] **Temporal misalignment.** ADDRESSED as a reasoned limitation (no full
  re-run possible): confirmed the HIFLD layer is 2024-vintage (records carry 2024
  source dates), no 2020-vintage layer is mirrored, and HIFLD has no per-facility
  open/close date, so a contemporaneous re-run is not feasible from the source.
  Bounded instead: deserts are conservative w.r.t. the gap (an opening we include
  understates a 2020 desert; a closure we miss would worsen it -> lower bounds),
  and over-concentration is a 262-zone family-wise result with large effect sizes
  (L-ratio median ~2.9x) that a few-percent 4-year turnover cannot manufacture.
  Written into Conclusion limitations. A dated HIFLD/CMS panel remains the ideal.
- [x] **Normative leap too strong.** RESOLVED: Implications rewritten to
  explicitly disclaim that over-concentration implies removing capacity (cites
  agglomeration, tertiary-referral role, historical siting, CON regulation as
  unobserved); the licensed claim is now the surface-dependent flip, not a
  prescription to curb supply.

## Minor

- [x] Report **effect sizes** for flagged zones. DONE: `code/scripts/effect_sizes.py`.
  Concentration reported as L_obs/L_null at 10 km (median 2.9x, range 1.3-31x);
  coverage as excess pop-weighted mean distance (up to ~3 km) and peak excess
  stranded fraction (9-37 pts). Cited in Results.
- [x] "Over-concentration and under-service never co-occur" is partly
  **structural**. RESOLVED: reframed in Abstract, Results, and Conclusion as
  partly structural (concentration tested only in the 262 dense zones; deserts
  are rural), presented as closer to expected than a discovery.
- [x] **Sufficiency tested-vs-thresholded asymmetry.** RESOLVED: added a Results
  paragraph flagging that sufficiency is a threshold crossing, not a test, and a
  threshold-sensitivity table (`docs/sufficiency_threshold_sensitivity.csv`):
  residential capacity-shortfall count moves 38 -> 102 -> 277 across bed cutoffs
  0.7x-US / US(2.8) / OECD(4.3), while tested categories are unchanged.
- [x] Beds/1,000 denominator confound. RESOLVED: caveated in the same Results
  paragraph (inherits the commuter-destination vs bedroom-community ambiguity).

## Production defects (clear before real reviewers)

- [x] Page-1 title block renders `true` and a bare `2026` where authors/date
  belong. FIXED: the `true` came from a structured `author:` object the default
  pandoc template can't render; flattened `metadata.yaml` author to a plain
  string and set `date: "July 2026"`.
- [x] Abstract build-fallback comment prints in the body ("(Abstract lives in
  00_abstract.md …)"). FIXED: removed the `abstract:` fallback field from
  `metadata.yaml` (real abstract is `00_abstract.md`).
- [x] **Trauma contradiction:** FIXED: dropped "and a trauma-center subset" from
  the contributions list in `02_related_work.md`, so it matches Data (trauma
  "deferred to future work").
- [x] **Zone count inconsistency:** RESOLVED, and it was not cosmetic. The USDA
  delineation makes all of Connecticut one CZ ("Hartford, CT", CZ 70), keyed in
  the crosswalk to CT's 2022 planning-region FIPS (09110-09190); the 2020 TIGER
  county file uses the old 8-county FIPS (09001-09015), so the merge in
  `acquire/02_commuting_zones.py` dropped the entire state (the 598-vs-597 gap).
  Fixed the acquire script to map CT counties to CZ 70, rebuilt
  `commuting_zones.gpkg` (598 zones), re-ran Hartford through all axes/surfaces,
  and recomputed family-wise + typology. Hartford is consistent/well-matched on
  every axis, so denominators shift (261->262 concentration, 585->586 coverage,
  597->598 total) but all headline numerators hold. Data section now states 598
  and explains the reconciliation.
- [ ] **Reproducibility gate:** repo stays PRIVATE for now (author decision,
  https://github.com/Matthew-R-Lehnert/hospital_kcross). Public + Zenodo/OSF DOI
  remains a pre-submission action to satisfy data-availability policy.

## Overall verdict

Publishable core. Path to acceptance was: (1) rule out hospital-induced ambient
population endogeneity; (2) show the reversal is more than mechanical urban-core
weighting; (3) validate rural deserts against travel time + a contemporaneous
hospital layer; (4) dial policy language back to what a proportionality test
licenses. Fix production defects first.

STATUS 2026-07-01: (1) DONE (hospital-neutralized ambient re-run, 0/262,
p=0.446). (2) DONE (normalized ambient/residential ratio at hospitals, median
1.73, structured not mechanical). (3) drive-time DONE (OSRM: road >= Euclidean,
deserts conservative); contemporaneous hospital layer NOT feasible (no 2020
vintage / no facility dates) -> bounded as a reasoned limitation. (4) DONE
(Implications rewritten). Production defects DONE. All statistics/minor items
DONE. Only open item is the reproducibility gate (repo public + DOI), deferred by
author choice. New robustness artifacts: coverage power, null-type sensitivity,
effect sizes, reversal decomposition, sufficiency threshold sensitivity,
drive-time (`code/{R,scripts}/*`, `docs/*.csv`).
