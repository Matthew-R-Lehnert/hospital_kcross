#!/usr/bin/env Rscript
# _selftest.R -- self-contained sanity check of the inhomogeneous-K engine,
# with NO external data (no rasters, no S3). It fabricates a population surface
# and two hospital patterns and confirms the test behaves correctly:
#
#   (1) hospitals drawn PROPORTIONAL to population  -> observed K stays inside
#       the envelope (verdict: consistent with population);
#   (2) hospitals CLUSTERED beyond population        -> observed K pierces the
#       upper envelope (verdict: over-concentrated).
#
# This exercises lambda_im(), the rpoispp(lambda) null, and the Kinhom envelope
# exactly as run_hk() does, validating the logic before the real data lands.
#
# Usage: Rscript code/scripts/_selftest.R

suppressPackageStartupMessages({ library(spatstat) })

set.seed(1)
W <- spatstat.geom::owin(c(0, 1e4), c(0, 1e4))      # 10 km square

# A smooth non-uniform population surface (a couple of population centers).
gx <- seq(W$xrange[1], W$xrange[2], length.out = 80)
gy <- seq(W$yrange[1], W$yrange[2], length.out = 80)
G  <- expand.grid(x = gx, y = gy)
peak <- function(cx, cy, s) exp(-((G$x - cx)^2 + (G$y - cy)^2) / (2 * s^2))
popv <- 50 + 1000 * peak(3000, 3000, 1500) + 700 * peak(7500, 6500, 1200)
pop_im <- spatstat.geom::im(matrix(popv, nrow = 80, byrow = FALSE),
                            xcol = gx, yrow = gy)

n <- 120
r_vals <- seq(0, 2500, by = 50)
mk_lambda <- function(pim, n) { cell <- pim$xstep * pim$ystep
  lam <- pim; lam$v <- pim$v * (n / (sum(pim$v) * cell)); lam }
lambda <- mk_lambda(pop_im, n)

env_of <- function(X) {
  spatstat.explore::envelope(
    X, fun = function(P, ...) spatstat.explore::Kinhom(P, lambda = lambda,
                                                       r = r_vals, correction = "Ripley"),
    nsim = 99, simulate = expression(spatstat.random::rpoispp(lambda)[W]),
    verbose = FALSE)
}
verdict <- function(e) { d <- as.data.frame(e)
  if (any(d$obs > d$hi)) "OVER-CONCENTRATED"
  else if (any(d$obs < d$lo)) "DISPERSED" else "CONSISTENT" }

# (1) hospitals ~ population  -> should be CONSISTENT
X_prop <- spatstat.random::rpoispp(lambda)[W]
v1 <- verdict(env_of(X_prop))

# (2) hospitals clustered in ONE tight knot beyond population -> OVER-CONCENTRATED
knot <- spatstat.random::rpoispp(mk_lambda(
          spatstat.geom::im(matrix(peak(5000, 5000, 250), nrow = 80),
                            xcol = gx, yrow = gy), n))[W]
v2 <- verdict(env_of(knot))

cat(sprintf("(1) hospitals proportional to population -> %s  [expect CONSISTENT]\n", v1))
cat(sprintf("(2) hospitals clustered beyond population -> %s  [expect OVER-CONCENTRATED]\n", v2))
ok <- (v1 == "CONSISTENT") && (v2 == "OVER-CONCENTRATED")
cat(if (ok) "\nSELFTEST PASSED\n" else "\nSELFTEST FAILED\n")
quit(status = if (ok) 0 else 1)
