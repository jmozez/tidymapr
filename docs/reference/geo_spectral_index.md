# Spectral indices from satellite bands

`geo_spectral_index()` computes common normalised-difference indices
from a multi-band image (Sentinel-2, Landsat, drone imagery), as in
GeoSpaX's Forestry plug-in. Each index is `(a - b) / (a + b)`:

|           |               |                                     |
|-----------|---------------|-------------------------------------|
| `index`   | Bands (a, b)  | Measures                            |
| `"NDVI"`  | NIR, red      | green vegetation                    |
| `"GNDVI"` | NIR, green    | chlorophyll                         |
| `"NDRE"`  | NIR, red edge | canopy chlorophyll (Sentinel-2 B05) |
| `"NDWI"`  | green, NIR    | open water (McFeeters)              |
| `"MNDWI"` | green, SWIR1  | open water in built-up areas        |
| `"NDMI"`  | NIR, SWIR1    | vegetation moisture                 |
| `"NBR"`   | NIR, SWIR2    | burned areas                        |
| `"NDBI"`  | SWIR1, NIR    | built-up land                       |

Name the band layers with `bands`, for example
`bands = c(red = "B04", nir = "B08")`. Sentinel-2 names (`B03`, `B04`,
`B05`, `B08`, `B11`, `B12`) are recognised automatically.

With `threshold = "otsu"`, the index is also split into two classes by
Otsu's method (the cut that best separates the two peaks of the
histogram), and the area above the cut is reported, for example
vegetated or water area.

## Usage

``` r
geo_spectral_index(
  x,
  index = c("NDVI", "GNDVI", "NDRE", "NDWI", "MNDWI", "NDMI", "NBR", "NDBI"),
  bands = NULL,
  threshold = NULL
)
```

## Arguments

- x:

  A multi-band `SpatRaster` or file path.

- index:

  Index name (see table).

- bands:

  Named character vector mapping `red`, `green`, `nir`, `rededge`,
  `swir1`, `swir2` to layer names of `x`.

- threshold:

  `NULL` (no classes), `"otsu"`, or a number.

## Value

A `SpatRaster` with the index; with a threshold, a second layer `above`
(1/0), and attribute `"threshold"` with the cut value, the area above it
(km^2) and its share of valid cells.

## References

Otsu, N. (1979). A threshold selection method from gray-level
histograms. *IEEE Transactions on Systems, Man, and Cybernetics*, 9,
62-66.
[doi:10.1109/TSMC.1979.4310076](https://doi.org/10.1109/TSMC.1979.4310076)

## Examples

``` r
# Sentinel-2 Level-2A bands over Luxembourg, 24 August 2024 (terra)
s2 <- terra::rast(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
ndvi <- geo_spectral_index(s2, "NDVI", threshold = "otsu")
ndvi
#> class       : SpatRaster
#> size        : 90, 95, 2  (nrow, ncol, nlyr)
#> resolution  : 0.008333333, 0.008333333  (x, y)
#> extent      : 5.741667, 6.533333, 49.44167, 50.19167  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : sent2_L2A_2024-08-24
#>               sent2_L2A_2024-08-24
#> names       :     NDVI, above
#> min values  :  0.12161, FALSE
#> max values  : 0.638247,  TRUE
attr(ndvi, "threshold")
#> $index
#> [1] "NDVI"
#> 
#> $method
#> [1] "Otsu"
#> 
#> $cut
#> [1] 0.4495535
#> 
#> $area_above_km2
#> [1] 2317.608
#> 
#> $share_above
#> [1] 0.8545939
#> 
```
