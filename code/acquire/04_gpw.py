#!/usr/bin/env python3
"""
04_gpw.py -- fetch NASA SEDAC GPWv4.11 residential-population raster (one year).

GPW = Gridded Population of the World, v4.11 (CIESIN/Columbia for NASA SEDAC):
gridded RESIDENTIAL population at 30 arc-seconds (~1 km), the residential
counterpart to LandScan's ambient surface. Available years: 2000, 2005, 2010,
2015, 2020.

SEDAC requires a (free) NASA Earthdata login. Two paths:

  (A) earthaccess (recommended) -- programmatic, uses ~/.netrc Earthdata creds:
        pip install earthaccess
        python code/acquire/04_gpw.py 2020
  (B) manual -- download the GeoTIFF from the SEDAC GPWv4.11 "Population Count"
        collection and drop it at the OUT path printed below.

Output: data/gpw/gpw_v4_<year>.tif  (population count, 30 arc-sec)
"""
from __future__ import annotations

import sys
from pathlib import Path

OUT_DIR = Path("data/gpw")
# SEDAC GPWv4.11 Population Count, 30 arc-sec, GeoTIFF. The dataset DOI /
# collection short-name is documented on SEDAC; confirm and pin before release.
SEDAC_SHORTNAME = "CIESIN_SEDAC_GPWv411_POPCOUNT"   # TODO: confirm exact id
VALID_YEARS = {2000, 2005, 2010, 2015, 2020}


def fetch_year(year: int) -> Path:
    if year not in VALID_YEARS:
        raise SystemExit(f"GPW years are {sorted(VALID_YEARS)}; got {year}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"gpw_v4_{year}.tif"
    if dst.exists():
        print(f"{dst} exists, skipping")
        return dst
    try:
        import earthaccess  # noqa: F401
    except ImportError:
        print("earthaccess not installed. Either:\n"
              "  pip install earthaccess   (then re-run)\n"
              f"or manually download GPWv4.11 Population Count {year} (30 arc-sec\n"
              f"GeoTIFF) from NASA SEDAC and save it to {dst}")
        raise SystemExit(2)

    import earthaccess
    earthaccess.login()                       # uses ~/.netrc Earthdata creds
    results = earthaccess.search_data(short_name=SEDAC_SHORTNAME,
                                      temporal=(f"{year}-01-01", f"{year}-12-31"))
    if not results:
        raise SystemExit(f"no SEDAC granules for {year}; confirm SEDAC_SHORTNAME")
    files = earthaccess.download(results, str(OUT_DIR))
    print(f"downloaded {len(files)} file(s); rename/select the 30-arcsec GeoTIFF "
          f"to {dst} if needed")
    return dst


def main(argv: list[str]) -> int:
    years = [int(a) for a in argv] or [2020]
    for y in years:
        p = fetch_year(y)
        print(f"  -> {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
