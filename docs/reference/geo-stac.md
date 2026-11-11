# Satellite imagery from STAC catalogues

Search and read satellite imagery from any STAC API (SpatioTemporal
Asset Catalog), such as Element 84 Earth Search, which serves
Sentinel-2, Landsat and Copernicus DEM data as cloud-optimised GeoTIFFs:

- `geo_stac_collections()` lists the collections a catalogue offers.

- `geo_stac_search()` finds the scenes of a collection over an area and
  a period, with a cloud cover limit, and returns their footprints as an
  `sf` table, clearest first.

- `geo_stac_read()` reads chosen bands of those scenes into a
  `SpatRaster`. Only the window over your area is downloaded (GDAL reads
  cloud-optimised GeoTIFFs over HTTP), the scale and offset stored in
  the catalogue are applied, so Sentinel-2 bands come out as surface
  reflectance from 0 to about 1 (negative values from the offset are set
  to 0), and several scenes are combined into a per-pixel median, which
  removes most clouds.

The result goes straight into
[`geo_spectral_index()`](https://tidymapr-e72c18.gitlab.io/reference/geo_spectral_index.md),
[`geo_spectral_diversity()`](https://tidymapr-e72c18.gitlab.io/reference/geo_spectral_diversity.md)
or
[`map_raster()`](https://tidymapr-e72c18.gitlab.io/reference/geo-map.md).

## Usage

``` r
geo_stac_collections(url = tmr_stac_default)

geo_stac_search(
  collection,
  area,
  datetime = NULL,
  cloud_cover = 20,
  limit = 50,
  url = tmr_stac_default
)

geo_stac_read(items, assets, area = NULL, n = 1, crs = NULL, scale = TRUE)
```

## Arguments

- url:

  Root URL of a STAC API. Default: Element 84 Earth Search.

- collection:

  Collection id, for example `"sentinel-2-l2a"`, `"landsat-c2-l2"` or
  `"cop-dem-glo-30"`.

- area:

  Area of interest: an `sf` or terra object, or
  `c(xmin, ymin, xmax, ymax)` in degrees.

- datetime:

  Period: two dates (`c("2024-06-01", "2024-08-31")`) or one.

- cloud_cover:

  Largest cloud cover (percent) to accept; `NULL` for collections
  without cloud cover.

- limit:

  Largest number of scenes to return.

- items:

  Scenes from `geo_stac_search()`.

- assets:

  Bands to read, by asset name, for example `c("red", "nir")` for
  Sentinel-2 on Earth Search.

- n:

  Number of scenes to combine (the clearest first). One scene is read as
  is; several are combined into the per-pixel median.

- crs:

  Coordinate reference system of the result; by default that of the
  first scene.

- scale:

  Apply the scale and offset stored in the catalogue?

## Value

`geo_stac_collections()`: a tibble of `id`, `title`.
`geo_stac_search()`: an `sf` table with one row per scene (`id`,
`datetime`, `cloud_cover`, `platform`, `assets`). `geo_stac_read()`: a
`SpatRaster` with one layer per asset.

## See also

[`geo_spectral_index()`](https://tidymapr-e72c18.gitlab.io/reference/geo_spectral_index.md),
[`map_raster()`](https://tidymapr-e72c18.gitlab.io/reference/geo-map.md).

## Examples

``` r
if (FALSE) { # interactive() && rlang::is_installed(c("httr2", "terra", "sf"))
# Sentinel-2 over Luxembourg City, summer 2024
lux <- c(6.08, 49.57, 6.18, 49.65)
scenes <- geo_stac_search("sentinel-2-l2a", lux,
  datetime = c("2024-06-01", "2024-08-31"), cloud_cover = 10
)
scenes
img <- geo_stac_read(scenes, c("red", "nir"), area = lux, n = 3)
ndvi <- geo_spectral_index(img, "NDVI")
geo_map(title = "NDVI, Luxembourg City, summer 2024") |>
  map_raster(ndvi, name = "NDVI", palette = "Greens 3")
}
```
