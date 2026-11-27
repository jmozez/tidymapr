# Names of the 1 x 1 degree SRTM tiles that intersect a bounding box

SRTM tiles are named after their south-west corner, for example
`S07E146` for the tile from 7 to 6 degrees S and 146 to 147 degrees E.

## Usage

``` r
geo_srtm_tile_names(bbox)
```

## Arguments

- bbox:

  `c(xmin, ymin, xmax, ymax)` in degrees.

## Value

Character vector of tile names.

## Examples

``` r
geo_srtm_tile_names(c(145.4, -7, 147.3, -5.5))
#> [1] "S07E145" "S07E146" "S07E147" "S06E145" "S06E146" "S06E147"
```
