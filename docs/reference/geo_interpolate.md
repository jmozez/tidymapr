# Interpolate point measurements onto a grid

Predicts a numeric column of a point table at new locations by
inverse-distance weighting (IDW) or ordinary kriging, both computed in
C++. Distances are great-circle metres on longitude/latitude data and
map units otherwise.

For kriging, give the variogram (`model`, `nugget`, `psill`, `range`) or
leave `psill` and `range` as `NULL` to fit it from the data with
**gstat**
([`gstat::fit.variogram()`](https://rdrr.io/pkg/gstat/man/fit.variogram.html)).
The predictions and kriging variances match
[`gstat::krige()`](https://rdrr.io/pkg/gstat/man/krige.html) for the
same variogram. The fitted or given variogram is stored in attribute
`"variogram"`.

Both methods run in C++ on several cores; set the number with
`options(tidymapr.threads = n)`.

## Usage

``` r
geo_interpolate(
  data,
  value,
  grid,
  method = c("idw", "kriging"),
  power = 2,
  maxdist = Inf,
  model = c("Exp", "Sph", "Gau"),
  nugget = 0,
  psill = NULL,
  range = NULL,
  variance = TRUE,
  name = "prediction"
)
```

## Arguments

- data:

  An `sf` point table.

- value:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Numeric column to interpolate.

- grid:

  Where to predict: a
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
  template (every cell centre is predicted) or an `sf` point table.

- method:

  `"idw"` or `"kriging"`.

- power:

  IDW distance power (default 2).

- maxdist:

  IDW search radius; samples farther away are ignored (default `Inf`,
  all samples).

- model:

  Kriging variogram model: `"Exp"` (exponential), `"Sph"` (spherical) or
  `"Gau"` (Gaussian), with gstat's parameterisation.

- nugget, psill, range:

  Variogram nugget, partial sill and range. `psill` and `range` default
  to a fit with gstat. `range` is in metres on longitude/latitude data
  and in map units otherwise.

- variance:

  For kriging, also return the kriging variance? Skipping it (`FALSE`)
  makes large grids much faster.

- name:

  Name of the prediction layer or column.

## Value

For a raster `grid`, a `SpatRaster` with layer `name` (and `"variance"`
for kriging). For an `sf` `grid`, the same table with these columns
added.

## References

Isaaks, E. H. and Srivastava, R. M. (1989). *An Introduction to Applied
Geostatistics*. Oxford University Press.

## Examples

``` r
sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
bb <- sf::st_bbox(sites)
grid <- terra::rast(nrows = 20, ncols = 20, xmin = bb[["xmin"]],
  xmax = bb[["xmax"]], ymin = bb[["ymin"]], ymax = bb[["ymax"]],
  crs = "EPSG:4326")
idw <- geo_interpolate(sites, elevation, grid, power = 2)
idw
#> class       : SpatRaster
#> size        : 20, 20, 1  (nrow, ncol, nlyr)
#> resolution  : 0.013753, 0.0045315  (x, y)
#> extent      : 145.058, 145.333, -5.81424, -5.72361  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> name        :  prediction
#> min value   :   237.59271
#> max value   : 3631.580387

# Kriging with a given variogram (fit one with gstat by leaving
# psill and range NULL)
geo_interpolate(sites, elevation, grid, method = "kriging",
  model = "Exp", psill = 4e5, range = 8000)
#> class       : SpatRaster
#> size        : 20, 20, 2  (nrow, ncol, nlyr)
#> resolution  : 0.013753, 0.0045315  (x, y)
#> extent      : 145.058, 145.333, -5.81424, -5.72361  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> names       :  prediction,      variance
#> min values  :  356.799255,  32323.955311
#> max values  : 3543.455139, 376588.725393
```
