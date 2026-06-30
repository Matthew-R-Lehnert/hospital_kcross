# =============================================================================
# hk_combined.R -- one pass per (zone, population-kind) measuring THREE
# orthogonal axes of hospital supply vs population, all from ONE set of shared
# population permutations (hospitals resampled, population fixed):
#
#   CONCENTRATION  is supply clumped beyond population?   inhomogeneous K
#                  - facilities (unweighted) and beds (capacity-weighted)
#   COVERAGE       are people far from care?              pop-weighted distance
#                  to nearest hospital vs the same null   (curve over distance)
#   SUFFICIENCY    is there enough capacity per person?   beds per 1,000 pop
#                  (a ratio; no simulation; covers sparse zones too)
#
# Concentration and coverage are point-process tests against rpoispp(lambda~pop)
# (the SAME 999 permutations, saved per layer for the across-zone family-wise
# test). Sufficiency is a descriptive ratio against US / OECD references.
#
# Estimator: spatstat::Kinhom (validated). Bed-weighting via the per-point
# intensity identity L_i/w_i (no custom estimator). Verdict: GET global ERL.
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra); library(spatstat); library(GET); library(ggplot2)
})
# Load hk_core.R helpers (population_im, lambda_im, utm_epsg_for, .json). Works
# whether this file is run directly (--file points here) or sourced by a caller
# that has already loaded hk_core.R.
if (!exists("population_im", mode = "function")) {
  .a <- grep("--file=", commandArgs(FALSE), value = TRUE)
  .d <- if (length(.a)) dirname(sub("--file=", "", .a[1])) else "."
  .cand <- file.path(.d, "hk_core.R")
  if (file.exists(.cand)) source(.cand) else
    stop("hk_core.R not loaded: source code/R/hk_core.R before hk_combined.R")
}

BEDS_PER_1000_US   <- 2.8    # ~US hospital beds per 1,000 (verify/cite)
BEDS_PER_1000_OECD <- 4.3    # ~OECD average (verify/cite)

# GET global-ERL verdict + outputs for ONE layer's observed + simulated curves.
.finalize_layer <- function(tag, x, obs, sims, out_dir, title, ylab, extra_meta,
                            above_label = "over-concentrated",
                            below_label = "dispersed", show_theo = TRUE) {
  cs <- GET::create_curve_set(list(r = x, obs = obs, sim_m = sims))
  gt <- GET::global_envelope_test(cs, type = "erl", alpha = 0.05)
  gp <- as.numeric(attr(gt, "p"))
  df <- data.frame(x = gt$r, obs = gt$obs, mmean = gt$central, lo = gt$lo, hi = gt$hi)
  if (show_theo) df$theo <- pi * gt$r^2
  above <- df$obs > df$hi; below <- df$obs < df$lo
  verdict <- if (any(above)) above_label else if (any(below)) below_label else "consistent"

  utils::write.csv(df, file.path(out_dir, paste0(tag, "_envelope.csv")), row.names = FALSE)
  saveRDS(list(x = x, obs = obs, sims = sims, tag = tag),
          file.path(out_dir, paste0(tag, "_simfuns.rds")))
  p <- ggplot(df, aes(x)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = "grey80", alpha = .6) +
    { if (show_theo) geom_line(aes(y = theo), linetype = 2, colour = "grey40") } +
    geom_line(aes(y = obs), colour = "firebrick", linewidth = 1) +
    labs(title = title, x = "Distance (m)", y = ylab) + theme_classic()
  ggsave(file.path(out_dir, paste0(tag, "_envelope.png")), p, width = 8, height = 6, dpi = 200)

  meta <- c(extra_meta, list(global_p = gp, verdict = verdict,
            frac_above = mean(above), frac_below = mean(below)))
  writeLines(.json(meta), file.path(out_dir, paste0(tag, "_meta.json")))
  list(verdict = verdict, global_p = gp)
}

