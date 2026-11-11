# Tidy raster analysis verbs

Native tidyverse-style wrappers around common **terra** operations for
elevation and climate rasters. terra (and therefore these helpers) reads
and writes through **GDAL**, so GeoTIFF, COG, netCDF and similar formats
work without calling `gdal_translate` yourself. Do not use the retired
**rgdal** package. Pair with
[`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md)
to join raster values to sites, and with
[`geo_buffer()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
plus `geo_raster_zonal()` for mean elevation in a site buffer.
`geo_raster_project()`, `geo_raster_crop()` and `geo_raster_mask()` are
the tidy entry points for GDAL warps / clips.

## Usage

``` r
geo_raster_crop(raster, y, ...)

geo_raster_mask(raster, y, ...)

geo_raster_resample(raster, res = NULL, method = "bilinear", ...)

geo_raster_project(raster, crs, method = "bilinear", ...)

geo_raster_terrain(
  raster,
  v = c("slope", "aspect", "TPI"),
  unit = "degrees",
  ...
)

geo_raster_focal(raster, w = 3, fun = "mean", ...)

geo_raster_zonal(raster, y, fun = "mean", ..., as_tibble = TRUE)
```

## Arguments

- raster:

  A
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
  or a file path.

- y:

  An `sf` polygon/line used to crop, mask or summarise.

- ...:

  Passed to the underlying terra helper.

- res:

  Target resolution (one or two numbers) for resampling.

- method:

  Resampling method passed to terra.

- crs:

  Target CRS (EPSG code, WKT or proj string).

- v:

  Terrain variables: `"slope"`, `"aspect"`, `"TPI"`, `"TRI"`,
  `"roughness"`, `"flowdir"`.

- unit:

  Unit for slope/aspect (`"degrees"` or `"radians"`).

- w:

  Window size (odd integer or matrix) for the focal filter.

- fun:

  Summary function name or function.

- as_tibble:

  Return a tibble (default) instead of the raw terra extract matrix?

## Examples

``` r
r <- terra::rast(ncols = 20, nrows = 20, xmin = 144.8, xmax = 145.4,
  ymin = -6.0, ymax = -5.5, crs = "EPSG:4326")
terra::values(r) <- seq_len(terra::ncell(r))
names(r) <- "elev"
sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
sites <- sites[sites$elevation <= 2200, ]
geo_raster_zonal(r, geo_buffer(sites, dist = 2000), fun = "mean")
#> # A tibble: 5 × 7
#>   site     lon   lat elevation elevation_band coordinate_note               elev
#>   <chr>  <dbl> <dbl>     <int> <fct>          <chr>                        <dbl>
#> 1 MW0200  145. -5.74       200 200 m          published bait GPS, doi:10.…   198
#> 2 MW0700  145. -5.73       700 700 m          published bait GPS, doi:10.…   196
#> 3 MW1200  145. -5.72      1200 1200 m         published bait GPS, doi:10.…   186
#> 4 MW1700  145. -5.76      1700 1700 m         published bait GPS, doi:10.…   215
#> 5 MW2200  145. -5.76      2200 2200 m         published bait GPS, doi:10.…   213
```
