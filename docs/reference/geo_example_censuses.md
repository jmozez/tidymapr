# Two simulated censuses for testing demography code

Builds a pair of ForestGEO-style tree tables five years apart, with
simulated mortality, recruitment and growth, for testing
[`tidydiversity::stems_demography()`](https://rdrr.io/pkg/tidydiversity/man/stems.html).
Not real census data.

## Usage

``` r
geo_example_censuses(n = 80, seed = 1, time = 5)
```

## Arguments

- n:

  Number of trees in census 1.

- seed:

  RNG seed.

- time:

  Interval in years between censuses.

## Value

A list with `census1` and `census2` tibbles.

## Examples

``` r
cens <- geo_example_censuses()
tidydiversity::stems_demography(cens$census1, cens$census2, time = 5, dbh_unit = "mm")
#> # A tibble: 1 x 12
#>       N     S     D     R mortality_rate recruitment_rate growth_rate growth  
#>   <int> <int> <int> <int>          <dbl>            <dbl>       <dbl> <chr>   
#> 1    80    74     6     8         0.0156           0.0205       0.460 absolute
#> # i 4 more variables: n_growth <int>, time <dbl>, mindbh <dbl>, dbh_unit <chr>
```
