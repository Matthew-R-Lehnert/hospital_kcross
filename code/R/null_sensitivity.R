#!/usr/bin/env Rscript
# null_sensitivity.R -- does the concentration verdict depend on the Poisson
# (random-N) null vs a fixed-N (binomial) null?
#
# The engine simulates hospitals with rpoispp(lambda) (a random number of points,
# with E[N] = n after rescaling integral(lambda) = n). A reviewer asks whether
# conditioning on the observed count n (a binomial/fixed-N null, rpoint(n, f =
# lambda)) would change anything. This re-tests a sample of concentration zones
# under BOTH nulls with the identical Kinhom estimator + GET ERL, and compares
# per-zone p-values and verdicts. Expectation: negligible difference, because at
# these n the Poisson count variance is a second-order effect on Kinhom.
#
# Output: docs/null_sensitivity.csv (window, n, p_poisson, p_fixedn,
#   verdict_poisson, verdict_fixedn) + prints agreement.
#
# Usage: Rscript code/R/null_sensitivity.R [pop_kind] [nzones] [nsim]

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args     <- commandArgs(trailingOnly = TRUE)
pop_kind <- if (length(args) >= 1) args[1] else "residential"
nzones   <- if (length(args) >= 2) as.integer(args[2]) else 8L
nsim     <- if (length(args) >= 3) as.integer(args[3]) else 999L
set.seed(42)

raster_path <- switch(pop_kind,
  ambient     = file.path(root, "data", "landscan", "landscan-global-2020.tif"),
  residential = file.path(root, "data", "gpw", "gpw_v4_2020.tif"))

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
hz <- sf::st_read(file.path(root, "data", "hospitals.gpkg"), quiet = TRUE)

# pick a representative sample: prefer the family-wise-flagged zones (where a
# null change would matter most), then fill with consistent zones.
fw_path <- file.path(root, "output", pop_kind, "_global_across_zones_all.csv")
flagged <- character(0)
if (file.exists(fw_path)) {
  fw <- utils::read.csv(fw_path)
  flagged <- fw$window[fw$fw_verdict == "over-concentrated"]
  others  <- fw$window[fw$fw_verdict != "over-concentrated"]
} else others <- character(0)
# fw$window are file-tag keys (non-alnum -> "_"); map back to real zone names
key2name <- setNames(cz[["name"]], gsub("[^A-Za-z0-9]+", "_", cz[["name"]]))
pick_keys <- c(head(flagged, ceiling(nzones / 2)), head(others, nzones))
pick <- unique(as.character(key2name[pick_keys]))
pick <- pick[!is.na(pick)][seq_len(min(nzones, sum(!is.na(pick))))]
message(sprintf("null sensitivity on %d %s zones: %s", length(pick), pop_kind,
                paste(pick, collapse = "; ")))

erl_p <- function(obs, sims, r) {
  keep <- is.finite(obs) & apply(sims, 1, function(row) all(is.finite(row)))
  cs <- GET::create_curve_set(list(r = r[keep], obs = obs[keep],
                                   sim_m = sims[keep, , drop = FALSE]))
  gt <- GET::global_envelope_test(cs, type = "erl", alpha = 0.05)
  list(p = as.numeric(attr(gt, "p")),
       verdict = if (any(gt$obs > gt$hi)) "over-concentrated"
                 else if (any(gt$obs < gt$lo)) "dispersed" else "consistent")
}

rows <- list()
for (z in pick) {
  w <- cz[cz[["name"]] == z, ]; epsg <- utm_epsg_for(w)
  wU <- sf::st_transform(sf::st_union(w), epsg); win <- spatstat.geom::as.owin(wU)
  h  <- sf::st_transform(hz, epsg); h <- h[sf::st_within(h, wU, sparse = FALSE)[, 1], ]
  n  <- nrow(h); if (n < 8) next
  hc <- sf::st_coordinates(h)
  X  <- spatstat.geom::ppp(hc[, 1], hc[, 2], window = win, checkdup = FALSE)
  pim <- population_im(raster_path, wU, epsg); lam <- lambda_im(pim, n)$im
  # intensity masked to the polygon, so fixed-N rpoint samples only inside win
  msk <- spatstat.geom::as.mask(win, xy = list(x = lam$xcol, y = lam$yrow))
  lam_win <- lam; lam_win$v[!msk$m] <- 0
  bb <- spatstat.geom::as.rectangle(win)
  r  <- seq(0, min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange))), by = 1000)
  KI <- function(P) {
    if (spatstat.geom::npoints(P) < 2) return(rep(0, length(r)))
    spatstat.explore::Kinhom(P, lambda = lam, r = r, correction = "Ripley", renormalise = TRUE)$iso
  }
  # draw one simulated K-curve, retrying only if spatstat's edge correction
  # throws (rare pathological pattern). NaN at r=0 is expected and handled later.
  sim_curve <- function(gen) {
    for (att in seq_len(20)) {
      out <- tryCatch(KI(gen()), error = function(e) NULL)
      if (!is.null(out)) return(out)
    }
    rep(NA_real_, length(r))
  }
  obs  <- KI(X)
  pois <- vapply(seq_len(nsim), function(i) sim_curve(function() spatstat.random::rpoispp(lam)[win]), numeric(length(r)))
  # rpoint returns a binary-mask window; Kinhom's Ripley correction needs the
  # polygonal window, so rebuild the pattern on win.
  gen_fixn <- function() {
    p <- spatstat.random::rpoint(n, f = lam_win, win = win)
    spatstat.geom::ppp(p$x, p$y, window = win, checkdup = FALSE)
  }
  fixn <- vapply(seq_len(nsim), function(i) sim_curve(gen_fixn), numeric(length(r)))
  # keep only fully-drawn sims (drop any that failed all retries)
  pois <- pois[, apply(pois, 2, function(c) !all(is.na(c))), drop = FALSE]
  fixn <- fixn[, apply(fixn, 2, function(c) !all(is.na(c))), drop = FALSE]
  a <- erl_p(obs, pois, r); b <- erl_p(obs, fixn, r)
  rows[[length(rows) + 1]] <- data.frame(window = z, n = n,
      p_poisson = round(a$p, 4), p_fixedn = round(b$p, 4),
      verdict_poisson = a$verdict, verdict_fixedn = b$verdict)
  message(sprintf("  %-24s n=%3d  p_pois=%.3f p_fix=%.3f  %s / %s", z, n, a$p, b$p, a$verdict, b$verdict))
}
df <- do.call(rbind, rows)
utils::write.csv(df, file.path(root, "docs", "null_sensitivity.csv"), row.names = FALSE)
agree <- sum(df$verdict_poisson == df$verdict_fixedn)
cat(sprintf("\nverdict agreement: %d / %d zones; max |p_pois - p_fix| = %.3f\n",
            agree, nrow(df), max(abs(df$p_poisson - df$p_fixedn))))
