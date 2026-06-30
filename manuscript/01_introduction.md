# Introduction

<!-- Target ~1000-1400 words. Structure: (1) the problem, (2) the limits of the
dominant paradigm, (3) our reframing, (4) the ambient-population angle, (5)
contributions + roadmap. Citation keys [@key] are resolved from references.bib
at build time. -->

## The problem

Access to hospital care is unevenly distributed across the United States, and
the consequences of that unevenness — delayed treatment, worse outcomes,
rural hospital closures — are well documented. A foundational question
underlies any equity claim: **are hospitals located in proportion to the
population that needs them?** Where they are not, two distinct failures appear:
*over-concentration*, where facilities pile up beyond what local population
warrants (urban redundancy, competitive clustering), and *under-service*, where
population is present but nearby hospital provision is thin (access deserts).

## The dominant paradigm and its limits

Most quantitative work on hospital access uses **catchment-based accessibility
scores** — the two-step floating catchment area (2SFCA) family and gravity
models — which produce a per-location accessibility index from
supply, demand, and travel impedance. These methods are powerful for *ranking*
places, but they (i) require modeling travel impedance and a distance-decay
function whose form is a researcher choice, (ii) yield a descriptive score
rather than a *formal hypothesis test* of proportionality, and (iii) almost
universally use **residential (nighttime) census population** as the demand
surface.

## Our reframing: a point-process test of proportionality

We treat hospital locations as a spatial **point pattern** and ask, directly,
whether that pattern is consistent with a process that places hospitals in
proportion to population. The natural instrument is the **inhomogeneous
Ripley's K-function**: the second-order summary of a point pattern relative to
a specified first-order intensity. By setting that intensity proportional to
population, the null becomes "hospitals are distributed as an inhomogeneous
Poisson process driven by population," and departures from the Monte-Carlo
envelope are interpretable as population-relative over- or under-clustering. A
homogeneous (complete spatial randomness) test would only re-discover that
hospitals sit where people are — the inhomogeneous formulation is what makes
the proportionality question answerable.

A methodological note distinguishes this design from kernel-based inhomogeneous
analyses: our intensity is **supplied externally** by a population raster, not
estimated from the hospital points themselves. This removes the bandwidth
selection, intensity-floor, and isolated-point instability that plague
point-estimated inhomogeneous intensities, and makes the null an explicit,
auditable demand surface rather than a smoothing artifact.

## Why ambient population

Conventional access analyses use where people *sleep*. But people have medical
emergencies where they work, shop, and commute. **Ambient (24-hour average)
population** — operationalized here with ORNL LandScan — is arguably the more
appropriate demand surface for acute hospital care. We make the ambient-versus-
residential choice a first-class object of study: we run the identical test
under both demand surfaces and report where the equity verdict *changes*,
which is itself an empirical contribution.

## Contributions

1. A formal, point-process hypothesis test of whether U.S. hospital locations
   follow population, applied **nationally** across all U.S. commuting zones —
   which, unlike metropolitan statistical areas, tile the entire country
   (rural included) and are exogenous to hospital locations — with
   **family-wise error control** across zones (a Myllymäki global envelope
   test).
2. The first use, to our knowledge, of **ambient** population as the
   point-process null for hospital distribution, and a direct ambient-versus-
   residential contrast.
3. **Capacity-aware** variants — weighting by staffed beds and restricting to
   trauma centers — that distinguish access to a *building* from access to a
   *bed* or to *emergency* care.
4. A reproducible, dual-engine (R/`spatstat` + independent Python) open
   implementation.

## Roadmap

Section 2 reviews related work and states the gap precisely. Section 3
describes the hospital, population (ambient and residential), and commuting-zone
boundary data. Section 4 develops the
inhomogeneous K-function test, the population-intensity null, the capacity
variants, and the global envelope correction. Section 5 reports results.
Section 6 concludes with limitations and policy implications.
