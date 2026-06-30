# =============================================================================
# hk_combined.R -- one pass per (zone, population-kind) measuring THREE
# orthogonal axes of hospital supply vs population, from shared population
# permutations (hospitals resampled, population fixed):
#
#   CONCENTRATION  is supply clumped beyond population?   inhomogeneous K
#                  - facilities (unweighted) and beds (capacity-weighted)
#   COVERAGE       are people far from care?              pop-weighted distance
#                  to nearest hospital, vs the same null (curve over distance)
#   SUFFICIENCY    is there enough capacity per person?   beds per 1,000 pop
#
# CROSS-BORDER (buffered) COVERAGE: a person near the zone edge may be served by
# a hospital in a neighbouring zone, so restricting coverage to in-zone
# hospitals would invent false edge deserts. The coverage axis therefore uses
# every hospital within the zone OR within `buffer_km` of it; the null resamples
# only the IN-ZONE hospitals (the allocation question) while holding the
# out-of-zone buffer hospitals FIXED, so both observed and null credit
# cross-border access. Concentration (K, edge-corrected) and sufficiency remain
# in-zone quantities.
#
# Estimator: spatstat::Kinhom (validated). Bed-weighting via the per-point
# intensity identity L_i/w_i. Verdict: GET global ERL. The 999 curves are saved
# per layer for the across-zone family-wise test.
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra); library(spatstat); library(GET); library(ggplot2)
})
if (!exists("population_im", mode = "function")) {
  .a <- grep("--file=", commandArgs(FALSE), value = TRUE)
  .d <- if (length(.a)) dirname(sub("--file=", "", .a[1])) else "."
  .cand <- file.path(.d, "hk_core.R")
  if (file.exists(.cand)) source(.cand) else
    stop("hk_core.R not loaded: source code/R/hk_core.R before hk_combined.R")
}

BEDS_PER_1000_US   <- 2.8    # ~US hospital beds per 1,000 (verify/cite)
BEDS_PER_1000_OECD <- 4.3    # ~OECD average (verify/cite)

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

