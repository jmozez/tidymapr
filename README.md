
# tidymapr <a href="https://gitlab.com/jimmy.moses/tidymapr"><img src="man/figures/logo.png" align="right" height="139" alt="tidymapr website" /></a>

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://gitlab.com/jimmy.moses/tidymapr/-/blob/main/LICENSE.md)
<!-- badges: end -->

<div class="tmr-hero">

**Tidy mapping, spatial analysis and publication cartography.**

tidymapr makes publication-quality maps and does spatial analysis in R, in
the style of a desktop GIS: one call can choose the projection,
classification, colour ramps, legends, scale bar and north arrow, and
explain each choice. It is compatible with the
GeoSpaX desktop GIS, following the
same cartographic conventions and reading and writing the same formats.
For ecology, it is the mapping companion to
[tidydiversity](https://gitlab.com/jimmy.moses/tidydiversity):
tidydiversity estimates diversity, tidymapr puts it on a map. Every verb
takes a data frame and returns a tibble, an `sf` table, a `SpatRaster` or a
ggplot.

</div>

<div class="tmr-cards">
<div class="tmr-card">

### Maps and cartography

Automatic, explained maps with `geo_automap()`; choropleth, bubble and
layered maps; Equal Earth, Mercator, UTM and other projections; graticules;
GeoSpaX-style scale bars, north arrows and legends; topographic and DEM
basemaps.

</div>
<div class="tmr-card">

### Spatial analysis and remote sensing

Kriging with measurement error, inverse-distance weighting, Getis-Ord
hotspots, local Moran's I, terrain hydrology, NDVI and other spectral
indices, spectral diversity, all in fast multi-core C++.

</div>
<div class="tmr-card">

### Data and ecology

GIS, CAD and remote sensing formats (netCDF, HDF, Sentinel-2, AutoCAD
DXF and more); diversity surfaces with uncertainty, distance decay,
species distribution models and forest plot maps with tidydiversity.

</div>
</div>

## Installation

Install the development version from GitLab:

``` r
# install.packages("pak")
pak::pak("gitlab::jimmy.moses/tidymapr")
```

The source code lives on GitLab, <https://gitlab.com/jimmy.moses/tidymapr>.

**sf**, **terra** and the other spatial packages are optional; install
the ones you need with `install.packages(c("sf", "terra"))`.

## Example

`png_ants` (from tidydiversity) records ground ants at baits along the
Mt Wilhelm elevational gradient in Papua New Guinea. Estimate richness
with tidydiversity and map it with tidymapr in one pipeline:

``` r
library(tidydiversity)
library(tidymapr)
library(dplyr)

sites <- geo_example_sites("wilhelm")

div_estimate(png_ants, q = 0, nboot = 0, .by = season) |>
  left_join(sites, by = "site") |>
  filter(season == "dry") |>
  plot_geo(estimate, lon, lat, label = site, basemap = "coast")
#> Warning: No Natural Earth land data available; install rnaturalearth.
#> i Returning an empty land layer. Pass `coastline` or use a tile basemap.
```

<img src="man/figures/README-example-1.png" alt="Observed ant richness at each Mt Wilhelm site in the dry season" width="100%" />

Site coordinates from `geo_example_sites()` are the published bait GPS
of the Mt Wilhelm ant survey (`png_ants_sites`; Mottl, Moses and Klimes
2023,
[doi:10.5281/zenodo.8191946](https://doi.org/10.5281/zenodo.8191946)).

## Functions

| Family                           | Functions                                                                                                                                                                  |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Sites and occurrences            | `geo_as_sf()`, `geo_drop_geometry()`, `geo_extract()`, `geo_clean()`, `geo_gbif()`, `as_sf()`, `as_spat_raster()`, `geo_as_features()`                                     |
| Distances and spatial statistics | `geo_distance()`, `geo_decay()`, `geo_moran()`, `geo_mem()`, `geo_rarefy_spatial()`, `geo_grain()`, `geo_middomain()`                                                      |
| Forest plot stem maps            | `stems_quadrat()`, `stems_habitat()`, `stems_neighbours()`, `stems_habitat_test()`                                                                                         |
| Maps                             | `plot_sites()`, `plot_geo()`, `plot_topo()`, `geo_basemap()`, `geo_save()`, `theme_tidymapr()`                                                                             |
| Vector and raster                | `geo_read()`, `geo_write()`, `geo_vector_*()`, `geo_raster_*()`, `geo_buffer()`, `geo_crop()`, `geo_union()`, `geo_area()`, `geo_join()`                                   |
| Environmental layers             | `geo_bioclim()`, `geo_worldclim()`, `geo_chelsa()`, `geo_elevation()`, `geo_gadm()`                                                                                        |
| Species distribution models      | `sdm_fit()`, `sdm_predict()`, `sdm_evaluate()`, `plot_sdm()`                                                                                                               |
| Example data                     | `png_ants_sites` and `geo_example_sites()` (published Mt Wilhelm GPS); `geo_example_stems()`, `geo_example_dem()` and `geo_example_censuses()` (simulated, for tests only) |

## Gallery

### Study-site map

    #> Warning: No Natural Earth land data available; install rnaturalearth.
    #> i Returning an empty land layer. Pass `coastline` or use a tile basemap.

<img src="man/figures/README-geo-sites-1.png" alt="Study-site map with coast basemap, labels, scale bar and north arrow" width="100%" />

### Stems over topography

<img src="man/figures/README-geo-topo-1.png" alt="Stem map over hillshade and contours" width="100%" />

### Distance decay

<img src="man/figures/README-geo-decay-1.png" alt="Ant dissimilarity against great-circle distance by season" width="100%" />

See the
[gallery](https://tidymapr-e72c18.gitlab.io/articles/gallery.html)
for every map with its table and code.

## Licence

MIT © 2026 Jimmy Moses
