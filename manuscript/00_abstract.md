# Abstract

**Background.** Whether hospitals are located where people need them is usually
studied with catchment-based accessibility scores and residential census
population. We reframe the question as a formal spatial point-process test and,
critically, ask it against *ambient* population, where people are over a 24-hour
day, rather than only where they sleep.

**Methods.** We characterize hospital supply in every US commuting zone (county
clusters that tile the entire country, rural included) on three orthogonal axes:
**concentration** (is supply clustered beyond population?), measured by an
inhomogeneous Ripley's K-function with a population-proportional null for both
hospital locations and bed capacity; **coverage** (are people far from care?),
measured by population-weighted distance to the nearest hospital against the
same null, crediting hospitals across zone boundaries; and **sufficiency** (is
there enough capacity?), measured by beds per 1,000. Concentration and coverage
are tested against Monte-Carlo simulations in which population is fixed and
hospitals are resampled, with a Myllymaki global envelope test controlling error
within and across zones. Hospitals come from HIFLD (n = 7,966). Ambient
population is ORNL LandScan; residential population is NASA SEDAC GPWv4.11.

**Results.** The demand surface reverses the conclusion. Against residential
population, 15 of 262 hospital-dense zones are significantly over-concentrated
(family-wise p = 0.002) and none are under-served; against ambient population,
that over-concentration disappears entirely (0 zones, p = 0.47) and instead 6
zones are significantly under-served (p = 0.001). Over-concentration and
under-service do not co-occur in the same zone (a pattern that is partly
structural, since concentration is tested only in hospital-dense zones), and 44
of 598 zones change
diagnosis between the two surfaces. A WorldPop control (modeled but residential)
shows the reversal tracks day-versus-night timing, not raster construction, and
the findings are stable to the hospital-count threshold, the coverage buffer,
a re-run on 939 CBSA windows, and neutralizing the population LandScan places at
the hospital sites themselves.

**Conclusions.** Whether US hospital supply looks over-provided or under-serving
depends on whether demand is counted where people sleep or where they are by
day. Accessibility analyses that default to residential population may
systematically mistake the nature of local hospital-access inequity.

**Keywords:** inhomogeneous K-function; spatial point patterns; healthcare
access; hospital capacity; ambient population; LandScan; hospital deserts.
