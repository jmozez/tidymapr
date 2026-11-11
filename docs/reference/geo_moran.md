# Moran's I for spatial autocorrelation of diversity

Computes Moran's I for a numeric site attribute (for example a Hill
number or a model residual) using inverse-distance weights among sites.
A permutation p-value is returned. Implemented natively so callers do
not need spdep; when spdep is installed, tests compare the two.

## Usage

``` r
geo_moran(
  data,
  value,
  lon = lon,
  lat = lat,
  site = NULL,
  nperm = 999,
  correlogram = FALSE,
  bins = 5,
  seed = NULL
)
```

## Arguments

- data:

  A data frame of sites with coordinates and a value column.

- value:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Numeric column to test.

- lon, lat:

  Coordinate columns.

- site:

  Optional site column for labels in the correlogram.

- nperm:

  Number of permutations for the p-value.

- correlogram:

  If `TRUE`, also return a simple distance-bin correlogram.

- bins:

  Number of distance bins for the correlogram.

- seed:

  Optional RNG seed for permutations.

## Value

A tibble (`tmr_geo_moran`) with Moran's I, the expected value under
randomness, the variance under normality, a two-sided permutation
p-value, and optional correlogram rows in attribute `correlogram`.

## References

Moran, P. A. P. (1950). Notes on continuous stochastic phenomena.
*Biometrika*, 37, 17-23.
[doi:10.2307/2332142](https://doi.org/10.2307/2332142)

## Examples

``` r
set.seed(1)
# Positive spatial autocorrelation along a gradient
g <- expand.grid(x = 1:6, y = 1:6)
g$val <- g$x + 0.3 * rnorm(nrow(g))
geo_moran(g, val, lon = x, lat = y, nperm = 199)
#> # A tibble: 1 x 7
#>   statistic expectation variance p.value     n nperm method                     
#>       <dbl>       <dbl>    <dbl>   <dbl> <int> <dbl> <chr>                      
#> 1     0.267     -0.0286 0.000530   0.005    36   199 Moran's I (inverse-distanc~
```
