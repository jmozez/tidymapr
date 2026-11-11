# Pairwise geographic or elevational distances

Great-circle (haversine) or elevational distances between sites, as a
long tibble ready to join with
[`tidydiversity::beta_pair()`](https://rdrr.io/pkg/tidydiversity/man/beta_pair.html)
or to build a
[`geo_decay()`](https://tidymapr.in4metrix.dev/reference/geo_decay.md)
distance-decay table. Elevational distance is the absolute difference in
metres.

## Usage

``` r
geo_distance(
  data,
  lon = lon,
  lat = lat,
  elevation = NULL,
  site = site,
  method = c("haversine", "elevation", "euclidean", "environmental"),
  vars = NULL,
  scale = TRUE,
  metric = c("euclidean", "gower"),
  .by = NULL
)
```

## Arguments

- data:

  A data frame of unique sites (or records constant within site) with
  coordinates and optional elevation.

- lon, lat, elevation, site:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Column selections.

- method:

  `"haversine"` (metres), `"elevation"` (metres), `"euclidean"` on
  lon/lat in degrees, or `"environmental"` for Euclidean or Gower
  distance on numeric covariate columns (for example bioclim layers from
  [`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md)
  /
  [`geo_bioclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)).

- vars:

  Character vector of covariate columns for `method = "environmental"`.
  When `NULL`, every numeric column except coordinates, elevation and
  the site id is used.

- scale:

  Standardise environmental columns to mean 0 and sd 1 before Euclidean
  distance? Ignored for Gower.

- metric:

  `"euclidean"` or `"gower"` for environmental distances.

- .by:

  Optional grouping columns.

## Value

A tibble with `site_1`, `site_2`, `distance` and grouping columns.

## Examples

``` r
sites <- tibble::tibble(
  site = c("a", "b", "c"),
  lon = c(147.0, 147.1, 147.2),
  lat = c(-9.4, -9.5, -9.6),
  elevation = c(200, 700, 1200)
)
geo_distance(sites, lon, lat, method = "haversine")
#> # A tibble: 3 × 3
#>   site_1 site_2 distance
#>   <chr>  <chr>     <dbl>
#> 1 a      b        15619.
#> 2 a      c        31236.
#> 3 b      c        15617.
geo_distance(sites, elevation = elevation, method = "elevation")
#> # A tibble: 3 × 3
#>   site_1 site_2 distance
#>   <chr>  <chr>     <dbl>
#> 1 a      b           500
#> 2 a      c          1000
#> 3 b      c           500
```
