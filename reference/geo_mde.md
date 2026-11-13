# Two-dimensional mid-domain null model of species richness

`geo_mde()` asks whether a map of species richness could arise from the
shape of the land alone. In a bounded domain (an island, a country, a
mountain range), ranges placed at random overlap most in the interior,
so richness peaks there with no environmental cause: the mid-domain
effect in two dimensions (Colwell and Lees 2000; Jetz and Rahbek 2001).

Each species keeps its observed range size (in grid cells) and its range
is placed at random in the domain `nsim` times with the spreading-dye
algorithm: a random seed cell, then growth into randomly chosen
neighbouring cells, so ranges stay contiguous and follow the real
coastline. Unlike RangeModel and rangemodelR, which work along one
dimension or on regular grids, the domain here is any polygon, on an
equal-area grid.

Ranges are built from occurrence points: `range = "hull"` (default)
takes the cells inside the convex hull of each species' records within
the domain, a common proxy for the extent of occurrence;
`range = "cells"` uses the occupied cells only.

## Usage

``` r
geo_mde(
  data,
  domain,
  res,
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

  Occurrence records: an `sf` object of points, or a data frame with
  longitude and latitude columns.

- domain:

  An `sf` polygon (or multipolygon) of the bounded domain.

- res:

  Grid cell size in metres.

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

A `SpatRaster` with layers `observed` (richness of the observed ranges),
`expected` (mean of the null model), `sd`, `lower`, `upper` (simulation
interval) and `ses` (standardised effect size, (observed - expected) /
sd: positive where there are more species than geometry predicts).
Attribute `fit` holds `n_species`, `n_cells`, `r2` (variance in observed
richness explained by the null model) and `truncated` (ranges that could
not grow to full size because the piece of domain they started in was
too small).

## References

Colwell, R. K. and Lees, D. C. (2000). The mid-domain effect: geometric
constraints on the geography of species richness. Trends in Ecology &
Evolution, 15, 70-76.
[doi:10.1016/S0169-5347(99)01767-X](https://doi.org/10.1016/S0169-5347%2899%2901767-X)

Jetz, W. and Rahbek, C. (2001). Geometric constraints explain much of
the species richness pattern in African birds. Proceedings of the
National Academy of Sciences, 98, 5661-5666.
[doi:10.1073/pnas.091100998](https://doi.org/10.1073/pnas.091100998)

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
  set.seed(1)
  pts <- sf::st_sample(sf::st_union(lux), 300)
  occ <- sf::st_sf(species = sample(paste0("sp", 1:20), 300, TRUE), geometry = pts)
  m <- geo_mde(occ, lux, res = 5000, nsim = 49)
  attr(m, "fit")
}
#> # A tibble: 1 × 4
#>   n_species n_cells    r2 truncated
#>       <int>   <int> <dbl>     <int>
#> 1        20     100 0.656         0
# }
```
