#!/usr/bin/env Rscript
# coverage_power.R -- power of the COVERAGE (population-beyond-distance) test.
#
# The concentration axis has a power analysis (power_analysis.R); the coverage
# axis, which produces the 6-desert headline, did not. This supplies it, using
# the exact coverage estimator the study uses (population-weighted fraction of
# residents whose nearest hospital is farther than d, tested against the same
# rpoispp(population) null with the GET ERL global envelope).
#
# Alternative = a genuine access DESERT: hospitals are placed proportional to
# population but only within a central core disk of the window, leaving the
# lower-density peripheral population with no nearby hospital. The severity is
# the fraction of the zone's population left outside the core (stranded). Under
# H0 hospitals follow population everywhere. We report power = P(reject | desert)
# and Type-I = P(reject | null) as a function of that stranded fraction, holding
# the hospital count at the representative zone's real n.
#
# Output: docs/coverage_power.csv (stranded_frac, n, power, type1) +
#   docs/coverage_power_curve.png; prints the smallest detectable desert.
#
# Usage: Rscript code/R/coverage_power.R [zone] [reps] [npool]

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET); library(ggplot2) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args   <- commandArgs(trailingOnly = TRUE)
zone   <- if (length(args) >= 1) args[1] else "Amarillo, TX"
reps   <- if (length(args) >= 2) as.integer(args[2]) else 200L
npool  <- if (length(args) >= 3) as.integer(args[3]) else 199L
FRACS  <- c(0.05, 0.10, 0.15, 0.20, 0.30, 0.40)   # target stranded-population fractions
TARGET <- 0.80
set.seed(42)

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
hz <- sf::st_read(file.path(root, "data", "hospitals.gpkg"), quiet = TRUE)
w  <- cz[cz[["name"]] == zone, ]; if (!nrow(w)) stop("zone not found: ", zone)
epsg <- utm_epsg_for(w); wU <- sf::st_transform(sf::st_union(w), epsg)
win <- spatstat.geom::as.owin(wU)
h   <- sf::st_transform(hz, epsg); h <- h[sf::st_within(h, wU, sparse = FALSE)[, 1], ]
n   <- nrow(h)
if (n < 1) stop("zone has no in-zone hospitals")

pim <- population_im(file.path(root, "data", "landscan", "landscan-global-2020.tif"), wU, epsg)

# populated in-zone cells (the coverage demand points) and their weights
ix  <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
cx  <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; wv <- pim$v[ix]
ins <- spatstat.geom::inside.owin(cx, cy, win)
cx <- cx[ins]; cy <- cy[ins]; wv <- wv[ins]
cells <- spatstat.geom::ppp(cx, cy, window = win, checkdup = FALSE)
bb <- spatstat.geom::as.rectangle(win); maxdim <- max(diff(bb$xrange), diff(bb$yrange))
cov_d <- seq(0, min(100000, maxdim), by = 2000)

# population-weighted fraction of residents beyond distance d from nearest hospital
covf <- function(hx, hy) {
  if (!length(hx)) return(rep(1, length(cov_d)))
  H <- spatstat.geom::ppp(hx, hy, window = win, checkdup = FALSE)
  d <- spatstat.geom::nncross(cells, H, what = "dist")
  vapply(cov_d, function(dd) sum(wv[d > dd]) / sum(wv), numeric(1))
}
reject_vs_pool <- function(obs, pool) {
  cs <- GET::create_curve_set(list(r = cov_d, obs = obs, sim_m = pool))
  as.numeric(attr(GET::global_envelope_test(cs, type = "erl", alpha = 0.05), "p")) < 0.05
}

# NULL intensity: population-proportional over the whole window, integrating to n
lam0 <- lambda_im(pim, n)$im

# population-weighted centroid, and per-cell distance from it (to carve the core)
ctrx <- sum(cx * wv) / sum(wv); ctry <- sum(cy * wv) / sum(wv)
cell_r <- sqrt((cx - ctrx)^2 + (cy - ctry)^2)
ord    <- order(cell_r)                          # cells inner -> outer
cumpop <- cumsum(wv[ord]) / sum(wv)              # cumulative pop by radius

# For a target stranded fraction f, find the core radius holding (1 - f) of pop;
# ALTERNATIVE intensity = population inside that radius only (renormalized to n).
alt_intensity <- function(f) {
  rad <- cell_r[ord][which.min(abs(cumpop - (1 - f)))]
  keep <- pim
  xm <- matrix(pim$xcol, nrow = length(pim$yrow), ncol = length(pim$xcol), byrow = TRUE)
  ym <- matrix(pim$yrow, nrow = length(pim$yrow), ncol = length(pim$xcol))
  dist_c <- sqrt((xm - ctrx)^2 + (ym - ctry)^2)
  keep$v <- pim$v; keep$v[dist_c > rad] <- 0
  list(im = lambda_im(keep, n)$im, rad = rad)
}
# realized stranded fraction (pop beyond the core radius)
stranded_frac <- function(rad) sum(wv[cell_r > rad]) / sum(wv)

res <- list()
for (f in FRACS) {
  a <- alt_intensity(f); sfrac <- stranded_frac(a$rad)
  pool <- vapply(seq_len(npool), function(i) {
    P <- spatstat.random::rpoispp(lam0)[win]; covf(P$x, P$y) }, numeric(length(cov_d)))
  pw <- mean(vapply(seq_len(reps), function(i) {
    P <- spatstat.random::rpoispp(a$im)[win]; reject_vs_pool(covf(P$x, P$y), pool) }, logical(1)))
  t1 <- mean(vapply(seq_len(reps), function(i) {
    P <- spatstat.random::rpoispp(lam0)[win]; reject_vs_pool(covf(P$x, P$y), pool) }, logical(1)))
  res[[length(res) + 1]] <- data.frame(stranded_frac = round(sfrac, 3), n = n, power = pw, type1 = t1)
  message(sprintf("  stranded=%.1f%%  n=%d  power=%.3f  type1=%.3f", 100 * sfrac, n, pw, t1))
}
df <- do.call(rbind, res)
utils::write.csv(df, file.path(root, "docs", "coverage_power.csv"), row.names = FALSE)
detect <- if (any(df$power >= TARGET)) min(df$stranded_frac[df$power >= TARGET]) else NA

p <- ggplot(df, aes(stranded_frac)) +
  geom_hline(yintercept = c(0.05, TARGET), linetype = 2, colour = "grey60") +
  geom_line(aes(y = power), colour = "firebrick") + geom_point(aes(y = power), colour = "firebrick") +
  geom_line(aes(y = type1), colour = "steelblue") + geom_point(aes(y = type1), colour = "steelblue") +
  coord_cartesian(ylim = c(0, 1)) +
  labs(title = sprintf("Coverage-test power (red) and Type-I (blue) vs desert severity [%s, n=%d]", zone, n),
       subtitle = "x = fraction of zone population stranded outside the hospital core; dashed: 0.05 and 0.80",
       x = "stranded population fraction", y = "rejection rate") + theme_classic()
ggsave(file.path(root, "docs", "coverage_power_curve.png"), p, width = 8, height = 5, dpi = 200)
cat(sprintf("\nSmallest desert detected with power>=%.2f (%s, n=%d): %s of population stranded\n",
            TARGET, zone, n, ifelse(is.na(detect), "not reached on grid", paste0(100 * detect, "%"))))
