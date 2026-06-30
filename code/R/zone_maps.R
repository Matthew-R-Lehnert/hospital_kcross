#!/usr/bin/env Rscript
# zone_maps.R -- diagnostic maps for ONE commuting zone, one per axis:
#   <tag>_desertmap.png  -- populated ~1km cells shaded by distance to the
#                           nearest hospital (deserts = warm cells with people
#                           far from care); hospitals overlaid. The COVERAGE axis.
#   <tag>_localK.png      -- hospitals sized/coloured by their localKinhom
#                           contribution at r_focus (the pile-ups that drive
#                           over-concentration). The CONCENTRATION axis.
#
# Usage:
#   Rscript code/R/zone_maps.R "<zone>" <year> <pop_kind> [r_focus_m] [desert_km]

suppressPackageStartupMessages({ library(sf); library(spatstat); library(ggplot2) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
source(file.path(root, "code", "R", "hk_core.R"))

args      <- commandArgs(trailingOnly = TRUE)
zone      <- if (length(args) >= 1) args[1] else "San Diego, CA"
year      <- if (length(args) >= 2) as.integer(args[2]) else 2020L
pop_kind  <- if (length(args) >= 3) args[3] else "ambient"
r_focus   <- if (length(args) >= 4) as.numeric(args[4]) else 10000
desert_km <- if (length(args) >= 5) as.numeric(args[5]) else 25
buffer_km <- if (length(args) >= 6) as.numeric(args[6]) else 50
out_dir   <- file.path(root, "output", pop_kind); dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
tag <- sprintf("%s_%s", gsub("[^A-Za-z0-9]+", "_", zone), pop_kind)
raster <- if (pop_kind == "ambient")
  file.path(root, "data", "landscan", sprintf("landscan-global-%d.tif", year)) else
  file.path(root, "data", "gpw", sprintf("gpw_v4_%d.tif", year))

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
h  <- sf::st_read(file.path(root, "data", "hospitals.gpkg"), quiet = TRUE)
w  <- cz[cz[["name"]] == zone, ]; epsg <- utm_epsg_for(w)
wU <- sf::st_transform(sf::st_union(w), epsg); win <- spatstat.geom::as.owin(wU)
buf_poly <- sf::st_buffer(wU, buffer_km * 1000); Wbuf <- spatstat.geom::as.owin(buf_poly)
h <- sf::st_transform(h, epsg)
in_mask <- sf::st_within(h, wU, sparse = FALSE)[, 1]
in_buf  <- sf::st_within(h, buf_poly, sparse = FALSE)[, 1]
hc <- sf::st_coordinates(h[in_mask, ])                       # in-zone (concentration)
X  <- spatstat.geom::ppp(hc[, 1], hc[, 2], window = win, checkdup = FALSE)
hb <- sf::st_coordinates(h[in_buf, ])                        # in-zone + buffer (coverage)
wsf <- sf::st_sf(geometry = wU)

pim <- population_im(raster, wU, epsg)
ix  <- which(is.finite(pim$v) & pim$v > 0, arr.ind = TRUE)
cx  <- pim$xcol[ix[, 2]]; cy <- pim$yrow[ix[, 1]]; pv <- pim$v[ix]
ins <- spatstat.geom::inside.owin(cx, cy, win)
cells <- spatstat.geom::ppp(cx[ins], cy[ins], window = Wbuf, checkdup = FALSE)
Hcov  <- spatstat.geom::ppp(hb[, 1], hb[, 2], window = Wbuf, checkdup = FALSE)
dist_km <- spatstat.geom::nncross(cells, Hcov, what = "dist") / 1000
cdf <- data.frame(x = cx[ins], y = cy[ins], pop = pv[ins], dist_km = dist_km)
thr_mi <- c(10, 25, 35)
pcts <- sapply(thr_mi * 1.60934, function(t) 100 * sum(cdf$pop[cdf$dist_km > t]) / sum(cdf$pop))
sub_txt <- paste0(">", paste(thr_mi, collapse = "/"), " mi from a hospital: ",
                  paste(sprintf("%.1f", pcts), collapse = "/"), "% of population; cyan = hospitals")

# --- desert map: cells by distance to nearest hospital -----------------------
p1 <- ggplot() +
  geom_raster(data = cdf, aes(x, y, fill = dist_km)) +
  scale_fill_viridis_c(option = "magma", direction = -1, name = "km to\nnearest\nhospital") +
  geom_sf(data = wsf, fill = NA, colour = "grey30", linewidth = .3) +
  geom_point(data = as.data.frame(hc), aes(X, Y), colour = "cyan", size = 1.1, shape = 16) +
  coord_sf(datum = epsg) +
  labs(title = sprintf("%s -- distance to nearest hospital (%s, +%gkm buffer)", zone, pop_kind, buffer_km),
       subtitle = sub_txt, x = NULL, y = NULL) +
  theme_minimal()
ggsave(file.path(out_dir, paste0(tag, "_desertmap.png")), p1, width = 8, height = 7, dpi = 200)

# --- concentration map: localKinhom contribution per hospital ----------------
lam <- lambda_im(pim, spatstat.geom::npoints(X))$im
lk  <- spatstat.explore::localKinhom(X, lambda = lam, correction = "Ripley", verbose = FALSE)
lkdf <- as.data.frame(lk); iso <- grep("^iso", names(lkdf), value = TRUE)
ri  <- which.min(abs(lkdf$r - r_focus))
contrib <- as.numeric(lkdf[ri, iso])                    # per-point local K at r_focus
hd <- data.frame(x = hc[, 1], y = hc[, 2], localK = contrib)
p2 <- ggplot() +
  geom_sf(data = wsf, fill = "grey95", colour = "grey30", linewidth = .3) +
  geom_point(data = hd, aes(x, y, colour = localK, size = localK)) +
  scale_colour_viridis_c(option = "inferno", name = sprintf("local K\n@ %gkm", r_focus / 1000)) +
  scale_size_continuous(guide = "none", range = c(1, 5)) +
  coord_sf(datum = epsg) +
  labs(title = sprintf("%s -- hospital contribution to over-concentration (%s)", zone, pop_kind),
       subtitle = sprintf("bright/large = hospitals in dense clusters driving the K signal at %g km", r_focus / 1000),
       x = NULL, y = NULL) +
  theme_minimal()
ggsave(file.path(out_dir, paste0(tag, "_localK.png")), p2, width = 8, height = 7, dpi = 200)

cat(sprintf("zone=%s n=%d  pop >%s mi from a hospital: %s%%\n", zone, nrow(hc),
            paste(thr_mi, collapse = "/"), paste(sprintf("%.1f", pcts), collapse = "/")))
cat(sprintf("wrote %s_desertmap.png and %s_localK.png\n", tag, tag))
