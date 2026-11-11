# Download or read elevation (SRTM-style DEM)

Fetches a digital elevation model for a bounding box or set of sites,
with an on-disk cache and an offline `path` for local GeoTIFFs. Prefers
**geodata** (SRTM via `elevation_*`) when installed, then **elevatr**,
then a user-supplied file. Cite Jarvis et al. (2008) / NASA SRTM when
publishing maps that use these surfaces.

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

  Numeric vector `c(xmin, ymin, xmax, ymax)` in WGS84, or an `sf` /
  `SpatExtent` object.

- path:

  Local GeoTIFF (or directory of GeoTIFFs) for offline use.

- cache_dir:

  Cache directory. Defaults to
  `tools::R_user_dir("tidymapr", "cache")/elevation`.

- download:

  Download when the cache is empty? Set `FALSE` on CRAN or offline
  runners.

- z:

  Zoom / resolution hint for elevatr (1-14). Ignored by geodata.

- buffer:

  Extra degrees added around the site bbox (default 0.1).

## Value

A
[`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
elevation surface (metres).

## References

Jarvis, A., Reuter, H. I., Nelson, A. and Guevara, E. (2008).
Hole-filled SRTM for the globe Version 4. CGIAR-CSI.
<https://srtm.csi.cgiar.org/>

## Examples

``` r
dem <- geo_example_dem()
terra::nlyr(dem)
#> [1] 1
```
