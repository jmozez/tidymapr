# Save a map figure (PNG, PDF, SVG, TIFF, JPEG)

Writes ggplot maps from
[`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
[`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md),
[`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md),
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md)
(or any ggplot / patchwork object) to disk. Format is taken from the
file extension. `geo_save()` is the geospatial-oriented name;
[`tidydiversity::plot_save()`](https://tidydiversity.in4metrix.dev/reference/plot_save.html)
is the general journal-size helper (also used outside maps).

## Usage

``` r
geo_save(
  plot,
  path,
  width = 180,
  height = 140,
  units = c("mm", "cm", "in", "px"),
  dpi = 300,
  bg = "white",
  ...
)
```

## Arguments

- plot:

  A ggplot or patchwork map object.

- path:

  Output path. The extension selects the device (`.png`, `.pdf`, `.svg`,
  `.tiff`/`.tif`, `.jpg`/`.jpeg`).

- width, height:

  Size in `units`. For `geo_save()`, defaults are 180 mm wide and 140 mm
  tall (a comfortable single map panel).

- units:

  `"mm"`, `"cm"`, `"in"`, or `"px"`.

- dpi:

  Resolution for raster formats (default 300 for print).

- bg:

  Background colour (default `"white"`).

- ...:

  Passed to
  [`ggplot2::ggsave()`](https://rdrr.io/pkg/ggplot2/man/ggsave.html)
  (device-specific extras such as `compression`, `family`, or
  `useDingbats`).

## Value

`path`, invisibly.

## See also

[`tidydiversity::plot_save()`](https://tidydiversity.in4metrix.dev/reference/plot_save.html),
[`geo_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md),
[`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md)

## Examples

``` r
p <- plot_sites(
  geo_example_sites("wilhelm"), lon, lat,
  colour = elevation_band, basemap = "none",
  scale_bar = FALSE, north_arrow = FALSE
)
f <- tempfile(fileext = ".png")
geo_save(p, f, width = 80, height = 60, units = "mm")
```
