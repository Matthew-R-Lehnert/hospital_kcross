#!/usr/bin/env Rscript
# power_analysis.R -- justify the concentration min-hospital threshold.
#
# For each candidate n we estimate the global ERL test's POWER to detect an
# over-concentration alternative and its TYPE-I rate, using the exact estimator
# the study uses (Kinhom with a population-proportional intensity + GET ERL).
# Alternative = an inhomogeneous Thomas cluster process: parents follow
# population, each spawning ~clmu offspring within ~clsd metres. The first-order
# trend still follows population, but with genuine SECOND-ORDER clustering, which
# is the kind of over-concentration the inhomogeneous K is built to detect (a
# pop^gamma first-order shift is not, since Kinhom is intensity-reweighted).
#
# Efficient design: for each n, build ONE null pool of `npool` curves from
# rpoispp(pop, integral n); then draw `reps` alternative curves and `reps` fresh
# null curves and test each against the pool. power = P(reject | alt),
# type-I = P(reject | null). No per-replicate envelope rebuild.
#
# Output: docs/power_analysis.csv (n, power, type1) + docs/power_curve.png; prints
# the justified floor (smallest n with power >= target).
#
# Usage: Rscript code/R/power_analysis.R [zone] [reps] [npool] [clmu] [clsd]

suppressPackageStartupMessages({ library(sf); library(spatstat); library(GET); library(ggplot2) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args   <- commandArgs(trailingOnly = TRUE)
zone   <- if (length(args) >= 1) args[1] else "Tucson, AZ"
reps   <- if (length(args) >= 2) as.integer(args[2]) else 200L
npool  <- if (length(args) >= 3) as.integer(args[3]) else 199L
clmu   <- if (length(args) >= 4) as.numeric(args[4]) else 4     # offspring per cluster
clsd   <- if (length(args) >= 5) as.numeric(args[5]) else 2500  # cluster scale (m)
N_GRID <- c(3, 5, 8, 10, 15, 20, 30, 50)
TARGET <- 0.80
set.seed(42)

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
w  <- cz[cz[["name"]] == zone, ]; epsg <- utm_epsg_for(w)
wU <- sf::st_transform(sf::st_union(w), epsg); win <- spatstat.geom::as.owin(wU)
pim <- population_im(file.path(root, "data", "landscan", "landscan-global-2020.tif"), wU, epsg)
bb <- spatstat.geom::as.rectangle(win)
r  <- seq(0, min(50000, 0.25 * min(diff(bb$xrange), diff(bb$yrange))), by = 1000)

# population-proportional intensity integrating to n (the NULL)
lam_n <- function(n) lambda_im(pim, n)$im
# ALTERNATIVE: inhomogeneous Thomas cluster process -- parents ~ pop, each with
# ~clmu offspring displaced by Gaussian(clsd). First-order trend still ~pop, but
# with genuine second-order clustering at scale clsd (real over-concentration).
alt_clustered <- function(n) {
  cell <- pim$xstep * pim$ystep
  kap <- pim; kap$v <- pim$v * ((n / clmu) / (sum(pim$v) * cell))   # parent intensity
  par <- spatstat.random::rpoispp(kap)
  if (par$n == 0) return(spatstat.geom::ppp(numeric(0), numeric(0), window = win))
  k <- stats::rpois(par$n, clmu)
  ox <- rep(par$x, k) + stats::rnorm(sum(k), 0, clsd)
  oy <- rep(par$y, k) + stats::rnorm(sum(k), 0, clsd)
  spatstat.geom::ppp(ox, oy, window = win, checkdup = FALSE)        # clips to window
}
Kcurve <- function(P) {
  if (spatstat.geom::npoints(P) < 2) return(rep(0, length(r)))
  lam <- lambda_im(pim, spatstat.geom::npoints(P))$im
  spatstat.explore::Kinhom(P, lambda = lam, r = r, correction = "Ripley", renormalise = TRUE)$iso
}
reject_vs_pool <- function(obs, pool) {
  cs <- GET::create_curve_set(list(r = r, obs = obs, sim_m = pool))
  as.numeric(attr(GET::global_envelope_test(cs, type = "erl", alpha = 0.05), "p")) < 0.05
}

res <- list()
for (n in N_GRID) {
  lam0 <- lam_n(n)
  pool <- vapply(seq_len(npool), function(i) Kcurve(spatstat.random::rpoispp(lam0)[win]),
                 numeric(length(r)))
  pw <- mean(vapply(seq_len(reps), function(i)
        reject_vs_pool(Kcurve(alt_clustered(n)), pool), logical(1)))
  t1 <- mean(vapply(seq_len(reps), function(i)
        reject_vs_pool(Kcurve(spatstat.random::rpoispp(lam0)[win]), pool), logical(1)))
  res[[length(res) + 1]] <- data.frame(n = n, power = pw, type1 = t1)
  message(sprintf("  n=%2d  power=%.3f  type1=%.3f", n, pw, t1))
}
df <- do.call(rbind, res)
utils::write.csv(df, file.path(root, "docs", "power_analysis.csv"), row.names = FALSE)
floor_n <- if (any(df$power >= TARGET)) min(df$n[df$power >= TARGET]) else NA

p <- ggplot(df, aes(n)) +
  geom_hline(yintercept = c(0.05, TARGET), linetype = 2, colour = "grey60") +
  geom_line(aes(y = power), colour = "firebrick") + geom_point(aes(y = power), colour = "firebrick") +
  geom_line(aes(y = type1), colour = "steelblue") + geom_point(aes(y = type1), colour = "steelblue") +
  coord_cartesian(ylim = c(0, 1)) +
  labs(title = sprintf("Power (red) and Type-I (blue) vs n  [%s, cluster mu=%g scale=%gm]", zone, clmu, clsd),
       subtitle = sprintf("dashed: alpha=0.05 and target power=%.2f", TARGET),
       x = "hospitals in zone (n)", y = "rejection rate") + theme_classic()
ggsave(file.path(root, "docs", "power_curve.png"), p, width = 8, height = 5, dpi = 200)
cat(sprintf("\nJustified floor (power>=%.2f, cluster mu=%g scale=%gm, %s): n = %s\n",
            TARGET, clmu, clsd, zone, ifelse(is.na(floor_n), "not reached on grid", floor_n)))
