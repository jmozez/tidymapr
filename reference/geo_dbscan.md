# Point clusters with DBSCAN

`geo_dbscan()` finds clusters of points with DBSCAN (Ester et al. 1996),
the clustering tool of the GeoSpaX plug-ins: points with at least
`min_pts` neighbours within `eps` form cluster cores, points near a core
join its cluster, and the rest are noise. Distances are in metres for
geographic data (points are projected to an equal-area projection
centred on them), so `eps` means the same thing anywhere on Earth. The
search uses a grid index in C++. Each cluster also gets its outline as a
convex hull.

## Usage

``` r
geo_dbscan(data, eps, min_pts = 5, lon = lon, lat = lat, crs = 4326)
```

## Arguments

- data:

  An `sf` point table, or a data frame with coordinate columns.

- eps:

  Neighbourhood radius, in metres (or in the units of a projected CRS).

- min_pts:

  Smallest number of points within `eps` (the point itself included) for
  a core point.

- lon, lat:

  \<[`data-masking`](https://dplyr.tidyverse.org/reference/dplyr_data_masking.html)\>
  Coordinate columns when `data` is not `sf`.

- crs:

  Coordinate reference system of `lon`/`lat` (default WGS 84).

## Value

The points as `sf` with `cluster` (integer; `0` for noise) and `core`
(logical). Attribute `"hulls"` holds an `sf` table of cluster outlines
with the number of points in each.

## References

Ester M, Kriegel H-P, Sander J, Xu X (1996) A density-based algorithm
for discovering clusters in large spatial databases with noise.
Proceedings of KDD-96: 226-231.

## See also

[`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
for hot spots of values,
[`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md)
for fragmentation.

## Examples

``` r
# Earthquakes near Fiji since 1964 (datasets::quakes)
cl <- geo_dbscan(datasets::quakes, eps = 50000, min_pts = 15,
  lon = long, lat = lat)
table(cl$cluster)
#> 
#>   0   1   2   3   4   5   6   7   8   9 
#> 513 259  23  25  76  19  26  17  27  15 
attr(cl, "hulls")
#> Simple feature collection with 9 features and 2 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -179.98 ymin: -28.1 xmax: 179.69 ymax: -10.96
#> Geodetic CRS:  WGS 84
#>   cluster   n                       geometry
#> 1       1 259 POLYGON ((-179.36 -22.64, -...
#> 2       2  23 POLYGON ((-175.94 -20.31, -...
#> 3       3  25 POLYGON ((165.76 -12.08, 16...
#> 4       4  76 POLYGON ((-179.98 -25.59, 1...
#> 5       5  19 POLYGON ((-174.68 -16.1, -1...
#> 6       6  26 POLYGON ((169.5 -19.64, 169...
#> 7       7  17 POLYGON ((-173.2 -15.66, -1...
#> 8       8  27 POLYGON ((-177.75 -28.1, -1...
#> 9       9  15 POLYGON ((-175.36 -23.95, -...
```
