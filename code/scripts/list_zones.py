#!/usr/bin/env python3
"""Print commuting-zone window names (one per line) for the Nextflow fan-out."""
import sys
import geopandas as gpd

path = sys.argv[1] if len(sys.argv) > 1 else "data/commuting_zones.gpkg"
g = gpd.read_file(path)
for n in g["name"].tolist():
    print(n)
