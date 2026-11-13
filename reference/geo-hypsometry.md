# Land area by elevation and climate-driven range shifts

Tools for asking how much land a mountain offers at each elevation, and
what warming does to the land available to species with known
elevational ranges (Colwell et al. 2008; Elsen and Tingley 2015):

- `geo_hypsometry()` gives the land area in each elevation band of a
  digital elevation model, optionally inside a region. Areas come from
  [`terra::cellSize()`](https://rspatial.github.io/terra/reference/cellSize.html),
  so cells on a longitude/latitude grid are measured on the ellipsoid
  (`area = "ellipsoid"`), not as equal squares.

- `geo_range_shift()` moves each species' range upslope by
  `warming / lapse_rate` and reports the land area within the range now
  and after warming, the percentage change, whether the shifted range no
  longer overlaps the current one (a *gap*, the range-shift gap of
  Colwell et al. 2008) and whether it runs past the summit (truncation).

- `geo_patches()` labels connected patches of a mask and their areas;
  `geo_largest_patch()` keeps the largest, for example the main land
  mass of a peninsula once a valley floor has been cut out.

## Usage

``` r
geo_hypsometry(
  dem,
  region = NULL,
  band_width = 100,
  area = c("ellipsoid", "planar"),
  unit = c("km2", "ha", "m2"),
  min_elevation = 0
)

geo_range_shift(
  hypsometry,
  ranges,
  warming,
  lapse_rate = 4.84,
  pad = 0,
  summit = NULL,
  lowland = NULL,
  floor = 0
)

geo_patches(
  x,
  min_area = 0,
  directions = 8,
  area = c("ellipsoid", "planar"),
  unit = c("km2", "ha", "m2")
)

geo_largest_patch(x, directions = 8)
```

## Arguments

- dem:

  Elevation `SpatRaster` (metres).

- region:

  Optional area to keep: `sf`, `sfc`, `SpatVector`, or a `SpatRaster`
  mask (cells that are `NA`, `FALSE` or 0 are dropped).

- band_width:

  Width of elevation bands in metres.

- area:

  `"ellipsoid"` (true cell areas from
  [`terra::cellSize()`](https://rspatial.github.io/terra/reference/cellSize.html))
  or `"planar"` (cell areas from the nominal resolution, only meaningful
  for projected grids).

- unit:

  Area unit: `"km2"`, `"ha"` or `"m2"`.

- min_elevation:

  Lowest elevation counted; cells below (sea, bathymetry, voids) are
  dropped. Default 0.

- hypsometry:

  Result of `geo_hypsometry()`.

- ranges:

  Data frame of species ranges with columns `species`, `lower` and
  `upper` (metres).

- warming:

  Warming scenarios in degrees C, for example `c(1.8, 3.7)` (IPCC AR6
  SSP1-2.6 and SSP5-8.5, 2081-2100).

- lapse_rate:

  Temperature lapse rate in degrees C per km. The default, 4.84, is a
  humid tropical value; give the one measured on your transect.

- pad:

  Metres added below and above each observed range (an observed range
  underestimates the true one); lower limits are not padded below
  `floor`.

- summit:

  Highest elevation available; defaults to the summit of the hypsometry.
  Shifted ranges are cut at the summit and flagged.

- lowland:

  Species whose (padded) lower limit is at or below this elevation keep
  their lower limit (no area is lost at the bottom: there is no warmer
  land below them to vacate). `NULL` (default) shifts every lower limit.

- floor:

  Lowest elevation (default 0, sea level).

- x:

  A mask `SpatRaster` (cells that are `NA`, `FALSE` or 0 are background)
  or an elevation raster with `NA` outside the land.

- min_area:

  Patches smaller than this (in `unit`) are dropped.

- directions:

  8 (default, queen) or 4 (rook) neighbour cells.

## Value

`geo_hypsometry()`: a tibble with one row per band: `lower`, `upper`,
`area`, `share` (of the total) and `area_above` (land at or above
`lower`), with attributes `unit` and `summit` (highest elevation).

`geo_range_shift()`: a tibble with one row per species and warming:
`species`, `warming`, `shift` (m), `lower`, `upper` (padded current
range), `new_lower`, `new_upper`, `area_now`, `area_future`, `change`
(percent), `gap` (shifted range does not overlap the current range) and
`truncated` (shifted range runs past the summit).

`geo_patches()`: a list with `patches` (a `SpatRaster` of patch ids,
largest first) and `areas` (a tibble of `patch` and `area`).
`geo_largest_patch()`: `x` with every cell outside the largest patch set
to `NA`.

## References

Colwell, R. K., Brehm, G., Cardelús, C. L., Gilman, A. C. and Longino,
J. T. (2008). Global warming, elevational range shifts, and lowland
biotic attrition in the wet tropics. Science, 322, 258-261.

Elsen, P. R. and Tingley, M. W. (2015). Global mountain topography and
the fate of montane species under climate change. Nature Climate Change,
5, 772-776.

## Examples

``` r
# \donttest{
if (requireNamespace("terra", quietly = TRUE)) {
  # A synthetic cone-shaped mountain, 0 to 3,000 m
  dem <- terra::rast(nrows = 100, ncols = 100, xmin = 145, xmax = 146, ymin = -7, ymax = -6)
  xy <- terra::crds(dem)
  terra::values(dem) <- pmax(0, 3000 - 6000 * sqrt((xy[, 1] - 145.5)^2 + (xy[, 2] + 6.5)^2))
  hyp <- geo_hypsometry(dem, band_width = 500)
  hyp
  ranges <- data.frame(species = c("a", "b"), lower = c(0, 1800), upper = c(900, 2100))
  geo_range_shift(hyp, ranges, warming = c(1.8, 3.7), pad = 250)
}
#> # A tibble: 4 × 12
#>   species warming shift lower upper new_lower new_upper area_now area_future
#>   <chr>     <dbl> <dbl> <dbl> <dbl>     <dbl>     <dbl>    <dbl>       <dbl>
#> 1 a           1.8  372.     0  1150      372.     1522.    8527.       5736.
#> 2 b           1.8  372.  1550  2350     1922.     2722.    1777.       1131.
#> 3 a           3.7  764.     0  1150      764.     1914.    8527.       4095.
#> 4 b           3.7  764.  1550  2350     2314.     3114.    1777.        540.
#> # ℹ 3 more variables: change <dbl>, gap <lgl>, truncated <lgl>
# }
```
