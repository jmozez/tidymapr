# Map diversity as a continuous surface, with its uncertainty

`geo_diversity_surface()` turns a community table (sites x species
counts) into continuous maps of Hill-number diversity:

1.  For every site it estimates diversity of order `q` (0 = richness, 1
    = exponential Shannon, 2 = inverse Simpson) at a **common sample
    coverage** with
    [`tidydiversity::div_standardise()`](https://tidydiversity.in4metrix.dev/reference/div_standardise.html)
    (Chao and Jost 2012), so sites sampled with different effort are
    compared fairly. The bootstrap standard error of each estimate is
    kept.

2.  It interpolates each `q` by **ordinary kriging with measurement
    error** (Cressie 1993): each site's estimation variance is added to
    the kriging system, so poorly sampled, uncertain sites count for
    less and the map shows the underlying diversity surface rather than
    sampling noise. The variogram nugget is filtered the same way, so
    the surface is smooth through the sites. Kriging runs on the log
    scale (diversity is positive and right-skewed) in C++ on several
    cores.

3.  It returns, for each `q`, the predicted diversity and a 95%
    interval, whose width combines spatial uncertainty (distance from
    sampled sites) and estimation uncertainty (how well each site was
    sampled).

The variogram of each `q` is fitted with **gstat** unless you give one.
Coverage-based standardisation, Hill numbers and kriging with known
measurement error each exist on their own; this function links them so a
diversity map carries an honest uncertainty map.

## Usage

``` r
geo_diversity_surface(
  data,
  site = site,
  species = species,
  abundance = NULL,
  sites,
  lon = lon,
  lat = lat,
  crs = 4326,
  q = c(0, 1, 2),
  coverage = NULL,
  grid = 100,
  model = c("Exp", "Sph", "Gau"),
  measurement_error = TRUE,
  nboot = 50,
  level = 0.95
)
```

## Arguments

- data:

  Long community table: one row per species per site.

- site, species, abundance:

  \<[`data-masking`](https://dplyr.tidyverse.org/reference/dplyr_data_masking.html)\>
  Columns for site, species and counts (`abundance = NULL` counts rows).

- sites:

  Site locations: an `sf` point table, or a data frame with
  longitude/latitude (or x/y) columns, with a column named like `site`
  in `data`.

- lon, lat:

  \<[`data-masking`](https://dplyr.tidyverse.org/reference/dplyr_data_masking.html)\>
  Coordinate columns when `sites` is not `sf`.

- crs:

  CRS of `lon`/`lat` when `sites` is not `sf` (default WGS 84).

- q:

  Orders of diversity.

- coverage:

  Sample coverage to standardise to. `NULL` uses the tidydiversity
  default (the highest coverage reachable by all sites without
  extrapolating beyond twice the smallest sample).

- grid:

  Where to predict: a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  template, or the number of cells along the longer side of the sites'
  extent (default 100).

- model:

  Variogram model: `"Exp"`, `"Sph"` or `"Gau"`.

- measurement_error:

  Use each site's estimation variance in the kriging (recommended)?
  `FALSE` gives ordinary kriging.

- nboot:

  Bootstrap replicates for the site standard errors.

- level:

  Width of the prediction interval.

## Value

A `SpatRaster` with three layers per `q`: `q0` (predicted diversity, the
back-transformed log-scale prediction), `q0_lower` and `q0_upper`
(interval bounds), and so on. Attribute `"sites"` holds the per-site
estimates, standard errors and coordinates; `"variograms"` holds the
fitted variogram of each `q`.

## References

Chao, A. and Jost, L. (2012). Coverage-based rarefaction and
extrapolation. *Ecology*, 93, 2533-2547.
[doi:10.1890/11-1952.1](https://doi.org/10.1890/11-1952.1)

Cressie, N. (1993). *Statistics for Spatial Data*, revised edition.
Wiley.
[doi:10.1002/9781119115151](https://doi.org/10.1002/9781119115151)

## See also

[`plot_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/plot_diversity_surface.md),
[`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md)

## Examples

``` r
# Trees in 50 one-hectare plots of the Barro Colorado Island forest
# dynamics plot, Panama (Condit et al. 2002; shipped with vegan)
e <- new.env()
utils::data(BCI, BCI.env, package = "vegan", envir = e)
trees <- tibble::tibble(
  plot = rep(sprintf("P%02d", 1:50), ncol(e$BCI)),
  species = rep(colnames(e$BCI), each = 50),
  n = as.vector(as.matrix(e$BCI))
)
trees <- trees[trees$n > 0, ]
plots <- tibble::tibble(
  plot = sprintf("P%02d", 1:50),
  x = e$BCI.env$UTM.EW, y = e$BCI.env$UTM.NS
)
set.seed(1)
surf <- geo_diversity_surface(trees, plot, species, n,
  sites = plots, lon = x, lat = y, crs = 32617, grid = 40, nboot = 20
)
surf
#> class       : SpatRaster
#> size        : 19, 41, 9  (nrow, ncol, nlyr)
#> resolution  : 22.5, 22.5  (x, y)
#> extent      : 625742.7, 626665.2, 1011558, 1011985  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / UTM zone 17N (EPSG:32617)
#> source(s)   : memory
#> names       :         q0,   q0_lower,   q0_upper,        q1,  q1_lower,  q1_upper, ...
#> min values  :  93.636048,  84.501117, 102.623939, 31.198013, 25.237274, 38.566607, ...
#> max values  : 111.534532, 101.429164, 122.646696, 57.048135, 47.014816, 69.524377, ...
attr(surf, "sites")
#> # A tibble: 150 × 12
#>    plot      q     m method   target coverage diversity    se lower upper      x
#>    <chr> <dbl> <dbl> <chr>     <dbl>    <dbl>     <dbl> <dbl> <dbl> <dbl>  <dbl>
#>  1 P01       0  503. extrapo…  0.940    0.940      96.5  3.96  88.8 104.  6.26e5
#>  2 P01       1  503. extrapo…  0.940    0.940      56.6  2.50  51.7  61.4 6.26e5
#>  3 P01       2  503. extrapo…  0.940    0.940      39.8  2.24  35.4  44.2 6.26e5
#>  4 P02       0  524. extrapo…  0.940    0.940      89.8  4.04  81.9  97.8 6.26e5
#>  5 P02       1  524. extrapo…  0.940    0.940      48.1  2.07  44.1  52.2 6.26e5
#>  6 P02       2  524. extrapo…  0.940    0.940      32.0  1.83  28.4  35.6 6.26e5
#>  7 P03       0  668. extrapo…  0.940    0.940     104.   6.09  92.3 116.  6.26e5
#>  8 P03       1  668. extrapo…  0.940    0.940      47.7  3.36  41.2  54.3 6.26e5
#>  9 P03       2  668. extrapo…  0.940    0.940      28.8  2.24  24.4  33.2 6.26e5
#> 10 P04       0  465. rarefac…  0.940    0.940      91.6  3.50  84.7  98.4 6.26e5
#> # ℹ 140 more rows
#> # ℹ 1 more variable: y <dbl>
```
