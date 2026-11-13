# Ensemble projections of range shifts

Climate projections differ between climate models (GCMs), emission
scenarios (SSPs) and, on mountains, the lapse rate used to bring coarse
climate down to the terrain. A single projection hides this uncertainty.
These functions run a range-shift model over every member of an ensemble
and report the results as probabilities:

- `geo_climate_scenarios()` builds the ensemble of climates on a fine
  DEM: for each GCM, SSP and lapse rate, the baseline CHELSA climate is
  downscaled with
  [`geo_downscale_lapse()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)
  and the change projected by the GCM (future minus baseline, the delta
  method) is added, so every member shares the observed baseline.

- `geo_shift_ensemble()` predicts suitability for the present and every
  member with a niche model (such as
  [`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)),
  simulates colonisation and extinction with
  [`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md),
  and also reports the unlimited-dispersal range (all habitat with
  suitability at or above the starting threshold) for comparison.

- [`summary()`](https://rdrr.io/r/base/summary.html) gives, per scenario
  and dispersal assumption, the median and range of the change in range
  area across members, and the probability that the range shrinks by
  more than set thresholds.

## Usage

``` r
geo_climate_scenarios(
  area,
  dem,
  variables = "bio1",
  period = "2071-2100",
  gcm = c("mpi-esm1-2-hr", "ukesm1-0-ll"),
  ssp = c("ssp126", "ssp585"),
  lapse_rates = 5,
  temperature = grep("^bio([1-9]|1[01])$", variables, value = TRUE),
  reader = geo_chelsa_area
)

geo_shift_ensemble(
  model,
  scenarios,
  initial = 0.5,
  dispersal_mean,
  steps = 10,
  nsim = 50,
  seed = NULL,
  elevation = NULL,
  rescale = TRUE,
  ...
)

# S3 method for class 'tmr_shift_ensemble'
summary(object, loss = c(30, 50, 80), ...)
```

## Arguments

- area, dem:

  Area to read and fine elevation `SpatRaster` (metres).

- variables:

  CHELSA temperature variables to downscale (e.g. `"bio1"`, `"bio5"`);
  others (e.g. `"bio12"`) are only resampled.

- period:

  Future period (see
  [`geo_chelsa_area()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)).

- gcm, ssp:

  GCMs and scenarios.

- lapse_rates:

  Lapse rates (degrees C per km) to try.

- temperature:

  Which of `variables` are temperatures (downscaled with the lapse
  rate); default bio1 to bio11 (the temperature variables).

- reader:

  Function used to read CHELSA (for testing).

- model:

  A niche model with a
  [`predict()`](https://rdrr.io/r/stats/predict.html) method returning
  the probability of presence for a `SpatRaster` of covariates (such as
  [`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)),
  or a function taking a `SpatRaster` and returning one of suitability
  (0 to 1).

- scenarios:

  Result of `geo_climate_scenarios()`, or a list with `current` (one
  `SpatRaster`, or one per lapse rate) and `members` (a named list of
  `SpatRaster`s) and optionally `design`.

- initial:

  Initial occupancy, as in
  [`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md);
  by default the present suitability above 0.5.

- dispersal_mean, steps, nsim, seed, ...:

  Passed to
  [`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md);
  `steps` is the number of dispersal generations between the present and
  the future period.

- elevation:

  Optional elevation `SpatRaster` for range edges.

- rescale:

  Divide suitability by its maximum under the present climate (of that
  lapse rate), so the best present habitat is 1? Niche models give the
  probability of presence in a plot of some size, which is rarely close
  to 1; the simulation treats suitability as the per-generation
  persistence, so unscaled probabilities make most populations die out.
  Default `TRUE`.

- object:

  A `geo_shift_ensemble()` result.

- loss:

  Range-loss thresholds (%) for the probabilities.

## Value

`geo_climate_scenarios()`: a named list with `current` (a `SpatRaster`
per lapse rate, in list `current`) and `members`, a named list of
`SpatRaster`s, one per GCM x SSP x lapse rate, with layers named after
`variables`; and a tibble `design` of the members.

`geo_shift_ensemble()`: an object of class `tmr_shift_ensemble` with
`results`, a tibble with one row per member and dispersal assumption
(`"limited"`, `"unlimited"`): `member`, `gcm`, `ssp`, `lapse_rate`,
`dispersal`, `area_now`, `area_future`, `change` (%) and, with
`elevation`, the shift of the lower edge, median and upper edge (m); and
`occupancy`, the future occupancy (or suitability) rasters.

[`summary()`](https://rdrr.io/r/base/summary.html): a tibble per `ssp`
(if known) and `dispersal`: number of members, median, minimum and
maximum change (%), and `p_loss_<x>`, the share of members losing more
than x% of the range.

## See also

[`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md),
[`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md),
[`geo_chelsa_area()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md).
