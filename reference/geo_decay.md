# Distance decay with geographic, elevational or environmental distance

Computes pairwise beta diversity with
[`tidydiversity::beta_pair()`](https://tidydiversity.in4metrix.dev/reference/beta_pair.html)
and joins distances from
[`geo_distance()`](https://tidymapr.in4metrix.dev/reference/geo_distance.md)
(great-circle, elevational or environmental), returning a
`td_beta_decay` object (see
[`tidydiversity::beta_decay()`](https://tidydiversity.in4metrix.dev/reference/beta_decay.html))
for
[`tidydiversity::beta_decay_model()`](https://tidydiversity.in4metrix.dev/reference/beta_decay_model.html)
and
[`ggplot2::autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html).

## Usage

``` r
geo_decay(
  data,
  lon = lon,
  lat = lat,
  elevation = NULL,
  site = site,
  species = species,
  abundance = NULL,
  index = c("sorensen", "jaccard", "bray"),
  method = c("haversine", "elevation", "euclidean", "environmental"),
  vars = NULL,
  scale = TRUE,
  metric = c("euclidean", "gower"),
  .by = NULL
)
```

## Arguments

- data:

  A long community table with coordinate columns.

- lon, lat, elevation:

  Coordinate and elevation columns of `data`.

- site, species, abundance:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Site, species and (optional) abundance columns of `data`.

- index:

  Dissimilarity family passed to
  [`tidydiversity::beta_pair()`](https://tidydiversity.in4metrix.dev/reference/beta_pair.html):
  `"sorensen"`, `"jaccard"` or `"bray"`.

- method, vars, scale, metric:

  Passed to
  [`geo_distance()`](https://tidymapr.in4metrix.dev/reference/geo_distance.md).

- .by:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Optional grouping columns.

## Value

A `td_beta_decay` tibble.

## Details

Needs the **tidydiversity** package.

## Examples

``` r
png_ants <- tidydiversity::png_ants
# Published bait GPS for the Mt Wilhelm sites
sites <- geo_example_sites()
com <- dplyr::left_join(png_ants, sites[c("site", "lon", "lat")],
  by = "site"
)
decay <- geo_decay(com, lon, lat, .by = season, method = "haversine")
head(decay)
#> # A tibble: 6 × 7
#>   season site_1 site_2 turnover nestedness total distance
#>   <chr>  <chr>  <chr>     <dbl>      <dbl> <dbl>    <dbl>
#> 1 dry    MW0200 MW0700    0.667     0.0108 0.677    8802.
#> 2 dry    MW0200 MW1200    0.769     0.0239 0.793    7212.
#> 3 dry    MW0200 MW1700    0.8       0.105  0.905   10931.
#> 4 dry    MW0200 MW2200    1         0      1       17211.
#> 5 dry    MW0700 MW1200    0.615     0.0275 0.643    1978.
#> 6 dry    MW0700 MW1700    0.8       0.1    0.9      3272.
```
