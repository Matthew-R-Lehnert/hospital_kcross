# Methods

## Setup and notation

Within a single commuting-zone window $W$ (a polygon, projected to local UTM),
let $X = \{x_1,\dots,x_n\}$ be the open hospital locations in $W$. Let $p(u)$ be
the population surface (LandScan ambient, or GPW residential) at location
$u \in W$, and let $b_i$ be the staffed-bed count of hospital $i$. We
characterize each zone on three orthogonal axes: whether supply is
**concentrated** beyond population, whether population is **covered** by nearby
hospitals, and whether capacity is **sufficient** per person. Across the three,
the population surface is held fixed and the hospitals are the random quantity;
the inferential question is always whether the observed hospitals depart from a
process tied to population.

## Zone inclusion criterion

The inhomogeneous K-function is a second-order (pairwise) summary, so it
requires enough hospitals per zone to estimate. Below a small count the
Monte-Carlo envelope is degenerate and the test has no power. We therefore
compute the concentration tests only for zones with at least **8 open
hospitals**; the threshold is justified by a simulation power analysis (the
smallest $n$ at which the global test reaches adequate power against a fixed
over-concentration alternative) and is reported with a sensitivity check at
higher values. Of the 597 commuting zones, **261 meet the threshold and 336 do
not**, but the excluded zones hold only about **9% of population**, so the
concentration analysis still covers roughly **91% of where people are during the
day**. The **sufficiency** and **coverage** axes are computed for *every* zone,
including sparse ones, since neither requires a minimum hospital count; this is
deliberate, because the sparse zones are exactly where access shortfalls are
most likely.

## Axis 1: Concentration (inhomogeneous K)

### The population-proportional intensity

We define the null intensity as population, rescaled so its integral over the
window equals the observed hospital count:

$$
\lambda(u) \;=\; n \,\frac{p(u)}{\int_W p(v)\,dv}, \qquad u \in W .
$$

By construction $\int_W \lambda = n$, so a process drawn from $\lambda$ produces
$n$ hospitals in expectation and the inhomogeneous K below is comparable to its
Poisson value $\pi r^2$. Because $\lambda$ is **supplied by the population
raster**, there is no kernel bandwidth to choose and no leave-one-out intensity
to floor; the instability that arises when $\lambda$ is estimated from sparse
points does not occur. A small positive floor is applied only to populated-by-a-
hospital-but-zero-population cells, to keep $1/\lambda$ finite.

### The estimator

We use the inhomogeneous K-function [@baddeley_moller_waagepetersen_2000]:

$$
\hat{K}_{\text{inhom}}(r) \;=\; \frac{1}{|W|}
\sum_{i}\sum_{j \neq i}
\frac{\mathbf{1}\{\lVert x_i - x_j \rVert \le r\}\, e(x_i, x_j)}
     {\lambda(x_i)\,\lambda(x_j)} ,
$$

with $e(\cdot,\cdot)$ the Ripley isotropic edge-correction weight. Under the
null that hospitals follow population, $K_{\text{inhom}}(r) \approx \pi r^2$;
values above indicate hospitals more clustered than population warrants
(over-concentration), values below a more regular-than-population arrangement.

### Bed-weighted concentration

To test whether *capacity* (not just buildings) is distributed proportional to
population, we weight each hospital by its bed count. Using the per-point
intensity identity, a weight $w_i$ with intensity $\Lambda$ equals an ordinary
inhomogeneous K with per-point intensity $\Lambda(x_i)/w_i$, where
$\Lambda(u) = (\sum_i w_i)\,p(u)/\int_W p$ is the bed-mass intensity. This
follows the mark-weighted K tradition [@penttinen_stoyan_henttonen_1992;
@giuliani_arbia_espa_2014] and requires no custom estimator. Missing bed counts
(the HIFLD `-999` sentinel, 5.2% of hospitals nationally) are imputed with the
zone median; zones where most beds are unknown are flagged and their bed verdict
treated as unreliable.

### What is permuted, and the envelope

The population surface is fixed; the hospitals are resampled. Each null
realization is a fresh hospital pattern drawn from the population-proportional
inhomogeneous Poisson process $\text{rpoispp}(\lambda)$. With `nsim = 999`
simulations we form the **global rank envelope test** (extreme-rank-length, ERL)
of @myllymaki_etal_2017, which controls the error rate over the whole $r$-curve
and returns one global $p$-value per zone, rather than the per-distance pointwise
envelope (which is miscalibrated: too narrow at small `nsim`, far too
conservative at 999). For the bed test the same simulated locations carry bed
counts resampled from the zone's own hospitals.

