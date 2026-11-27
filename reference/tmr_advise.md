# tidyvisor advice for spatial analyses

The advisor of tidymapr for the
[tidyvisor](https://tidyvisor.in4metrix.dev/reference/tidyvisor.html)
package. tidymapr registers it when loaded, so
[`tidyvisor()`](https://tidyvisor.in4metrix.dev/reference/tidyvisor.html)
uses it. Give
[`tidyvisor()`](https://tidyvisor.in4metrix.dev/reference/tidyvisor.html)
**data** and a question, and it recommends the analysis, checks the data
for the usual pitfalls, and names the plots and the code to run
(`tmr_advise()`). Give it a **result** (a growth rate, a spread rate, an
epidemic or range-shift simulation, a species distribution model or a
Moran's I test), and it explains the numbers and the figure in plain
sentences (`tmr_interpret()`).

The advice gives its reasons, so it can be checked and overruled: the
question, which only the analyst knows, comes first.

Questions:

- `"distribution"`: where can a species live? Species distribution
  models, from presence-only, presence-absence or both kinds of record.

- `"spread"`: how fast is an invasion or a range expansion moving?

- `"epidemic"`: how fast are cases growing, and what is the reproduction
  number? How could an infection spread across a landscape?

- `"range_shift"`: where will a species be under a future climate, given
  how far it can disperse?

- `"autocorrelation"`: are values at nearby sites more alike than
  expected?

## Usage

``` r
tmr_advise(
  x,
  question = c("auto", "distribution", "spread", "epidemic", "range_shift",
    "autocorrelation"),
  date = NULL,
  cases = NULL,
  lon = NULL,
  lat = NULL,
  presence = NULL,
  value = NULL
)

tmr_interpret(x, ...)
```

## Arguments

- x:

  A data frame of records (to be advised) or a result of
  [`epi_growth_rate()`](https://tidymapr.in4metrix.dev/reference/epi_growth_rate.md),
  [`geo_spread_rate()`](https://tidymapr.in4metrix.dev/reference/geo_spread_rate.md),
  [`geo_epidemic_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_epidemic_simulate.md),
  [`geo_shift_ensemble()`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md),
  [`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md),
  [`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)
  or
  [`geo_moran()`](https://tidymapr.in4metrix.dev/reference/geo_moran.md)
  (to be interpreted).

- question:

  What is asked (see above), or `"auto"` to guess it from the columns.

- date, cases, lon, lat, presence, value:

  Names (strings) of the columns holding the date, case counts,
  coordinates, presence (1) or absence (0), and a measured value.
  Guessed from common names when not given.

- ...:

  Passed on.

## Value

A `tmr_advice` or a `tmr_interpretation` object, printed as sentences.

## Examples

``` r
# Advice on weekly case counts
cases <- data.frame(
  week = seq(as.Date("2024-01-01"), by = "week", length.out = 12),
  n = c(2, 3, 5, 4, 9, 12, 15, 24, 30, 41, 60, 77)
)
tidyvisor(cases, question = "epidemic", date = "week", cases = "n")
#> 
#> ── tidyvisor: how fast is the epidemic growing? ────────────────────────────────
#> Question: epidemic
#> 
#> ── What the data show ──
#> 
#> • Records: 12
#> • Time points: 12
#> • Dispersion about the trend (Pearson): 0.1 — close to Poisson
#> • Locations: none — case counts over time without places: tidyepidemio covers
#>   outbreak statistics (incidence, Rt, nowcasting); tidymapr adds the spatial
#>   side
#> 
#> ── Recommended ──
#> 
#> Outbreak statistics: Incidence, growth, Rt and nowcasting with tidyepidemio
#> Without locations this is an outbreak-statistics question; the tidyepidemio
#> package has the full toolkit, and tidyvisor hands these data to it.
#> tidyvisor(data, question = "outbreak", time = <date column>, cases = <count column>)
#> Approach: Exponential growth rate from a log-linear count model
#> Early in an outbreak cases grow exponentially; the slope of log cases on time
#> is the growth rate r.
#> Method: Poisson generalised linear model over the exponential phase
#> Choose a window where the log counts rise in a straight line; later, control
#> and depletion bend the curve.
#> g <- epi_growth_rate(data, date = week, cases = n, family = "poisson", window = c(<start>, <end>))
#> Reproduction number: Convert r to R with the generation interval
#> R depends on r and on the mean and standard deviation of the generation
#> interval (Wallinga and Lipsitch 2007); take these from the literature for the
#> pathogen.
#> epi_growth_rate(..., generation_mean = <mean>, generation_sd = <sd>)
#> Spatial spread: Simulate spread across hosts with a dispersal kernel
#> To ask where an infection could go, combine host density, transmission and a
#> dispersal kernel.
#> geo_epidemic_simulate(hosts, init_inf, beta = <beta>, gamma = <gamma>, dispersal_mean = <km>)
#> Plots: Observed counts with the fitted curve and its confidence band, on a log
#> scale
#> On a log scale exponential growth is a straight line, so departures from it are
#> easy to see.
#> plot(g)
#> Interpret: Plain-language explanation of the estimates
#> tidyvisor(g)
# ... and the interpretation of the fit
g <- epi_growth_rate(cases, date = week, cases = n, unit = "week")
tidyvisor(g)
#> 
#> ── tidyvisor: what the results show ────────────────────────────────────────────
#> 
#> ── Overview ──
#> 
#> • Exponential growth fitted to 12 weeks of counts with a Poisson model.
#> 
#> ── Growth ──
#> 
#> • Cases change by 38.2% per week (growth rate r = 0.324, 95% CI 0.277 to
#>   0.370).
#> • The epidemic is growing: cases double every 2.1 weeks (1.9 to 2.5).
#> 
#> ── Reading the plot ──
#> 
#> • Points are the observed counts; the line is the fitted exponential curve and
#>   the band its confidence interval, computed on the log scale and
#>   back-transformed.
#> • On a log scale the curve is straight; counts bending below it late in the
#>   window suggest control measures or depletion of susceptibles.
#> 
#> ── After the overall test ──
#> 
#> • To compare growth between places or periods, fit each and compare the rates
#>   with their intervals, or fit one model with an interaction of time and place;
#>   do not compare doubling times by eye.
#> 
#> ── For the paper ──
#> 
#> • Results: 'Cases grew by 38.2% per week (growth rate r = 0.324, 95% CI 0.277
#>   to 0.370), doubling every 2.1 weeks (1.9 to 2.5).'
#> • Figure: the counts with the fitted curve and its confidence band, on a log
#>   scale:
#> • p <- plot(g)
#> • geo_save(p, "figure1.pdf", width = 180, height = 100) # full page width, in
#>   mm
#> • Table: the growth rate, doubling time and R, each with its interval.
#> • Methods: the Poisson model, the window of exponential growth and how it was
#>   chosen, the generation interval (mean and SD) and its source for R (Wallinga
#>   and Lipsitch 2007), and the software (R 4.6.2; citation("tidymapr")).
```
