#!/usr/bin/env Rscript
# buffer_sensitivity.R -- does the coverage (desert) verdict depend on the
# cross-border buffer distance? Recomputes ONLY the coverage layer for a set of
# zones at several buffer distances and reports the verdict, global p, and the
# share of population beyond 25 miles at each. Concentration/sufficiency are not
# recomputed (buffer only affects coverage).
#
# Usage: Rscript code/R/buffer_sensitivity.R "<zone1>;<zone2>;..." <pop_kind> <nsim>

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args     <- commandArgs(trailingOnly = TRUE)
zones    <- strsplit(if (length(args) >= 1) args[1] else
            "Amarillo, TX;Dallas city, TX;Detroit, MI;Houston, TX;San Diego, CA;San Juan zona urbana, PR", ";")[[1]]
pop_kind <- if (length(args) >= 2) args[2] else "ambient"
nsim     <- if (length(args) >= 3) as.integer(args[3]) else 499L
BUFFERS  <- c(25, 50, 100)
raster <- if (pop_kind == "ambient")
  file.path(root, "data", "landscan", "landscan-global-2020.tif") else
  file.path(root, "data", "gpw", "gpw_v4_2020.tif")

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
h0 <- sf::st_read(file.path(root, "data", "hospitals.gpkg"), quiet = TRUE)

cov_verdict <- function(zone, buffer_km) {
  w <- cz[cz[["name"]] == zone, ]; if (!nrow(w)) return(c(NA, NA, NA))
  epsg <- utm_epsg_for(w); wU <- sf::st_transform(sf::st_union(w), epsg)
  win <- spatstat.geom::as.owin(wU)
  buf_poly <- sf::st_buffer(wU, buffer_km * 1000); Wbuf <- spatstat.geom::as.owin(buf_poly)
  h <- sf::st_transform(h0, epsg)
  in_mask <- sf::st_within(h, wU, sparse = FALSE)[, 1]
  in_buf  <- sf::st_within(h, buf_poly, sparse = FALSE)[, 1]
  hc <- sf::st_coordinates(h[in_mask, ]); n_all <- nrow(hc)
  nbc <- sf::st_coordinates(h[in_buf & !in_mask, ])
  nbx <- if (nrow(nbc)) nbc[, 1] else numeric(0); nby <- if (nrow(nbc)) nbc[, 2] else numeric(0)
  pim <- population_im(raster, wU, epsg); lam <- lambda_im(pim, n_all)$im
  ix <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
  cx <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; wv <- pim$v[ix]
  ins <- spatstat.geom::inside.owin(cx, cy, win)
  cells <- spatstat.geom::ppp(cx[ins], cy[ins], window = Wbuf, checkdup = FALSE); cw <- wv[ins]
  bb <- spatstat.geom::as.rectangle(win)
  cov_d <- seq(0, min(100000, max(diff(bb$xrange), diff(bb$yrange))), by = 2000)
  covf <- function(hx, hy) { H <- spatstat.geom::ppp(hx, hy, window = Wbuf, checkdup = FALSE)
    d <- spatstat.geom::nncross(cells, H, what = "dist")
    vapply(cov_d, function(dd) sum(cw[d > dd]) / sum(cw), numeric(1)) }
  set.seed(42)
  obs <- covf(c(hc[, 1], nbx), c(hc[, 2], nby))
  sims <- vapply(seq_len(nsim), function(i) {
    P <- spatstat.random::rpoispp(lam)[win]; covf(c(P$x, nbx), c(P$y, nby)) }, numeric(length(cov_d)))
  gt <- GET::global_envelope_test(GET::create_curve_set(list(r = cov_d, obs = obs, sim_m = sims)),
                                  type = "erl", alpha = 0.05)
  p <- as.numeric(attr(gt, "p"))
  v <- if (any(gt$obs > gt$hi)) "under-served" else if (any(gt$obs < gt$lo)) "over-served" else "consistent"
  pct25 <- round(100 * obs[which.min(abs(cov_d - 25 * 1609.34))], 1)
  c(verdict = v, p = sprintf("%.3f", p), pct_beyond_25mi = pct25)
}

cat(sprintf("Coverage buffer sensitivity (%s, nsim=%d)\n", pop_kind, nsim))
cat(sprintf("%-28s %-14s %-14s %-14s\n", "zone", "25km", "50km", "100km"))
for (z in zones) {
  cells_out <- sapply(BUFFERS, function(b) { r <- cov_verdict(z, b); sprintf("%s(p%s)", r["verdict"], r["p"]) })
  cat(sprintf("%-28s %-14s %-14s %-14s\n", substr(z, 1, 28), cells_out[1], cells_out[2], cells_out[3]))
}
