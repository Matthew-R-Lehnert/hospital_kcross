#!/usr/bin/env Rscript
# run_cz.R -- run the hospital × population inhomogeneous K test for ONE
# commuting zone (or any window present in the windows file).
#
# Usage:
#   Rscript code/scripts/run_cz.R <window_name> <year> <pop_kind> [subset] [weight_by] [nsim]
# Examples:
#   Rscript code/scripts/run_cz.R "CZ_19400" 2021 ambient
#   Rscript code/scripts/run_cz.R "CZ_19400" 2020 residential trauma none 999
#
# Env overrides: HK_WINDOWS, HK_HOSPITALS, HK_LANDSCAN_DIR, HK_GPW_DIR, HK_OUT.

suppressPackageStartupMessages(library(sf))
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("need: <window_name> <year> <pop_kind> [subset] [weight_by] [nsim]")
window_name <- args[1]
year        <- as.integer(args[2])
pop_kind    <- match.arg(args[3], c("ambient", "residential"))
subset      <- if (length(args) >= 4) args[4] else "all"
weight_by   <- if (length(args) >= 5) args[5] else "none"
nsim        <- if (length(args) >= 6) as.integer(args[6]) else 999

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

res <- run_hk(window_name, windows_sf, hospitals_sf, raster_path,
              out_dir = out_dir, pop_kind = pop_kind,
              subset = subset, weight_by = weight_by, nsim = nsim)
if (isTRUE(res$skipped)) message("skipped: ", res$reason)
