# Simulated DEM for testing local metre stem maps

Builds a small elevation raster in the same 0-100 m local coordinates as
[`geo_example_stems()`](https://tidymapr.in4metrix.dev/reference/geo_example_stems.md),
for testing topographic backdrops in
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md).
The surface is a formula, not a survey: use a real DEM (for example
[`geo_elevation()`](https://tidymapr.in4metrix.dev/reference/geo_elevation.md))
for figures.

## Usage

``` r
geo_example_dem(res = 2)
```

## Arguments

- res:

  Grid resolution in metres.

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

## Examples

``` r
geo_example_dem()
#> class       : SpatRaster
#> size        : 50, 50, 1  (nrow, ncol, nlyr)
#> resolution  : 2, 2  (x, y)
#> extent      : 0, 100, 0, 100  (xmin, xmax, ymin, ymax)
#> coord. ref. : 
#> source(s)   : memory
#> name        :  elevation
#> min value   : 109.033475
#> max value   : 133.037084
```
