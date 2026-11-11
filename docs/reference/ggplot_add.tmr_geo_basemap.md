# Add a tidymapr basemap to a ggplot

S3 method for
[`ggplot2::ggplot_add()`](https://rdrr.io/pkg/ggplot2/man/update_ggplot.html)
so that `ggplot2::ggplot() + geo_basemap(...)` works. Not intended to be
called directly.

## Usage

``` r
# S3 method for class 'tmr_geo_basemap'
ggplot_add(object, plot, object_name)
```

## Arguments

- object:

  A `tmr_geo_basemap` from
  [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md).

- plot:

  A ggplot object.

- object_name:

  Not used.

## Value

`plot` with basemap layers added.
