# Present and future climate: CHELSA, lapse-rate downscaling and canopy buffering

Climate inputs for range-shift models. Unlike the deprecated
[`geo_chelsa()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md),
which downloads whole global files, these read only the area needed, and
future climate comes from CHELSA-CMIP6 itself.

- `geo_chelsa_area()` reads CHELSA V2.1 climatologies (Karger et al.
  2017), about 1 km, for an area: the 1981-2010 baseline or CMIP6
  projections for 2011-2040, 2041-2070 and 2071-2100 under SSP1-2.6,
  SSP3-7.0 and SSP5-8.5 from five global climate models (GCMs). Only the
  window over the area is read from the cloud-optimised files; scale and
  offset are applied, so temperatures are in degrees C.

- `geo_downscale_lapse()` brings a coarse temperature layer down to the
  resolution of a fine digital elevation model with a lapse rate:
  \$\$T\_{fine} = T\_{coarse} + \gamma (z\_{coarse} - z\_{fine}) /
  1000,\$\$ where \\z\_{coarse}\\ is the elevation the coarse value
  represents (by default the mean of the fine DEM within each coarse
  cell) and \\\gamma\\ the lapse rate in degrees C per km. On steep
  tropical mountains a 1 km cell can span over 1,000 m, about 5 degrees
  C, so this step matters for species with narrow elevational ranges.

- `geo_canopy_offset()` adds the buffering of the forest canopy: below
  closed forest, maximum temperatures are lower and minimum temperatures
  higher than in the open (De Frenne et al. 2019, 2021). The offset is
  scaled by canopy cover (0 to 1), for example from
  [`geo_landcover()`](https://tidymapr.in4metrix.dev/reference/geo_landcover.md).

## Usage

``` r
geo_chelsa_area(
  area,
  variables = "bio1",
  period = "1981-2010",
  gcm = NULL,
  ssp = NULL
)

geo_chelsa_urls(
  variables = "bio1",
  period = "1981-2010",
  gcm = NULL,
  ssp = NULL
)

geo_downscale_lapse(climate, dem, lapse_rate, coarse_dem = NULL)

geo_canopy_offset(temperature, canopy, offset)
```

## Arguments

- area:

  Area: `sf`, `SpatRaster`, `SpatVector`, `SpatExtent` or
  `c(xmin, ymin, xmax, ymax)` in degrees.

- variables:

  CHELSA variables, for example `"bio1"` (annual mean temperature),
  `"bio5"` (maximum temperature of the warmest month), `"bio6"`,
  `"bio12"` (annual precipitation).

- period:

  `"1981-2010"` (baseline), `"2011-2040"`, `"2041-2070"` or
  `"2071-2100"`.

- gcm, ssp:

  For future periods: GCMs (`"gfdl-esm4"`, `"ipsl-cm6a-lr"`,
  `"mpi-esm1-2-hr"`, `"mri-esm2-0"`, `"ukesm1-0-ll"`) and scenarios
  (`"ssp126"`, `"ssp370"`, `"ssp585"`). Every combination is read,
  giving an ensemble.

- climate:

  Coarse temperature `SpatRaster` (one or more layers).

- dem:

  Fine elevation `SpatRaster` (metres); the result has its grid.

- lapse_rate:

  Temperature lapse rate in degrees C per km (positive: cooler with
  height). Use one measured on your mountain where possible; about 5 to
  6.5 is typical of humid tropical mountains.

- coarse_dem:

  Elevation that the coarse values represent; by default the mean of
  `dem` within each cell of `climate`.

- temperature:

  Temperature `SpatRaster` (degrees C).

- canopy:

  Canopy cover `SpatRaster`, 0 (open) to 1 (closed forest), or a logical
  forest layer.

- offset:

  Temperature difference below closed canopy relative to the open, in
  degrees C: one number, or a `SpatRaster`. There is no default because
  it depends on the variable: forests cool maximum temperatures by about
  4 degrees C on average and warm minimum temperatures by about 1 degree
  C (De Frenne et al. 2019), with larger offsets in dense tropical
  forest. Use a value measured with loggers where possible.

## Value

`geo_chelsa_area()`: a `SpatRaster` with one layer per variable (and GCM
and scenario), named for example
`"bio1_2071-2100_mpi-esm1-2-hr_ssp585"`.

`geo_chelsa_urls()`: a tibble of `name` and `url` of the files
`geo_chelsa_area()` would read (no download).

`geo_downscale_lapse()`: a `SpatRaster` on the grid of `dem`.

`geo_canopy_offset()`: `temperature + canopy * offset`.

## References

De Frenne, P. et al. (2019). Global buffering of temperatures under
forest canopies. Nature Ecology & Evolution, 3, 744-749.

De Frenne, P. et al. (2021). Forest microclimates and climate change:
importance, drivers and future research agenda. Global Change Biology,
27, 2279-2297.

Karger, D. N. et al. (2017). Climatologies at high resolution for the
earth's land surface areas. Scientific Data, 4, 170122.

## Examples

``` r
if (FALSE) { # interactive() && rlang::is_installed("terra")
huon <- c(146.5, -6.5, 147, -6)
now <- geo_chelsa_area(huon, "bio1")
future <- geo_chelsa_area(huon, "bio1",
  period = "2071-2100",
  gcm = c("mpi-esm1-2-hr", "ukesm1-0-ll"), ssp = "ssp585"
)
warming <- future - now
}
```
