# Aggregate sites or rasters across grains (MAUP helpers)

Rebins point sites into square cells of one or more grain sizes and
recomputes Hill numbers per cell, so users can see how richness patterns
change with grain (Dungan et al. 2002; Wagner and Fortin 2005). Also
aggregates SpatRaster layers with
[`terra::aggregate()`](https://rdrr.io/pkg/terra/man/aggregate.html)
when `raster` is supplied. Recomputing Hill numbers needs the
**tidydiversity** package.

## Usage

``` r
geo_grain(
  data = NULL,
  grains,
  lon = lon,
  lat = lat,
  site = site,
  species = species,
  abundance = NULL,
  q = 0,
  raster = NULL,
  fun = "mean",
  .by = NULL
)
```

## Arguments

- data:

  Long community table with coordinates.

- grains:

  Numeric vector of cell sizes in the same units as the coordinates
  (degrees for lon/lat, metres for local plots).

- lon, lat, site, species, abundance:

  Column selections.

- q:

  Hill-number orders passed to
  [`tidydiversity::div_hill()`](https://tidydiversity.in4metrix.dev/reference/div_hill.html).

- raster:

  Optional `SpatRaster` to aggregate instead of (or as well as) the
  community table.

- fun:

  Raster aggregation function (`"mean"`, `"sum"`, `"modal"`, ...).

- .by:

  Optional grouping columns preserved inside each grain.

## Value

When `data` is supplied, a tibble (`tmr_geo_grain`) with columns
`grain`, `cell`, coordinates of cell centres, and Hill estimates. When
only `raster` is supplied, a named list of SpatRasters.

## Examples

``` r
set.seed(1)
pts <- expand.grid(lon = seq(145, 145.4, by = 0.1),
                   lat = seq(-5.9, -5.5, by = 0.1))
pts$site <- paste0("s", seq_len(nrow(pts)))
com <- expand.grid(site = pts$site, species = paste0("sp", 1:8),
                   stringsAsFactors = FALSE)
com$abundance <- rpois(nrow(com), 2)
com <- dplyr::left_join(com, pts, by = "site")
geo_grain(com, grains = c(0.15, 0.3), q = 0)
#> # A tibble: 20 × 7
#>        q     n diversity grain   lon   lat cell          
#>    <dbl> <int>     <dbl> <dbl> <dbl> <dbl> <chr>         
#>  1     0    18         8  0.15  145. -5.92 144.975_-5.925
#>  2     0    16         7  0.15  145. -5.92 145.125_-5.925
#>  3     0    35         8  0.15  145. -5.92 145.275_-5.925
#>  4     0    17         7  0.15  145. -5.92 145.425_-5.925
#>  5     0    13         7  0.15  145. -5.78 144.975_-5.775
#>  6     0    13         6  0.15  145. -5.78 145.125_-5.775
#>  7     0    28         8  0.15  145. -5.78 145.275_-5.775
#>  8     0    32         8  0.15  145. -5.62 144.975_-5.625
#>  9     0    33         8  0.15  145. -5.62 145.125_-5.625
#> 10     0    67         8  0.15  145. -5.62 145.275_-5.625
#> 11     0    36         8  0.15  145. -5.62 145.425_-5.625
#> 12     0    23         8  0.15  145. -5.48 144.975_-5.475
#> 13     0    12         6  0.15  145. -5.48 145.125_-5.475
#> 14     0    28         8  0.15  145. -5.48 145.275_-5.475
#> 15     0    19         8  0.15  145. -5.48 145.425_-5.475
#> 16     0    19         7  0.15  145. -5.78 145.425_-5.775
#> 17     0    60         8  0.3   145. -5.85 145.05_-5.85  
#> 18     0    99         8  0.3   145. -5.85 145.35_-5.85  
#> 19     0   100         8  0.3   145. -5.55 145.05_-5.55  
#> 20     0   150         8  0.3   145. -5.55 145.35_-5.55  
```
