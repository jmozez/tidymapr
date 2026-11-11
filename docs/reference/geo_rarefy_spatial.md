# Spatially constrained rarefaction

Accumulates species richness by adding samples in order of increasing
distance from a seed sample (spatially contiguous rarefaction), and
optionally compares that curve to random-order accumulation. Coverage
standardisation
([`tidydiversity::div_rarefy()`](https://tidydiversity.in4metrix.dev/reference/div_rarefy.html),
[`tidydiversity::div_standardise()`](https://tidydiversity.in4metrix.dev/reference/div_standardise.html))
remains the default for effort bias; use this verb when you need an
aggregation signal along a transect or plot (Chiu 2023; McGlinn et al.
2025).

## Usage

``` r
geo_rarefy_spatial(
  data,
  lon = lon,
  lat = lat,
  site = site,
  species = species,
  abundance = NULL,
  seed = NULL,
  nperm = 0,
  .by = NULL
)
```

## Arguments

- data:

  Long community table with coordinates and species.

- lon, lat, site, species:

  Coordinate, site and species columns.

- abundance:

  Optional abundance column; presence is used when `NULL`.

- seed:

  Site id or row index of the starting sample. When `NULL`, every site
  is used as a seed and curves are averaged.

- nperm:

  Number of random-order permutations for the null curve.

- .by:

  Optional grouping columns.

## Value

A tibble (`tmr_geo_rarefy`) with `n_sites`, `richness_spatial`, and when
`nperm > 0` also `richness_random` (mean) and `richness_random_sd`.

## Examples

``` r
set.seed(1)
pts <- expand.grid(x = 1:4, y = 1:3)
pts$site <- paste0("s", seq_len(nrow(pts)))
com <- expand.grid(site = pts$site, species = paste0("sp", 1:5),
                   stringsAsFactors = FALSE)
com$abundance <- rpois(nrow(com), 1)
com <- dplyr::left_join(com, pts, by = "site")
geo_rarefy_spatial(com, lon = x, lat = y, nperm = 19)
#> # A tibble: 12 × 4
#>    n_sites richness_spatial richness_random richness_random_sd
#>      <int>            <dbl>           <dbl>              <dbl>
#>  1       1                5               5                  0
#>  2       2                5               5                  0
#>  3       3                5               5                  0
#>  4       4                5               5                  0
#>  5       5                5               5                  0
#>  6       6                5               5                  0
#>  7       7                5               5                  0
#>  8       8                5               5                  0
#>  9       9                5               5                  0
#> 10      10                5               5                  0
#> 11      11                5               5                  0
#> 12      12                5               5                  0
```
