# Landscape fragmentation metrics

`geo_landscape()` measures how fragmented each class of a categorical
raster (land cover, habitat, forest/non-forest) is, with the standard
FRAGSTATS metrics (McGarigal and Marks 1995) as in the GeoSpaX
fragmentation plug-in. Patches are built with 8-neighbour rules; areas
are in hectares and edges in metres, measured on the ground for both
projected and geographic rasters.

Class-level metrics: `np` (number of patches), `ca` (class area, ha),
`pland` (share of the landscape, %), `lpi` (largest patch index, %),
`area_mn` (mean patch area, ha), `ed` (edge density, m/ha), `ai`
(aggregation index, %; He et al. 2000) and `mesh` (effective mesh size,
ha; Jaeger 2000), the expected size of the patch a randomly placed
animal finds itself in. Landscape-level metrics add Shannon's (`shdi`)
and Simpson's (`sidi`) diversity of classes.

## Usage

``` r
geo_landscape(x, level = c("class", "landscape"))
```

## Arguments

- x:

  A categorical `SpatRaster` (integer classes; `NA` is outside the
  landscape).

- level:

  `"class"` or `"landscape"`.

## Value

A tibble: one row per class (`level = "class"`) or one row.

## References

He HS, DeZonia BE, Mladenoff DJ (2000) An aggregation index (AI) to
quantify spatial patterns of landscapes. Landscape Ecology 15:591-601.

Jaeger JAG (2000) Landscape division, splitting index, and effective
mesh size. Landscape Ecology 15:115-130.

McGarigal K, Marks BJ (1995) FRAGSTATS: spatial pattern analysis program
for quantifying landscape structure. USDA Forest Service General
Technical Report PNW-351.

## See also

[`geo_dbscan()`](https://tidymapr-e72c18.gitlab.io/reference/geo_dbscan.md).

## Examples

``` r
r <- terra::rast(nrows = 30, ncols = 30, xmin = 0, xmax = 3000,
  ymin = 0, ymax = 3000, crs = "EPSG:32631")
terra::values(r) <- rep(c(1, 2), length.out = 900)
geo_landscape(r)
#> # A tibble: 2 × 9
#>   class    np    ca pland   lpi area_mn    ed    ai  mesh
#>   <dbl> <int> <dbl> <dbl> <dbl>   <dbl> <dbl> <dbl> <dbl>
#> 1     1    15   450    50  3.33      30  96.7  50.8    15
#> 2     2    15   450    50  3.33      30  96.7  50.8    15
```
