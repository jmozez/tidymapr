# ESA WorldCover land cover

`geo_landcover()` reads the ESA WorldCover 10 m global land-cover map
(Zanaga et al. 2022) for an area, straight from its public
cloud-optimised GeoTIFFs (3 x 3 degree tiles on AWS; also served as the
`"esa-worldcover"` collection of the Microsoft Planetary Computer STAC
API, see
[`geo_stac_search()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)).
Only the window over the area is read.

Classes: 10 tree cover, 20 shrubland, 30 grassland, 40 cropland, 50
built-up, 60 bare or sparse vegetation, 70 snow and ice, 80 permanent
water, 90 herbaceous wetland, 95 mangroves, 100 moss and lichen.

## Usage

``` r
geo_landcover(area, classes = NULL, template = NULL, year = 2021)

geo_worldcover_tiles(bbox)
```

## Arguments

- area:

  Area: `sf`, `sfc`, `SpatVector`, `SpatRaster`, `SpatExtent` or
  `c(xmin, ymin, xmax, ymax)` in degrees.

- classes:

  Optional class codes to keep, for example `c(10, 95)` for forest (tree
  cover and mangroves). The result is then `TRUE` for those classes and
  `FALSE` elsewhere.

- template:

  Optional `SpatRaster` (for example a DEM) whose grid the result should
  share. Land cover is resampled to it with the modal class (`"mode"`),
  reading coarser overviews when the template is coarser than 10 m.

- year:

  2021 (version 200, default) or 2020 (version 100).

- bbox:

  `c(xmin, ymin, xmax, ymax)` in degrees.

## Value

A `SpatRaster` of class codes, or a logical layer with `classes`.

`geo_worldcover_tiles()`: tile names such as `"S09E144"` (the south-west
corner of each 3 x 3 degree tile).

## References

Zanaga, D. et al. (2022). ESA WorldCover 10 m 2021 v200.
[doi:10.5281/zenodo.7254221](https://doi.org/10.5281/zenodo.7254221)

## Examples

``` r
if (FALSE) { # interactive() && rlang::is_installed("terra")
forest <- geo_landcover(c(146.5, -6.6, 146.7, -6.4), classes = c(10, 95))
}
```
