#!/usr/bin/env python3
"""
05_cbsa.py -- CBSA (metropolitan + micropolitan) windows for the robustness
re-run, from Census TIGER cartographic boundaries.

Output: data/cbsa.gpkg (EPSG:4326 polygons; column: name)
Usage:  python code/acquire/05_cbsa.py [year=2020]
"""
from __future__ import annotations
import sys, zipfile
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen, Request
import geopandas as gpd

year = int(sys.argv[1]) if len(sys.argv) > 1 else 2020
url = f"https://www2.census.gov/geo/tiger/GENZ{year}/shp/cb_{year}_us_cbsa_500k.zip"
tmp = Path("data/_cbsa_tmp"); tmp.mkdir(parents=True, exist_ok=True)
print(f"downloading {url}")
data = urlopen(Request(url, headers={"User-Agent": "hospital-kcross/1.0"})).read()  # noqa: S310
with zipfile.ZipFile(BytesIO(data)) as z:
    z.extractall(tmp)
shp = next(tmp.glob("*.shp"))
g = gpd.read_file(shp).to_crs("EPSG:4326")
g["name"] = g["NAME"]
g[["name", "geometry"]].to_file("data/cbsa.gpkg", driver="GPKG")
print(f"wrote {len(g)} CBSA windows -> data/cbsa.gpkg")
