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

geo_raster_resample(
  raster,
  res = NULL,
  method = "bilinear",
  ...,
  origin = c(0, 0),
  align_to = NULL
)

geo_raster_project(raster, crs, method = "bilinear", ...)

geo_raster_terrain(
  raster,
  v = c("slope", "aspect", "TPI"),
  unit = "degrees",
  ...
)

geo_raster_focal(raster, w = 3, fun = "mean", ...)

geo_raster_zonal(
  raster,
  y,
  fun = "mean",
  ...,
  as_tibble = TRUE,
  weight = c("none", "area")
)
```

## Arguments

- raster:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  or a file path.

- y:

  What to crop, mask or summarise by: an `sf` or `sfc` object, a terra
  `SpatVector`, `SpatExtent` or `SpatRaster` (its extent), an sf `bbox`,
  or four numbers. Unnamed numbers are read as
  `c(xmin, ymin, xmax, ymax)`, the order of
  [`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html);
  note that
  [`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html)
  uses `xmin, xmax, ymin, ymax`. Named numbers (`xmin`, `ymin`, `xmax`,
  `ymax`) may be in any order.

- ...:

  Passed to the underlying terra helper.

- res:

  Target resolution (one or two numbers) for resampling.

- method:

  Resampling method passed to terra (`"average"` gives the same values
  as
  [`terra::aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html)
  when the grids are aligned).

- origin:

  Grid origin for `geo_raster_resample()`: cell edges fall on
  `origin + k * res`. The default, `c(0, 0)`, aligns cells to whole
  multiples of the resolution (for example whole degrees for 1/120
  degree), so results match
  [`terra::aggregate()`](https://rspatial.github.io/terra/reference/aggregate.html)
  or
  [`terra::resample()`](https://rspatial.github.io/terra/reference/resample.html)
  on an aligned template. Earlier versions started the grid at the
  raster's edge, which could shift results by part of a cell.

- align_to:

  Optional template `SpatRaster` whose grid (origin and, unless `res` is
  given, resolution) the result should share.

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

- weight:

  For `geo_raster_zonal()` with a zone raster: `"area"` weights each
  cell by its true area
  ([`terra::cellSize()`](https://rspatial.github.io/terra/reference/cellSize.html)),
  which matters for longitude/latitude grids whose cells shrink away
  from the equator; `"none"` gives every cell equal weight. With
  `"area"`, `fun` must be `"mean"` or `"sum"` (the area-weighted sum is
  the integral, e.g. km2 for an indicator raster).

## Value

`geo_raster_crop()`, `geo_raster_mask()`, `geo_raster_resample()`,
`geo_raster_project()`, `geo_raster_terrain()` and `geo_raster_focal()`
return a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).
`geo_raster_zonal()` returns a tibble with one row per feature of `y`
(its attributes and the summary statistic), or the raw
[`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html)
result when `as_tibble = FALSE`.

## Details

`geo_raster_zonal()` accepts polygons (sf, sfc, SpatVector) or a **zone
raster** as `y`: a categorical `SpatRaster` (for example elevation bands
or land-cover classes). A zone raster on a different grid is resampled
to the value raster with nearest-neighbour first.

## Examples

``` r
r <- terra::rast(
  ncols = 20, nrows = 20, xmin = 144.8, xmax = 145.4,
  ymin = -6.0, ymax = -5.5, crs = "EPSG:4326"
)
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
