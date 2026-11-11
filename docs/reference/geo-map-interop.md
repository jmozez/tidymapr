# Hand off spatial objects to tmap, leaflet and friends

tidymapr keeps mapping in ggplot via
[`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
[`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md) and
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md),
but never blocks **tmap**, **leaflet** or other spatial viewers. These
helpers return plain [sf](https://rdrr.io/pkg/sf/man/sf.html) and
[terra](https://rdrr.io/pkg/terra/man/SpatRaster-class.html) objects
(with a CRS) so
[`tmap::tm_shape()`](https://rdrr.io/pkg/tmap/man/tm_shape.html),
[`leaflet::addTiles()`](https://rdrr.io/pkg/leaflet/man/map-layers.html),
[`leaflet::addCircleMarkers()`](https://rdrr.io/pkg/leaflet/man/map-layers.html)
and
[`leaflet::addRasterImage()`](https://rdrr.io/pkg/leaflet/man/addRasterImage.html)
work without extra wrangling. Neither tmap nor leaflet is a hard Import;
examples are wrapped in
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html).

## Usage

``` r
as_sf(x, ...)

# Default S3 method
as_sf(x, lon = lon, lat = lat, crs = 4326, ...)

# S3 method for class 'sf'
as_sf(x, crs = NULL, ...)

# S3 method for class 'tmr_geo_sf'
as_sf(x, ...)

# S3 method for class 'tmr_sdm'
as_sf(x, ...)

as_spat_raster(x, ...)

# Default S3 method
as_spat_raster(x, ...)

# S3 method for class 'SpatRaster'
as_spat_raster(x, crs = NULL, ...)

# S3 method for class 'data.frame'
as_spat_raster(x, lon = lon, lat = lat, value = NULL, crs = "EPSG:4326", ...)

# S3 method for class 'tmr_sdm'
as_spat_raster(x, ...)
```

## Arguments

- x:

  A data frame with coordinates, an `sf` object, a SpatRaster, a
  `tmr_sdm` prediction tibble, or another supported spatial result.

- ...:

  Passed to
  [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md)
  or ignored.

- lon, lat:

  Coordinate columns when `x` is a data frame.

- crs:

  Target CRS (default EPSG:4326).

- value:

  Column to place in a single-layer SpatRaster when converting a point
  table with a numeric attribute (optional).

## Value

`as_sf()` returns an `sf` object (subclass `tmr_geo_sf` when built from
coordinates). `as_spat_raster()` returns a
[`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
with a CRS.

## Examples

``` r
sites <- geo_example_sites()
sites <- sites[!is.na(sites$lon), ]
pts <- as_sf(sites)
inherits(pts, "sf")
#> [1] TRUE
sf::st_crs(pts)$epsg
#> [1] 4326
# Optional: same sites in tmap (skipped when tmap is not installed)
# tmap::tm_shape(as_sf(sites)) + tmap::tm_dots(col = "elevation")
# Optional: leaflet (skipped when leaflet is not installed)
# leaflet::leaflet(as_sf(sites)) |>
#   leaflet::addTiles() |>
#   leaflet::addCircleMarkers()
```
