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

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Columns for site, species and counts (`abundance = NULL` counts rows).

- sites:

  Site locations: an `sf` point table, or a data frame with
  longitude/latitude (or x/y) columns, with a column named like `site`
  in `data`.

- lon, lat:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
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
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
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
#> min values  :  93.598113,  84.518706, 102.580416, 30.007096, 24.404414, 36.896021, ...
#> max values  : 110.803534, 100.638584, 121.995188, 57.065617, 47.030838, 69.516398, ...
attr(surf, "sites")
#> # A tibble: 150 × 11
#>    plot      q     m method   coverage diversity    se lower upper      x      y
#>    <chr> <dbl> <dbl> <chr>       <dbl>     <dbl> <dbl> <dbl> <dbl>  <dbl>  <dbl>
#>  1 P10       0  583. extrapo…    0.940     101.   4.39  92.0 109.  6.26e5 1.01e6
#>  2 P10       1  583. extrapo…    0.940      50.2  2.51  45.3  55.1 6.26e5 1.01e6
#>  3 P10       2  583. extrapo…    0.940      30.1  2.15  25.8  34.3 6.26e5 1.01e6
#>  4 P28       0  483. extrapo…    0.940      91.7  3.69  84.4  98.9 6.26e5 1.01e6
#>  5 P28       1  483. extrapo…    0.940      41.6  2.30  37.1  46.1 6.26e5 1.01e6
#>  6 P28       2  483. extrapo…    0.940      20.2  1.67  16.9  23.4 6.26e5 1.01e6
#>  7 P32       0  451. rarefac…    0.940      87.5  3.75  80.2  94.9 6.26e5 1.01e6
#>  8 P32       1  451. rarefac…    0.940      43.9  2.10  39.8  48.1 6.26e5 1.01e6
#>  9 P32       2  451. rarefac…    0.940      23.0  1.94  19.2  26.8 6.26e5 1.01e6
#> 10 P34       0  567. extrapo…    0.940     100.   5.15  90.0 110.  6.26e5 1.01e6
#> # ℹ 140 more rows
```
