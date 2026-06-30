# =============================================================================
# hk_core.R  —  Hospital × Population inhomogeneous K-function engine
# -----------------------------------------------------------------------------
# Tests whether hospital point locations follow population within a window
# (a commuting zone), using an inhomogeneous K-function whose null intensity is
# set PROPORTIONAL TO POPULATION (an externally supplied raster: LandScan
# ambient or GPW residential), evaluated against a Monte-Carlo envelope of
# inhomogeneous-Poisson simulations.
#
# Contrast with the Kcross (LIHTC × crime) engine this is adapted from: there,
# the inhomogeneous intensity was KDE-estimated from the sparse fixed layer,
# which created the bandwidth/floor/eps-underflow artifact. HERE lambda is the
# population raster itself — no bandwidth, no leave-one-out, no floor artifact.
# A small positive floor is applied only to populated-by-a-hospital-but-zero-pop
# cells, purely to keep 1/lambda finite, and its level is reported.
#
# Estimator (Baddeley/Møller/Waagepetersen):
#   K_inhom(r) = (1/|W|) sum_{i!=j} 1{||xi-xj||<=r} e(xi,xj) / (lambda(xi) lambda(xj))
# Under H0 (hospitals ~ inhomogeneous Poisson, lambda ∝ population):
#   K_inhom(r) ≈ pi r^2.  Above the upper envelope => over-concentrated relative
#   to population; below the lower => more regular than population.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(spatstat)
  library(GET)
  library(ggplot2)
})

# -----------------------------------------------------------------------------
# utm_epsg_for(): pick a local UTM EPSG from a geometry's centroid so the
# K-function distances and the intensity area-integral are in meters. Works for
# CONUS, AK, HI, and territories (per-zone). Northern hemisphere assumed (US).
# -----------------------------------------------------------------------------
utm_epsg_for <- function(geom_4326) {
  ctr <- sf::st_coordinates(sf::st_centroid(sf::st_union(geom_4326)))
  lon <- ctr[1, 1]; lat <- ctr[1, 2]
  zone <- floor((lon + 180) / 6) + 1
  base <- if (lat >= 0) 32600 else 32700
  as.integer(base + zone)
}

# -----------------------------------------------------------------------------
# population_im(): read a population raster, clip to the window, project to the
# window's UTM CRS, and return a spatstat image (im) of population PER CELL,
# zeroed outside the window. `res_m` sets the working pixel size in meters
# (default 1000 m, matching the ~1 km native LandScan/GPW grid).
# -----------------------------------------------------------------------------
population_im <- function(raster_path, window_utm, epsg, res_m = 1000) {
  r <- terra::rast(raster_path)
  # crop in the raster's own CRS (LandScan/GPW are EPSG:4326)
  win_ll <- sf::st_transform(window_utm, terra::crs(r))
  r <- terra::crop(r, terra::vect(win_ll), snap = "out")
  # mask negative nodata/sentinels to NA, then project to the window UTM
  r <- terra::clamp(r, lower = 0, values = FALSE)
  tmpl <- terra::rast(terra::ext(terra::project(terra::vect(win_ll),
                                                paste0("EPSG:", epsg))),
                      resolution = res_m, crs = paste0("EPSG:", epsg))
  r <- terra::project(r, tmpl, method = "bilinear")
  r <- terra::mask(r, terra::vect(window_utm))
  # terra SpatRaster -> spatstat im
  m  <- terra::as.matrix(r, wide = TRUE)
  m  <- m[nrow(m):1, , drop = FALSE]            # im rows go bottom-up
  ex <- terra::ext(r)
  xs <- seq(ex$xmin + res_m / 2, ex$xmax - res_m / 2, length.out = ncol(m))
  ys <- seq(ex$ymin + res_m / 2, ex$ymax - res_m / 2, length.out = nrow(m))
  v  <- m; v[is.na(v)] <- 0
  spatstat.geom::im(v, xcol = xs, yrow = ys)
}

# -----------------------------------------------------------------------------
# lambda_im(): turn a population image into the null intensity surface,
# normalized so that the integral over the window equals n (the hospital count),
# i.e. lambda(u) = n * pop(u) / ∫pop. A positive floor replaces exact zeros so
# 1/lambda stays finite. Returns list(im, floor_used, integral_pop).
# -----------------------------------------------------------------------------
lambda_im <- function(pop_im, n, floor_frac = 1e-6) {
  cell <- pop_im$xstep * pop_im$ystep
  integral_pop <- sum(pop_im$v, na.rm = TRUE) * cell
  if (integral_pop <= 0) stop("population integral is zero over this window")
  lam <- pop_im
  lam$v <- pop_im$v * (n / integral_pop)        # ∫lambda = n
  # floor: a small fraction of the mean intensity, applied to zero cells only
  mean_int <- n / (sum(!is.na(pop_im$v)) * cell)
  fl <- floor_frac * mean_int
  lam$v[lam$v <= 0] <- fl
  list(im = lam, floor_used = fl, integral_pop = integral_pop)
}

