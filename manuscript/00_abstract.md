# Abstract

**Background.** Whether hospitals are located where people need them is a
long-standing question in health geography, usually approached with
catchment-based accessibility scores (for example, the two-step floating
catchment area) and residential census population. We instead pose the question
as a formal spatial point-process hypothesis test, and we ask it against
*ambient* population, meaning where people are over a 24-hour day.

**Methods.** We characterize each US **commuting zone** (county clusters that
tile the entire country, rural included) on three orthogonal axes:
**concentration** (is supply clumped beyond population?), measured by an
**inhomogeneous Ripley's K-function** with a population-proportional null for
both hospital locations and bed capacity; **coverage** (are people far from
care?), measured by the population-weighted distance to the nearest hospital
against the same null, crediting hospitals across zone boundaries; and
**sufficiency** (is there enough capacity?), measured by beds per 1,000
population against US and OECD references. Concentration and coverage are tested
against Monte-Carlo inhomogeneous-Poisson simulations in which population is held
fixed and hospitals are resampled, with a Myllymäki global envelope test
controlling error within and across zones. Hospital locations come from HIFLD
(*n* = 7,966 open facilities). Population is ORNL LandScan Global **ambient**
(24-hour) population at about 1 km, contrasted against NASA SEDAC GPWv4.11
**residential** population at the same grid.

**Results.** Across 597 commuting zones, the demand surface reverses the
conclusion. Against **residential** population, 15 of 261 hospital-dense zones
are significantly over-concentrated (family-wise $p = 0.002$) and none are
under-served; against **ambient** population, that over-concentration disappears
entirely (0 zones, $p = 0.47$) and instead 6 zones are significantly
under-served ($p = 0.001$). Over-concentration and under-service never co-occur
in the same zone. In total, **44 of 597 zones change diagnosis** between the two
surfaces, moving metros such as Dallas and San Diego from a redundancy diagnosis
(residential) to a geographic-access-gap diagnosis (ambient).

**Conclusions.** Whether US hospital supply looks over-provided or under-serving
depends on whether demand is measured by where people sleep or where they are by
day. Analyses that default to residential population may systematically mistake
the nature of local hospital-access inequity.

**Keywords:** inhomogeneous K-function; spatial point patterns; healthcare
access; hospital capacity; ambient population; LandScan; hospital deserts.
