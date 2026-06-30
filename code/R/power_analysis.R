#!/usr/bin/env Rscript
# power_analysis.R -- justify the minimum-hospital threshold by simulation.
#
# The univariate Kinhom needs enough hospitals per zone to have power. We
# estimate that power as a function of n against a substantively meaningful
# alternative: hospitals OVER-CONCENTRATED relative to population, modeled as an
# inhomogeneous Poisson process with intensity proportional to population^gamma
# (gamma = 1 is the null "exactly proportional to population"; gamma > 1 places
# hospitals more tightly in dense areas than people are). For each n we draw R
# replicate patterns at that gamma, run the exact test used in the study
# (Kinhom vs an rpoispp(pop) envelope, global ERL at alpha = 0.05), and record
# the rejection rate (= power). gamma = 1 replicates give the Type-I rate, which
# should sit near alpha and validates calibration.
#
# Output: docs/power_analysis.csv (n, gamma, reject_rate) + docs/power_curve.png.
# The justified floor is the smallest n whose power reaches the target (~0.8).
#
# Usage:
#   Rscript code/R/power_analysis.R [zone] [reps] [nsim_env] [gamma]
#   Rscript code/R/power_analysis.R "Tucson, AZ" 200 199 1.5

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET); library(ggplot2) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args     <- commandArgs(trailingOnly = TRUE)
zone     <- if (length(args) >= 1) args[1] else "Tucson, AZ"
reps     <- if (length(args) >= 2) as.integer(args[2]) else 200L
nsim_env <- if (length(args) >= 3) as.integer(args[3]) else 199L
gamma    <- if (length(args) >= 4) as.numeric(args[4]) else 1.5
N_GRID   <- c(2, 3, 4, 5, 8, 10, 15, 20, 30)
TARGET   <- 0.80
set.seed(42)

# --- build the window + population surface for the chosen zone ---------------
cz   <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
w    <- cz[cz[["name"]] == zone, ]
if (!nrow(w)) stop("zone not found: ", zone)
epsg <- utm_epsg_for(w)
wU   <- sf::st_transform(sf::st_union(w), epsg)
win  <- spatstat.geom::as.owin(wU)
pim  <- population_im(file.path(root, "data", "landscan", "landscan-global-2020.tif"),
                      wU, epsg, res_m = 1000)

bb <- spatstat.geom::as.rectangle(win)
r_max  <- min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange)))
r_vals <- seq(0, r_max, by = 1000)

# intensity image proportional to pop^gamma, scaled to integrate to target n
pow_im <- function(g, target_n) {
  v <- pim$v^g
  im <- pim; cell <- pim$xstep * pim$ystep
  im$v <- v * (target_n / (sum(v) * cell)); im
}
# one test -> global ERL p-value for a given hospital pattern X
test_p <- function(X) {
  lam <- lambda_im(pim, spatstat.geom::npoints(X))$im
  Kf  <- function(P, ...) spatstat.explore::Kinhom(P, lambda = lam, r = r_vals, correction = "Ripley")
  env <- spatstat.explore::envelope(X, fun = Kf, nsim = nsim_env,
              simulate = expression(spatstat.random::rpoispp(lam)[win]),
              savefuns = TRUE, verbose = FALSE)
  as.numeric(attr(GET::global_envelope_test(env, type = "erl", alpha = 0.05), "p"))
}

# --- power (gamma) and Type-I (gamma=1) over the n grid ----------------------
res <- list()
for (g in c(1.0, gamma)) {
  lam_alt_base <- NULL
  for (n in N_GRID) {
    rej <- 0L; done <- 0L
    for (r in seq_len(reps)) {
      lam_alt <- pow_im(g, n)
      X <- spatstat.random::rpoispp(lam_alt)[win]
      if (spatstat.geom::npoints(X) < 2) next
      p <- tryCatch(test_p(X), error = function(e) NA_real_)
      if (!is.na(p)) { rej <- rej + (p < 0.05); done <- done + 1L }
    }
    rate <- if (done) rej / done else NA_real_
    res[[length(res) + 1]] <- data.frame(n = n, gamma = g,
                                         reject_rate = rate, reps = done)
    message(sprintf("  gamma=%.2f n=%2d  rate=%.3f (%d reps)", g, n, rate, done))
  }
}
df <- do.call(rbind, res)
utils::write.csv(df, file.path(root, "docs", "power_analysis.csv"), row.names = FALSE)

# justified floor: smallest n whose power (gamma>1 row) reaches TARGET
pw <- df[df$gamma == gamma & !is.na(df$reject_rate), ]
floor_n <- if (any(pw$reject_rate >= TARGET)) min(pw$n[pw$reject_rate >= TARGET]) else NA
typeI <- df[df$gamma == 1.0, ]

p <- ggplot(df, aes(n, reject_rate, colour = factor(gamma))) +
  geom_hline(yintercept = c(0.05, TARGET), linetype = 2, colour = "grey60") +
  geom_line() + geom_point() +
  labs(title = sprintf("Power vs n (%s; gamma=%.2f alternative)", zone, gamma),
       subtitle = sprintf("dashed: alpha=0.05 (Type-I, gamma=1) and target power=%.2f", TARGET),
       x = "hospitals in zone (n)", y = "rejection rate",
       colour = "gamma") +
  coord_cartesian(ylim = c(0, 1)) + theme_classic()
ggsave(file.path(root, "docs", "power_curve.png"), p, width = 8, height = 5, dpi = 200)

cat(sprintf("\nType-I (gamma=1) rates: %s\n",
            paste(sprintf("n%d=%.3f", typeI$n, typeI$reject_rate), collapse = " ")))
cat(sprintf("Justified floor (power>=%.2f at gamma=%.2f): n = %s\n",
            TARGET, gamma, ifelse(is.na(floor_n), "not reached on grid", floor_n)))
cat(sprintf("wrote docs/power_analysis.csv + docs/power_curve.png\n"))
