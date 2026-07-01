#!/usr/bin/env Rscript
# threshold_sensitivity.R -- is the concentration headline stable to the
# min-hospital threshold? Re-runs the across-zone family-wise ERL test on the
# subsets of zones with n >= 8, 10, 15 (reusing the saved simulations; nothing
# is re-simulated) and reports how many zones remain family-wise over-concentrated
# at each threshold.
#
# Usage: Rscript code/R/threshold_sensitivity.R [sim_dir] [layer]
#   Rscript code/R/threshold_sensitivity.R output/residential all

suppressPackageStartupMessages({ library(GET) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
args    <- commandArgs(trailingOnly = TRUE)
sim_dir <- if (length(args) >= 1) args[1] else "output/residential"
layer   <- if (length(args) >= 2) args[2] else "all"
pop_kind <- basename(normalizePath(sim_dir))

# tagbase -> n_hospitals from summary.csv
S <- utils::read.csv(file.path(root, "output", "summary.csv"))
S <- S[S$pop_kind == pop_kind & S$layer == "facilities", c("window", "n_hospitals")]
S$key <- gsub("[^A-Za-z0-9]+", "_", S$window)
nmap <- setNames(S$n_hospitals, S$key)

files <- list.files(sim_dir, pattern = sprintf("_%s_simfuns\\.rds$", layer), full.names = TRUE)
cs <- list(); ns <- integer()
for (f in files) {
  s <- readRDS(f); if (is.null(s$sims) || nrow(s$sims) < 2) next
  key <- sub(sprintf("_%s_simfuns\\.rds$", layer), "", basename(f))
  key <- sub(sprintf("_%s$", pop_kind), "", key)
  n <- nmap[[key]]; if (is.null(n) || is.na(n)) next
  cs[[length(cs) + 1]] <- GET::create_curve_set(list(r = s$x, obs = s$obs, sim_m = s$sims))
  ns <- c(ns, n)
}
cat(sprintf("layer=%s surface=%s: %d zones with sims\n", layer, pop_kind, length(cs)))
for (thr in c(8, 10, 15)) {
  keep <- ns >= thr
  sub <- cs[keep]
  res <- GET::global_envelope_test(sub, type = "erl", alpha = 0.05)
  p <- attr(res, "p")
  per <- if (is.null(res$obs)) res else list(res)
  over <- sum(vapply(per, function(e) any(e$obs > e$hi), logical(1)))
  cat(sprintf("  n>=%2d: %3d zones, combined p=%.3f, over-concentrated=%d\n",
              thr, sum(keep), p, over))
}
