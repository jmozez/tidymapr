# Maxent species distribution models, in C++

`sdm_maxent()` fits Maxent (Phillips, Anderson and Schapire 2006) as an
infinitely-weighted logistic regression with a lasso penalty (Fithian
and Hastie 2013; Phillips et al. 2017), the formulation of the maxnet
package, with the same feature classes and default regularisation. The
lasso path is solved by coordinate descent in C++, so no Java and no
glmnet are needed. Predictions are on the cloglog scale by default
(Phillips et al. 2017), clamped to the training range.

## Usage

``` r
sdm_maxent(
  presence,
  data,
  features = "default",
  regmult = 1,
  add_samples_to_background = TRUE,
  standardize = TRUE
)

# S3 method for class 'tmr_maxent'
predict(
  object,
  newdata,
  type = c("cloglog", "logistic", "exponential", "link"),
  clamp = TRUE,
  ...
)
```

## Arguments

- presence:

  0/1 vector: 1 for presences, 0 for background points.

- data:

  Data frame of predictors for the same rows; numeric columns are
  continuous, factors are categorical.

- features:

  Feature classes, any of `"l"` (linear), `"q"` (quadratic), `"p"`
  (product), `"h"` (hinge), `"t"` (threshold) as one string such as
  `"lqh"`, or `"default"`, which uses maxnet's rule (`l` below 10
  presences, `lq` below 15, `lqh` below 80, else `lqph`).

- regmult:

  Regularisation multiplier: larger gives smoother models.

- add_samples_to_background:

  Add presences to the background, as Maxent does?

- standardize:

  Rescale every continuous predictor to 0-1 over the training data
  before building features (default `TRUE`), as the original Java Maxent
  does. The maxnet package builds linear, quadratic and product features
  on the raw scale and fits them unstandardised, so a predictor in
  metres (elevation) and one in millimetres (rainfall) produce squares
  and products that differ by many orders of magnitude. The penalties
  then do not compare across features and the lasso path can stall. On
  the 0-1 scale every feature class is comparable, the default
  regularisation means the same thing for every predictor, and the fit
  is stable. Use `FALSE` to reproduce maxnet exactly.

- object:

  A model from `sdm_maxent()`.

- newdata:

  Data frame or `SpatRaster` of predictors.

- type:

  `"cloglog"` (default), `"logistic"`, `"exponential"` or `"link"`.

- clamp:

  Clamp predictors and features to the training range?

- ...:

  Not used.

## Value

`sdm_maxent()`: an object of class `tmr_maxent` with the non-zero
coefficients (`betas`), `alpha`, `entropy` and the feature definitions.
[`predict()`](https://rdrr.io/r/stats/predict.html): a numeric vector,
or a `SpatRaster` for raster input.

## References

Phillips SJ, Anderson RP, Schapire RE (2006) Maximum entropy modeling of
species geographic distributions. Ecological Modelling 190:231-259.

Fithian W, Hastie T (2013) Finite-sample equivalence in statistical
models for presence-only data. Annals of Applied Statistics 7:1917-1939.

Phillips SJ, Anderson RP, Dudik M, Schapire RE, Blair ME (2017) Opening
the black box: an open-source release of Maxent. Ecography 40:887-893.

## See also

[`sdm_ensemble()`](https://tidymapr-e72c18.gitlab.io/reference/sdm_ensemble.md)
to combine Maxent with other algorithms.

## Examples

``` r
# Brown-throated sloth, Bradypus variegatus (Phillips et al. 2006)
data(bradypus, package = "maxnet")
fit <- sdm_maxent(bradypus$presence, bradypus[, -1])
fit
#> Maxent (lqph features, regmult 1): 116 presences, 1116 background points,
#> standardised predictors, 48 non-zero features of 1379.
#> Features kept: linear 4, quadratic 6, product 18, hinge 11, categorical 9.
head(predict(fit, bradypus[, -1]))
#> [1] 0.1112069 0.1129934 0.7535782 0.2086556 0.2789875 0.4703282
```
