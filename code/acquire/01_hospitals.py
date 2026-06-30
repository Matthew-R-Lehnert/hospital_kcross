#!/usr/bin/env python3
"""
01_hospitals.py -- build the open-hospital point layer from the HIFLD archive.

Source: HIFLD "Hospitals" (DataLumos / ICPSR 239108), mirrored to S3 as a
GeoJSON zip. We filter to STATUS == OPEN, mask the HIFLD -999 "unknown" bed
sentinel to NaN, and flag trauma centers (TRAUMA != "NOT AVAILABLE").

Output: data/hospitals.gpkg  (EPSG:4326 points; columns: name, beds, is_trauma)

Requires AWS credentials with read access to the raw mirror, plus geopandas.
"""
from __future__ import annotations

import io
import subprocess
import sys
import zipfile
from pathlib import Path

import geopandas as gpd
import numpy as np

S3_ZIP = ("s3://geo-geospatial-dev/terrafusion/sandbox/N3C/raw/hospitals/"
          "239108-V1/hospitals-3-geojson.zip")
OUT = Path("data/hospitals.gpkg")


def fetch_zip(s3_uri: str) -> bytes:
    """Download the S3 object to memory via the AWS CLI (already authenticated)."""
    print(f"downloading {s3_uri}")
    res = subprocess.run(["aws", "s3", "cp", s3_uri, "-"],
                         capture_output=True, check=True)
    return res.stdout


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    raw = fetch_zip(S3_ZIP)
    with zipfile.ZipFile(io.BytesIO(raw)) as zf:
        member = next(n for n in zf.namelist() if n.lower().endswith((".geojson", ".json")))
        with zf.open(member) as fh:
            gdf = gpd.read_file(fh)
    print(f"read {len(gdf)} HIFLD facilities; columns: {list(gdf.columns)[:12]}...")

    # normalize column names (HIFLD ships uppercase)
    gdf.columns = [c.upper() if c != "geometry" else c for c in gdf.columns]

    open_mask = gdf["STATUS"].astype(str).str.upper() == "OPEN"
    gdf = gdf[open_mask].copy()
    print(f"{len(gdf)} open facilities")

    gdf = gdf.to_crs("EPSG:4326")
    beds = gdf["BEDS"].astype(float)
    gdf["beds"] = beds.mask(beds <= -999, np.nan)        # -999 = unknown
    gdf["is_trauma"] = (gdf["TRAUMA"].astype(str).str.upper().str.strip()
                        != "NOT AVAILABLE")
    gdf["name"] = gdf.get("NAME")

    out = gdf[["name", "beds", "is_trauma", "geometry"]].copy()
    out = out[out.geometry.notna() & ~out.geometry.is_empty]

    out.to_file(OUT, driver="GPKG")
    print(f"wrote {len(out)} hospitals -> {OUT}  "
          f"(trauma: {int(out.is_trauma.sum())}, "
          f"total beds: {np.nansum(out.beds):,.0f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
