# Geometric mid-domain null for elevational richness

Randomises species elevational ranges within a hard domain while keeping
each range size fixed (Colwell and Lees 2000), then recomputes richness
per elevation band. Compare the observed band richness to the null
envelope when testing mid-domain effects on tropical mountains.

## Usage

``` r
geo_middomain(
  data,
  species = species,
  elevation = elevation,
  bands = 10,
  nperm = 999,
  seed = NULL
)
```

## Arguments

- data:

  A data frame with species occurrences and elevation.

- species, elevation:

  Column selections.

- bands:

  Number of elevation bands, or a numeric vector of breaks.

- nperm:

  Number of null permutations.

- seed:

  Optional RNG seed.

## Value

A tibble (`tmr_geo_middomain`) with band midpoints, observed richness,
null mean, and 2.5% / 97.5% null quantiles. Attribute `ranges` holds the
observed species range table.

## References

Colwell, R. K. and Lees, D. C. (2000). The mid-domain effect: geometric
constraints on the geography of species richness. *Trends in Ecology and
Evolution*, 15, 70-76.
[doi:10.1016/s0169-5347(99)01767-x](https://doi.org/10.1016/s0169-5347%2899%2901767-x)

## Examples

``` r
set.seed(1)
occ <- expand.grid(
  species = paste0("sp", 1:20),
  elevation = seq(200, 3200, by = 200),
  stringsAsFactors = FALSE
)
# Each species occupies a contiguous elevational range
occ <- dplyr::filter(
  occ,
  elevation >= 200 + (as.integer(factor(species)) - 1) * 50,
  elevation <= 1200 + (as.integer(factor(species)) - 1) * 80
)
geo_middomain(occ, nperm = 49)
#> # A tibble: 10 × 8
#>     band elevation elev_min elev_max richness null_mean null_lower null_upper
#>    <int>     <dbl>    <dbl>    <dbl>    <dbl>     <dbl>      <dbl>      <dbl>
#>  1     1       320      200      440        1      2           0          5.8
#>  2     2       560      440      680        5      5.47        1.2       10  
#>  3     3       800      680      920       13      9.98        7         13.8
#>  4     4      1040      920     1160       17     13.3        10         16.8
#>  5     5      1280     1160     1400       17     16.2        13.2       19  
#>  6     6      1520     1400     1640       15     16.2        13         18.8
#>  7     7      1760     1640     1880       12     13.6         9.2       16.8
#>  8     8      2000     1880     2120       10      9.63        6         12  
#>  9     9      2240     2120     2360        5      5.98        3          9.8
#> 10    10      2480     2360     2600        2      2.10        0          4.8
```
