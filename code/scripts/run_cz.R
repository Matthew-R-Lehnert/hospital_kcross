#!/usr/bin/env Rscript
# run_cz.R -- run the combined hospital x population analysis for ONE commuting
# zone: concentration (facilities + beds), coverage, and sufficiency, all from
# shared population permutations.
#
# Usage:
#   Rscript code/scripts/run_cz.R <window_name> <year> <pop_kind> [nsim]
# Examples:
#   Rscript code/scripts/run_cz.R "Tucson, AZ" 2020 ambient
#   Rscript code/scripts/run_cz.R "San Diego, CA" 2020 residential 999
#
# Env overrides: HK_WINDOWS, HK_HOSPITALS, HK_LANDSCAN_DIR, HK_GPW_DIR, HK_OUT.

suppressPackageStartupMessages(library(sf))
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))
source(file.path(root, "code", "R", "hk_combined.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("need: <window_name> <year> <pop_kind> [nsim]")
window_name <- args[1]
year        <- as.integer(args[2])
pop_kind    <- match.arg(args[3], c("ambient", "residential"))
nsim        <- if (length(args) >= 4) as.integer(args[4]) else 999

windows_path   <- Sys.getenv("HK_WINDOWS",   file.path(root, "data", "commuting_zones.gpkg"))
hospitals_path <- Sys.getenv("HK_HOSPITALS", file.path(root, "data", "hospitals.gpkg"))
landscan_dir   <- Sys.getenv("HK_LANDSCAN_DIR", file.path(root, "data", "landscan"))
gpw_dir        <- Sys.getenv("HK_GPW_DIR",      file.path(root, "data", "gpw"))
out_dir        <- Sys.getenv("HK_OUT",          file.path(root, "output", pop_kind))

raster_path <- if (pop_kind == "ambient")
  file.path(landscan_dir, sprintf("landscan-global-%d.tif", year)) else
  file.path(gpw_dir, sprintf("gpw_v4_%d.tif", year))
if (!file.exists(raster_path)) stop("missing population raster: ", raster_path)

windows_sf   <- sf::st_read(windows_path, quiet = TRUE)
hospitals_sf <- sf::st_read(hospitals_path, quiet = TRUE)

res <- run_hk_all(window_name, windows_sf, hospitals_sf, raster_path,
                  out_dir = out_dir, pop_kind = pop_kind, nsim = nsim)
if (isTRUE(res$skipped_pp)) message("point-pattern skipped: ", res$reason)