## Axis 2: Coverage (population-weighted distance to care)

Concentration measures the arrangement of hospitals relative to each other;
**coverage** measures whether population is near care. For each populated ~1 km
cell we compute the distance to the nearest hospital and summarize the
population-weighted fraction beyond distance $d$, $C(d)$, across a grid of $d$.
$C(d)$ is compared against the same null (hospitals resampled proportional to
population): a curve **above** the envelope means more population is stranded far
from care than a population-proportional placement would produce
(**under-served**); **below** means better-than-proportional coverage.

### Cross-border (buffered) coverage

A person near a zone edge may be served by a hospital in a neighboring zone, so
restricting coverage to in-zone hospitals would invent false edge deserts. The
coverage axis therefore uses every hospital within the zone **or within a 50 km
buffer** of it. The null resamples only the **in-zone** hospitals (the within-
zone allocation question) while holding the **out-of-zone buffer hospitals
fixed**, so observed and null both credit cross-border access. We report the
descriptive share of population beyond 10, 25, and 35 miles of a hospital (the
35-mile figure corresponds to the CMS Critical Access Hospital distance rule);
the test itself is threshold-free. Distances are Euclidean, a deliberate
simplification discussed in the limitations.

## Axis 3: Sufficiency (capacity per capita)

Both tests above condition on the observed hospital (or bed) total, so neither
asks whether there is *enough* capacity. We measure that with the standard
metric, **staffed beds per 1,000 population**, reported against the US national
average (~2.8) and the OECD average (~4.3) [reference values to be cited]. It is
a descriptive ratio, computed for every zone (including the sparse zones the
concentration tests skip), under both ambient and residential population. Folding
sufficiency into the K statistic would confound it with concentration (over-
supply and over-clustering shift the curve the same way), so it is kept as a
separate, orthogonal coordinate.

## A diagnostic typology

The three axes combine into a per-zone diagnosis that a single accessibility
score cannot provide: low sufficiency with under-served coverage indicates a
genuine **shortage**; adequate sufficiency with over-concentration and under-
served coverage indicates **maldistribution** (enough supply, clumped, fringe
stranded); adequate sufficiency with proportional concentration but under-served
coverage indicates a **geographic gap** (remote population); high sufficiency
with over-concentration and over-served coverage indicates **redundancy**. The
national results are reported as the distribution of zones across this typology,
which maps each failure mode to a different policy response.

## Two-level inference

Within each zone, the global ERL envelope controls error across the $r$ (or $d$)
grid. Across the several hundred zones, running one test per zone is a
multiple-comparison problem, so we apply the **combined** global envelope test
[@myllymaki_etal_2017; @mrkvicka_myllymaki_hahn_2017] to control the family-wise
error rate across zones, reusing each zone's saved simulated curves rather than
re-simulating. This is run separately for each axis.

## Local decomposition and maps

For zones flagged on concentration, `localKinhom` decomposes the global K into a
per-hospital contribution, mapping which hospitals drive the clustering. For
coverage, the per-cell distance field maps where under-served population sits.
Together these convert a global verdict into an interpretable geography.

## Ambient versus residential

Every quantity is computed twice, once with the LandScan ambient $\lambda$ and
once with the GPW residential $\lambda$, holding the hospital data, window,
buffer, edge correction, grids, and seeds fixed. The reported contrast is the
set of zones whose diagnosis changes between the two demand surfaces.

## Validation

The facility test reproduces the standard spatstat `Kinhom` behavior. For the
newer bed and coverage estimators we confirm **Type-I calibration** by simulation
(drawing patterns under the null and verifying the test rejects at the nominal
rate): facilities, beds, and coverage all reject near 0.04 against a 0.05 target,
confirming no estimator bias. A power analysis against a population-raised-to-a-
power over-concentration alternative establishes the inclusion threshold.

## Implementation and reproducibility

The reference engine is R / `spatstat` (`Kinhom`, `localKinhom`, `rpoispp` on a
pixel-image intensity, and the `GET` package for the global test), orchestrated
across zones and population surfaces by a Nextflow pipeline (local, SLURM, and
AWS Batch profiles). Each run writes envelope curves, verdicts, global
$p$-values, the saved simulations, and metadata; code is in `code/` and is not
part of the submitted manuscript.
