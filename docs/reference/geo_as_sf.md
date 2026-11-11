# Convert site coordinates to an sf tibble

Builds a consistent [sf](https://rdrr.io/pkg/sf/man/sf.html) tibble from
longitude and latitude columns (default CRS EPSG:4326), drops empty
coordinates, and keeps the site identifier. Already-sf inputs are
validated and returned with the same CRS check.

## Usage

``` r
geo_as_sf(data, lon = lon, lat = lat, site = NULL, crs = 4326, drop_na = TRUE)

geo_drop_geometry(data)
```

## Arguments

- data:

  A data frame with coordinates, or an `sf` object.

- lon, lat:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Longitude and latitude columns. Ignored when `data` is already `sf`.

- site:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Optional site identifier to keep. Use `NULL` to skip.

- crs:

  Coordinate reference system. Default `4326` (WGS84).

- drop_na:

  Drop rows with missing or non-finite coordinates?

## Value

An `sf` tibble (`tmr_geo_sf`) with a point geometry column.

## Examples

``` r
sites <- tibble::tibble(
  site = c("a", "b", "c"),
  lon = c(147.1, 147.2, NA_real_),
  lat = c(-9.4, -9.5, -9.6),
  elevation = c(200, 700, 1200)
)
geo_as_sf(sites, lon, lat, site = site)
#> Simple feature collection with 2 features and 4 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 147.1 ymin: -9.5 xmax: 147.2 ymax: -9.4
#> Geodetic CRS:  WGS 84
#> # A tibble: 2 × 5
#>   site    lon   lat elevation     geometry
#> * <chr> <dbl> <dbl>     <dbl>  <POINT [°]>
#> 1 a      147.  -9.4       200 (147.1 -9.4)
#> 2 b      147.  -9.5       700 (147.2 -9.5)
```
