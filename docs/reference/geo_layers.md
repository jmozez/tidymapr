# List what a spatial file contains

`geo_layers()` looks inside a file before you read it and returns a tidy
table of its contents:

- vector files (GeoPackage, GDB, GPX, OSM, KML, ...): one row per layer,
  with geometry type, number of features and fields;

- netCDF, HDF and GRIB files: one row per variable or subdataset, with
  its description, grid size and number of layers (time steps, depths or
  bands); pass the `var` value to
  [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md);

- AutoCAD (`.dxf`, `.dwg`) and MicroStation (`.dgn`) drawings: one row
  per CAD layer or level, with its number of entities; pass the
  `cad_layer` value to
  [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md);

- other rasters: one row per band.

## Usage

``` r
geo_layers(path)
```

## Arguments

- path:

  Path to a spatial file (or a `.SAFE` folder / `.gdb`).

## Value

A tibble.

## See also

[`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)

## Examples

``` r
# ERA5 monthly climate at the Nouragues station, French Guiana (netCDF)
nc <- system.file("ex/nouragues.nc", package = "terra")
geo_layers(nc)
#> # A tibble: 7 x 6
#>   var   description                                     nrow  ncol layers source
#>   <chr> <chr>                                          <int> <int>  <int> <chr> 
#> 1 u10   u10 (16-bit integer)                               3     3     48 "NETC~
#> 2 v10   v10 (16-bit integer)                               3     3     48 "NETC~
#> 3 d2m   d2m (16-bit integer)                               3     3     48 "NETC~
#> 4 t2m   t2m (16-bit integer)                               3     3     48 "NETC~
#> 5 sp    surface_air_pressure (16-bit integer)              3     3     48 "NETC~
#> 6 tp    tp (16-bit integer)                                3     3     48 "NETC~
#> 7 ssrd  surface_downwelling_shortwave_flux_in_air (16~     3     3     48 "NETC~
t2m <- geo_read(nc, var = "t2m")
t2m
#> class       : SpatRaster
#> size        : 3, 3, 48  (nrow, ncol, nlyr)
#> dimensions  : longitude, latitude, expver, time (3, 3, 2, 24}
#> resolution  : 0.1005001, 0.0999999  (x, y)
#> extent      : -52.90525, -52.60375, 3.911, 4.211  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (CRS84) (OGC:CRS84)
#> source      : nouragues.nc
#> varname     : t2m (2 metre temperature)
#> names       : t2m_e~r=1_1, t2m_e~r=1_2, t2m_e~r=1_3, t2m_e~r=1_4, t2m_e~r=1_5, t2m_e~r=1_6, ...
#> unit        : K
#> depth       : 1 to 5 (expver: 2 steps)
#> time        : 2021-01-01 00:00:00 to 2022-12-01 00:00:00 (24 steps)

# Sentinel-2 Level-2A bands over Luxembourg
geo_layers(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
#> # A tibble: 4 x 5
#>    band name   nrow  ncol crs   
#>   <int> <chr> <dbl> <dbl> <chr> 
#> 1     1 B02      90    95 WGS 84
#> 2     2 B03      90    95 WGS 84
#> 3     3 B04      90    95 WGS 84
#> 4     4 B08      90    95 WGS 84

# Luxembourg cantons written to AutoCAD DXF, then one CAD layer read back
lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
lux <- sf::st_cast(lux[, "NAME_1"], "MULTILINESTRING")
names(lux)[1] <- "Layer"
dxf <- tempfile(fileext = ".dxf")
sf::st_write(lux, dxf, driver = "DXF", quiet = TRUE)
geo_layers(dxf)
#> # A tibble: 3 x 3
#>   cad_layer    entities geometry  
#>   <chr>           <int> <chr>     
#> 1 Diekirch            5 LINESTRING
#> 2 Grevenmacher        3 LINESTRING
#> 3 Luxembourg          4 LINESTRING
geo_read(dxf, cad_layer = "Diekirch", crs = 4326)
#> Simple feature collection with 5 features and 6 fields
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: 5.74414 ymin: 49.69933 xmax: 6.315773 ymax: 50.18162
#> Geodetic CRS:  WGS 84
#>      Layer PaperSpace              SubClasses Linetype EntityHandle Text
#> 1 Diekirch         NA AcDbEntity:AcDbPolyline     <NA>        20000 <NA>
#> 2 Diekirch         NA AcDbEntity:AcDbPolyline     <NA>        20001 <NA>
#> 3 Diekirch         NA AcDbEntity:AcDbPolyline     <NA>        20002 <NA>
#> 4 Diekirch         NA AcDbEntity:AcDbPolyline     <NA>        20003 <NA>
#> 5 Diekirch         NA AcDbEntity:AcDbPolyline     <NA>        20004 <NA>
#>                         geometry
#> 1 LINESTRING (6.026519 50.177...
#> 2 LINESTRING (6.178368 49.876...
#> 3 LINESTRING (5.881378 49.870...
#> 4 LINESTRING (6.131309 49.972...
#> 5 LINESTRING (5.977929 50.026...
```
