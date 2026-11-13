# Integrated species distribution model with physiological limits

`sdm_integrated()` fits one niche model to two kinds of data at once
(Fithian et al. 2015; Isaac et al. 2020):

- **presence-only** records (for example GBIF), modelled as an
  inhomogeneous Poisson point process with background (quadrature)
  points, with its own intercept and optional **bias** covariates that
  describe where people look (distance to roads, towns, field stations);

- **presence-absence** surveys (for example standardised elevational
  transects), modelled with a complementary log-log link, so that the
  probability of presence at a site of area \\A\\ is \\1 - \exp(-A
  \lambda(x))\\.

Both share the same environmental response \\\lambda(x)\\, so the many
but biased presence-only records and the few but unbiased surveys inform
one niche: the surveys correct the sampling bias of the records and the
records fill in where no surveys were made.

Two constraints keep projections to future climates biologically
plausible:

- `unimodal`: the response to these covariates is forced to be a hump
  (negative quadratic term), so suitability falls beyond the optimum
  instead of rising without limit in novel climates;

- `limits`: physiological limits, such as a critical thermal maximum
  (CTmax) for maximum temperature. Suitability is multiplied by a smooth
  step that falls from 0.9 to 0.1 over the `limit_width` just inside the
  limit, and towards 0 beyond it.

Covariates are standardised before fitting, and a small ridge penalty
(`lambda`) stabilises the fit; the coefficients are reported on the
standardised scale.

## Usage

``` r
sdm_integrated(
  presence,
  background,
  area,
  survey = NULL,
  covariates,
  quadratic = covariates,
  unimodal = character(),
  bias = character(),
  limits = list(),
  limit_width = 1,
  lambda = 0.01
)

# S3 method for class 'tmr_sdm_integrated'
predict(
  object,
  newdata,
  type = c("probability", "intensity", "link"),
  site_area = 1,
  se_fit = FALSE,
  level = 0.95,
  ...
)
```

## Arguments

- presence:

  Data frame of covariates at presence-only records.

- background:

  Data frame of covariates at background points spread over the study
  area (for example 10,000 random cells).

- area:

  Total area of the study region (any unit; it scales the intensity of
  the presence-only process).

- survey:

  Optional data frame of presence-absence surveys: covariates and a 0/1
  column `present` (and optionally `site_area`, in the same units as
  `area`; default 1).

- covariates:

  Environmental covariates (column names).

- quadratic:

  Covariates that also get a squared term; default all.

- unimodal:

  Quadratic covariates whose response must be a hump.

- bias:

  Bias covariates, used only for the presence-only data. Set them to a
  common value (for example their minimum, meaning "well surveyed") when
  predicting.

- limits:

  Named list of physiological limits, each `c(lower, upper)` on the
  original scale of the covariate (use `NA` for no limit), for example
  `list(bio5 = c(NA, 33))` for a CTmax of 33 degrees C.

- limit_width:

  Width of the smooth fall to zero at a limit, in the units of the
  covariate.

- lambda:

  Ridge penalty on the environmental coefficients.

- object:

  A fitted `sdm_integrated()` model.

- newdata:

  Data frame or `SpatRaster` of covariates. Bias covariates are ignored
  (prediction is for unbiased sampling).

- type:

  `"probability"`, `"intensity"` or `"link"`.

- site_area:

  Area for `type = "probability"`; default 1 (one survey site).

- se_fit:

  For a data frame `newdata`, also return the standard error of the
  linear predictor (`se_link`, by the delta method from the covariance
  of the fitted parameters) and a confidence interval formed on the link
  scale and back-transformed to `type` (`lower`, `upper`).

- level:

  Confidence level of the interval.

- ...:

  Unused.

## Value

`sdm_integrated()`: an object of class `tmr_sdm_integrated` with the
coefficients (`coef`), their standard errors (`se`, from the inverse
Hessian), the log-likelihood and the standardisation used.
[`predict()`](https://rdrr.io/r/stats/predict.html) gives, for a data
frame or a `SpatRaster` of covariates, the probability of presence in an
area of `site_area` (`type = "probability"`), the intensity
(`"intensity"`) or the linear predictor (`"link"`).

## References

Fithian, W., Elith, J., Hastie, T. and Keith, D. A. (2015). Bias
correction in species distribution models: pooling survey and collection
data for multiple species. Methods in Ecology and Evolution, 6, 424-438.

Isaac, N. J. B. et al. (2020). Data integration for large-scale models
of species distributions. Trends in Ecology & Evolution, 35, 56-67.

Sunday, J. M., Bates, A. E. and Dulvy, N. K. (2012). Thermal tolerance
and the global redistribution of animals. Nature Climate Change, 2,
686-690.

## See also

[`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md)
to add dispersal to the projections.

## Examples

``` r
set.seed(1)
# Virtual species with an optimum at 20 C, records biased towards roads
bg <- data.frame(temp = runif(5000, 5, 30), road = runif(5000))
lam <- function(d) exp(2 - 0.08 * (d$temp - 20)^2)
keep <- runif(5000) < lam(bg) / max(lam(bg)) * exp(-3 * bg$road)
po <- bg[keep, ][1:300, ]
sv <- data.frame(temp = runif(80, 5, 30), road = runif(80))
sv$present <- rbinom(80, 1, 1 - exp(-0.02 * lam(sv)))
fit <- sdm_integrated(po, bg,
  area = 1000, survey = sv,
  covariates = "temp", unimodal = "temp", bias = "road",
  limits = list(temp = c(NA, 28))
)
fit
#> Integrated species distribution model
#> 300 presence-only records, 5000 background points, 80 survey sites
#> Physiological limits: "temp"
#>                  estimate     se
#> temp               3.0253 0.2900
#> temp^2            -4.4654 0.3490
#> po_intercept      -0.4739 0.0912
#> road              -0.7831 0.0680
#> survey_intercept  -2.2072 0.5811
predict(fit, data.frame(temp = c(10, 20, 27, 29), road = 0))
#> [1] 3.178927e-05 1.677707e-01 2.371421e-03 2.242139e-07
```
