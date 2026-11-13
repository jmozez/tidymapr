# Three-dimensional mid-domain null model for marine and other volumes

`geo_mde_3d()` extends
[`geo_mde()`](https://tidymapr.in4metrix.dev/reference/geo_mde.md) to
volumes: the sea, lakes, caves or a forest canopy, where species occupy
a range in depth as well as on the map. The domain is the water column
defined by a bathymetry raster, divided into depth bands; a band exists
in a cell if the sea floor there is deeper than the top of the band.
Each species keeps its observed range size in grid cells x depth bands
(voxels) and is placed at random `nsim` times with the spreading-dye
algorithm, growing into the six face-neighbouring voxels (north, south,
east, west, up and down), so ranges stay contiguous and follow the
coastline and the sea floor.

A species' observed range (`range = "hull"`) is the convex hull of its
records on the map, in every depth band between its shallowest and
deepest record (range-through interpolation in depth), restricted to the
domain; `range = "cells"` uses the occupied voxels only. With one depth
band the model equals
[`geo_mde()`](https://tidymapr.in4metrix.dev/reference/geo_mde.md); on a
single water column it equals the one-dimensional model along depth.

## Usage

``` r
geo_mde_3d(
  data,
  bathymetry,
  breaks,
  depth = depth,
  species = species,
  range = c("hull", "buffer", "cells"),
  buffer = NULL,
  nsim = 199,
  conf = 0.95,
  lon = lon,
  lat = lat
)
```

## Arguments

- data:

  Occurrence records with a depth column: an `sf` object of points or a
  data frame with longitude and latitude.

- bathymetry:

  A `SpatRaster` of sea-floor depth in metres, positive downwards (cells
  that are land or `NA` are outside the domain). Its grid is the grid of
  the model.

- breaks:

  Depth band limits in metres, increasing from 0.

- depth:

  Column with the depth of each record (metres, positive).

- species:

  Column with species names.

- range:

  How each species' range is built from its records: `"hull"` (the
  convex hull), `"buffer"` (all cells within `buffer` metres of a
  record) or `"cells"` (occupied cells only). Hulls suit continuous
  ranges on land; buffers suit species tied to patchy habitat such as
  reefs, coasts or mountain tops, where a hull would span unsuitable
  ground between distant records.

- buffer:

  Buffer distance in metres for `range = "buffer"`; by default twice the
  cell size.

- nsim:

  Number of randomisations.

- conf:

  Width of the simulation interval.

- lon, lat:

  Coordinate columns when `data` is not `sf`.

## Value

A list with `observed`, `expected`, `sd`, `lower`, `upper` and `ses`,
each a `SpatRaster` with one layer per depth band; `profile`, a tibble
with the mean observed and expected richness per water voxel, and its
interval, for every depth band (the vertical richness profile); and
`fit`, as in
[`geo_mde()`](https://tidymapr.in4metrix.dev/reference/geo_mde.md).

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  bathy <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10, ymin = 0, ymax = 10,
    crs = "EPSG:3857", vals = rep(seq(10, 300, length.out = 10), 10))
  set.seed(1)
  recs <- data.frame(x = runif(200, 0, 10), y = runif(200, 0, 10),
    depth = runif(200, 0, 250), species = sample(letters, 200, TRUE))
  recs <- sf::st_as_sf(recs, coords = c("x", "y"), crs = 3857)
  m <- geo_mde_3d(recs, bathy, breaks = c(0, 50, 100, 200, 300), nsim = 19)
  m$profile
}
#> # A tibble: 4 × 8
#>   band        top bottom n_voxels observed expected lower upper
#>   <fct>     <dbl>  <dbl>    <int>    <dbl>    <dbl> <dbl> <dbl>
#> 1 0-50 m        0     50      100     8.01     7.88  4.69  11.4
#> 2 50-100 m     50    100       80     9.71     9.61  6.29  13.2
#> 3 100-200 m   100    200       70    10.7      9.65  6.17  13.1
#> 4 200-300 m   200    300       40     6.42     8.75  5.51  12.3
# }
```
