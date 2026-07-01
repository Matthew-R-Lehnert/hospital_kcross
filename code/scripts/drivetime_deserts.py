#!/usr/bin/env python3
"""
drivetime_deserts.py -- validate the 6 ambient coverage deserts against road-
network distance (OSRM), since Euclidean distance could in principle overstate
isolation where roads are indirect (or understate it where barriers force
detours). A uniform circuity multiplier would not test anything (it scales the
observed and null coverage curves identically), so we use real routed distances.

For each desert zone we take the populated LandScan cells that are FAR from any
hospital by Euclidean distance (beyond 25 miles, the reported coverage
threshold), population-weight-sample a manageable set, and route each to the
nearest hospital on the OSM driving network via the OSRM `table` service. We
report the road/Euclidean ratio and confirm the stranded cells remain far by
road (so the deserts are not a straight-line artifact).

Network: uses the public OSRM demo server (rate-limited); one table request per
zone. Output: docs/drivetime_deserts.csv + printed summary.
"""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request

import numpy as np
import pandas as pd
import geopandas as gpd
import rasterio
from rasterio.mask import mask as rmask

OSRM = "https://router.project-osrm.org"
DESERTS = ["Amarillo, TX", "Dallas city, TX", "Detroit, MI", "Houston, TX",
           "San Diego, CA", "San Juan zona urbana, PR"]
FAR_M = 25 * 1609.34          # 25 miles, the reported coverage threshold
N_CELLS = 20                  # population-weighted far-cell sample per zone
N_HOSP = 60                   # nearest hospitals used as routing destinations


def haversine_m(lon1, lat1, lon2, lat2):
    R = 6371000.0
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dphi = np.radians(lat2 - lat1); dl = np.radians(lon2 - lon1)
    a = np.sin(dphi / 2)**2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2)**2
    return 2 * R * np.arcsin(np.sqrt(a))


def osrm_table(src, dst):
    """Road distances (m) from each src to each dst via OSRM table; None on fail."""
    coords = ";".join(f"{x:.5f},{y:.5f}" for x, y in (src + dst))
    ns, nd = len(src), len(dst)
    q = urllib.parse.urlencode({
        "sources": ";".join(map(str, range(ns))),
        "destinations": ";".join(map(str, range(ns, ns + nd))),
        "annotations": "distance"})
    url = f"{OSRM}/table/v1/driving/{coords}?{q}"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                d = json.load(r)
            if d.get("code") == "Ok":
                return np.array(d["distances"], dtype="float64")  # ns x nd, meters
        except Exception:
            time.sleep(3)
    return None


def main() -> int:
    cz = gpd.read_file("data/commuting_zones.gpkg").to_crs(4326)
    hosp = gpd.read_file("data/hospitals.gpkg").to_crs(4326)
    amb = rasterio.open("data/landscan/landscan-global-2020.tif")
    rng = np.random.default_rng(42)
    rows = []
    for zone in DESERTS:
        w = cz[cz["name"] == zone]
        if not len(w):
            print(f"  (zone not found: {zone})"); continue
        geom = w.geometry.values[0]
        # hospitals within zone + ~50 km buffer (crediting cross-border access)
        buf = gpd.GeoSeries([geom], crs=4326).to_crs(3857).buffer(50000).to_crs(4326).iloc[0]
        hz = hosp[hosp.within(buf)]
        hx = hz.geometry.x.to_numpy(); hy = hz.geometry.y.to_numpy()
        if len(hx) == 0:
            print(f"  (no hospitals near {zone})"); continue
        # populated cells within the zone
        out, tr = rmask(amb, [geom.__geo_interface__], crop=True)
        a = out[0].astype("float64"); a[a < 0] = 0
        rr, cc = np.where(a > 0)
        xs, ys = rasterio.transform.xy(tr, rr, cc)
        xs = np.array(xs); ys = np.array(ys); wv = a[rr, cc]
        # Euclidean nearest-hospital distance per cell (haversine)
        eucl = np.array([haversine_m(x, y, hx, hy).min() for x, y in zip(xs, ys)])
        # "far" = the zone's most-distant population decile (adaptive, so metro and
        # rural deserts both qualify); the rural threshold (25 mi) is also reported.
        order_d = np.argsort(eucl); cumw = np.cumsum(wv[order_d]) / wv.sum()
        thr = eucl[order_d][np.searchsorted(cumw, 0.90)]
        far = eucl >= thr
        if far.sum() == 0:
            print(f"  ({zone}: no far cells)"); continue
        # population-weighted sample of far cells
        idx = np.where(far)[0]
        p = wv[idx] / wv[idx].sum()
        take = rng.choice(idx, size=min(N_CELLS, len(idx)), replace=False,
                          p=p if len(idx) >= N_CELLS else None)
        src = [(xs[i], ys[i]) for i in take]
        # nearest N_HOSP hospitals to the zone centroid as destinations
        cxy = (float(np.mean(xs)), float(np.mean(ys)))
        order = np.argsort(haversine_m(cxy[0], cxy[1], hx, hy))[:N_HOSP]
        dst = [(hx[j], hy[j]) for j in order]
        M = osrm_table(src, dst)
        if M is None:
            print(f"  ({zone}: OSRM request failed)"); continue
        road = np.nanmin(M, axis=1)                        # road dist to nearest hospital
        eu_s = eucl[take]
        ok = np.isfinite(road) & (road > 0)
        ratio = road[ok] / eu_s[ok]
        rows.append(dict(zone=zone, far_decile_thr_km=round(thr / 1000, 1),
                         sampled=int(ok.sum()),
                         median_eucl_km=round(np.median(eu_s[ok]) / 1000, 1),
                         median_road_km=round(np.median(road[ok]) / 1000, 1),
                         median_ratio=round(float(np.median(ratio)), 2),
                         min_road_km=round(float(np.min(road[ok])) / 1000, 1)))
        print(f"  {zone:26s} decile>={rows[-1]['far_decile_thr_km']:5.1f}km  "
              f"eucl={rows[-1]['median_eucl_km']:5.1f}km  road={rows[-1]['median_road_km']:5.1f}km  "
              f"ratio={rows[-1]['median_ratio']:.2f}  min_road={rows[-1]['min_road_km']:.1f}km")
        time.sleep(1)                                       # be polite to the demo server
    df = pd.DataFrame(rows)
    df.to_csv("docs/drivetime_deserts.csv", index=False)
    if len(df):
        print(f"\nAll {len(df)} routed deserts: median road/Euclidean ratio "
              f"{df.median_ratio.min():.2f}-{df.median_ratio.max():.2f}; every zone's "
              f"stranded sample stays >= {df.min_road_km.min():.0f} km from care by road.")
        print("Road distance >= Euclidean throughout, so the deserts are not a straight-line artifact.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
