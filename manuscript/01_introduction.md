# Introduction

<!-- Target ~1000-1400 words. Structure: (1) the problem, (2) the limits of the
dominant paradigm, (3) our reframing, (4) the ambient-population angle, (5)
contributions + roadmap. Citation keys [@key] are resolved from references.bib
at build time. -->

## The problem

Access to hospital care is unevenly distributed across the United States, and
the consequences of that unevenness, including delayed treatment, worse
outcomes, and rural hospital closures, are well documented. A foundational
question underlies any equity claim: are hospitals located in proportion to the
population that needs them? Where they are not, two distinct failures appear.
The first is over-concentration, where facilities accumulate beyond what local
population warrants, producing urban redundancy and competitive clustering. The
second is under-service, where population is present but nearby hospital
provision is thin, producing access deserts.

## The dominant paradigm and its limits

Most quantitative work on hospital access uses catchment-based accessibility
scores, principally the two-step floating catchment area (2SFCA) family and
gravity models, which produce a per-location accessibility index from supply,
demand, and travel impedance. These methods are effective for ranking places,
but they have three properties that motivate an alternative. They require
modeling travel impedance and a distance-decay function whose form is a
researcher choice. They yield a descriptive score rather than a formal
hypothesis test of proportionality. And they almost universally use residential
(nighttime) census population as the demand surface.

## Our reframing: a point-process test of proportionality

We treat hospital locations as a spatial point pattern and ask directly whether
that pattern is consistent with a process that places hospitals in proportion to
population. The natural instrument is the inhomogeneous Ripley's K-function, the
second-order summary of a point pattern relative to a specified first-order
intensity. By setting that intensity proportional to population, the null
becomes a statement that hospitals are distributed as an inhomogeneous Poisson
process driven by population, and departures from the Monte-Carlo envelope are
interpretable as population-relative over- or under-clustering. A homogeneous
(complete spatial randomness) test would only rediscover that hospitals sit
where people are; the inhomogeneous formulation is what makes the
proportionality question answerable.

A methodological point distinguishes this design from kernel-based
inhomogeneous analyses. Our intensity is supplied externally by a population
raster rather than estimated from the hospital points themselves. This removes
the bandwidth selection, intensity-floor, and isolated-point instability that
affect point-estimated inhomogeneous intensities, and it makes the null an
explicit, auditable demand surface rather than a smoothing artifact.

## Why ambient population

Conventional access analyses use where people sleep. People have medical
emergencies, however, where they work, shop, and commute. Ambient (24-hour
average) population, operationalized here with ORNL LandScan, is a more
appropriate demand surface for acute hospital care. We make the ambient versus
residential choice a first-class object of study. We run the identical test
under both demand surfaces and report where the equity verdict changes, which is
itself an empirical contribution.

## Contributions

1. A formal, point-process hypothesis test of whether US hospital locations
   follow population, applied nationally across all US commuting zones. Unlike
   metropolitan statistical areas, commuting zones tile the entire country
   (rural areas included) and are exogenous to hospital locations. The test
   controls the family-wise error rate across zones with a Myllymäki global
   envelope test.
2. The first use, to our knowledge, of ambient population as the point-process
   null for hospital distribution, with a direct ambient versus residential
   contrast.
3. Capacity-aware variants, weighting by staffed beds and restricting to trauma
   centers, that distinguish access to a building from access to a bed or to
   emergency care.
4. A reproducible, dual-engine (R/`spatstat` and an independent Python port)
   open implementation.

## Roadmap

Section 2 reviews related work and states the gap. Section 3 describes the
hospital, population (ambient and residential), and commuting-zone boundary
data. Section 4 develops the inhomogeneous K-function test, the
population-intensity null, the capacity variants, and the global envelope
correction. Section 5 reports results. Section 6 concludes with limitations and
policy implications.
