# Data

All three inputs are public. Acquisition is scripted in `code/acquire/`; the
exact provenance, vintages, and filtering are recorded below and in each
derived file's metadata.

## Hospital locations (HIFLD)

Hospital point locations come from the **Homeland Infrastructure
Foundation-Level Data (HIFLD)** "Hospitals" layer (DHS / Oak Ridge National
Laboratory). The HIFLD Open portal was deactivated 2025-08-26; we source the
layer from the **DataLumos archive** (ICPSR project 239108).

- **Count.** 8,340 facilities, of which **7,966 are `STATUS == OPEN`**; the 374
  closed facilities are excluded.
- **Geometry.** Point locations in EPSG:4326 (`lat`/`lon`).
- **Attributes used.** `BEDS` (staffed beds; the HIFLD `-999` "unknown"
  sentinel is masked to missing before any summation), and `TRAUMA` (a facility
  is treated as a **trauma center** when `TRAUMA` is any value other than
  "NOT AVAILABLE", i.e. any level I–V / pediatric / state TRH/TRF/CTH code).
- **Vintage.** A single ~2024 snapshot. HIFLD is *not* a time series; hospitals
  open and close over time but the snapshot reflects one cross-section. We
  therefore treat the hospital layer as static and analyze population time
  variation against a fixed hospital geography (see Limitations).

## Population (ORNL LandScan Global — ambient)

The demand surface is **LandScan Global ambient population** (ORNL): a gridded,
~30 arc-second (~1 km at the equator) raster of **24-hour average** ("ambient")
population, distributed annually. We use years **2018–2024** (one GeoTIFF per
year), native EPSG:4326, globally complete (so Alaska, Hawaii, and territories
receive real values).

LandScan estimates *where people are over a day* — incorporating workplaces,
roads, and land cover — rather than where they sleep, which is the property we
exploit: it is the more defensible demand surface for acute care.

## Population (NASA SEDAC GPW v4.11 — residential, for contrast)

To isolate the effect of the ambient choice, we replicate the entire analysis
with a conventional **residential (nighttime) population** surface: the
**Gridded Population of the World, version 4.11 (GPWv4.11)** from NASA's
Socioeconomic Data and Applications Center (SEDAC; CIESIN, Columbia University)
[@doxseywhitfield_gpw_2015]. GPW is provided natively at **30 arc-seconds
(~1 km at the equator)** — the same grid as LandScan Global — so the two
surfaces align essentially cell-for-cell and the contrast is a clean grid-vs-
grid swap with no areal-interpolation step. Both rasters are read identically;
only the intensity surface changes.

**Two differences, not one (a controlled-contrast caveat).** GPW and LandScan
differ in the property we wish to study — residential vs. ambient timing — but
*also* in construction: GPW is **areal/proportional** (census counts spread
uniformly within each input administrative unit, so its effective resolution is
the input unit size), whereas LandScan is **dasymetric/modeled** (counts
redistributed within units using roads, land cover, and imagery). A raw
LandScan-vs-GPW difference therefore conflates "ambient vs. residential" with
"modeled vs. unmodeled." <!-- TODO (robustness): add WorldPop (modeled
residential, ~1 km) to hold construction constant, or LandScan USA day/night
(~90 m, US-only) for a same-product-family ambient/residential check. Decide
v1 scope. -->

## Analysis windows (USDA commuting zones)

The unit of analysis is the **commuting zone (CZ)** — clusters of counties tied
together by commuting flows [@tolbert_sizer_1996]. Commuting zones are chosen
deliberately over metropolitan/micropolitan statistical areas (CBSAs) for three
reasons that matter for this test:

1. **National coverage including rural.** CZs partition the *entire* United
   States — every county belongs to exactly one zone — so non-metropolitan
   rural areas, where hospital access deserts are most severe, remain *in*
   sample. CBSAs, by contrast, exclude all outside-CBSA rural counties.
2. **Movement-defined, matching ambient population.** CZs are delineated from
   where people actually travel, the same behavioral basis as LandScan's
   ambient surface — the window and the demand surface share a logic.
3. **Exogenous to hospital locations.** Unlike Dartmouth Hospital Service /
   Referral Regions (which are drawn from hospital-utilization patterns and so
   are partly endogenous to the thing we test), CZ boundaries do not depend on
   where hospitals are, avoiding circularity.

CZ geometries are built by dissolving U.S. Census county polygons
(TIGER/Line) using the USDA Economic Research Service county→CZ crosswalk.
<!-- TODO: fix CZ vintage (e.g., 2010-delineation) + TIGER county vintage. -->
As a robustness/comparability check the analysis can additionally be run on
CBSAs (urban-only) — reported as a sensitivity, not the headline.

## Coordinate reference systems

Population is read in EPSG:4326. Within each CBSA, points, the boundary
polygon, and the population raster are projected to a **local UTM zone** (chosen
from the CBSA centroid) so that the distance-based K-function and the area
integral of the intensity are computed in meters with minimal distortion.

## Derived inputs

| File (gitignored, under `data/`)            | Produced by                       | Contents |
|---------------------------------------------|-----------------------------------|----------|
| `hospitals.gpkg`                             | `acquire/01_hospitals.py`         | open hospital points + `beds`, `is_trauma` |
| `commuting_zones.gpkg`                       | `acquire/02_commuting_zones.py`   | CZ boundary polygons (counties dissolved by USDA crosswalk) |
| `landscan/landscan-global-<year>.tif`        | `acquire/03_landscan.py`          | ambient population rasters (LandScan Global) |
| `gpw/gpw_v4_<year>.tif`                       | `acquire/04_gpw.py`               | residential population rasters (NASA SEDAC GPWv4.11) |
