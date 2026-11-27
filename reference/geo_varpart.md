# Variation partitioning between environment and space

Separates the variation in species composition explained by measured
environmental variables from that explained by spatial structure, as in
the spatial variation partitioning of CANOCO and Borcard et al. (2018):

1.  Spatial predictors are distance-based Moran's eigenvector maps
    ([`geo_mem()`](https://tidymapr.in4metrix.dev/reference/geo_mem.md))
    of the site coordinates.

2.  MEMs are kept only if they explain composition significantly as a
    set, and then chosen by forward selection with the double stopping
    criterion (Blanchet et al. 2008), so space is not over-fitted.

3.  The variation is partitioned
    ([`vegan::varpart()`](https://vegandevs.github.io/vegan/reference/varpart.html))
    into the fraction explained by environment alone `[a]`, shared by
    environment and space `[b]`, explained by space alone `[c]`, and
    unexplained, each as an adjusted \\R^2\\. The fractions that can be
    tested (`[a]`, `[c]` and the two sets) are tested by permutation in
    partial redundancy analyses.

Read `[a]` as the effect of the measured environment free of spatial
structure; `[c]` as spatial structure not explained by the measured
environment (unmeasured variables, dispersal or biotic processes); `[b]`
as spatially structured environment, which cannot be attributed to
either alone. Shared fractions are not tested and can be negative when
the two sets suppress each other.

## Usage

``` r
geo_varpart(
  data,
  site = site,
  species = species,
  abundance = NULL,
  env,
  env_vars,
  lon = "lon",
  lat = "lat",
  method = c("euclidean", "haversine"),
  transform = "hellinger",
  alpha = 0.05,
  permutations = 999
)
```

## Arguments

- data:

  Long community data: one row per site and species.

- site, species, abundance:

  Columns of `data`.

- env:

  A data frame with one row per site: the site column, the coordinates
  and the environmental variables.

- env_vars:

  Names of the environmental variables in `env`.

- lon, lat:

  Names of the coordinate columns in `env`.

- method:

  Distance for the MEMs: `"euclidean"` for projected or local
  coordinates, `"haversine"` for longitude and latitude.

- transform:

  Transformation of the community matrix
  ([`vegan::decostand()`](https://vegandevs.github.io/vegan/reference/decostand.html)
  method); `"hellinger"` by default.

- alpha:

  Significance level for keeping and selecting MEMs.

- permutations:

  Number of permutations.

## Value

A list of class `tmr_geo_varpart`: `fractions` (a tibble of fraction,
meaning, adjusted R2, statistic and p-value), `mems` (the selected MEMs)
and `fit` (the `varpart` object).

## References

Blanchet, F. G., Legendre, P. and Borcard, D. (2008). Forward selection
of explanatory variables. *Ecology*, 89, 2623-2632.
[doi:10.1890/07-0986.1](https://doi.org/10.1890/07-0986.1)

Borcard, D., Gillet, F. and Legendre, P. (2018). *Numerical Ecology with
R*, second edition. Springer. Chapter 7.

Peres-Neto, P. R., Legendre, P., Dray, S. and Borcard, D. (2006).
Variation partitioning of species data matrices: estimation and
comparison of fractions. *Ecology*, 87, 2614-2625.

## Examples

``` r
data("mite", "mite.env", "mite.xy", package = "vegan")
long <- data.frame(
  site = rep(rownames(mite), ncol(mite)),
  species = rep(colnames(mite), each = nrow(mite)),
  n = unlist(mite)
)
env <- cbind(site = rownames(mite), mite.xy, mite.env)
geo_varpart(long, abundance = n, env = env,
  env_vars = c("SubsDens", "WatrCont"), lon = "x", lat = "y",
  permutations = 199)
#> Variation partitioning: environment and space
#> 10 MEMs selected: MEM2, MEM3, MEM8, MEM1, MEM6, MEM4, MEM9, MEM16, MEM7, and
#> MEM20
#> # A tibble: 6 × 5
#>   fraction             meaning                          adj_r2 statistic p.value
#>   <chr>                <chr>                             <dbl>     <dbl>   <dbl>
#> 1 [a+b] environment    all variation the measured envi… 0.307      16.3    0.005
#> 2 [b+c] space          all variation the selected MEMs… 0.442       6.46   0.005
#> 3 [a] environment only environment free of spatial str… 0.0590      4.49   0.005
#> 4 [b] shared           spatially structured environmen… 0.194      NA     NA    
#> 5 [c] space only       spatial structure not explained… 0.248       3.61   0.005
#> 6 [d] unexplained      residual variation               0.499      NA     NA    
```
