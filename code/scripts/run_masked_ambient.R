#!/usr/bin/env Rscript
# run_masked_ambient.R -- ambient-endogeneity robustness for the concentration
# axis. Re-runs Kinhom (facilities, layer "all") for every commuting zone with
# >= min_hospitals hospitals, using the LandScan ambient raster with the
# hospital-containing cells BLANKED (mask_hospital_cells = TRUE). This removes
# the daytime population LandScan allocates to hospitals themselves (staff,
# outpatients, visitors), which is the reviewer's mechanical-inflation threat to
# the ambient/residential reversal. Outputs go to output/ambient_masked/ with
# pop_kind = "ambient_masked" so global_across_zones.R keys zone names cleanly.
#
# Usage:
#   Rscript code/scripts/run_masked_ambient.R [year] [nsim] [n_cores]
# Then:
#   Rscript code/R/global_across_zones.R output/ambient_masked all

suppressPackageStartupMessages({ library(sf); library(parallel) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args    <- commandArgs(trailingOnly = TRUE)
year    <- if (length(args) >= 1) as.integer(args[1]) else 2020L
nsim    <- if (length(args) >= 2) as.integer(args[2]) else 999L
ncores  <- if (length(args) >= 3) as.integer(args[3]) else max(1L, detectCores() - 2L)

windows_path   <- file.path(root, "data", "commuting_zones.gpkg")
hospitals_path <- file.path(root, "data", "hospitals.gpkg")
raster_path    <- file.path(root, "data", "landscan",
                            sprintf("landscan-global-%d.tif", year))
out_dir        <- file.path(root, "output", "ambient_masked")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

windows_sf   <- sf::st_read(windows_path,   quiet = TRUE)
hospitals_sf <- sf::st_read(hospitals_path, quiet = TRUE)
zones <- windows_sf[["name"]]

message(sprintf("masked-ambient concentration: %d candidate zones, nsim=%d, cores=%d",
                length(zones), nsim, ncores))

run_one <- function(z) {
  tryCatch({
    res <- run_hk(z, windows_sf, hospitals_sf, raster_path, out_dir,
                  pop_kind = "ambient_masked", subset = "all", weight_by = "none",
                  nsim = nsim, save_sims = TRUE, verbose = FALSE,
                  mask_hospital_cells = TRUE)
    if (!is.null(res$skipped) && isTRUE(res$skipped))
      return(sprintf("skip %s (n=%d)", z, res$n))
    sprintf("done %s: n=%d verdict=%s p=%s", z, res$meta$n_hospitals,
            res$meta$verdict, format(res$meta$global_p))
  }, error = function(e) sprintf("ERROR %s: %s", z, conditionMessage(e)))
}

logs <- mclapply(zones, run_one, mc.cores = ncores)
invisible(lapply(logs, function(l) message(l)))
message("masked-ambient run complete -> ", out_dir)
