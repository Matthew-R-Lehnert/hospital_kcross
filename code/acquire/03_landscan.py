#!/usr/bin/env python3
"""
03_landscan.py -- fetch a LandScan Global ambient-population raster (one year).

LandScan Global has no public API (manual, form-gated download from ORNL), but
the raw GeoTIFFs are mirrored to the project S3 bucket. We copy the requested
year's raster down to data/landscan/.

Output: data/landscan/landscan-global-<year>.tif

Usage:
  python code/acquire/03_landscan.py 2021
  python code/acquire/03_landscan.py 2018 2019 2020 2021 2022 2023 2024
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

S3_PREFIX = ("s3://geo-geospatial-dev/terrafusion/sandbox/N3C/raw/landscan/"
             "landscan-global-{year}-assets/landscan-global-{year}.tif")
OUT_DIR = Path("data/landscan")


def fetch_year(year: int) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    src = S3_PREFIX.format(year=year)
    dst = OUT_DIR / f"landscan-global-{year}.tif"
    if dst.exists():
        print(f"{dst} exists, skipping")
        return dst
    print(f"copying {src}")
    subprocess.run(["aws", "s3", "cp", "--no-progress", src, str(dst)], check=True)
    return dst


def main(argv: list[str]) -> int:
    years = [int(a) for a in argv] or [2021]
    for y in years:
        p = fetch_year(y)
        print(f"  -> {p} ({p.stat().st_size/1e6:.0f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
