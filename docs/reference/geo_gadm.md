# Administrative boundaries from GADM

Downloads (and caches) Global Administrative Areas (GADM) boundaries as
an `sf` tibble via **geodata**. Level 0 is the country outline, level 1
provinces / states, and level 2 districts. Use the result as `admin` in
[`plot_sites()`](https://tidymapr-e72c18.gitlab.io/reference/plot_sites.md)
/
[`plot_geo()`](https://tidymapr-e72c18.gitlab.io/reference/plot_geo.md),
as an overview for `geo_annotation_inset()`, or to clip occurrences with
[`geo_intersection()`](https://tidymapr-e72c18.gitlab.io/reference/geo-vector.md)
/
[`geo_raster_mask()`](https://tidymapr-e72c18.gitlab.io/reference/geo-raster.md).

## Usage

``` r
geo_gadm(
  country = "PNG",
  level = 0,
  path = NULL,
  cache_dir = NULL,
  download = TRUE,
  version = "4.1"
)
```

## Arguments

- country:

  ISO3 code or country name understood by `geodata::gadm()` (for example
  `"PNG"` or `"Papua New Guinea"`).

- level:

  Administrative level: `0` (country), `1` (province), or `2`
  (district).

- path:

  Optional local GeoPackage / shapefile / RDS previously saved with
  [`geo_vector_write()`](https://tidymapr-e72c18.gitlab.io/reference/geo-io.md).
  When set, no download is attempted.

- cache_dir:

  Cache directory. Defaults to
  `tools::R_user_dir("tidymapr", "cache")/gadm`.

- download:

  Download when the cache is empty? Set `FALSE` on CRAN or offline
  runners.

- version:

  GADM version string passed to geodata (default `"4.1"`).

## Value

An `sf` tibble of multipolygons (class `tmr_geo_sf`).

## Details

GADM data are free for academic and non-commercial use; redistribution
of the full database (or derived commercial products) is restricted. See
<https://gadm.org/license.html>. This package never bundles GADM files;
each call downloads into a user cache (or reads `path`) and the download
is skipped when `download = FALSE` (the CRAN / offline default pattern).

## References

Global Administrative Areas (GADM). <https://gadm.org/>

## See also

[`geo_vector_read()`](https://tidymapr-e72c18.gitlab.io/reference/geo-io.md),
[`geo_vector_write()`](https://tidymapr-e72c18.gitlab.io/reference/geo-io.md),
[`plot_sites()`](https://tidymapr-e72c18.gitlab.io/reference/plot_sites.md)

## Examples

``` r
# Offline: read a previously cached GeoPackage
# png <- geo_gadm("PNG", level = 1, path = "png_adm1.gpkg")
#
# Online (needs geodata + network; skipped on CRAN):
# png <- geo_gadm("PNG", level = 1)
# plot_sites(geo_example_sites("wilhelm"), lon, lat, admin = png)
```
