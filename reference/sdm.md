# Tidy species distribution models (presence-background / presence-absence)

Fits presence-only (presence-background) or presence-absence models with
a tidy interface. Engines: `"glm"` (logistic or cloglog), `"gam"` (mgcv
when installed), and `"maxnet"` (native Maxent-like linear + quadratic
features with ridge-penalised logistic regression; no Java Maxent, no
biomod2 or dismo). Predictors may be columns or a SpatRaster stack from
[`geo_bioclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)
/
[`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md).

## Usage

``` r
sdm_fit(
  data,
  predictors,
  lon = lon,
  lat = lat,
  present = NULL,
  engine = c("glm", "gam", "maxnet"),
  link = c("logit", "cloglog"),
  n_background = 500,
  features = c("linear", "quadratic"),
  lambda = 1e-04,
  seed = NULL
)

sdm_predict(object, newdata = NULL, type = c("response", "link"))

sdm_evaluate(object, newdata = NULL, threshold = NULL)

plot_sdm(x, basemap = "esri", ...)
```

## Arguments

- data:

  Occurrence table with coordinates and optional absence rows (`present`
  column 1/0). When absences are missing, background points are sampled
  from `predictors` or from the bounding box.

- predictors:

  Character vector of predictor columns in `data`, or a `SpatRaster` of
  predictors.

- lon, lat:

  Coordinate columns.

- present:

  Optional presence/absence column (1/0). When `NULL`, every row is
  treated as a presence and background points are added.

- engine:

  `"glm"`, `"gam"`, or `"maxnet"`.

- link:

  `"logit"` or `"cloglog"`.

- n_background:

  Number of background points for presence-only data.

- features:

  Feature types for `"maxnet"`: any of `"linear"`, `"quadratic"`.

- lambda:

  Ridge penalty for `"maxnet"` (larger = more shrinkage).

- seed:

  Optional RNG seed for background sampling.

- object:

  A `tmr_sdm` from `sdm_fit()`.

- newdata:

  Optional data frame of prediction locations. When `NULL` and a
  predictor raster was supplied at fit time, predicts on that raster.

- type:

  `"response"` (probability) or `"link"`.

- threshold:

  Suitability threshold for TSS / sensitivity. When `NULL`, the
  threshold that maximises TSS on the training data is used.

- x:

  A `tmr_sdm`, a prediction tibble from `sdm_predict()`, or a
  suitability SpatRaster.

- basemap:

  Basemap for ggplot maps. See
  [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md).

- ...:

  Passed through to the surface /
  [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md)
  helpers (for example `legend_position`, `scale_bar`, `north_arrow`,
  `subtitle`). Regular prediction grids are drawn as a continuous raster
  surface; sparse tables stay as points.

## Value

An object of class `tmr_sdm` with elements `engine`, `model`,
`predictors`, `coefficients` (tibble), `training` (tibble), `link`, and
`formula`.

## Examples

``` r
set.seed(1)
# Species present only at high bio1
grid <- expand.grid(lon = seq(145, 145.5, length.out = 12),
                    lat = seq(-5.9, -5.5, length.out = 10))
grid$bio1 <- 15 + 10 * (grid$lat - min(grid$lat)) /
  diff(range(grid$lat))
occ <- dplyr::filter(grid, bio1 > 22) |>
  dplyr::slice_sample(n = 25)
fit <- sdm_fit(occ, predictors = "bio1", engine = "glm")
sdm_evaluate(fit)
#> # A tibble: 1 × 8
#>     auc   tss threshold sensitivity specificity     n n_presence n_absence
#>   <dbl> <dbl>     <dbl>       <dbl>       <dbl> <int>      <int>     <int>
#> 1 0.523 0.268    0.0454           1       0.268   525         25       500
```