run_hk_all <- function(window_name, windows_sf, hospitals_sf, raster_path,
                       out_dir, pop_kind = "ambient",
                       nsim = 999, seed = 42, res_m = 1000,
                       min_hospitals = 8, beds_median = NA, buffer_km = 50,
                       verbose = TRUE) {
  t0 <- Sys.time(); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  w <- windows_sf[windows_sf[["name"]] == window_name, ]
  if (!nrow(w)) stop("window not found: ", window_name)
  epsg <- utm_epsg_for(w); wU <- sf::st_transform(sf::st_union(w), epsg)
  win  <- spatstat.geom::as.owin(wU)
  buf_poly <- sf::st_buffer(wU, buffer_km * 1000); Wbuf <- spatstat.geom::as.owin(buf_poly)

  # in-zone hospitals (for K, beds, sufficiency) + out-of-zone buffer neighbours
  h_all   <- sf::st_transform(hospitals_sf, epsg)
  in_mask <- sf::st_within(h_all, wU, sparse = FALSE)[, 1]
  in_buf  <- sf::st_within(h_all, buf_poly, sparse = FALSE)[, 1]
  h   <- h_all[in_mask, ]
  nb  <- h_all[in_buf & !in_mask, ]
  nbx <- if (nrow(nb)) sf::st_coordinates(nb)[, 1] else numeric(0)
  nby <- if (nrow(nb)) sf::st_coordinates(nb)[, 2] else numeric(0)
  n_all <- nrow(h); hc <- if (n_all) sf::st_coordinates(h) else matrix(0, 0, 2)

  pim <- population_im(raster_path, wU, epsg, res_m = res_m)
  pop_total <- sum(pim$v, na.rm = TRUE)

  # --- SUFFICIENCY (always; covers sparse zones the K-test skips) -----------
  beds_known <- h$beds[is.finite(h$beds) & h$beds > 0]
  beds_total <- sum(beds_known)
  beds_per_1000 <- if (pop_total > 0) 1000 * beds_total / pop_total else NA_real_
  suff <- list(layer = "sufficiency", n_hospitals = n_all, pop_total = pop_total,
               beds_total_known = beds_total, beds_per_1000 = beds_per_1000,
               ratio_to_US = beds_per_1000 / BEDS_PER_1000_US,
               ratio_to_OECD = beds_per_1000 / BEDS_PER_1000_OECD,
               us_ref = BEDS_PER_1000_US, oecd_ref = BEDS_PER_1000_OECD)
  tagbase <- gsub("[^A-Za-z0-9]+", "_", window_name)
  writeLines(.json(c(list(window = window_name, pop_kind = pop_kind), suff)),
             file.path(out_dir, sprintf("%s_%s_sufficiency_meta.json", tagbase, pop_kind)))

  if (n_all < min_hospitals)
    return(invisible(list(skipped_pp = TRUE, window = window_name, n = n_all, sufficiency = suff,
        reason = sprintf("only %d hospitals (< %d): point-pattern tests skipped, sufficiency reported", n_all, min_hospitals))))

  X_all <- spatstat.geom::ppp(hc[, 1], hc[, 2], window = win, checkdup = FALSE)
  beds  <- h$beds; if (is.na(beds_median)) beds_median <- stats::median(beds, na.rm = TRUE)
  n_imp <- sum(is.na(beds) | beds < 1); beds[is.na(beds) | beds < 1] <- beds_median

  lam_all <- lambda_im(pim, n_all)$im
  g_im    <- lambda_im(pim, 1)$im

  # populated in-zone cells (coverage), placed in the buffered window so distance
  # to out-of-zone hospitals is computable
  ix  <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
  cx  <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; wv <- pim$v[ix]
  ins <- spatstat.geom::inside.owin(cx, cy, win)
  cells <- spatstat.geom::ppp(cx[ins], cy[ins], window = Wbuf, checkdup = FALSE)
  cellw <- wv[ins]

  bb <- spatstat.geom::as.rectangle(win)
  maxdim <- max(diff(bb$xrange), diff(bb$yrange))
  r_max <- min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange)))
  r <- seq(0, r_max, by = 1000); r_capped <- r_max < 50000
  cov_d <- seq(0, min(100000, maxdim), by = 2000)
  KI  <- function(P, lam) spatstat.explore::Kinhom(P, lambda = lam, r = r,
                                                  correction = "Ripley", renormalise = TRUE)$iso
  gat <- function(P) as.numeric(g_im[P, drop = FALSE])
  covf <- function(hx, hy) {                          # % pop beyond d from nearest hospital (in-zone + buffer)
    H <- spatstat.geom::ppp(hx, hy, window = Wbuf, checkdup = FALSE)
    d <- spatstat.geom::nncross(cells, H, what = "dist")
    vapply(cov_d, function(dd) sum(cellw[d > dd]) / sum(cellw), numeric(1))
  }

  K_fac_obs <- KI(X_all, lam_all)
  K_bed_obs <- KI(X_all, (sum(beds) * gat(X_all)) / beds)
  cov_obs   <- covf(c(hc[, 1], nbx), c(hc[, 2], nby))

  set.seed(seed)
  fac <- bed <- cov <- vector("list", nsim)
  for (s in seq_len(nsim)) {
    P  <- spatstat.random::rpoispp(lam_all)[win]; np <- spatstat.geom::npoints(P)
    if (np >= 2) {
      fac[[s]] <- KI(P, lam_all)
      ws <- sample(beds, np, replace = TRUE); bed[[s]] <- KI(P, (sum(ws) * gat(P)) / ws)
    } else { fac[[s]] <- rep(0, length(r)); bed[[s]] <- rep(0, length(r)) }
    cov[[s]] <- covf(c(P$x, nbx), c(P$y, nby))        # resampled in-zone + FIXED neighbours
  }
  base_meta <- list(window = window_name, epsg = epsg, pop_kind = pop_kind,
                    nsim = nsim, r_max = r_max, r_step = 1000, r_capped = r_capped,
                    correction = "Ripley", res_m = res_m, seed = seed,
                    n_hospitals = n_all, n_neighbors = nrow(nb), buffer_km = buffer_km,
                    beds_imputed = n_imp, beds_median = beds_median, beds_per_1000 = beds_per_1000)

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
    out_dir, sprintf("%s -- population beyond distance d from nearest hospital (%s, +%gkm buffer)",
                     window_name, pop_kind, buffer_km),
    "fraction of population beyond d",
    c(base_meta, list(layer = "coverage")),
    above_label = "under-served", below_label = "over-served", show_theo = FALSE)

  if (verbose) message(sprintf("  [%s/%s] n=%d (+%d nbr) beds/1k=%.2f  %.1fs  conc=%s beds=%s cover=%s",
      window_name, pop_kind, n_all, nrow(nb), beds_per_1000,
      as.numeric(difftime(Sys.time(), t0, units = "secs")),
      res$facilities$verdict, res$beds$verdict, res$coverage$verdict))
  invisible(res)
}
