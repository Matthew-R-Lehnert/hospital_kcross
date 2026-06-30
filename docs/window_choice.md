# Design memo: why commuting zones are the analysis window

*Status: decision record. This is the defense we will be asked for in review —*
*reviewers in health geography will specifically ask "why not HRRs/HSAs?" and*
*"why not CBSAs?". The argument is part principled, part empirical (a*
*multi-window robustness re-run).*

## What the window does in this analysis

The window $W$ is not cosmetic — in a K-function test it is load-bearing:

1. It is the region over which the population intensity is normalized
   ($\int_W \lambda = n$), so it defines what "proportional to population" means.
2. It carries the **edge correction**; a biased or arbitrary boundary biases the
   estimator.
3. It determines **what is in sample**. Anything outside every window is
   silently excluded from the entire study.
4. It scopes the null: hospitals are simulated *within* $W$, so $W$ is the
   universe of "where a hospital could have gone."

So the window must (a) cover the populations we care about — including rural —
(b) be exogenous to hospital locations (or the test is circular), and (c) have
boundaries with behavioral meaning rather than arbitrary lines.

## The candidates

| Window | National coverage? | Rural in-sample? | Exogenous to hospitals? | Behavioral basis | Notes |
|--------|-------------------|------------------|--------------------------|------------------|-------|
| **Commuting zones (USDA)** | **Yes — partitions all counties** | **Yes** | **Yes** (commuting flows) | commuting / labor-market | chosen |
| CBSAs (metro+micro) | No — only urbanized cores | **No** (excludes outside-CBSA rural) | Yes (population thresholds) | urban core + commuting fringe | robustness re-run |
| Dartmouth HSA / HRR | Yes | Yes | **No** — drawn from hospital *use* | hospital admission / referral | endogeneity caveat; robustness re-run |
| Counties | Yes | Yes | Yes | administrative | too small: many have 0–1 hospitals → K undefined |
| States | Yes | Yes | Yes | administrative | too large/heterogeneous; weak, hard-to-interpret test |
| Single national window | Yes | Yes | Yes | none | edge effects across ~4000 km; AK/HI disconnected; clustering scale meaningless |

## Why commuting zones win for *this* question

1. **They keep rural in the sample.** The headline claim is about access
   *deserts*; the worst are rural and non-metropolitan. CBSAs exclude exactly
   those areas, so a CBSA-only study cannot honestly make a national
   access-desert claim. CZs partition every U.S. county.
2. **Their logic matches the demand surface.** Both commuting zones and LandScan
   ambient population are built from where people *move*. Using a commuting-based
   window with an ambient-population null is internally consistent: the window
   and the demand share a behavioral definition.
3. **They are exogenous to hospital locations.** This is the decisive advantage
   over HSAs/HRRs. Dartmouth regions are delineated *from hospital utilization*
   (HSAs from general-admission patterns, HRRs from major-referral patterns), so
   every HSA contains ≥1 hospital by construction and its boundary is drawn
   around hospital use. Testing "are hospitals proportional to population
   *within* a region that was itself defined by hospital use" is partly
   circular. CZ boundaries do not depend on where hospitals are.
4. **They are estimable.** Unlike counties (many with 0–1 hospitals, where a
   K-function is undefined), CZs aggregate enough area/points for a stable
   second-order estimate, while staying far smaller and more homogeneous than
   states.

## The honest counter-arguments (and our responses)

- *"HRRs are the health-services standard; reviewers expect them."* True — so we
  **also run the analysis on HRRs/HSAs and CBSAs** and report it as a robustness
  table. If the verdict pattern is stable across windows, the CZ choice is
  vindicated and the endogeneity worry is shown to be immaterial; if it is not,
  that instability is itself a finding worth reporting.
- *"CZ delineations have vintages (1990/2000/2010) and they drift."* We fix and
  cite a single vintage, and note CZ stability work [@fowler_cz_stability]. <!--
  confirm key once references.bib is built -->
- *"CZs can be large in the rural West."* The inhomogeneous correction handles
  internal density variation; and large sparse zones are precisely where the
  access-desert signal should live, so excluding them would bias the result.

## Empirical defense (the robustness re-run)

The engine takes the window as a parameter (`code/scripts/run_cz.R` /
`run_all.R` accept a windows file), so re-running on CBSAs and HRRs is a config
change, not a rewrite. The paper will report:

- headline on commuting zones;
- a robustness table: fraction of zones over-concentrated / proportional /
  under-served under **CZ vs. CBSA vs. HRR**, with the cross-window agreement
  rate;
- explicit discussion wherever a window choice moves a verdict.

## References to add to `references.bib`

- Tolbert & Sizer (1996), USDA ERS — commuting zone delineation.
- Fowler et al. — commuting-zone stability/comparability.
- Dartmouth Atlas — HSA/HRR methodology.
- U.S. OMB / Census — CBSA delineation standards.
