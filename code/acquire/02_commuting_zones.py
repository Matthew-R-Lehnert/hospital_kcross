#!/usr/bin/env python3
"""
02_commuting_zones.py -- build commuting-zone (CZ) polygons.

Commuting zones are clusters of counties tied by commuting flows (USDA ERS).
There is no official CZ shapefile; the standard build is to DISSOLVE U.S. county
polygons using a county-FIPS -> CZ crosswalk. We use the ERS **2020** delineation
(598 contiguous zones), which matches the 2020 population rasters.

Inputs (auto-downloaded if absent):
  * County polygons: Census TIGER/Line cartographic boundary (1:500k), 2020.
  * County -> CZ crosswalk: ERS "2020 Commuting Zones" CSV
    (columns FIPStxt, CZ2020, CZName).

Output: data/commuting_zones.gpkg  (EPSG:4326 polygons; columns: name, cz_id)

Usage:
  python code/acquire/02_commuting_zones.py
  python code/acquire/02_commuting_zones.py --county-year 2020
"""
from __future__ import annotations

import argparse
import sys
import zipfile
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen, Request

import geopandas as gpd
import pandas as pd

OUT = Path("data/commuting_zones.gpkg")
XWALK_PATH = Path("data/_cz_src/2020-commuting-zones.csv")
XWALK_URL = "https://www.ers.usda.gov/media/6968/2020-commuting-zones.csv?v=37379"


def _get(url: str) -> bytes:
    req = Request(url, headers={"User-Agent": "hospital-kcross/1.0"})
    with urlopen(req) as resp:                       # noqa: S310
        return resp.read()


def crosswalk() -> pd.DataFrame:
    if not XWALK_PATH.exists():
        XWALK_PATH.parent.mkdir(parents=True, exist_ok=True)
        print(f"downloading CZ crosswalk: {XWALK_URL}")
        XWALK_PATH.write_bytes(_get(XWALK_URL))
    df = pd.read_csv(XWALK_PATH, dtype={"FIPStxt": str})
    df["FIPStxt"] = df["FIPStxt"].str.zfill(5)
    return df[["FIPStxt", "CZ2020", "CZName"]]


def county_polygons(year: int) -> gpd.GeoDataFrame:
    url = (f"https://www2.census.gov/geo/tiger/GENZ{year}/shp/"
           f"cb_{year}_us_county_500k.zip")
    print(f"downloading counties: {url}")
    tmp = Path("data/_county_tmp")
    tmp.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(BytesIO(_get(url))) as zf:
        zf.extractall(tmp)
    shp = next(tmp.glob("*.shp"))
    g = gpd.read_file(shp).to_crs("EPSG:4326")
    g["FIPStxt"] = (g["STATEFP"].astype(str).str.zfill(2)
                    + g["COUNTYFP"].astype(str).str.zfill(3))
    return g[["FIPStxt", "geometry"]]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--county-year", type=int, default=2020)
    args = ap.parse_args()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    counties = county_polygons(args.county_year)
    xw = crosswalk()

    merged = counties.merge(xw, on="FIPStxt", how="left")

    # --- Connecticut fix ------------------------------------------------------
    # The 2020 CZ crosswalk keys Connecticut to its 2022 planning-region FIPS
    # (09110-09190), which do not exist in the 2020 TIGER county file (CT there
    # is still the old 8 counties, 09001-09015). The left-merge therefore leaves
    # every CT county unmatched and drops the entire state. All CT planning
    # regions belong to a single CZ (the whole state, "Hartford, CT"), so remap
    # every unmatched CT county polygon to that CZ. Guarded so it only fires when
    # CT genuinely maps to one CZ in the crosswalk.
    ct_xw = xw[xw["FIPStxt"].str.startswith("09")]
    if len(ct_xw) and ct_xw["CZ2020"].nunique() == 1:
        ct_cz = ct_xw["CZ2020"].iloc[0]
        ct_name = ct_xw["CZName"].iloc[0]
        ct_fix = merged["FIPStxt"].str.startswith("09") & merged["CZ2020"].isna()
        if ct_fix.any():
            merged.loc[ct_fix, "CZ2020"] = ct_cz
            merged.loc[ct_fix, "CZName"] = ct_name
            print(f"Connecticut fix: mapped {int(ct_fix.sum())} CT counties to "
                  f"CZ {ct_cz} ({ct_name}); 2022 planning-region FIPS reconciled")

    missing = merged["CZ2020"].isna().sum()
    if missing:
        print(f"warning: {missing} county polygons unmatched to a CZ (dropped); "
              "these are typically territories outside the CONUS+PR crosswalk")
    merged = merged.dropna(subset=["CZ2020"])

    cz = merged.dissolve(by="CZ2020").reset_index()
    # human-readable, unique window name
    cz["name"] = cz["CZName"].astype(str)
    dup = cz["name"].duplicated(keep=False)
    cz.loc[dup, "name"] = cz.loc[dup, "name"] + " [" + cz.loc[dup, "CZ2020"].astype(str) + "]"
    cz["cz_id"] = cz["CZ2020"].astype(int)
    cz = cz[["name", "cz_id", "geometry"]]
    cz.to_file(OUT, driver="GPKG")
    print(f"wrote {len(cz)} commuting zones -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
