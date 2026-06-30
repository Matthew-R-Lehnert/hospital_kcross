#!/usr/bin/env Rscript
# calibration.R -- Type-I check for the three estimators (facilities, beds,
# coverage). Under the null, hospitals are placed proportional to population, so
# a test run on null data must reject only ~alpha (5%) of the time. We draw M
# iid null patterns the SAME way the engine draws its simulations (locations
# rpoispp(lambda~pop); beds resampled from the zone's hospitals), compute each
# layer's curve, then test each pattern against the other M-1 as its envelope
# (the exact Monte-Carlo construction). The rejection rate estimates Type-I; a
# value near 0.05 confirms the observed-vs-simulation computation is symmetric
# (no estimator bug) for each layer -- especially the newer bed and coverage
# statistics.
#
# Usage: Rscript code/R/calibration.R [zone] [M] [nsim_env]

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args     <- commandArgs(trailingOnly = TRUE)
zone     <- if (length(args) >= 1) args[1] else "Tucson, AZ"
M        <- if (length(args) >= 2) as.integer(args[2]) else 300L
nsim_env <- if (length(args) >= 3) as.integer(args[3]) else 199L
set.seed(42)

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
h  <- sf::st_read(file.path(root, "data", "hospitals.gpkg"), quiet = TRUE)
w  <- cz[cz[["name"]] == zone, ]; epsg <- utm_epsg_for(w)
wU <- sf::st_transform(sf::st_union(w), epsg); win <- spatstat.geom::as.owin(wU)
h  <- sf::st_transform(h, epsg); h <- h[sf::st_within(h, wU, sparse = FALSE)[, 1], ]
n  <- nrow(h); beds <- h$beds; bm <- stats::median(beds, na.rm = TRUE)
beds[is.na(beds) | beds < 1] <- bm

pim <- population_im(file.path(root, "data", "landscan", "landscan-global-2020.tif"), wU, epsg)
lam_all <- lambda_im(pim, n)$im; g_im <- lambda_im(pim, 1)$im
ix <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
cx <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; wv <- pim$v[ix]
ins <- spatstat.geom::inside.owin(cx, cy, win)
cells <- spatstat.geom::ppp(cx[ins], cy[ins], window = win, checkdup = FALSE); cellw <- wv[ins]

bb <- spatstat.geom::as.rectangle(win)
r <- seq(0, min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange))), by = 1000)
cov_d <- seq(0, min(100000, max(diff(bb$xrange), diff(bb$yrange))), by = 2000)
KI  <- function(P, lam) spatstat.explore::Kinhom(P, lambda = lam, r = r, correction = "Ripley", renormalise = TRUE)$iso
gat <- function(P) as.numeric(g_im[P, drop = FALSE])
covf <- function(P) { d <- spatstat.geom::nncross(cells, P, what = "dist")
  vapply(cov_d, function(dd) sum(cellw[d > dd]) / sum(cellw), numeric(1)) }

# M iid null draws -> three curve matrices
fac <- matrix(0, length(r), M); bed <- matrix(0, length(r), M); cov <- matrix(0, length(cov_d), M)
for (m in seq_len(M)) {
  P <- spatstat.random::rpoispp(lam_all)[win]; np <- spatstat.geom::npoints(P)
  if (np >= 2) {
    fac[, m] <- KI(P, lam_all)
    ws <- sample(beds, np, replace = TRUE); bed[, m] <- KI(P, (sum(ws) * gat(P)) / ws)
    cov[, m] <- covf(P)
  } else { cov[, m] <- 1 }
}

rej <- function(mat, x) {
  p <- numeric(M)
  for (m in seq_len(M)) {
    others <- sample(setdiff(seq_len(M), m), nsim_env)
    cs <- GET::create_curve_set(list(r = x, obs = mat[, m], sim_m = mat[, others]))
    p[m] <- as.numeric(attr(GET::global_envelope_test(cs, type = "erl", alpha = 0.05), "p"))
  }
  mean(p < 0.05)
}
cat(sprintf("Type-I (zone=%s, M=%d, envelope=%d, target alpha=0.05):\n", zone, M, nsim_env))
cat(sprintf("  facilities: %.3f\n", rej(fac, r)))
cat(sprintf("  beds:       %.3f\n", rej(bed, r)))
cat(sprintf("  coverage:   %.3f\n", rej(cov, cov_d)))
