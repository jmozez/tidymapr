# Download or read elevation (SRTM-style DEM)

Fetches a digital elevation model for a bounding box or set of sites,
with an on-disk cache, or reads local files.

## Usage

``` r
geo_elevation(
  data = NULL,
  lon = lon,
  lat = lat,
  bbox = NULL,
  path = NULL,
  cache_dir = NULL,
  download = TRUE,
  z = 5,
  buffer = 0.1
)
```

## Arguments

- data:

  Optional data frame of sites with `lon`/`lat` used to build the
  bounding box when `bbox` is `NULL`.

- lon, lat:

  Coordinate columns of `data`.

- bbox:

  Numeric vector `c(xmin, ymin, xmax, ymax)` in WGS84 (the order of
  [`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html),
  not of
  [`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html)),
  or an `sf`, `SpatExtent` or `SpatRaster` object.

- path:

  Local raster file, folder of tiles, or vector of files.

- cache_dir:

  Cache directory. Defaults to
  `tools::R_user_dir("tidymapr", "cache")/elevation`.

- download:

  Download when the cache is empty? Set `FALSE` on CRAN or offline
  runners.

- z:

  Zoom / resolution hint for elevatr (1-14), the last fallback.

- buffer:

  Extra degrees added around the site bbox (default 0.1).

## Value

A one-layer
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
elevation surface (metres).

## Details

**Local files.** `path` may be one raster file or a folder of tiles:
GeoTIFF (`.tif`), SRTM height files (`.hgt`, also gzipped `.hgt.gz`) or
`.zip` archives containing them. Adjacent tiles are mosaicked into one
surface (earlier versions kept only the first tile). A warning is given
when tiles differ in coordinate reference system or resolution.

**Download.** Every 1 x 1 degree SRTM tile that intersects the bounding
box is fetched (1 arc-second where available, from the public "skadi"
archive of the AWS Terrain Tiles), cached in `cache_dir`, mosaicked and
cropped to the box. If that archive cannot be reached, the tiles of
**geodata** (`elevation_3s()`, every tile intersecting the box) or
**elevatr** are used. Cite NASA SRTM (Farr et al. 2007) when publishing
maps that use these surfaces.

## References

Farr, T. G. et al. (2007). The Shuttle Radar Topography Mission. Reviews
of Geophysics, 45, RG2004.
[doi:10.1029/2005RG000183](https://doi.org/10.1029/2005RG000183)

## Examples

``` r
dem <- geo_example_dem()
terra::nlyr(dem)
#> [1] 1
```
