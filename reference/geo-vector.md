# Tidy vector geometry verbs

Native tidyverse-style wrappers around common **sf** operations. Inputs
accept `sf` tables or data frames with lon/lat (converted with
[`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md));
outputs are `sf` tibbles. sf reads and writes through **GDAL/OGR**, so
GeoPackage, shapefile, GeoJSON and similar formats work via
[`geo_vector_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
/
[`geo_vector_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
without calling GDAL utilities or the retired **rgdal** package. Prefer
GeoPackage over shapefile for new work.

## Usage

``` r
geo_buffer(data, dist, lon = lon, lat = lat, ...)

geo_intersection(data, y, lon = lon, lat = lat, ...)

geo_difference(data, y, lon = lon, lat = lat, ...)

geo_union(data, y = NULL, lon = lon, lat = lat, ...)

geo_crop(data, y, lon = lon, lat = lat, ...)

geo_area(data, lon = lon, lat = lat)

geo_centroid(data, lon = lon, lat = lat)

geo_bbox(data, lon = lon, lat = lat)

geo_join(
  data,
  y,
  join = c("intersects", "within", "contains", "nearest"),
  lon = lon,
  lat = lat,
  ...
)

geo_distance_to(data, to, lon = lon, lat = lat, ...)
```

## Arguments

- data:

  An `sf` object or a data frame with coordinates.

- dist:

  Buffer distance: metres for longitude/latitude data (each feature is
  buffered in an azimuthal equidistant projection centred on it, so the
  distance is true at any latitude), CRS units otherwise.

- lon, lat:

  Coordinate columns when `data` is not `sf`.

- ...:

  Passed to the underlying sf helper.

- y:

  Second geometry table for binary operations and joins.

- join:

  Spatial predicate for `geo_join()`: `"intersects"`, `"within"`,
  `"contains"`, or `"nearest"`.

- to:

  Geometry or coordinates to measure distance to.

## Value

- `geo_buffer()`, `geo_intersection()`, `geo_difference()`,
  `geo_union()`, `geo_crop()`, `geo_centroid()` and `geo_join()`: an
  `sf` table in the CRS of `data`.

- `geo_area()`: a tibble of the attributes of `data` with `area_m2`, the
  true area in square metres (spherical for longitude/latitude data).

- `geo_bbox()`: a one-row tibble with `xmin`, `ymin`, `xmax`, `ymax` and
  `crs`.

- `geo_distance_to()`: a tibble of the attributes of `data` with
  `distance_m`, the distance to the nearest feature of `to`
  (great-circle metres for longitude/latitude data, CRS units
  otherwise).

## Examples

``` r
sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
buf <- geo_buffer(sites, dist = 5000)
geo_area(buf)
#> # A tibble: 8 × 7
#>   site     lon   lat elevation elevation_band coordinate_note            area_m2
#>   <chr>  <dbl> <dbl>     <int> <fct>          <chr>                        <dbl>
#> 1 MW0200  145. -5.74       200 200 m          published bait GPS, doi:1…  7.88e7
#> 2 MW0700  145. -5.73       700 700 m          published bait GPS, doi:1…  7.88e7
#> 3 MW1200  145. -5.72      1200 1200 m         published bait GPS, doi:1…  7.88e7
#> 4 MW1700  145. -5.76      1700 1700 m         published bait GPS, doi:1…  7.88e7
#> 5 MW2200  145. -5.76      2200 2200 m         published bait GPS, doi:1…  7.88e7
#> 6 MW2700  145. -5.81      2700 2700 m         published bait GPS, doi:1…  7.88e7
#> 7 MW3200  145. -5.80      3200 3200 m         published bait GPS, doi:1…  7.88e7
#> 8 MW3700  145. -5.78      3700 3700 m         published bait GPS, doi:1…  7.88e7
```
