# Simulate range shifts with dispersal and colonisation-extinction dynamics

`geo_shift_simulate()` projects where a species can actually be, not
only where the climate suits it. Correlative niche models assume that a
species fills all suitable habitat at once; real species colonise new
habitat at the speed of their dispersal and lose populations where
conditions deteriorate, often with a lag. This function runs a spatially
explicit, stochastic colonisation-extinction model (a stochastic patch
occupancy model on a grid; Hanski 1999; Engler and Guisan 2009) over a
time series of habitat suitability, such as the output of a species
distribution model projected onto successive climate periods.

In each step, an empty cell \\j\\ is colonised with probability \$\$1 -
\exp(-c \\ s_j \sum_i K(d\_{ij})),\$\$ where the sum runs over occupied
cells \\i\\ and \\K\\ is the dispersal kernel, truncated at
`max_distance` and normalised to sum to 1 over the neighbourhood (so the
sum is the kernel-weighted share of occupied neighbours, and results do
not depend on the cell size). Two kernels are offered, both
parameterised by their mean dispersal distance \\\bar d\\ in two
dimensions:

- `"exponential"`: \\K(d) \propto e^{-2d/\bar d}\\;

- `"2Dt"` (Clark et al. 1999): \\K(d) \propto (1 + d^2/u)^{-(p+1)}\\,
  fat-tailed, so rare long-distance dispersal is far more likely than
  under the exponential; smaller `kernel_shape` (\\p \> 0.5\\) gives a
  fatter tail. Use
  [`geo_dispersal_kernel()`](https://tidymapr.in4metrix.dev/reference/geo_dispersal_kernel.md)
  to see a kernel's realised mean and tail.

Optional processes:

- `resistance`: movement costs. The distance is replaced by an effective
  distance, the straight-line distance times the mean resistance of the
  cells crossed (1 = baseline, 5 = five times harder, below 1 =
  corridor; `NA`, 0 or `Inf` = impassable barrier). This is a local,
  straight-line approximation, not a least-cost path.

- `jump_rate` and `jump_weights`: human-assisted or other long-distance
  jumps. Each step, a Poisson number of propagules with mean `jump_rate`
  times the number of occupied cells lands on cells chosen in proportion
  to `jump_weights` (for example road density, ports or towns), and
  establishes with probability equal to suitability.

- `disturbance`: the probability, per step, that an occupied cell is
  lost to clearing, fire or eradication, on top of the climate.

\\s_j\\ is the suitability of the cell and \\c\\ the colonisation rate.
An occupied cell persists with probability \\s_j^p\\. Cell sizes come
from the grid's true geometry, so the kernel is isotropic in metres on
longitude/latitude grids. Simulations run in parallel in C++ with
independent random streams; results depend on `seed` but not on the
number of threads.

The result is the probability that each cell is occupied at the end of
each period, over `nsim` simulations. Compare it with the suitability
itself (unlimited dispersal) to see the dispersal lag, the extinction
debt and whether a species can cross gaps in habitat.

## Usage

``` r
geo_shift_simulate(
  suitability,
  initial = 0.5,
  dispersal_mean,
  max_distance = NULL,
  colonisation = 1,
  persistence = 1,
  steps_per_layer = 1,
  nsim = 100,
  seed = NULL,
  threads = 0,
  kernel = c("exponential", "2Dt"),
  kernel_shape = 1,
  resistance = NULL,
  jump_rate = 0,
  jump_weights = NULL,
  disturbance = NULL
)

geo_shift_summary(occupancy, elevation = NULL)
```

## Arguments

- suitability:

  A `SpatRaster` with one layer per time period (values 0 to 1; `NA` or
  negative values are unsuitable, e.g. sea).

- initial:

  Starting occupancy: a `SpatRaster` (cells \> 0 occupied), an `sf`
  table of occurrence points, or a number, the suitability threshold
  applied to the first layer.

- dispersal_mean:

  Mean dispersal distance per step, in metres.

- max_distance:

  Largest dispersal distance in metres (kernel truncation); default five
  times the mean for the exponential kernel and ten times for the 2Dt
  kernel.

- colonisation:

  Colonisation rate \\c\\.

- persistence:

  Exponent \\p\\ of local persistence; larger values make populations in
  marginal habitat more likely to disappear.

- steps_per_layer:

  Number of dispersal generations within each period (for example 10 for
  ten-year periods and a species that disperses once a year).

- nsim:

  Number of stochastic simulations.

- seed:

  Random seed.

- threads:

  Number of threads (0 = OpenMP default).

- kernel:

  `"exponential"` or `"2Dt"` (fat-tailed).

- kernel_shape:

  Shape \\p\\ of the 2Dt kernel (above 0.5; smaller is fatter-tailed).

- resistance:

  Optional `SpatRaster` of movement resistance (1 = baseline; `NA`, 0 or
  `Inf` = barrier).

- jump_rate:

  Expected number of long-distance jumps per occupied cell per step
  (default 0, none).

- jump_weights:

  Optional `SpatRaster` of relative weights of jump destinations;
  default all cells equally.

- disturbance:

  Optional `SpatRaster` of the probability that an occupied cell is lost
  per step: one layer, or one per layer of `suitability`.

- occupancy:

  Result of `geo_shift_simulate()` (or a suitability raster, for
  comparison).

- elevation:

  Optional elevation `SpatRaster` on the same grid; adds the
  occupancy-weighted 5%, 50% and 95% elevations (lower edge, centre and
  upper edge).

## Value

`geo_shift_simulate()`: a `SpatRaster` of occupancy probability, one
layer per period, named after the layers of `suitability`, with the
settings as attribute `"settings"`.

`geo_shift_summary()`: a tibble with one row per period: `period`,
`area_km2` (expected occupied area), and with `elevation`, `lower`,
`median` and `upper`.

## References

Engler, R. and Guisan, A. (2009). MigClim: predicting plant distribution
and dispersal in a changing climate. Diversity and Distributions, 15,
590-601.

Hanski, I. (1999). Metapopulation Ecology. Oxford University Press.

Clark, J. S., Silman, M., Kern, R., Macklin, E. and HilleRisLambers, J.
(1999). Seed dispersal near and far: patterns across temperate and
tropical forests. Ecology, 80, 1475-1494.

## See also

[`geo_dispersal_kernel()`](https://tidymapr.in4metrix.dev/reference/geo_dispersal_kernel.md),
[`geo_epidemic_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_epidemic_simulate.md),
`geo_shift_summary()`,
[`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md),
[`geo_range_shift()`](https://tidymapr.in4metrix.dev/reference/geo-hypsometry.md).

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  # A virtual mountain: suitability is a band that moves upslope
  r <- terra::rast(
    nrows = 40, ncols = 40, xmin = 145, xmax = 145.4,
    ymin = -6.4, ymax = -6, crs = "EPSG:4326"
  )
  elev <- terra::init(r, "y")
  elev <- (elev - min(terra::values(elev))) * 10000
  band <- function(mid) exp(-((elev - mid) / 400)^2)
  suit <- c(band(1000), band(1400), band(1800))
  names(suit) <- c("2000", "2050", "2100")
  occ <- geo_shift_simulate(suit, 0.5, dispersal_mean = 2000, nsim = 20, seed = 1)
  geo_shift_summary(occ, elevation = elev)
}
#> # A tibble: 3 × 5
#>   period area_km2 lower median upper
#>   <chr>     <dbl> <dbl>  <dbl> <dbl>
#> 1 2000      290.   700.  1000. 1300.
#> 2 2050      158.   900.  1200. 1500.
#> 3 2100       46.2 1100.  1400. 1700 
# }
```
