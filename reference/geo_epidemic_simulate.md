# Simulate the spread of a disease across a landscape

`geo_epidemic_simulate()` runs a stochastic, spatially explicit SIR
(susceptible-infected-recovered) model on a grid of host populations,
for example a wildlife disease such as chytridiomycosis in frogs, a
plant pathogen in a forest, or an outbreak among villages. Each cell
holds `hosts` individuals. In each time step a susceptible host in cell
\\j\\ is infected with probability \\1 - e^{-\lambda_j}\\, \$\$\lambda_j
= \beta \left\[(1 - m) \frac{I_j}{N_j} + m \sum_i K(d\_{ij})
\frac{I_i}{N_i}\right\],\$\$ where \\\beta\\ is the transmission rate,
\\m\\ the share of contacts made outside the home cell (`coupling`) and
\\K\\ the normalised dispersal kernel of
[`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md)
(exponential or fat-tailed 2Dt, with optional resistance). Infected
hosts recover with probability \\1 - e^{-\gamma}\\ per step, and
recovered hosts lose immunity with probability \\1 - e^{-\omega}\\
(`omega = 0`: lasting immunity). Time runs in discrete steps, so an
infected host stays infectious for \\1 / (1 - e^{-\gamma})\\ steps on
average (close to \\1/\gamma\\ when \\\gamma\\ is small), and in a
single well-mixed population the basic reproduction number is \\R_0 =
\beta / (1 - e^{-\gamma})\\. The expected final share infected \\z\\
then solves \\z = 1 - e^{-R_0 z}\\; the tests check the simulation
against this.

## Usage

``` r
geo_epidemic_simulate(
  hosts,
  initial,
  beta,
  gamma,
  omega = 0,
  coupling = 0.1,
  dispersal_mean,
  times,
  kernel = c("exponential", "2Dt"),
  kernel_shape = 1,
  max_distance = NULL,
  resistance = NULL,
  initial_count = 1,
  nsim = 100,
  seed = NULL,
  threads = 0
)
```

## Arguments

- hosts:

  `SpatRaster` of the number of hosts per cell (rounded to whole
  numbers; `NA` or 0 = no hosts).

- initial:

  Initially infected hosts: a `SpatRaster` of counts, or an
  `sf`/`SpatVector` of points, each infecting `initial_count` hosts in
  its cell.

- beta:

  Transmission rate per time step.

- gamma:

  Recovery rate per time step (mean infectious period \\1 / (1 -
  e^{-\gamma})\\ steps).

- omega:

  Rate of loss of immunity per step (0 = lasting immunity).

- coupling:

  Share of contacts outside the home cell, 0 to 1.

- dispersal_mean:

  Mean distance of contacts outside the cell, in metres.

- times:

  Time steps at which to record the maps (increasing integers).

- kernel:

  `"exponential"` or `"2Dt"` (fat-tailed).

- kernel_shape:

  Shape \\p\\ of the 2Dt kernel (above 0.5; smaller is fatter-tailed).

- max_distance:

  Largest dispersal distance in metres (kernel truncation); default five
  times the mean for the exponential kernel and ten times for the 2Dt
  kernel.

- resistance:

  Optional `SpatRaster` of movement resistance (1 = baseline; `NA`, 0 or
  `Inf` = barrier).

- initial_count:

  Hosts infected at each starting point.

- nsim:

  Number of stochastic simulations.

- seed:

  Random seed.

- threads:

  Number of threads (0 = OpenMP default).

## Value

A list of class `tmr_epidemic`:

- `prevalence`: `SpatRaster`, mean share of hosts infected at each of
  `times`;

- `reached`: `SpatRaster`, probability that the disease has reached each
  cell by each of `times`;

- `curve`: tibble of `time` and mean number `infected` per step;

- `attack`: share of all hosts ever infected, per simulation;

- `settings`.

## References

Keeling, M. J. and Rohani, P. (2008). Modeling Infectious Diseases in
Humans and Animals. Princeton University Press.

## See also

[`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md),
[`geo_dispersal_kernel()`](https://tidymapr.in4metrix.dev/reference/geo_dispersal_kernel.md).

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  r <- terra::rast(
    nrows = 30, ncols = 30, xmin = 0, xmax = 30000,
    ymin = 0, ymax = 30000, crs = "EPSG:32755"
  )
  hosts <- terra::init(r, 200)
  seed <- terra::init(r, 0)
  seed[15, 15] <- 5
  ep <- geo_epidemic_simulate(hosts, seed,
    beta = 0.4, gamma = 0.1, coupling = 0.3,
    dispersal_mean = 2000, times = c(20, 40, 80), nsim = 10, seed = 1
  )
  terra::plot(ep$reached)
  mean(ep$attack)
}

#> [1] 0.9653506
# }
```
