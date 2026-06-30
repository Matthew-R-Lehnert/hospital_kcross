#!/usr/bin/env python3
"""
04_gpw.py -- fetch NASA SEDAC GPWv4.11 residential-population raster (one year).

GPW = Gridded Population of the World, v4.11 (CIESIN/Columbia for NASA SEDAC):
gridded RESIDENTIAL population count at 30 arc-seconds (~1 km), the residential
counterpart to LandScan's ambient surface. Collection short-name:
CIESIN_SEDAC_GPWv4_POPCOUNT_R11. Target years: 2000, 2005, 2010, 2015, 2020.

Requires a (free) NASA Earthdata login via ~/.netrc, and `earthaccess`
(pip install earthaccess).

Output: data/gpw/gpw_v4_<year>.tif  (population count, 30 arc-sec, global)
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

OUT_DIR = Path("data/gpw")
SHORT_NAME = "CIESIN_SEDAC_GPWv4_POPCOUNT_R11"
VALID_YEARS = {2000, 2005, 2010, 2015, 2020}


def fetch_year(year: int) -> Path:
    if year not in VALID_YEARS:
        raise SystemExit(f"GPW years are {sorted(VALID_YEARS)}; got {year}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"gpw_v4_{year}.tif"
    if dst.exists():
        print(f"{dst} exists, skipping")
        return dst

    import earthaccess
    earthaccess.login(strategy="netrc")
    granules = earthaccess.search_data(short_name=SHORT_NAME, count=200)
    want = f"_{year}_30_sec_tif.zip"
    target = None
    for g in granules:
        for link in g.data_links():
            if link.endswith(want):
                target = g
                break
        if target:
            break
    if target is None:
        raise SystemExit(f"no 30 arc-sec GeoTIFF granule for {year} in {SHORT_NAME}")

    files = earthaccess.download(target, str(OUT_DIR))
    zip_path = Path(files[0])
    with zipfile.ZipFile(zip_path) as zf:
        tif = next(n for n in zf.namelist() if n.lower().endswith(".tif"))
        zf.extract(tif, OUT_DIR)
    (OUT_DIR / tif).rename(dst)
    zip_path.unlink(missing_ok=True)
    print(f"  -> {dst} ({dst.stat().st_size/1e6:.0f} MB)")
    return dst


def main(argv: list[str]) -> int:
    years = [int(a) for a in argv] or [2020]
    for y in years:
        fetch_year(y)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
