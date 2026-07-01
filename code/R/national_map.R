#!/usr/bin/env Rscript
# national_map.R -- CONUS map of commuting zones coloured by their diagnostic
# typology, one panel per population surface. Reads output/typology_<kind>.csv
# (window -> diagnosis) and joins to the commuting-zone polygons.
#
# Output: output/typology_map_ambient.png, output/typology_map_residential.png
# Usage:  Rscript code/R/national_map.R

suppressPackageStartupMessages({ library(sf); library(ggplot2) })
root <- normalizePath(file.path(dirname(sub("--file=", "",
        grep("--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))

cz <- sf::st_read(file.path(root, "data", "commuting_zones.gpkg"), quiet = TRUE)
pal <- c("no hospital" = "#000000", "shortage" = "#7a0177",
         "maldistribution" = "#c51b8a", "geographic gap" = "#e6550d",
         "capacity shortfall" = "#fdae6b", "redundancy" = "#3182bd",
         "well-matched" = "#d9d9d9")
lev <- names(pal)

for (kind in c("ambient", "residential")) {
  t <- utils::read.csv(file.path(root, "output", sprintf("typology_%s.csv", kind)))
  m <- merge(cz, t[, c("window", "diagnosis")], by.x = "name", by.y = "window", all.x = TRUE)
  m$diagnosis <- factor(m$diagnosis, levels = lev)
  m <- sf::st_transform(m, 5070)                       # CONUS Albers
  ctr <- suppressWarnings(sf::st_coordinates(sf::st_centroid(sf::st_geometry(m))))
  keep <- ctr[, 1] > -2600000 & ctr[, 1] < 2600000 & ctr[, 2] > 100000 & ctr[, 2] < 3300000
  m <- m[keep, ]                                       # CONUS only (AK/HI/PR off-frame)
  p <- ggplot(m) +
    geom_sf(aes(fill = diagnosis), colour = "white", linewidth = 0.05) +
    scale_fill_manual(values = pal, drop = FALSE, na.value = "grey60", name = "diagnosis") +
    coord_sf(expand = FALSE) +
    labs(title = sprintf("Hospital supply diagnosis by commuting zone (%s population)", kind),
         subtitle = "family-wise corrected; CONUS shown (AK, HI, PR analyzed, off-frame)") +
    theme_void() +
    theme(legend.position = "right",
          plot.background = element_rect(fill = "white", colour = NA),
          panel.background = element_rect(fill = "white", colour = NA))
  ggsave(file.path(root, "output", sprintf("typology_map_%s.png", kind)),
         p, width = 11, height = 7, dpi = 200)
  cat(sprintf("wrote typology_map_%s.png\n", kind))
}
