# Data

All three inputs are public. Acquisition is scripted in `code/acquire/`; the
exact provenance, vintages, and filtering are recorded below and in each
derived file's metadata.

## Hospital locations (HIFLD)

Hospital point locations come from the Homeland Infrastructure Foundation-Level
Data (HIFLD) "Hospitals" layer (DHS / Oak Ridge National Laboratory). The HIFLD
Open portal was deactivated on 2025-08-26, so we source the layer from the
DataLumos archive (ICPSR project 239108).

- **Count.** 8,340 facilities, of which 7,966 are `STATUS == OPEN`; the 374
  closed facilities are excluded.
- **Geometry.** Point locations in EPSG:4326 (`lat`/`lon`).
- **Attributes used.** `BEDS` (staffed beds; the HIFLD `-999` "unknown" bed
  sentinel is masked to missing). Missing beds are uncommon nationally (415 of
  7,966 hospitals, 5.2%; total known beds 1,087,608, median 70), but are
  concentrated enough that 9 zones have over half their beds unknown and are
  flagged where the bed result depends on imputation. The `TRAUMA` designation
  is recorded but the trauma-subset analysis is deferred to future work.
- **Vintage.** A single snapshot dated approximately 2024. HIFLD is not a time
  series; hospitals open and close over time, but the snapshot reflects one
  cross-section. We therefore treat the hospital layer as static and analyze
  population time variation against a fixed hospital geography (see
  Limitations).

## Population (ORNL LandScan Global, ambient)

The demand surface is LandScan Global ambient population (ORNL): a gridded,
roughly 30 arc-second (about 1 km at the equator) raster of 24-hour average
("ambient") population, distributed annually (one GeoTIFF per year), native
EPSG:4326, globally complete, so Alaska, Hawaii, and the territories receive
real values. The LandScan record covers 2018 through 2024; the headline analysis
uses **2020** to align with the residential surface and the commuting-zone
vintage, and the other years support a temporal sensitivity check against the
fixed hospital geography.

LandScan estimates where people are over a day, incorporating workplaces, roads,
and land cover, rather than where they sleep. This property is what we exploit:
it is a complementary demand surface whose timing differs from the residential
denominator that accessibility analyses use by default. We do not claim it is the
single correct surface for acute care. Many acute events (nocturnal myocardial
infarction, stroke, falls among older adults) occur at or near home, and
admissions reflect a mix of daytime and residential exposure; ambient population
captures the daytime component that residential surfaces miss, and our point is
that the choice between the two materially changes the verdict, not that one is
uniformly right.

## Population (NASA SEDAC GPW v4.11, residential, for contrast)

To isolate the effect of the ambient choice, we replicate the entire analysis
with a conventional residential (nighttime) population surface: the Gridded
Population of the World, version 4.11 (GPWv4.11) from NASA's Socioeconomic Data
and Applications Center (SEDAC; CIESIN, Columbia University)
[@doxsey_whitfield_etal_2015]. GPW is provided natively at 30 arc-seconds (about
1 km at the equator), the same grid as LandScan Global, so the two surfaces
align essentially cell for cell and the contrast is a clean grid-versus-grid
swap with no areal-interpolation step. Both rasters are read identically; only
the intensity surface changes.

**Two differences, not one: a controlled-contrast caveat.** GPW and LandScan
differ in the property we wish to study, residential versus ambient timing, but
they also differ in construction. GPW is areal and proportional (census counts
are spread uniformly within each input administrative unit, so its effective
resolution is the input unit size), whereas LandScan is dasymetric and modeled
(counts are redistributed within units using roads, land cover, and imagery). A
raw LandScan-versus-GPW difference therefore conflates ambient versus
residential with modeled versus unmodeled. To separate the two we add a third
surface as a control: **WorldPop** (UN-adjusted, ~1 km, 2020), which is
dasymetric and modeled like LandScan but residential like GPW. If the ambient
effect were a modeling artifact, WorldPop would behave like LandScan; if it is
about day-versus-night timing, WorldPop behaves like GPW (Results confirm the
latter). WorldPop is distributed per country and we use the US file, so Puerto
Rico is not covered by this control.

