# 8. Data in and out, occurrence cleaning, web maps and recipes

``` r

library(tidymapr)
library(dplyr)
```

## 1. Reading data

### The concept

Spatial data come in two kinds (Chapter 1): **vector** data (points,
lines, polygons with attribute tables) and **raster** data (grids of
cells). tidymapr reads both through GDAL, the library behind QGIS,
ArcGIS and GeoSpaX, so almost any format works. Every file must carry,
or be given, its **coordinate reference system** (Chapter 2).

| Data | Common formats | Read with | Returns |
|----|----|----|----|
| Vector | GeoPackage (`.gpkg`), shapefile (`.shp`), GeoJSON, KML, GPX | [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md) | `sf` table |
| CAD drawings | AutoCAD DXF | `geo_read(cad_layer = )` | `sf` table |
| Raster | GeoTIFF, ASCII grid, JPEG2000 | [`geo_raster_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md) | `SpatRaster` |
| Multidimensional | netCDF (`.nc`), HDF4, HDF5 (climate, satellite products) | `geo_raster_read(var = )` | `SpatRaster` with one layer per time or depth |
| Tables | CSV, Excel with coordinates | [`read.csv()`](https://rdrr.io/r/utils/read.table.html), then [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md) | `sf` table |

``` r

# A file can hold several layers: list them first
geo_layers(system.file("shapes/world.gpkg", package = "spData"))
#> # A tibble: 1 × 4
#>   layer geometry      features fields
#>   <chr> <chr>            <int>  <int>
#> 1 world Multi Polygon      177     10

cantons <- geo_read(system.file("ex/lux.shp", package = "terra"))
cantons
#> Simple feature collection with 12 features and 6 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 5.74414 ymin: 49.44781 xmax: 6.528252 ymax: 50.18162
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    ID_1       NAME_1 ID_2           NAME_2 AREA    POP
#> 1     1     Diekirch    1         Clervaux  312  18081
#> 2     1     Diekirch    2         Diekirch  218  32543
#> 3     1     Diekirch    3          Redange  259  18664
#> 4     1     Diekirch    4          Vianden   76   5163
#> 5     1     Diekirch    5            Wiltz  263  16735
#> 6     2 Grevenmacher    6       Echternach  188  18899
#> 7     2 Grevenmacher    7           Remich  129  22366
#> 8     2 Grevenmacher   12     Grevenmacher  210  29828
#> 9     3   Luxembourg    8         Capellen  185  48187
#> 10    3   Luxembourg    9 Esch-sur-Alzette  251 176820
#>                          geometry
#> 1  POLYGON ((6.026519 50.17767...
#> 2  POLYGON ((6.178368 49.87682...
#> 3  POLYGON ((5.881378 49.87015...
#> 4  POLYGON ((6.131309 49.97256...
#> 5  POLYGON ((5.977929 50.02602...
#> 6  POLYGON ((6.385532 49.83703...
#> 7  POLYGON ((6.316665 49.62337...
#> 8  POLYGON ((6.425158 49.73164...
#> 9  POLYGON ((5.998312 49.69992...
#> 10 POLYGON ((6.039474 49.44826...
```

netCDF files from climate models and reanalyses hold many variables and
time steps in one file:

``` r

era5 <- geo_raster_read(system.file("ex/nouragues.nc", package = "terra"))
era5
#> class       : SpatRaster
#> size        : 3, 3, 336  (nrow, ncol, nlyr)
#> resolution  : 0.1005001, 0.0999999  (x, y)
#> extent      : -52.90525, -52.60375, 3.911, 4.211  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (CRS84) (OGC:CRS84)
#> sources     : nouragues.nc
#> varnames    : d2m (2 metre dewpoint temperature)
#>               sp (Surface pressure)
#>               ssrd (Surface solar radiation downwards)
#>               t2m (2 metre temperature)
#>               tp (Total precipitation)
#>               ...
#> names       : d2m_e~r=1_1, d2m_e~r=1_2, d2m_e~r=1_3, d2m_e~r=1_4, d2m_e~r=1_5, d2m_e~r=1_6, ...
#> unit        :           K,           K,           K,           K,           K,           K, ...
#> depth       : 1 to 5 (: 2 steps)
#> time        : 2021-01-01 00:00:00zUTC to 2022-12-01 00:00:00zUTC (24 steps)
```

**How to read this.** The file holds ERA5 climate reanalysis for the
Nouragues station in French Guiana: 336 layers, made of several
variables (dewpoint `d2m`, temperature `t2m`, precipitation `tp`, …) for
each month of 2021-2022. Pick one with
`geo_raster_read(path, var = "t2m")`; units are kelvin for temperature,
as the `unit` line shows.

### Coordinates in a spreadsheet

``` r

sites <- read.csv("data/sites.csv")                 # columns lon, lat
sites <- geo_as_sf(sites, lon, lat)                 # WGS84 longitude/latitude

utm <- read.csv("data/plots_utm.csv")               # columns x, y in metres
utm <- geo_as_sf(utm, x, y, crs = 32755)            # say which UTM zone
```

tidymapr refuses coordinate columns that cannot be longitude and
latitude unless you give their CRS, because treating metres as degrees
would silently give wrong distances.

### Writing

``` r

geo_write(cantons, "output/cantons.gpkg")           # GeoPackage: the best general format
geo_write(cantons, "output/cantons.shp")            # shapefile, for older software
terra::writeRaster(era5[[1]], "output/d2m.tif")     # GeoTIFF
```

Prefer GeoPackage over shapefiles: one file instead of five, no
10-character limit on column names, and no 2 GB size limit.

## 2. Occurrence records from GBIF

### The concept

The Global Biodiversity Information Facility (GBIF) aggregates over two
billion species records from museums, surveys and citizen science. They
are invaluable and imperfect: **coordinate errors** are common, and they
bias species distribution models (Chapter 5). Typical errors:

| Error | Example | Test in [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md) |
|----|----|----|
| Zero coordinates | 0°, 0° in the Gulf of Guinea | `"zeros"` |
| Equal coordinates | Longitude = latitude, a typing error | `"equal"` |
| Country capitals and centroids | The record was georeferenced to the country, not the site | `"capitals"`, `"centroids"` |
| Biodiversity institutions | A museum’s own coordinates instead of the collecting site | `"institutions"` |
| The GBIF headquarters | Copenhagen | `"gbif"` |
| Duplicates | The same record from two datasets | `"duplicates"` |
| Outliers | Far from all other records of the species | `"outliers"` |

These follow CoordinateCleaner (Zizka et al. 2019), with the same
default distances. The zero, equal-coordinate and GBIF tests give
exactly CoordinateCleaner’s flags, which is checked in tidymapr’s tests;
the capital and centroid tests use all 215 national capitals and three
definitions of each country’s centroid from Natural Earth.

Download with `geo_gbif("Oecophylla smaragdina", country = "PG")` (needs
internet). The records of the weaver ant *Oecophylla smaragdina* in
Papua New Guinea are shipped with tidymapr, so this example runs
offline:

``` r

recs <- read.csv(system.file("extdata", "gbif_oecophylla_png.csv", package = "tidymapr"))
nrow(recs)
#> [1] 96

# Add three typical mistakes to see how they are caught
bad <- recs[1:3, ]
bad$lon <- c(0, 147.18, -6.6)
bad$lat <- c(0, -9.44, -6.6)     # zeros; Port Moresby (the capital); equal coordinates
both <- rbind(recs, bad)

flags <- geo_clean(both, lon = lon, lat = lat, species = species, value = "flagged")
flags |>
  filter(.summary) |>
  select(lon, lat, .zer, .equ, .cap, .summary)
#> # A tibble: 3 × 6
#>     lon   lat .zer  .equ  .cap  .summary
#>   <dbl> <dbl> <lgl> <lgl> <lgl> <lgl>   
#> 1   0    0    TRUE  TRUE  FALSE TRUE    
#> 2 147.  -9.44 FALSE FALSE TRUE  TRUE    
#> 3  -6.6 -6.6  FALSE TRUE  FALSE TRUE
clean <- geo_clean(both, lon = lon, lat = lat, species = species)
nrow(clean)
#> [1] 96
```

**How to read it.** Each `.xxx` column is one test, and `TRUE` means the
record was **flagged** by it; `.summary` is `TRUE` if any test flagged
the record. (CoordinateCleaner uses the opposite convention, `TRUE` =
passed.) The three added records are flagged: zero coordinates (which
are also equal coordinates, so two tests catch them), the capital, and
equal coordinates. All 96 real records pass every test, so `clean` keeps
exactly those. Always look at what was removed: a record near a capital
may be real, and automated tests are a first filter, not a substitute
for knowing the species.

## 3. Interactive web maps

### The concept

A static map is for print; an **interactive web map** lets readers zoom,
switch layers and click features for details.
[`geo_webmap()`](https://tidymapr.in4metrix.dev/reference/geo_webmap.md)
turns any tidymapr map into a single, self-contained HTML file that
opens in any browser, with no server needed: e-mail it, put it on a
website, or attach it to a report.

``` r

recs_sf <- geo_as_sf(recs, lon, lat)
web <- geo_map(title = "Weaver ant records in Papua New Guinea (GBIF)") |>
  map_points(recs_sf, preset = "occurrence", label = "Records")
dir.create("guide-08-data-webmaps-recipes_files", showWarnings = FALSE)
geo_webmap(web, file = "guide-08-data-webmaps-recipes_files/oecophylla.html", popup = c("year", "basis_of_record"))
```

Click a point for its year and type of record; switch basemaps at the
top right. The same legend and colours as the static map are used, so
the two can be published side by side.

## 4. GeoSpaX recipes

### The concept

A **recipe** is a complete analysis written as a short YAML file:
inputs, a list of steps, and outputs. GeoSpaX, the desktop GIS, runs
recipes from its menus; tidymapr runs the same files in R. A colleague
can therefore repeat your analysis by clicking, and you can re-run
theirs in a script, with identical results. Recipes also document
methods: the file *is* the methods section.

``` r

rec <- geo_recipe_read(system.file("recipes/points-to-hotspots.yaml", package = "tidymapr"))
rec
#> GeoSpaX recipe "points-to-hotspots" (v1): Incidents → hot spot map (Getis-Ord
#> Gi*)
#> Inputs: layer and field
#> Steps: incidents (io.open), hot (stats.hotspots), style (automap.style), map
#> (export.map), and report (export.report)
#> Outputs: hot, map, and report
geo_recipe_validate(rec)       # an empty table means the recipe is valid
#> # A tibble: 0 × 3
#> # ℹ 3 variables: severity <chr>, step <chr>, problem <chr>
```

Run it on the Meuse soil samples (Chapter 3):

``` r

meuse <- terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra")))
samples <- sf::st_as_sf(as.data.frame(meuse), coords = c("x", "y"), crs = 28992)
out <- geo_recipe_run(rec, inputs = list(layer = samples, field = "zinc"),
  dir = tempfile(), quiet = TRUE)
out$log
#> # A tibble: 5 × 4
#>   step      use            status seconds
#>   <chr>     <chr>          <chr>    <dbl>
#> 1 incidents io.open        done      0   
#> 2 hot       stats.hotspots done      0.04
#> 3 style     automap.style  done      0   
#> 4 map       export.map     done      2.16
#> 5 report    export.report  done      0
```

**How to read it.** The log lists each step, the GeoSpaX tool it used
(`use`) and whether it finished. `out$hot` holds the hot-spot results,
`out$map` the map and `out$report` an HTML report. To write your own
recipe, build it with
[`geo_recipe()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
and
[`recipe_step()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md),
then save it with
[`geo_recipe_write()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
and open it in GeoSpaX.

## References

Zizka, A. et al. (2019). CoordinateCleaner: standardized cleaning of
occurrence records from biological collection databases. *Methods in
Ecology and Evolution*, 10, 744-751.

GBIF.org. Occurrence records of *Oecophylla smaragdina* in Papua New
Guinea, retrieved through the GBIF API; each record keeps its dataset
key and licence (all CC BY 4.0 or CC0).
