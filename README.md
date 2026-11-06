
# tidymapr <a href="https://jmozez.github.io/tidymapr/"><img src="man/figures/logo.png" align="right" height="139" alt="tidymapr website" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/jmozez/tidymapr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/jmozez/tidymapr/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/test-coverage.yaml)
[![lint](https://github.com/jmozez/tidymapr/actions/workflows/lint.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/lint.yaml)
[![pkgdown](https://github.com/jmozez/tidymapr/actions/workflows/pkgdown.yaml/badge.svg)](https://jmozez.github.io/tidymapr/)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jmozez/tidymapr/blob/main/LICENSE.md)
<!-- badges: end -->

<div class="tmr-hero">

**Tidy mapping verbs for biodiversity and spatial ecology.**

tidymapr is the mapping companion to
[tidydiversity](https://jmozez.github.io/tidydiversity/). tidydiversity
estimates diversity, tidymapr puts it on a map, and the two work
together the way dplyr and ggplot2 do. Every verb takes a data frame and
returns a tibble, an `sf` table, a `SpatRaster` or a ggplot.

</div>

<div class="tmr-cards">

<div class="tmr-card">

### Sites and rasters

Sites as `sf` tables, raster values joined as columns, occurrence
cleaning and GBIF records, vector and raster verbs, GDAL-backed I/O.

</div>

<div class="tmr-card">

### Publication maps

Study-site maps, Hill numbers on maps and stems over topography, with
basemaps, scale bars and north arrows, saved at journal sizes.

</div>

<div class="tmr-card">

### Spatial ecology

Geographic and environmental distance decay, Moran’s I, dbMEM, spatial
rarefaction, grain, mid-domain nulls and tidy species distribution
models.

</div>

</div>

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("jmozez/tidymapr")
```

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
```

<img src="man/figures/README-example-1.png" alt="Observed ant richness at each Mt Wilhelm site in the dry season" width="100%" />

Site coordinates from `geo_example_sites()` are illustrative; replace
them with your own GPS before publication.

## Functions

| Family                           | Functions                                                                                                                                |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Sites and occurrences            | `geo_as_sf()`, `geo_drop_geometry()`, `geo_extract()`, `geo_clean()`, `geo_gbif()`, `as_sf()`, `as_spat_raster()`, `geo_as_features()`   |
| Distances and spatial statistics | `geo_distance()`, `geo_decay()`, `geo_moran()`, `geo_mem()`, `geo_rarefy_spatial()`, `geo_grain()`, `geo_middomain()`                    |
| Forest plot stem maps            | `stems_quadrat()`, `stems_habitat()`, `stems_neighbours()`, `stems_habitat_test()`                                                       |
| Maps                             | `plot_sites()`, `plot_geo()`, `plot_topo()`, `geo_basemap()`, `geo_save()`, `theme_tidymapr()`                                           |
| Vector and raster                | `geo_read()`, `geo_write()`, `geo_vector_*()`, `geo_raster_*()`, `geo_buffer()`, `geo_crop()`, `geo_union()`, `geo_area()`, `geo_join()` |
| Environmental layers             | `geo_bioclim()`, `geo_worldclim()`, `geo_chelsa()`, `geo_elevation()`, `geo_gadm()`                                                      |
| Species distribution models      | `sdm_fit()`, `sdm_predict()`, `sdm_evaluate()`, `plot_sdm()`                                                                             |
| Example data                     | `geo_example_sites()`, `geo_example_stems()`, `geo_example_dem()`, `geo_example_censuses()`                                              |

## Gallery

### Study-site map

<img src="man/figures/README-geo-sites-1.png" alt="Study-site map with coast basemap, labels, scale bar and north arrow" width="100%" />

### Stems over topography

<img src="man/figures/README-geo-topo-1.png" alt="Stem map over hillshade and contours" width="100%" />

### Distance decay

<img src="man/figures/README-geo-decay-1.png" alt="Ant dissimilarity against great-circle distance by season" width="100%" />

See the
[gallery](https://jmozez.github.io/tidymapr/articles/gallery.html) for
every map with its table and code.

## Licence

MIT © 2026 Jimmy Moses
