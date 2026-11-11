# Map tree stems over topography

`plot_topo()` draws individual trees or stems over a topographic
backdrop for ForestGEO-style and similar plot inventories (Wanang and
other large forest dynamics plots). Points use local projected
coordinates in metres (`gx`, `gy`) or geographic lon/lat. The backdrop
can be contour lines, a DEM / hillshade raster, or both. Colour by
species or size (DBH), and optionally draw the plot boundary.

Expected columns for a ForestGEO-like table: `plot`, `treeID`, `stemID`,
`gx`, `gy` (metres from the plot origin), `dbh`, `species`, `status`.
Geographic inventories may use `lon` / `lat` instead of `gx` / `gy`.

Pass your own stem inventory.
[`geo_example_stems()`](https://tidymapr-e72c18.gitlab.io/reference/geo_example_stems.md)
is simulated test data for checking code, not a real plot, so do not
publish maps drawn from it.

## Usage

``` r
plot_topo(
  data,
  x = "gx",
  y = "gy",
  lon = NULL,
  lat = NULL,
  colour = NULL,
  size = NULL,
  dem = NULL,
  boundary = NULL,
  contours = TRUE,
  hillshade = TRUE,
  contour_breaks = NULL,
  basemap = "none",
  palette = c("okabe_ito", "grey"),
  point_alpha = 0.85
)
```

## Arguments

- data:

  A data frame of stems/trees, or an `sf` object.

- x, y:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Local metre columns (defaults `gx`, `gy`). Ignored when `lon`/`lat`
  are set or `data` is `sf`.

- lon, lat:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Optional geographic coordinates. When supplied, they override `x`/`y`.

- colour:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Grouping column (species, status) or a continuous size such as DBH.

- size:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Optional column mapped to point size (typically `dbh`). When `NULL`
  and `dbh` exists, DBH is used.

- dem:

  Optional
  [`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
  elevation surface for hillshade and/or contours. In local metre
  coordinates the raster should use the same origin as `gx`/`gy`.

- boundary:

  Optional `sf` polygon of the plot boundary, or a numeric bbox
  `c(xmin, ymin, xmax, ymax)`.

- contours:

  Draw contour lines from `dem`?

- hillshade:

  Draw a hillshade backdrop from `dem`?

- contour_breaks:

  Contour interval, or a vector of breaks. When `NULL`, pretty breaks
  are chosen.

- basemap:

  Passed to
  [`geo_basemap()`](https://tidymapr-e72c18.gitlab.io/reference/geo_basemap.md)
  when using lon/lat (for example `"coast"`). Ignored for local metre
  coordinates.

- palette:

  Discrete palette when `colour` is categorical.

- point_alpha:

  Point opacity.

## Value

A ggplot object.

## Examples

``` r
stems <- geo_example_stems()
dem <- geo_example_dem()
plot_topo(stems, colour = species, size = dbh, dem = dem, boundary = c(0, 0, 100, 100))
```