## Analysis windows (USDA commuting zones)

The unit of analysis is the commuting zone (CZ), a cluster of counties tied
together by commuting flows [@tolbert_sizer_1996]. Commuting zones are chosen
over metropolitan and micropolitan statistical areas (CBSAs) for three reasons
that matter for this test.

1. **National coverage including rural.** Commuting zones partition the entire
   United States; every county belongs to exactly one zone. Non-metropolitan
   rural areas, where hospital access deserts are most severe, therefore remain
   in sample. CBSAs, by contrast, exclude all outside-CBSA rural counties.
2. **Movement-defined, matching ambient population.** Commuting zones are
   delineated from where people travel, the same behavioral basis as LandScan's
   ambient surface, so the window and the demand surface share a logic.
3. **Exogenous to hospital locations.** Unlike Dartmouth Hospital Service and
   Referral Regions, which are drawn from hospital-utilization patterns and so
   are partly endogenous to the thing we test, commuting zone boundaries do not
   depend on where hospitals are, which avoids circularity.

We use the USDA Economic Research Service 2020 commuting-zone delineation, which
groups the 3,222 US and Puerto Rico counties into 598 contiguous labor markets
following the Fowler, Rhubart, and Jensen methodology [@fowler_rhubart_jensen_2016;
@usda_cz2020_2024]. CZ geometries are built by dissolving US Census county
polygons (TIGER/Line) using the ERS county-to-CZ crosswalk. The 2020 vintage is
chosen to match the 2020 population rasters (below). One reconciliation is
required: the 2020 crosswalk keys Connecticut (a single commuting zone spanning
the whole state) to the state's 2022 planning-region FIPS codes, which are not
present in the 2020 county boundary file (Connecticut there is still its eight
historical counties); we map Connecticut's counties to that zone so the state is
retained, giving the full set of 598 commuting zones.

As a windowing-comparability check we additionally re-run the entire analysis on
**Core-Based Statistical Areas** (939 metropolitan and micropolitan CBSAs,
Census TIGER 2020 cartographic boundaries). CBSAs are the more familiar unit but
cover only urbanized cores and their commuting fringes, omitting the
outside-CBSA rural areas; comparing the two window sets tests whether the
findings depend on the partition rather than on the data. The CBSA run is
reported as a sensitivity, not the headline.

## Coordinate reference systems

Population is read in EPSG:4326. Within each commuting zone, the points, the
boundary polygon, and the population raster are projected to a local UTM zone
(chosen from the zone centroid) so that the distance-based K-function and the
area integral of the intensity are computed in meters with minimal distortion.

## Derived inputs

| File (gitignored, under `data/`)            | Produced by                       | Contents |
|---------------------------------------------|-----------------------------------|----------|
| `hospitals.gpkg`                             | `acquire/01_hospitals.py`         | open hospital points + `beds`, `is_trauma` |
| `commuting_zones.gpkg`                       | `acquire/02_commuting_zones.py`   | CZ boundary polygons (counties dissolved by USDA crosswalk) |
| `landscan/landscan-global-<year>.tif`        | `acquire/03_landscan.py`          | ambient population rasters (LandScan Global) |
| `gpw/gpw_v4_<year>.tif`                       | `acquire/04_gpw.py`               | residential population rasters (NASA SEDAC GPWv4.11) |
| `cbsa.gpkg`                                   | `acquire/05_cbsa.py`              | 939 CBSA windows (Census TIGER 2020), robustness re-run |
| `worldpop/worldpop_2020.tif`                  | `acquire/06_worldpop.py`          | modeled-residential control raster (WorldPop US, ~1 km) |
