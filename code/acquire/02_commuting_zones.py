#!/usr/bin/env python3
"""
02_commuting_zones.py -- build commuting-zone (CZ) polygons.

Commuting zones are clusters of counties tied by commuting flows (USDA ERS).
There is no single official CZ shapefile; the standard build is to DISSOLVE
U.S. county polygons using a county-FIPS -> CZ crosswalk.

Inputs:
  * County polygons: Census TIGER/Line cartographic boundary (downloaded).
  * County -> CZ crosswalk: USDA ERS commuting-zone delineation (a CSV with
    FIPS and CZ id). Provide via --crosswalk; we do not hardcode a URL because
    the ERS distribution path and vintage (1990/2000/2010) must be chosen and
    cited deliberately (see docs/window_choice.md).

Output: data/commuting_zones.gpkg  (EPSG:4326 polygons; column: name = CZ id)

Usage:
  python code/acquire/02_commuting_zones.py --crosswalk path/to/cz_crosswalk.csv \
      [--fips-col FIPS --cz-col OUT10 --county-year 2021]
"""
from __future__ import annotations

import argparse
import sys
import zipfile
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen

import geopandas as gpd
import pandas as pd

OUT = Path("data/commuting_zones.gpkg")


def county_polygons(year: int) -> gpd.GeoDataFrame:
    """Census cartographic-boundary counties (1:500k)."""
    url = (f"https://www2.census.gov/geo/tiger/GENZ{year}/shp/"
           f"cb_{year}_us_county_500k.zip")
    print(f"downloading counties: {url}")
    with urlopen(url) as resp:                       # noqa: S310
        data = resp.read()
    tmp = Path("data/_county_tmp")
    tmp.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(BytesIO(data)) as zf:
        zf.extractall(tmp)
    shp = next(tmp.glob("*.shp"))
    g = gpd.read_file(shp).to_crs("EPSG:4326")
    g["FIPS"] = (g["STATEFP"].astype(str).str.zfill(2)
                 + g["COUNTYFP"].astype(str).str.zfill(3))
    return g[["FIPS", "geometry"]]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--crosswalk", required=True,
                    help="CSV with county FIPS -> CZ id (USDA ERS delineation)")
    ap.add_argument("--fips-col", default="FIPS")
    ap.add_argument("--cz-col", default="CZ")
    ap.add_argument("--county-year", type=int, default=2021)
    args = ap.parse_args()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    counties = county_polygons(args.county_year)

    xwalk = pd.read_csv(args.crosswalk, dtype=str)
    xwalk[args.fips_col] = xwalk[args.fips_col].str.zfill(5)
    counties = counties.merge(
        xwalk[[args.fips_col, args.cz_col]].rename(
            columns={args.fips_col: "FIPS", args.cz_col: "cz"}),
        on="FIPS", how="left")
    missing = counties["cz"].isna().sum()
    if missing:
        print(f"warning: {missing} counties have no CZ assignment (dropped)")
    counties = counties.dropna(subset=["cz"])

    cz = counties.dissolve(by="cz").reset_index()
    cz["name"] = "CZ_" + cz["cz"].astype(str)
    cz = cz[["name", "geometry"]]
    cz.to_file(OUT, driver="GPKG")
    print(f"wrote {len(cz)} commuting zones -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
