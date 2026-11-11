# Ensembles of species distribution models

`sdm_ensemble()` fits several algorithms to the same presence-background
(or presence-absence) data, scores each with spatial block
cross-validation, and combines them into one weighted ensemble, in the
spirit of biomod2 (Thuiller et al. 2009) but without its dependencies
and with fixes for common weaknesses:

- **Spatial cross-validation by default.** Random folds put test points
  next to training points, so spatially autocorrelated data look better
  than they are (Roberts et al. 2017). Folds here are whole spatial
  blocks.

- **Comparable algorithms.** Presence-background data are fitted with
  equal total weight for presences and background (Barbet-Massin et
  al. 2012) for GLM and GAM, Maxent uses its own infinitely-weighted
  formulation, and the random forest grows each tree on a balanced
  bootstrap (down-sampling; Valavi et al. 2021), so all four answer the
  same question on the same 0-1 scale.

- **Weights from transferable skill.** Each algorithm is weighted by its
  cross-validated true skill statistic above `min_tss`; algorithms below
  it are left out rather than allowed to dilute the ensemble.

- **Standardised predictors.** Every algorithm sees predictors rescaled
  to 0-1 on the training range, so results do not depend on units or on
  where zero lies.

- **Agreement as uncertainty.** Predictions give the weighted mean and
  the weighted standard deviation across algorithms.

The random forest and Maxent are written in C++ and run on several
cores.

## Usage

``` r
sdm_ensemble(
  presence,
  data,
  coords = NULL,
  algorithms = c("maxent", "glm", "gam", "rf"),
  folds = 5,
  block_size = NULL,
  min_tss = 0.3,
  ntree = 500,
  mtry = NULL,
  seed = 1,
  ...
)

# S3 method for class 'tmr_sdm_ensemble'
predict(object, newdata, what = c("mean", "sd", "all"), ...)
```

## Arguments

- presence:

  0/1 vector: 1 for presences, 0 for background or absence.

- data:

  Data frame of predictors (numeric, or factors for Maxent and the
  random forest).

- coords:

  Optional two-column matrix or data frame of x and y coordinates for
  spatial blocks. Without it, folds are random.

- algorithms:

  Any of `"maxent"`, `"glm"`, `"gam"`, `"rf"`.

- folds:

  Number of cross-validation folds.

- block_size:

  Side of the square spatial blocks, in the units of `coords`. By
  default a tenth of the larger side of the extent.

- min_tss:

  Algorithms with a cross-validated TSS below this get no weight.

- ntree, mtry:

  Random forest size and variables tried at each split (default: square
  root of the number of predictors).

- seed:

  Random seed for the folds and the forest.

- ...:

  Passed on to
  [`sdm_maxent()`](https://tidymapr-e72c18.gitlab.io/reference/sdm_maxent.md).

- object:

  An ensemble from `sdm_ensemble()`.

- newdata:

  Data frame or `SpatRaster` of predictors.

- what:

  `"mean"` (weighted ensemble), `"sd"` (weighted standard deviation
  across algorithms), `"all"` (every algorithm and both summaries).

## Value

`sdm_ensemble()`: an object of class `tmr_sdm_ensemble`, with `scores`
(a tibble of AUC, TSS and Boyce index per algorithm and fold), `summary`
(mean scores and the ensemble weight of each algorithm) and the models
fitted on all data. [`predict()`](https://rdrr.io/r/stats/predict.html):
a numeric vector, data frame or `SpatRaster`.

## References

Barbet-Massin M, Jiguet F, Albert CH, Thuiller W (2012) Selecting
pseudo-absences for species distribution models: how, where and how
many? Methods in Ecology and Evolution 3:327-338.

Hirzel AH, Le Lay G, Helfer V, Randin C, Guisan A (2006) Evaluating the
ability of habitat suitability models to predict species presences.
Ecological Modelling 199:142-152.

Roberts DR et al. (2017) Cross-validation strategies for data with
temporal, spatial, hierarchical, or phylogenetic structure. Ecography
40:913-929.

Thuiller W, Lafourcade B, Engler R, Araujo MB (2009) BIOMOD: a platform
for ensemble forecasting of species distributions. Ecography 32:369-373.

Valavi R, Elith J, Lahoz-Monfort JJ, Guillera-Arroita G (2021) Modelling
species presence-only data with random forests. Ecography 44:1731-1742.

## See also

[`sdm_maxent()`](https://tidymapr-e72c18.gitlab.io/reference/sdm_maxent.md).

## Examples

``` r
# Brown-throated sloth (Phillips et al. 2006)
data(bradypus, package = "maxnet")
ens <- sdm_ensemble(bradypus$presence, bradypus[, c(2, 3, 5:15)],
  algorithms = c("maxent", "glm", "rf"), folds = 4, ntree = 200
)
ens
#> SDM ensemble of 3 algorithms: 116 presences, 1000 background points, 4 random
#> folds.
#> # A tibble: 3 × 5
#>   algorithm   auc   tss boyce weight
#>   <chr>     <dbl> <dbl> <dbl>  <dbl>
#> 1 maxent    0.883 0.657 0.876  0.374
#> 2 glm       0.828 0.552 0.788  0.264
#> 3 rf        0.894 0.647 0.891  0.363
```
