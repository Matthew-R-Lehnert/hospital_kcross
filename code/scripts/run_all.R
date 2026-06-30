#!/usr/bin/env Rscript
# run_all.R -- fan the inhomogeneous-K test across ALL windows for one year and
# population kind, in parallel, then write a collated summary table.
#
# Usage:
#   Rscript code/scripts/run_all.R <year> <pop_kind> [nsim] [cores] [subset] [weight_by]
# Example:
#   Rscript code/scripts/run_all.R 2021 ambient 999 8
#
# macOS fork-safety with GDAL/sf (see Kcross METHODOLOGY §11):
Sys.setenv(OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES")

suppressPackageStartupMessages({ library(sf); library(parallel) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args      <- commandArgs(trailingOnly = TRUE)
year      <- as.integer(args[1]); pop_kind <- args[2]
nsim      <- if (length(args) >= 3) as.integer(args[3]) else 999
cores     <- if (length(args) >= 4) as.integer(args[4]) else max(1, detectCores() - 2)
subset    <- if (length(args) >= 5) args[5] else "all"
weight_by <- if (length(args) >= 6) args[6] else "none"

windows_sf   <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
hospitals_sf <- sf::st_read(file.path(root, "data", "hospitals.gpkg"),      quiet = TRUE)
raster_path  <- if (pop_kind == "ambient")
  file.path(root, "data", "landscan", sprintf("landscan-global-%d.tif", year)) else
  file.path(root, "data", "gpw", sprintf("gpw_v4_%d.tif", year))
stopifnot(file.exists(raster_path))
out_dir <- file.path(root, "output", pop_kind)

names_all <- windows_sf[["name"]]
message(sprintf("running %d windows x (%s, %d) on %d cores",
                length(names_all), pop_kind, year, cores))

results <- mclapply(names_all, function(nm) {
  tryCatch(
    run_hk(nm, windows_sf, hospitals_sf, raster_path, out_dir = out_dir,
           pop_kind = pop_kind, subset = subset, weight_by = weight_by,
           nsim = nsim, verbose = FALSE)$meta,
    error = function(e) list(window = nm, error = conditionMessage(e)))
}, mc.cores = cores, mc.preschedule = FALSE)

# collate to output/summary_<kind>_<year>.csv
rows <- Filter(function(m) is.list(m) && !is.null(m$frac_r_overconc), results)
if (length(rows)) {
  df <- do.call(rbind, lapply(rows, function(m) data.frame(
    window = m$window, n = m$n_hospitals, pop_kind = m$pop_kind,
    frac_overconc = m$frac_r_overconc, frac_dispersed = m$frac_r_dispersed,
    r_first_overconc = m$r_first_overconc)))
  f <- file.path(root, "output", sprintf("summary_%s_%d.csv", pop_kind, year))
  utils::write.csv(df, f, row.names = FALSE)
  message(sprintf("collated %d windows -> %s", nrow(df), f))
}