# One (zone, pop_kind): concentration (facilities, beds) + coverage + sufficiency.
run_hk_all <- function(window_name, windows_sf, hospitals_sf, raster_path,
                       out_dir, pop_kind = "ambient",
                       nsim = 999, seed = 42, res_m = 1000,
                       min_hospitals = 8, beds_median = NA, verbose = TRUE) {
  t0 <- Sys.time(); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  w <- windows_sf[windows_sf[["name"]] == window_name, ]
  if (!nrow(w)) stop("window not found: ", window_name)
  epsg <- utm_epsg_for(w); wU <- sf::st_transform(sf::st_union(w), epsg)
  win  <- spatstat.geom::as.owin(wU)

  h <- sf::st_transform(hospitals_sf, epsg)
  h <- h[sf::st_within(h, wU, sparse = FALSE)[, 1], ]
  n_all <- nrow(h)
  hc    <- if (n_all) sf::st_coordinates(h) else matrix(0, 0, 2)

  # population image + total population (people) for this pop_kind
  pim     <- population_im(raster_path, wU, epsg, res_m = res_m)
  cell_km2 <- (pim$xstep / 1000) * (pim$ystep / 1000)
  pop_total <- sum(pim$v, na.rm = TRUE)              # LandScan/GPW = people per cell

  # --- SUFFICIENCY (always computed, even for sparse/skipped-by-K zones) ----
  beds_known <- h$beds[is.finite(h$beds) & h$beds > 0]
  beds_total <- sum(beds_known)
  beds_per_1000 <- if (pop_total > 0) 1000 * beds_total / pop_total else NA_real_
  suff <- list(layer = "sufficiency", n_hospitals = n_all,
               pop_total = pop_total, beds_total_known = beds_total,
               beds_per_1000 = beds_per_1000,
               ratio_to_US = beds_per_1000 / BEDS_PER_1000_US,
               ratio_to_OECD = beds_per_1000 / BEDS_PER_1000_OECD,
               us_ref = BEDS_PER_1000_US, oecd_ref = BEDS_PER_1000_OECD)
  tagbase <- gsub("[^A-Za-z0-9]+", "_", window_name)
  writeLines(.json(c(list(window = window_name, pop_kind = pop_kind), suff)),
             file.path(out_dir, sprintf("%s_%s_sufficiency_meta.json", tagbase, pop_kind)))

  if (n_all < min_hospitals)
    return(invisible(list(skipped_pp = TRUE, window = window_name, n = n_all,
                          sufficiency = suff,
                          reason = sprintf("only %d hospitals (< %d): point-pattern tests skipped, sufficiency still reported", n_all, min_hospitals))))

  X_all <- spatstat.geom::ppp(hc[, 1], hc[, 2], window = win, checkdup = FALSE)
  beds  <- h$beds; if (is.na(beds_median)) beds_median <- stats::median(beds, na.rm = TRUE)
  n_imp <- sum(is.na(beds) | beds < 1); beds[is.na(beds) | beds < 1] <- beds_median

  lam_all <- lambda_im(pim, n_all)$im
  g_im    <- lambda_im(pim, 1)$im                    # population density, integral 1

  # populated cells (for coverage): centroids + population weights, kept only
  # where the centroid is inside the polygon window so cells and weights align.
  ix  <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
  cx  <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; wv <- pim$v[ix]
  ins <- spatstat.geom::inside.owin(cx, cy, win)
  cells <- spatstat.geom::ppp(cx[ins], cy[ins], window = win, checkdup = FALSE)
  cellw <- wv[ins]

  bb <- spatstat.geom::as.rectangle(win)
  maxdim <- max(diff(bb$xrange), diff(bb$yrange))
  r_max <- min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange)))
  r <- seq(0, r_max, by = 1000); r_capped <- r_max < 50000
  cov_d <- seq(0, min(100000, maxdim), by = 2000)    # coverage distance grid
  KI  <- function(P, lam) spatstat.explore::Kinhom(P, lambda = lam, r = r,
                                                  correction = "Ripley", renormalise = TRUE)$iso
  gat <- function(P) as.numeric(g_im[P, drop = FALSE])
  covfrac <- function(P) {                            # % population beyond d from nearest hospital
    d <- spatstat.geom::nncross(cells, P, what = "dist")
    vapply(cov_d, function(dd) sum(cellw[d > dd]) / sum(cellw), numeric(1))
  }

  # observed curves
  K_fac_obs <- KI(X_all, lam_all)
  K_bed_obs <- KI(X_all, (sum(beds) * gat(X_all)) / beds)
  cov_obs   <- covfrac(X_all)

  # shared base simulations -> facility, bed, coverage curves
  set.seed(seed)
  fac <- bed <- cov <- vector("list", nsim)
  for (s in seq_len(nsim)) {
    P  <- spatstat.random::rpoispp(lam_all)[win]
    np <- spatstat.geom::npoints(P)
    if (np >= 2) {
      fac[[s]] <- KI(P, lam_all)
      ws <- sample(beds, np, replace = TRUE)
      bed[[s]] <- KI(P, (sum(ws) * gat(P)) / ws)
      cov[[s]] <- covfrac(P)
    } else {
      fac[[s]] <- rep(0, length(r)); bed[[s]] <- rep(0, length(r))
      cov[[s]] <- rep(1, length(cov_d))
    }
  }
  base_meta <- list(window = window_name, epsg = epsg, pop_kind = pop_kind,
                    nsim = nsim, r_max = r_max, r_step = 1000, r_capped = r_capped,
                    correction = "Ripley", res_m = res_m, seed = seed,
                    n_hospitals = n_all, beds_imputed = n_imp, beds_median = beds_median,
                    beds_per_1000 = beds_per_1000)

  res <- list(sufficiency = suff)
  res$facilities <- .finalize_layer(
    sprintf("%s_%s_all", tagbase, pop_kind), r, K_fac_obs, do.call(cbind, fac),
    out_dir, sprintf("%s -- hospitals vs %s population", window_name, pop_kind),
    expression(italic(K)[inhom](r)),
    c(base_meta, list(layer = "facilities", subset = "all", weight_by = "none")))
  res$beds <- .finalize_layer(
    sprintf("%s_%s_beds", tagbase, pop_kind), r, K_bed_obs, do.call(cbind, bed),
    out_dir, sprintf("%s -- bed supply vs %s population", window_name, pop_kind),
    expression(italic(K)[inhom]^{beds}(r)),
    c(base_meta, list(layer = "beds", subset = "all", weight_by = "beds")))
  res$coverage <- .finalize_layer(
    sprintf("%s_%s_coverage", tagbase, pop_kind), cov_d, cov_obs, do.call(cbind, cov),
    out_dir, sprintf("%s -- population beyond distance d from nearest hospital (%s)", window_name, pop_kind),
    "fraction of population beyond d",
    c(base_meta, list(layer = "coverage")),
    above_label = "under-served", below_label = "over-served", show_theo = FALSE)

  if (verbose) message(sprintf("  [%s/%s] n=%d beds/1k=%.2f  %.1fs  conc=%s beds=%s cover=%s",
      window_name, pop_kind, n_all, beds_per_1000,
      as.numeric(difftime(Sys.time(), t0, units = "secs")),
      res$facilities$verdict, res$beds$verdict, res$coverage$verdict))
  invisible(res)
}
