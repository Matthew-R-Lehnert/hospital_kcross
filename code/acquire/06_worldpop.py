#!/usr/bin/env python3
"""
06_worldpop.py -- WorldPop US ~1km population (modeled residential) for the
robustness control that separates the ambient-vs-residential effect from the
modeled-vs-areal one (GPW is areal; WorldPop and LandScan are both modeled).

Output: data/worldpop/worldpop_2020.tif  (UN-adjusted, ~1km, 2020, USA)
Usage:  python code/acquire/06_worldpop.py
"""
from __future__ import annotations
from pathlib import Path
from urllib.request import urlopen, Request

URL = ("https://data.worldpop.org/GIS/Population/Global_2000_2020_1km_UNadj/"
       "2020/USA/usa_ppp_2020_1km_Aggregated_UNadj.tif")
out = Path("data/worldpop/worldpop_2020.tif"); out.parent.mkdir(parents=True, exist_ok=True)
if out.exists():
    print(f"{out} exists, skipping")
else:
    print(f"downloading {URL}")
    out.write_bytes(urlopen(Request(URL, headers={"User-Agent": "hospital-kcross/1.0"})).read())  # noqa: S310
    print(f"wrote {out} ({out.stat().st_size/1e6:.0f} MB). Note: USA file; PR not covered.")
