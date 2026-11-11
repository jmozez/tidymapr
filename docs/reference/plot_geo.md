# Map Hill numbers (and coverage) in geographic space

Plots site-level diversity estimates as points on an sf map, with an
optional raster backdrop. Uses
[`theme_tidymapr()`](https://tidymapr.in4metrix.dev/reference/theme_tidymapr.md)
and the colour-blind-safe Okabe-Ito / viridis scales.

## Usage

``` r
plot_geo(
  data,
  value = NULL,
  lon = lon,
  lat = lat,
  basemap = "esri",
  raster = NULL,
  coastline = NULL,
  size = 3,
  label = NULL,
  scale_bar = TRUE,
  north_arrow = TRUE,
  scale_bar_km = NULL,
  scale_units = c("metric", "imperial", "both"),
  legend_title = NULL,
  legend_position = "auto",
  legend_frame = TRUE,
  inset = FALSE,
  admin = NULL,
  admin_level = 1,
  admin_fill = FALSE
)
```

## Arguments

- data:

  An `sf` object or a data frame with `lon`/`lat` and an estimate column
  (for example the output of
  [`tidydiversity::div_estimate()`](https://rdrr.io/pkg/tidydiversity/man/div_estimate.html)
  joined to coordinates with
  [`tidydiversity::add_site_data()`](https://rdrr.io/pkg/tidydiversity/man/tidy-tidydiversity.html)
  /
  [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md)).

- value:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Column to map (fill / size).

- lon, lat:

  Coordinate columns when `data` is not `sf`.

- basemap:

  Basemap: `"none"`, `"coast"`, tile name, SpatRaster or path. See
  [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md).

- raster:

  Optional `SpatRaster` backdrop (used when `basemap` is `"none"`).

- coastline:

  Optional coastline `sf` for a coast basemap.

- size:

  Point size, or a bare column mapped to point size (combined with
  `value` like tmap size + col, e.g. Hill number and elevation).

- label:

  Optional column of site labels.

- scale_bar, north_arrow:

  Draw a scale bar and north arrow? `TRUE` uses the default style,
  `FALSE` none, or name a style (see
  [`annotation_scale_bar()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md)).

- scale_bar_km:

  Length of the scale bar in kilometres.

- scale_units:

  Scale bar units: `"metric"`, `"imperial"` or `"both"`.

- legend_title:

  Optional legend title (defaults to the value column).

- legend_position:

  `"auto"` (collision-aware inside corner), `"outside"`, or a corner
  `"bl"` / `"br"` / `"tl"` / `"tr"`.

- legend_frame:

  Draw a frame around an inside legend?

- inset:

  Overview map: `FALSE`, `TRUE`/`"auto"`, `"png"`, or a length-4 bbox.
  Uses the same collision reservation as the scale bar and north arrow.
  PNG insets prefer GADM provinces when cached.

- admin:

  Optional administrative boundaries (`sf` or ISO3 code); see
  [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md).

- admin_level:

  GADM level when `admin` is a country code.

- admin_fill:

  Fill admin polygons instead of outlines only.

## Value

A ggplot object with attribute `tmr_decoration`.

## Examples

``` r
est <- tibble::tibble(
  site = c("a", "b", "c"),
  lon = c(147.0, 147.2, 147.4),
  lat = c(-9.4, -9.5, -9.6),
  diversity = c(12, 18, 9)
)
plot_geo(est, diversity, lon, lat, basemap = "coast", label = site)
#> Warning: No Natural Earth land data available; install rnaturalearth.
#> ℹ Returning an empty land layer. Pass `coastline` or use a tile basemap.
```
