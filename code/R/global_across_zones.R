#!/usr/bin/env Rscript
# global_across_zones.R -- family-wise (across-zone) global envelope test.
#
# The per-zone run already applies a global (over-r) ERL envelope within each
# zone. Running that in hundreds of zones is a multiple-comparison problem. This
# script controls the family-wise error rate ACROSS zones by combining every
# zone's saved observed+simulated K-curves into one GET combined global envelope
# test (Myllymaki et al. 2017). It REUSES the *_simfuns.rds written by the
# per-zone runs, so nothing is re-simulated.
#
# Each layer (facilities/beds/trauma) saved its own simfuns, so the family-wise
# test runs PER LAYER -- mixing layers into one combined test would be wrong.
# Select the layer with the 2nd arg (all | beds | trauma; default all).
#
# Usage:
#   Rscript code/R/global_across_zones.R <sim_dir> [layer] [out_csv]
#   Rscript code/R/global_across_zones.R output/ambient all
#   Rscript code/R/global_across_zones.R output/residential trauma
#
# Output: <sim_dir>/_global_across_zones_<layer>.csv (per-zone family-wise verdict)
#   and prints the combined family-wise global p-value for that layer.

suppressPackageStartupMessages({ library(GET) })

args    <- commandArgs(trailingOnly = TRUE)
sim_dir <- if (length(args) >= 1) args[1] else "output/ambient"
layer   <- if (length(args) >= 2) args[2] else "all"
out_csv <- if (length(args) >= 3) args[3] else
             file.path(sim_dir, sprintf("_global_across_zones_%s.csv", layer))

files <- list.files(sim_dir, pattern = sprintf("_%s_simfuns\\.rds$", layer),
                    full.names = TRUE)
if (!length(files)) stop("no *_", layer, "_simfuns.rds in ", sim_dir,
                         " -- run the combined per-zone analysis first")
message(sprintf("layer = %s", layer))

cs <- list(); zones <- character()
for (f in files) {
  s <- readRDS(f)
  if (is.null(s$sims) || nrow(s$sims) < 2) next
  cs[[length(cs) + 1]] <- GET::create_curve_set(
    list(r = s$r, obs = s$obs, sim_m = s$sims))
  zones <- c(zones, s$window)
}
names(cs) <- zones
message(sprintf("combining %d zones from %s", length(cs), sim_dir))

# Combined (two-step) global envelope test: controls error across all zones.
res <- GET::global_envelope_test(cs, type = "erl", alpha = 0.05)
combined_p <- attr(res, "p")

# Per-zone family-wise-adjusted verdict (does the zone's obs exit its combined
# envelope). res is a list of per-zone global envelopes when given a list.
per <- if (is.null(res$obs)) res else list(res)   # robust to 1-zone case
rows <- lapply(seq_along(per), function(i) {
  e <- per[[i]]
  data.frame(window = zones[i],
             fw_verdict = if (any(e$obs > e$hi)) "over-concentrated"
                          else if (any(e$obs < e$lo)) "dispersed" else "consistent")
})
df <- do.call(rbind, rows)
utils::write.csv(df, out_csv, row.names = FALSE)
cat(sprintf("combined family-wise global p-value = %s\n", format(combined_p)))
cat(sprintf("family-wise over-concentrated zones: %d / %d\n",
            sum(df$fw_verdict == "over-concentrated"), nrow(df)))
cat(sprintf("wrote %s\n", out_csv))
