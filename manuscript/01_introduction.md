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

## Three axes, not one number

Concentration alone does not capture access. A region can have hospitals
arranged proportional to population yet leave a remote population stranded, or
have adequate buildings but capacity concentrated in one center, or simply have
too few beds for its people. We therefore measure three orthogonal axes:
**concentration** (is supply clumped beyond population?), **coverage** (are
people far from care?), and **sufficiency** (is there enough capacity per
person?). Each answers a distinct question that a single accessibility score
conflates, and their combination yields a per-zone diagnosis that maps to a
distinct policy response.

## Contributions

1. A formal, point-process test of whether US hospital **locations** and **bed
   capacity** follow population, applied nationally across all US commuting
   zones, which tile the entire country (rural included) and are exogenous to
   hospital locations, with family-wise error control within and across zones.
2. The first use, to our knowledge, of **ambient** population as the
   point-process null for hospital distribution, with a direct ambient versus
   residential contrast that we report at the level of changed verdicts.
3. A **coverage** test of population-weighted distance to care that credits
   cross-border hospitals, and a **sufficiency** measure of beds per capita,
   combined with concentration into a **diagnostic typology** (shortage,
   maldistribution, geographic gap, redundancy) that distinguishes "too few"
   from "in the wrong place" from "people stranded."
4. A reproducible, validated (Type-I calibrated), open implementation with a
   Nextflow pipeline.

## Roadmap

Section 2 reviews related work and states the gap. Section 3 describes the
hospital, population (ambient and residential), and commuting-zone data. Section
4 develops the three axes, the population-proportional null, the cross-border
coverage construction, and the global envelope tests. Section 5 reports results.
Section 6 concludes with limitations and policy implications.
