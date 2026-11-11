# Case study: ants along Mt Wilhelm, from sites to maps

`png_ants` (in tidydiversity) records ground-foraging ants at nutrient
baits at elevations from 200 to 2200 m on Mt Wilhelm, Papua New Guinea,
in the dry and the wet season (Moses et al. 2023,
[doi:10.5281/zenodo.8191946](https://doi.org/10.5281/zenodo.8191946)).
tidydiversity estimates diversity; tidymapr maps it.

``` r
library(tidymapr)
library(tidydiversity)
library(dplyr)
library(ggplot2)
```

## Study sites

[`geo_example_sites()`](https://tidymapr.in4metrix.dev/reference/geo_example_sites.md)
returns the published bait GPS of the survey (`png_ants_sites`; Mottl,
Moses and Klimes 2023,
[doi:10.5281/zenodo.8191946](https://doi.org/10.5281/zenodo.8191946)),
averaged to one point per elevation band.

``` r
sites <- geo_example_sites("wilhelm") |>
  filter(elevation <= 2200)
plot_sites(sites, lon, lat, colour = elevation_band, label = site, basemap = "coast") +
  labs(title = "Ant sampling sites on Mt Wilhelm")
#> Warning: No Natural Earth land data available; install rnaturalearth.
#> ℹ Returning an empty land layer. Pass `coastline` or use a tile basemap.
```

![Study sites along Mt Wilhelm coloured by elevation
band](case-png-wilhelm_files/figure-html/sites-1.png)

## Diversity on a map

``` r
est <- div_estimate(png_ants, q = 0, nboot = 0, .by = season) |>
  left_join(sites[c("site", "lon", "lat")], by = "site")
plot_geo(filter(est, season == "wet"), estimate, lon, lat, label = site, basemap = "coast") +
  labs(title = "Observed richness, wet season", colour = "Species")
#> Warning: No Natural Earth land data available; install rnaturalearth.
#> ℹ Returning an empty land layer. Pass `coastline` or use a tile basemap.
#> Ignoring unknown labels:
#> • colour : "Species"
```

![Observed ant richness on a map, one panel per
season](case-png-wilhelm_files/figure-html/map-1.png)

## Distance decay

[`geo_decay()`](https://tidymapr.in4metrix.dev/reference/geo_decay.md)
computes pairwise dissimilarity with
[`tidydiversity::beta_pair()`](https://rdrr.io/pkg/tidydiversity/man/beta_pair.html)
and joins geographic or elevational distance.

``` r
com <- left_join(png_ants, sites[c("site", "lon", "lat")], by = "site")
decay <- geo_decay(com, lon, lat, .by = season, method = "haversine")
autoplot(decay)
```

![Ant dissimilarity against geographic distance by
season](case-png-wilhelm_files/figure-html/decay-1.png)

``` r
beta_decay_model(decay)
#> # A tibble: 2 × 10
#>   season model     component n_pairs     a       b half_distance pseudo_r2   aic
#>   <chr>  <chr>     <chr>       <int> <dbl>   <dbl>         <dbl>     <dbl> <dbl>
#> 1 dry    exponent… total          10 0.267 1.02e-4         6815.     0.150 -9.29
#> 2 wet    exponent… total          10 0.383 1.41e-4         4910.     0.334 -9.79
#> # ℹ 1 more variable: p.value <dbl>
```

## Spatial autocorrelation

``` r
wet <- filter(est, season == "wet")
geo_moran(wet, estimate, lon, lat, nperm = 199, seed = 1)
#> # A tibble: 1 × 7
#>   statistic expectation variance p.value     n nperm method                     
#>       <dbl>       <dbl>    <dbl>   <dbl> <int> <dbl> <chr>                      
#> 1    -0.236       -0.25   0.0114    0.95     5   199 Moran's I (inverse-distanc…
```

## Save the figure

[`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md)
writes maps at journal sizes:

``` r
p <- plot_sites(sites, lon, lat, colour = elevation_band, label = site)
geo_save(p, "fig1-sites.pdf", width = 170, height = 120, units = "mm")
```
