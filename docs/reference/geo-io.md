# Read and write spatial files through GDAL

Tidy readers and writers so you rarely need
[`sf::st_read()`](https://rdrr.io/pkg/sf/man/st_read.html),
[`terra::rast()`](https://rdrr.io/pkg/terra/man/rast.html), or raw GDAL
utilities. `geo_read()` auto-detects raster versus vector from the file
extension (and GDAL driver when needed). `geo_write()` picks a writer
from the object type and the destination extension. Format-specific
twins `geo_vector_read()` / `geo_vector_write()` and `geo_raster_read()`
/ `geo_raster_write()` are available when you already know the type. All
I/O goes through **sf** and **terra** (GDAL / OGR under the hood). Do
not use the retired **rgdal** package.

Supported formats (read unless noted; anything else GDAL reads also
works, with `type` set):

|                          |                                                                         |                    |                                                                                                                            |
|--------------------------|-------------------------------------------------------------------------|--------------------|----------------------------------------------------------------------------------------------------------------------------|
| Format                   | Extensions                                                              | Type               | Notes                                                                                                                      |
| GeoTIFF / COG            | `.tif`, `.tiff`                                                         | raster             | write supported                                                                                                            |
| netCDF                   | `.nc`, `.nc4`, `.cdf`                                                   | raster             | climate and ocean data; pick variables with `var`, time kept in [`terra::time()`](https://rdrr.io/pkg/terra/man/time.html) |
| HDF4 / HDF5              | `.hdf`, `.h4`, `.he4`, `.h5`, `.hdf5`, `.he5`                           | raster             | MODIS, VIIRS, GEDI; pick subdatasets with `var`                                                                            |
| GRIB                     | `.grib`, `.grb`, `.grib2`, `.grb2`                                      | raster             | weather model output                                                                                                       |
| Sentinel-2               | `.SAFE` folder, `.zip`, `MTD_*.xml`                                     | raster             | Level-1C and Level-2A products                                                                                             |
| JPEG 2000                | `.jp2`                                                                  | raster             | Sentinel-2 band files                                                                                                      |
| ENVI                     | `.dat`/`.bin` with `.hdr`, `.envi`                                      | raster             | hyperspectral cubes                                                                                                        |
| ERDAS Imagine            | `.img`                                                                  | raster             |                                                                                                                            |
| Zarr                     | `.zarr`                                                                 | raster             | cloud-native arrays                                                                                                        |
| Other rasters            | `.asc`, `.grd`, `.vrt`, `.rst`, `.sdat`, `.ers`, `.bil`, `.bip`, `.bsq` | raster             | ASCII grid, VRT, IDRISI, SAGA, ER Mapper                                                                                   |
| Band files               | several paths                                                           | raster             | stacked into one multi-band raster                                                                                         |
| GeoPackage               | `.gpkg`                                                                 | vector (or raster) | preferred vector write                                                                                                     |
| Shapefile                | `.shp` (+ sidecars)                                                     | vector             | write supported                                                                                                            |
| GeoJSON / TopoJSON       | `.geojson`, `.json`, `.topojson`                                        | vector             | write supported                                                                                                            |
| FlatGeobuf               | `.fgb`                                                                  | vector             | write supported                                                                                                            |
| KML / KMZ                | `.kml`, `.kmz`                                                          | vector             | KMZ unzipped to KML                                                                                                        |
| GPS exchange             | `.gpx`                                                                  | vector             | waypoints, tracks, routes (`layer`)                                                                                        |
| AutoCAD                  | `.dxf`, `.dwg`                                                          | vector             | pick CAD layers with `cad_layer`; DWG needs GDAL's CAD driver                                                              |
| MicroStation             | `.dgn`                                                                  | vector             | `cad_layer` filters by level                                                                                               |
| MapInfo                  | `.tab`, `.mif`                                                          | vector             |                                                                                                                            |
| GML, SQLite / SpatiaLite | `.gml`, `.sqlite`                                                       | vector             |                                                                                                                            |
| OpenStreetMap            | `.osm`, `.pbf`                                                          | vector             | `layer` = `"points"`, `"lines"`, `"multipolygons"`                                                                         |
| Nautical charts (S-57)   | `.000`                                                                  | vector             |                                                                                                                            |
| FileGDB                  | `.gdb`                                                                  | vector             | when GDAL has OpenFileGDB/FileGDB                                                                                          |
| Spreadsheets             | `.xlsx`, `.xls`, `.ods`                                                 | vector             | through GDAL; needs lon/lat columns                                                                                        |
| CSV / text               | `.csv`, `.tsv`, `.txt`                                                  | vector             | needs lon/lat columns                                                                                                      |

Use
[`geo_layers()`](https://tidymapr.in4metrix.dev/reference/geo_layers.md)
to see what a file holds (vector layers, netCDF/HDF variables and
subdatasets, or AutoCAD layers) before reading it. GADM downloads use
these writers for the on-disk cache; see
[`geo_gadm()`](https://tidymapr.in4metrix.dev/reference/geo_gadm.md) for
license notes (do not redistribute the full GADM database).

Map figures from
[`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
[`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md),
[`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md) and
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md)
are saved with
[`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md) (or
[`tidydiversity::plot_save()`](https://rdrr.io/pkg/tidydiversity/man/plot_save.html)).

## Usage

``` r
geo_read(
  path,
  type = NULL,
  driver = NULL,
  lon = NULL,
  lat = NULL,
  layer = NULL,
  crs = 4326,
  var = NULL,
  cad_layer = NULL,
  ...
)

geo_vector_read(
  path,
  driver = NULL,
  lon = NULL,
  lat = NULL,
  layer = NULL,
  crs = NULL,
  cad_layer = NULL,
  ...
)

geo_raster_read(path, driver = NULL, var = NULL, ...)

geo_write(
  x,
  path,
  driver = NULL,
  lon = NULL,
  lat = NULL,
  layer = NULL,
  overwrite = FALSE,
  crs = 4326,
  ...
)

geo_vector_write(
  data,
  path,
  driver = NULL,
  lon = NULL,
  lat = NULL,
  layer = NULL,
  overwrite = FALSE,
  crs = 4326,
  ...
)

geo_raster_write(raster, path, driver = NULL, overwrite = FALSE, ...)
```

## Arguments

- path:

  File path. The extension selects the format unless `driver` is set.

- type:

  Force `"vector"` or `"raster"` in `geo_read()`; `NULL` auto-detects.

- driver:

  Optional GDAL/OGR driver name (for example `"GPKG"`,
  `"ESRI Shapefile"`, `"GeoJSON"`, `"GTiff"`, `"netCDF"`).

- lon, lat:

  Column names used when reading CSV/text or writing a non-`sf` table.
  Defaults try `lon`/`lat`, then `longitude`/`latitude`, then `x`/`y`.

- layer:

  Layer name for multi-layer containers (GeoPackage, GDB, GPX, OSM).

- crs:

  CRS assigned to lon/lat tables (default WGS84) and to CAD drawings,
  which store none (for example `32755` for UTM zone 55S).

- var:

  For netCDF, HDF and GRIB rasters: variable or subdataset names (or
  numbers) to read, as listed by
  [`geo_layers()`](https://tidymapr.in4metrix.dev/reference/geo_layers.md).
  `NULL` reads them all.

- cad_layer:

  For AutoCAD (`.dxf`, `.dwg`) and MicroStation (`.dgn`) files: CAD
  layers (or DGN levels) to keep. `NULL` keeps all.

- ...:

  Passed to [`sf::st_read()`](https://rdrr.io/pkg/sf/man/st_read.html) /
  [`sf::st_write()`](https://rdrr.io/pkg/sf/man/st_write.html) or
  [`terra::rast()`](https://rdrr.io/pkg/terra/man/rast.html) /
  [`terra::writeRaster()`](https://rdrr.io/pkg/terra/man/writeRaster.html).

- x:

  Object to write: `sf`, `SpatRaster`, or a data frame with lon/lat
  columns for `geo_write()` / `geo_vector_write()`.

- overwrite:

  Overwrite an existing file? Default `FALSE`.

- data:

  Vector object or table for `geo_vector_write()` (`sf` or a data frame
  with lon/lat columns).

- raster:

  A
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
  (or coercible) for `geo_raster_write()`.

## Value

- Readers: an `sf` tibble (`tmr_geo_sf`) or a
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html).

- Writers: `path`, invisibly.

## See also

[`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md),
[`geo_gadm()`](https://tidymapr.in4metrix.dev/reference/geo_gadm.md),
[`as_sf()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md),
[`as_spat_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md)

## Examples

``` r
sites <- geo_example_sites("wilhelm")
gpkg <- tempfile(fileext = ".gpkg")
geo_write(sites, gpkg, overwrite = TRUE)
geo_read(gpkg)
#> Simple feature collection with 8 features and 6 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 145.058 ymin: -5.81424 xmax: 145.333 ymax: -5.72361
#> Geodetic CRS:  WGS 84
#>     site      lon      lat elevation elevation_band
#> 1 MW0200 145.3330 -5.73561       200          200 m
#> 2 MW0700 145.2535 -5.73258       700          700 m
#> 3 MW1200 145.2690 -5.72361      1200         1200 m
#> 4 MW1700 145.2365 -5.75665      1700         1700 m
#> 5 MW2200 145.1796 -5.76114      2200         2200 m
#> 6 MW2700 145.1529 -5.81424      2700         2700 m
#> 7 MW3200 145.0706 -5.80470      3200         3200 m
#> 8 MW3700 145.0580 -5.78483      3700         3700 m
#>                                  coordinate_note                      geom
#> 1 published bait GPS, doi:10.5281/zenodo.8191946  POINT (145.333 -5.73561)
#> 2 published bait GPS, doi:10.5281/zenodo.8191946 POINT (145.2535 -5.73258)
#> 3 published bait GPS, doi:10.5281/zenodo.8191946  POINT (145.269 -5.72361)
#> 4 published bait GPS, doi:10.5281/zenodo.8191946 POINT (145.2365 -5.75665)
#> 5 published bait GPS, doi:10.5281/zenodo.8191946 POINT (145.1796 -5.76114)
#> 6 published bait GPS, doi:10.5281/zenodo.8191946 POINT (145.1529 -5.81424)
#> 7 published bait GPS, doi:10.5281/zenodo.8191946  POINT (145.0706 -5.8047)
#> 8 published bait GPS, doi:10.5281/zenodo.8191946  POINT (145.058 -5.78483)

r <- terra::rast(
  ncols = 8, nrows = 8, xmin = 144.8, xmax = 145.4,
  ymin = -6, ymax = -5.5, crs = "EPSG:4326"
)
terra::values(r) <- seq_len(terra::ncell(r))
tif <- tempfile(fileext = ".tif")
geo_raster_write(r, tif, overwrite = TRUE)
geo_raster_read(tif)
#> class       : SpatRaster
#> size        : 8, 8, 1  (nrow, ncol, nlyr)
#> resolution  : 0.075, 0.0625  (x, y)
#> extent      : 144.8, 145.4, -6, -5.5  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : file1cba473301e7.tif
#> name        : lyr.1
#> min value   :     1
#> max value   :    64
```
