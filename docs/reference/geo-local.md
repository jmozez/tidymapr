# Local spatial statistics: hotspots and LISA clusters

Per-site statistics that say *where* values cluster, adding columns to
`data`:

- `geo_hotspot()`: the Getis-Ord \\G_i^\*\\ statistic (Getis and Ord
  1992; Ord and Getis 1995) as a z-score, its two-sided p-value and a
  class (`"hot"`, `"cold"` or `"not significant"`). The site itself is
  in its own neighbourhood, with binary weights.

- `geo_lisa()`: local Moran's \\I_i\\ (Anselin 1995) with row-
  standardised weights, its expectation, variance, z-score and p-value
  under conditional randomisation (Sokal, Oden and Thomson 1998), and
  the cluster type (`"High-High"`, `"Low-Low"`, `"High-Low"`,
  `"Low-High"` or `"not significant"`). With `nperm > 0` the p-value
  comes from conditional permutation instead.

Neighbours are the `k` nearest sites (default) or all sites within
`dist` metres (great-circle). Values equal
[`spdep::localG()`](https://rdrr.io/pkg/spdep/man/localG.html) and
[`spdep::localmoran()`](https://rdrr.io/pkg/spdep/man/localmoran.html)
for the same neighbours.

Many sites are tested at once, so consider adjusting `p_value` (for
example `p.adjust(p_value, "fdr")`) before reading individual sites.

## Usage

``` r
geo_hotspot(
  data,
  value,
  lon = lon,
  lat = lat,
  k = 5,
  dist = NULL,
  alpha = 0.05
)

geo_lisa(
  data,
  value,
  lon = lon,
  lat = lat,
  k = 5,
  dist = NULL,
  alpha = 0.05,
  nperm = 0,
  seed = NULL
)
```

## Arguments

- data:

  A data frame of sites with coordinates and a value column, or an `sf`
  table (its point coordinates are used).

- value:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Numeric column to test.

- lon, lat:

  Longitude and latitude columns in degrees (ignored for `sf` input),
  giving great-circle distances in metres. For projected coordinates
  pass an `sf` table with its CRS: distances are then straight-line
  distances in the CRS units.

- k:

  Number of nearest neighbours (used when `dist` is `NULL`).

- dist:

  Distance band in metres; overrides `k`.

- alpha:

  Significance level for the class columns.

- nperm:

  `geo_lisa()` only: number of conditional permutations for the p-value;
  `0` (default) uses the analytical randomisation variance.

- seed:

  Optional RNG seed for permutations.

## Value

`data` with columns `gi_star`, `p_value` and `hotspot`
(`geo_hotspot()`), or `lisa`, `lisa_expected`, `lisa_variance`,
`lisa_z`, `p_value` and `cluster` (`geo_lisa()`). Rows with a missing
value or coordinate get `NA`. The neighbour definition is in attribute
`"neighbours"`.

## References

Anselin, L. (1995). Local indicators of spatial association – LISA.
*Geographical Analysis*, 27, 93-115.
[doi:10.1111/j.1538-4632.1995.tb00338.x](https://doi.org/10.1111/j.1538-4632.1995.tb00338.x)

Getis, A. and Ord, J. K. (1992). The analysis of spatial association by
use of distance statistics. *Geographical Analysis*, 24, 189-206.
[doi:10.1111/j.1538-4632.1992.tb00261.x](https://doi.org/10.1111/j.1538-4632.1992.tb00261.x)

Sokal, R. R., Oden, N. L. and Thomson, B. A. (1998). Local spatial
autocorrelation in a biological model. *Geographical Analysis*, 30,
331-354.
[doi:10.1111/j.1538-4632.1998.tb00406.x](https://doi.org/10.1111/j.1538-4632.1998.tb00406.x)

Ord, J. K. and Getis, A. (1995). Local spatial autocorrelation
statistics: distributional issues and an application. *Geographical
Analysis*, 27, 286-306.
[doi:10.1111/j.1538-4632.1995.tb00912.x](https://doi.org/10.1111/j.1538-4632.1995.tb00912.x)

## Examples

``` r
# The 16 real Mt Wilhelm ant transects (Mottl, Moses and Klimes 2023)
geo_hotspot(png_ants_sites, elevation, k = 3)
#> # A tibble: 16 × 10
#>    site   transect elevation_band elevation   lon   lat baits gi_star p_value
#>    <chr>     <int>          <int>     <int> <dbl> <dbl> <int>   <dbl>   <dbl>
#>  1 MW0200        1            200       216  145. -5.74    60 -2.49   0.0127 
#>  2 MW0200        2            200       249  145. -5.74    60 -2.49   0.0127 
#>  3 MW0700        1            700       716  145. -5.73    60 -2.01   0.0441 
#>  4 MW0700        2            700       774  145. -5.73    60 -2.01   0.0441 
#>  5 MW1200        1           1200      1166  145. -5.72    60 -2.01   0.0441 
#>  6 MW1200        2           1200      1089  145. -5.72    60 -2.01   0.0441 
#>  7 MW1700        1           1700      1638  145. -5.76    60 -1.44   0.150  
#>  8 MW1700        2           1700      1840  145. -5.76    60 -1.44   0.150  
#>  9 MW2200        1           2200      2398  145. -5.76    60  0.535  0.592  
#> 10 MW2200        2           2200      2339  145. -5.76    60  0.0774 0.938  
#> 11 MW2700        1           2700      2752  145. -5.81    60  0.962  0.336  
#> 12 MW2700        2           2700      2617  145. -5.81    60  0.962  0.336  
#> 13 MW3200        1           3200      3404  145. -5.80    60  2.97   0.00296
#> 14 MW3200        2           3200      3259  145. -5.81    60  2.97   0.00296
#> 15 MW3700        1           3700      3825  145. -5.79    60  2.97   0.00296
#> 16 MW3700        2           3700      3916  145. -5.78    60  2.97   0.00296
#> # ℹ 1 more variable: hotspot <fct>
geo_lisa(png_ants_sites, elevation, k = 3)
#> # A tibble: 16 × 13
#>    site   transect elevation_band elevation   lon   lat baits    lisa
#>    <chr>     <int>          <int>     <int> <dbl> <dbl> <int>   <dbl>
#>  1 MW0200        1            200       216  145. -5.74    60  1.48  
#>  2 MW0200        2            200       249  145. -5.74    60  1.47  
#>  3 MW0700        1            700       716  145. -5.73    60  0.910 
#>  4 MW0700        2            700       774  145. -5.73    60  0.886 
#>  5 MW1200        1           1200      1166  145. -5.72    60  0.683 
#>  6 MW1200        2           1200      1089  145. -5.72    60  0.728 
#>  7 MW1700        1           1700      1638  145. -5.76    60  0.236 
#>  8 MW1700        2           1700      1840  145. -5.76    60  0.117 
#>  9 MW2200        1           2200      2398  145. -5.76    60  0.0683
#> 10 MW2200        2           2200      2339  145. -5.76    60 -0.0123
#> 11 MW2700        1           2700      2752  145. -5.81    60  0.227 
#> 12 MW2700        2           2700      2617  145. -5.81    60  0.205 
#> 13 MW3200        1           3200      3404  145. -5.80    60  1.61  
#> 14 MW3200        2           3200      3259  145. -5.81    60  1.49  
#> 15 MW3700        1           3700      3825  145. -5.79    60  1.92  
#> 16 MW3700        2           3700      3916  145. -5.78    60  1.98  
#> # ℹ 5 more variables: lisa_expected <dbl>, lisa_variance <dbl>, lisa_z <dbl>,
#> #   p_value <dbl>, cluster <fct>
```
