# Dispersal kernels

`geo_dispersal_kernel()` describes the dispersal kernel used by
[`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md)
and
[`geo_epidemic_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_epidemic_simulate.md)
on a grid of a given cell size: its realised mean distance (after
truncation at `max_distance` and discretisation on the grid), the share
of dispersal beyond five times the mean (the long-distance tail), and
the number of neighbouring cells it reaches. Use it to choose between
the exponential and the fat-tailed 2Dt kernel and to check that the grid
resolves the kernel (cells much smaller than the mean distance).

## Usage

``` r
geo_dispersal_kernel(
  dispersal_mean,
  cell_size,
  kernel = c("exponential", "2Dt"),
  kernel_shape = 1,
  max_distance = NULL
)
```

## Arguments

- dispersal_mean:

  Mean dispersal distance per step, in metres.

- cell_size:

  Cell size in metres.

- kernel:

  `"exponential"` or `"2Dt"` (fat-tailed).

- kernel_shape:

  Shape \\p\\ of the 2Dt kernel (above 0.5; smaller is fatter-tailed).

- max_distance:

  Largest dispersal distance in metres (kernel truncation); default five
  times the mean for the exponential kernel and ten times for the 2Dt
  kernel.

## Value

A one-row tibble: `kernel`, `kernel_shape`, `dispersal_mean`,
`max_distance`, `realised_mean`, `share_beyond_5mean`, `neighbours`.

## Examples

``` r
geo_dispersal_kernel(500, cell_size = 50)
#> # A tibble: 1 × 7
#>   kernel      kernel_shape dispersal_mean max_distance realised_mean
#>   <chr>              <dbl>          <dbl>        <dbl>         <dbl>
#> 1 exponential           NA            500         2500          502.
#> # ℹ 2 more variables: share_beyond_5mean <dbl>, neighbours <int>
geo_dispersal_kernel(500, cell_size = 50, kernel = "2Dt", kernel_shape = 1)
#> # A tibble: 1 × 7
#>   kernel kernel_shape dispersal_mean max_distance realised_mean
#>   <chr>         <dbl>          <dbl>        <dbl>         <dbl>
#> 1 2Dt               1            500         5000          465.
#> # ℹ 2 more variables: share_beyond_5mean <dbl>, neighbours <int>
```
