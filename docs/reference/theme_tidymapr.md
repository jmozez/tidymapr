# Map theme

`theme_tidymapr()` is the clean ggplot2 theme used by every tidymapr
map: white background, black text, plain facet strips and a legend at
the bottom. It matches
[`tidydiversity::theme_tidydiversity()`](https://rdrr.io/pkg/tidydiversity/man/theme_tidydiversity.html),
so maps and diversity plots from the two packages look the same side by
side.

## Usage

``` r
theme_tidymapr(
  base_size = 11,
  base_family = "",
  legend_position = "bottom",
  grid = c("y", "x", "xy", "none")
)
```

## Arguments

- base_size:

  Base font size in points.

- base_family:

  Base font family.

- legend_position:

  Legend position, passed to
  [`ggplot2::theme()`](https://rdrr.io/pkg/ggplot2/man/theme.html).

- grid:

  Draw major grid lines: `"y"`, `"x"`, `"xy"` or `"none"`.

## Value

A ggplot2 theme.

## Examples

``` r
library(ggplot2)
ggplot(geo_example_sites(), aes(lon, lat, colour = elevation_band)) +
  geom_point() +
  theme_tidymapr(grid = "none")
```