# -----------------------------------------------------------------------------
# run_hk(): one (window, year, population-kind) analysis.
#   windows_sf  : sf of commuting zones (or any windows) in EPSG:4326, with a
#                 name column `name_col`.
#   hospitals_sf: sf of open hospital points (EPSG:4326) with `beds`, `is_trauma`.
#   raster_path : the population GeoTIFF for this year/kind.
#   subset      : "all" | "trauma"          (which hospitals)
#   weight_by   : "none" | "beds"           (capacity weighting; see note)
# Writes <name>_envelope.{png,csv} and <name>_meta.json into out_dir.
# -----------------------------------------------------------------------------
run_hk <- function(window_name, windows_sf, hospitals_sf, raster_path,
                   out_dir, pop_kind = "ambient",
                   subset = c("all", "trauma"),
                   weight_by = c("none", "beds"),
                   nsim = 999, r_max = NULL, r_step = NULL,
                   correction = "Ripley", seed = 42, res_m = 1000,
                   min_hospitals = 8, save_sims = TRUE, verbose = TRUE) {
  subset    <- match.arg(subset)
  weight_by <- match.arg(weight_by)
  t0 <- Sys.time()
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # --- window + projection -------------------------------------------------
  w <- windows_sf[windows_sf[["name"]] == window_name, ]
  if (nrow(w) == 0) stop("window not found: ", window_name)
  epsg <- utm_epsg_for(w)
  w_utm <- sf::st_transform(sf::st_union(w), epsg)
  win <- spatstat.geom::as.owin(w_utm)

  # --- hospitals inside window --------------------------------------------
  h <- sf::st_transform(hospitals_sf, epsg)
  if (subset == "trauma") h <- h[h$is_trauma %in% TRUE, ]
  h <- h[sf::st_within(h, w_utm, sparse = FALSE)[, 1], ]
  n <- nrow(h)
  if (n < min_hospitals)
    return(invisible(list(skipped = TRUE, n = n, window = window_name,
                          reason = sprintf("only %d hospitals (< %d)", n, min_hospitals))))
  hc <- sf::st_coordinates(h)
  X  <- spatstat.geom::ppp(hc[, 1], hc[, 2], window = win, checkdup = FALSE)

  # capacity weighting by bed-count: first pass replicates each point by its
  # (rounded) bed count so a high-capacity hospital counts proportionally more.
  # TODO: replace with a proper weighted-K estimator; replication is the crude
  # but transparent v1. Beds missing (HIFLD -999 -> NA) fall back to weight 1.
  if (weight_by == "beds") {
    bw <- h$beds; bw[is.na(bw) | bw < 1] <- 1
    rep_idx <- rep(seq_len(n), pmax(1L, round(bw / stats::median(bw[bw > 0]))))
    X <- spatstat.geom::ppp(hc[rep_idx, 1], hc[rep_idx, 2], window = win, checkdup = FALSE)
  }

  # --- population intensity (the null) ------------------------------------
  pim <- population_im(raster_path, w_utm, epsg, res_m = res_m)
  lam <- lambda_im(pim, n = spatstat.geom::npoints(X))
  lambda <- lam$im

  # --- radii ---------------------------------------------------------------
  # Fixed, interpretable grid: 0..50 km in 1 km ticks (hospital access is a
  # drive-time-scale question; 50 km spans metro access and the trauma "golden
  # hour" at typical speeds). Each zone's r_max is capped at ~1/4 of the
  # window's SHORTER side so Ripley edge correction stays reliable; the cap is
  # recorded (r_capped) so truncated zones can be flagged in the analysis.
  bb       <- spatstat.geom::as.rectangle(win)
  mindim   <- min(diff(bb$xrange), diff(bb$yrange))
  r_cap    <- 0.25 * mindim
  r_max    <- if (is.null(r_max))  min(50000, r_cap) else r_max
  r_step   <- if (is.null(r_step)) 1000 else r_step
  r_vals   <- seq(0, r_max, by = r_step)
  r_capped <- r_max < 50000

  # --- observed K + envelope ----------------------------------------------
  set.seed(seed)
  Kfun <- function(P, ...) spatstat.explore::Kinhom(P, lambda = lambda,
                                                    r = r_vals, correction = correction)
  sim_one <- function() {
    p <- spatstat.random::rpoispp(lambda)        # inhomogeneous-Poisson hospitals
    p[win]                                        # keep to the polygon window
  }
  env <- spatstat.explore::envelope(
    X, fun = Kfun, nsim = nsim, simulate = expression(sim_one()),
    savefuns = TRUE, verbose = verbose
  )
  # Global (family-wise over the whole r-curve) envelope test, ERL ordering,
  # alpha = 0.05 (Myllymaki et al. 2017; GET package). This replaces the raw
  # pointwise min/max band, which at nsim=999 is the 1st/999th extreme -- far
  # too conservative (per-r alpha ~0.001) and, at small nsim, too narrow (false
  # positives). The ERL band has a controlled GLOBAL 5% level across all r and
  # yields one global p-value per zone. lo/hi below are the 95% global band.
  gt <- GET::global_envelope_test(env, type = "erl", alpha = 0.05)
  global_p <- as.numeric(attr(gt, "p"))
  env_df <- data.frame(r = gt$r, obs = gt$obs, mmean = gt$central,
                       lo = gt$lo, hi = gt$hi, theo = pi * gt$r^2)

  # --- verdict + outputs ---------------------------------------------------
  above <- env_df$obs > env_df$hi
  below <- env_df$obs < env_df$lo
  tag <- sprintf("%s_%s_%s%s", gsub("[^A-Za-z0-9]+", "_", window_name),
                 pop_kind, subset, if (weight_by == "beds") "_beds" else "")
  png_path  <- file.path(out_dir, paste0(tag, "_envelope.png"))
  csv_path  <- file.path(out_dir, paste0(tag, "_envelope.csv"))
  meta_path <- file.path(out_dir, paste0(tag, "_meta.json"))

  # Persist the 999 simulated K-curves (+ observed) so the across-zone
  # family-wise global test (code/R/global_across_zones.R) and any re-analysis
  # can reuse them WITHOUT re-simulating. Sims are valid only for THIS
  # (zone, pop_kind, subset, weight_by) -- lambda and n differ across those.
  if (save_sims) {
    simfv <- attr(env, "simfuns")
    simm  <- if (!is.null(simfv))
               as.matrix(as.data.frame(simfv)[, -1, drop = FALSE]) else NULL
    saveRDS(list(r = env_df$r, obs = env_df$obs, sims = simm,
                 window = window_name, pop_kind = pop_kind, subset = subset,
                 weight_by = weight_by, nsim = nsim, n_hospitals = n,
                 r_capped = r_capped, seed = seed),
            file.path(out_dir, paste0(tag, "_simfuns.rds")))
  }

  p <- ggplot(env_df, aes(x = r)) +
    geom_ribbon(aes(ymin = lo, ymax = hi), fill = "grey80", alpha = .6) +
    geom_line(aes(y = theo), linetype = 2, colour = "grey40") +
    geom_line(aes(y = obs), colour = "firebrick", linewidth = 1) +
    labs(title = sprintf("%s — hospitals vs %s population", window_name, pop_kind),
         subtitle = sprintf("Kinhom, nsim=%d, n=%d%s", nsim, n,
                            if (subset == "trauma") ", trauma only" else ""),
         x = "Distance (m)", y = expression(italic(K)[inhom](r))) +
    theme_classic()
  ggsave(png_path, p, width = 8, height = 6, dpi = 200)
  utils::write.csv(env_df, csv_path, row.names = FALSE)

  meta <- list(window = window_name, epsg = epsg, pop_kind = pop_kind,
               subset = subset, weight_by = weight_by, n_hospitals = n,
               nsim = nsim, r_max = r_max, r_step = r_step, r_capped = r_capped,
               correction = correction, res_m = res_m, seed = seed,
               lambda_floor = lam$floor_used, pop_integral = lam$integral_pop,
               global_p = global_p,
               verdict = if (any(above)) "over-concentrated"
                         else if (any(below)) "dispersed" else "consistent",
               r_first_overconc = if (any(above)) min(env_df$r[above]) else NA_real_,
               frac_r_overconc = mean(above), frac_r_dispersed = mean(below),
               runtime_sec = round(as.numeric(difftime(Sys.time(), t0, "secs")), 1))
  writeLines(.json(meta), meta_path)
  if (verbose) message(sprintf("  [%s/%s] n=%d  done %.1fs -> %s",
                               window_name, pop_kind, n, meta$runtime_sec, png_path))
  invisible(list(env_df = env_df, meta = meta, env = env))
}

# minimal JSON writer (avoids a hard jsonlite dependency)
.json <- function(x) {
  if (requireNamespace("jsonlite", quietly = TRUE))
    return(jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE, na = "null"))
  fmt <- function(v) if (is.character(v)) paste0('"', v, '"')
                     else if (length(v) == 0 || is.na(v)) "null" else as.character(v)
  paste0("{\n", paste(sprintf('  "%s": %s', names(x), vapply(x, fmt, "")),
                      collapse = ",\n"), "\n}")
}
