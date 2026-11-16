# Spread rate of a biological invasion

`geo_spread_rate()` estimates how fast an invading species (or disease)
expands its range, from dated occurrence records, with two standard
methods:

- `"first_record"` (default): the study area is divided into cells of
  `cell_size` km, the first record in each cell is kept, and the
  distance of each cell from the point of introduction is regressed on
  the date of its first record. The slope is the spread rate. Using
  first records per cell reduces the effect of uneven sampling effort.

- `"front"`: for each year with at least 5 records, the distance of the
  invasion front, taken as the `front_quantile` (default 0.99) of the
  distances of that year's records from the point of introduction,
  regressed on year. Records from behind the front do not matter, but
  records far ahead of it (hitchhikers, mislabelled localities) do:
  clean the data first
  ([`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md))
  and inspect the plot.

- `"area"`: the cumulative area of occupied cells is converted to the
  radius of a circle of the same area, \\\sqrt{A/\pi}\\, and regressed
  on time (Shigesada and Kawasaki 1997). This assumes nearly every
  invaded cell has a record; with sparse sampling it underestimates the
  rate badly.

Distances are geodesic. The rate, its standard error and confidence
interval come from the fitted linear model, and so do the fitted
distances and their confidence band (`fitted`). Look at the plot before
trusting a single rate: many invasions accelerate (Phillips et al.
2006), so fit separate periods with `period` if the relationship is
curved.

## Usage

``` r
geo_spread_rate(
  data,
  date,
  origin = NULL,
  method = c("first_record", "front", "area"),
  cell_size = 25,
  front_quantile = 0.99,
  period = NULL,
  level = 0.95
)
```

## Arguments

- data:

  An `sf` table of points, or a data frame with `lon` and `lat` (WGS84).

- date:

  Column of dates (`Date`) or decimal years.

- origin:

  Point of introduction, `c(lon, lat)`; default the earliest record.

- method:

  `"first_record"` or `"area"`.

- cell_size:

  Cell size in km for first records and occupied area.

- front_quantile:

  Quantile of record distances taken as the front (`method = "front"`).

- period:

  Optional length-2 vector of years to fit.

- level:

  Confidence level.

## Value

A list of class `tmr_spread_rate`: `estimate` (a tibble with the rate in
km per year, its standard error and interval, and \\R^2\\), `fitted`
(the data used, with fitted values and confidence band), `model` (the
`lm`) and the settings.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the data
and fit.

## References

Phillips, B. L., Brown, G. P., Webb, J. K. and Shine, R. (2006).
Invasion and the evolution of speed in toads. Nature, 439, 803.

Shigesada, N. and Kawasaki, K. (1997). Biological Invasions: Theory and
Practice. Oxford University Press.
