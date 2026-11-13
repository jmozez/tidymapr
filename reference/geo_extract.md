# Extract raster values at sites

Joins CHELSA, WorldClim or SRTM-style rasters (a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
or a file path) to site coordinates. Layer names become columns. Points
that fall on NA cells keep `NA` in those columns.

## Usage

``` r
geo_extract(data, raster, lon = lon, lat = lat, method = "simple", bind = TRUE)
```

## Arguments

- data:

  A data frame or `sf` object with site coordinates.

- raster:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
  a file path, or a list of either.

- lon, lat:

  \<[`data-masking`](https://dplyr.tidyverse.org/reference/dplyr_data_masking.html)\>
  Coordinate columns when `data` is not `sf`.

- method:

  Extraction method passed to
  [`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html),
  default `"simple"`.

- bind:

  Bind extracted columns onto `data`? If `FALSE`, return only the
  extracted tibble.

## Value

A tibble (or `sf` tibble) with one column per raster layer.

## Examples

``` r
r <- terra::rast(ncols = 36, nrows = 18, xmin = -180, xmax = 180,
  ymin = -90, ymax = 90, crs = "EPSG:4326")
terra::values(r) <- seq_len(terra::ncell(r))
names(r) <- "demo"
sites <- tibble::tibble(site = "a", lon = 147, lat = -9)
geo_extract(sites, r, lon, lat)
#> # A tibble: 1 × 4
#>   site    lon   lat  demo
#>   <chr> <dbl> <dbl> <int>
#> 1 a       147    -9   357
```
