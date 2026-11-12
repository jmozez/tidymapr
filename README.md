
# tidymapr <a href="https://tidymapr.in4metrix.dev/"><img src="man/figures/logo.png" align="right" height="139" alt="tidymapr website" /></a>

<!-- badges: start -->
[![R-CMD-check](https://github.com/jmozez/tidymapr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/R-CMD-check.yaml)
[![Tests and coverage](https://github.com/jmozez/tidymapr/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/test-coverage.yaml)
[![Lint](https://github.com/jmozez/tidymapr/actions/workflows/lint.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/lint.yaml)
[![Website deploy](https://github.com/jmozez/tidymapr/actions/workflows/vercel.yaml/badge.svg)](https://github.com/jmozez/tidymapr/actions/workflows/vercel.yaml)
[![GitHub](https://img.shields.io/badge/source-GitHub-181717?logo=github)](https://github.com/jmozez/tidymapr)

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jmozez/tidymapr/blob/main/LICENSE.md)
[![Website](https://img.shields.io/badge/website-tidymapr.in4metrix.dev-349295)](https://tidymapr.in4metrix.dev)
[![Diversity with tidydiversity](https://img.shields.io/badge/diversity%20with-tidydiversity-1A9E93)](https://tidydiversity.in4metrix.dev)
[![Compatible with GeoSpaX](https://img.shields.io/badge/compatible%20with-GeoSpaX-11376B)](https://geospax.in4metrix.dev)
[![CRAN checks](https://img.shields.io/badge/R%20CMD%20check-as--cran-349295)](https://tidymapr.in4metrix.dev/cran-check.txt)
<!-- badges: end -->

<div class="tmr-hero">

**Tidy mapping, spatial analysis and publication cartography.**

tidymapr makes publication-quality maps and does spatial analysis in R, in
the style of a desktop GIS: one call can choose the projection,
classification, colour ramps, legends, scale bar and north arrow, and
explain each choice. It is compatible with the
[GeoSpaX](https://geospax.in4metrix.dev) desktop GIS, following the
same cartographic conventions, reading and writing the same formats and
running the same recipes.
For ecology, it is the mapping companion to
[tidydiversity](https://tidydiversity.in4metrix.dev/):
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

Install a ready-built binary from r-universe (Windows, macOS and Linux; no
compiler needed):

```r
install.packages("tidymapr",
  repos = c("https://jmozez.r-universe.dev", "https://cloud.r-project.org"))
```

Or build the latest development version from GitHub source (needs Rtools on
Windows or the Xcode command-line tools on macOS):

```r
# install.packages("pak")
pak::pak("jmozez/tidymapr")
```

The source code lives on GitHub, <https://github.com/jmozez/tidymapr>, with a mirror on GitLab, <https://gitlab.com/jimmy.moses/tidymapr>.

**sf**, **terra** and the other spatial packages are optional; install
the ones you need with `install.packages(c("sf", "terra"))`.

## User guide

New to tidymapr, or to spatial analysis? The
[User guide](https://tidymapr.in4metrix.dev/articles/user-guide.html)
explains, chapter by chapter, how to install and run tidymapr in RStudio
and what every analysis means: the concept and theory, runnable code on
real data, figures and tables, how to interpret them and how to report
them in a paper.

1. [Install and run in RStudio](https://tidymapr.in4metrix.dev/articles/guide-01-install.html)
2. [Cartography concepts: projections, classes and colour](https://tidymapr.in4metrix.dev/articles/guide-02-cartography.html)
3. [Spatial autocorrelation: Moran's I, LISA and hot spots](https://tidymapr.in4metrix.dev/articles/guide-03-autocorrelation.html)
4. [Interpolation: IDW and kriging](https://tidymapr.in4metrix.dev/articles/guide-04-interpolation.html)
5. [Species distribution models: Maxent and ensembles](https://tidymapr.in4metrix.dev/articles/guide-05-sdm.html)
6. [Remote sensing and terrain](https://tidymapr.in4metrix.dev/articles/guide-06-remote-sensing-terrain.html)
7. [Point clusters and landscape fragmentation](https://tidymapr.in4metrix.dev/articles/guide-07-patterns-landscapes.html)
8. [Data in and out, GBIF cleaning, web maps and recipes](https://tidymapr.in4metrix.dev/articles/guide-08-data-webmaps-recipes.html)
9. [Distance decay and spatial eigenvectors](https://tidymapr.in4metrix.dev/articles/guide-09-decay-mem.html)

## Example

A layered map in the style of a desktop GIS layout: each layer gets its
own legend section with the symbol for its geometry, and the scale bar,
north arrow and projection are set for you. Real data shipped with terra:

```r
library(tidymapr)

elev    <- terra::rast(system.file("ex/elev.tif", package = "terra"))
cantons <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
roads   <- sf::st_as_sf(terra::unwrap(
  readRDS(system.file("ex/lux_highways.rds", package = "terra"))
))

geo_map(title = "Luxembourg", caption = "Data: terra package") |>
  map_raster(elev, name = "Elevation (m)", palette = "Terrain 2", hillshade = TRUE) |>
  map_polygons(cantons, fill = NA, label = "Cantons") |>
  map_lines(roads, colour = highway, palette = c("#B2182B", "#F4A582"), group = "Roads") |>
  map_labels(cantons, text = NAME_2)
```

<img src="man/figures/readme-layered-map.png" alt="Layered map of Luxembourg: elevation over a hillshade, canton boundaries, roads by class and canton names, with scale bar, north arrow and a legend section for each layer" width="80%">

## Functions

| Family | Functions |
|---|---|
| Layered maps | `geo_map()`, `map_raster()`, `map_polygons()`, `map_lines()`, `map_points()`, `map_labels()`, `map_curved_labels()`, `map_contours()`, `map_zoom()`, `map_build()`, `geo_map3d()`, `geo_webmap()` |
| Automatic maps | `geo_automap()`, `geo_automap_explain()`, `plot_choropleth()`, `plot_bubble()`, `geo_classify()` |
| Figures and furniture | `geo_panels()`, `geo_facet_map()`, `geo_inset()`, `annotation_scale_bar()`, `annotation_north_arrow()`, `map_legend()`, `map_graticule()`, `coord_projection()`, `theme_tidymapr()`, `geo_save()` |
| GeoSpaX recipes | `geo_recipe_read()`, `geo_recipe_validate()`, `geo_recipe_run()`, `geo_recipe_write()`, `geo_recipe()`, `recipe_step()` |
| Spatial analysis | `geo_interpolate()` (kriging with measurement error, IDW), `geo_hotspot()`, `geo_lisa()`, `geo_moran()`, `geo_dbscan()`, `geo_landscape()`, `geo_distance()`, `geo_decay()`, `geo_mem()` |
| Terrain and remote sensing | `geo_flow_direction()` and other hydrology tools, `geo_stac_search()`, `geo_stac_read()`, `geo_spectral_index()`, `geo_spectral_diversity()` |
| Data input and output | `geo_read()`, `geo_write()`, `geo_layers()`, `geo_raster_read()`, `geo_as_sf()`, `geo_extract()`, `geo_basemap()` |
| Ecology with tidydiversity | `geo_diversity_surface()`, `plot_diversity_surface()`, `geo_clean()`, `geo_gbif()`, `geo_rarefy_spatial()`, `sdm_maxent()`, `sdm_ensemble()`, `sdm_fit()`, `stems_habitat_test()` |

## Gallery

Every map below is made with tidymapr from real, openly licensed data.

### Interactive web maps

`geo_webmap()` turns the same layered map into one interactive HTML page
with basemaps, switchable layers, pop-ups and a matching legend.

```r
geo_webmap(m, file = "luxembourg.html")
```

<img src="man/figures/readme-webmap.png" alt="Interactive web map of Luxembourg in a browser: cantons classed by population over an Esri topographic basemap, main roads, canton centres and labels, a layer menu and a legend" width="100%">

### 3D terrain maps

`geo_map3d()` renders a DEM as a lit, shaded 3D block in C++ (no OpenGL),
with sites placed on the terrain. Here, the Mt Wilhelm ant survey
transect on the Copernicus 30 m DEM, fetched with `geo_stac_read()`.

```r
dem <- geo_stac_search("cop-dem-glo-30", area, cloud_cover = NULL) |>
  geo_stac_read("data", area = area, n = 2)
geo_map3d(dem, theta = 190, phi = 30, points = sites, label = "site")
```

<img src="man/figures/readme-map3d.png" alt="3D block diagram of Mt Wilhelm, Papua New Guinea, from the Copernicus 30 m DEM with the eight ant survey sites from 200 m to 3700 m labelled on the terrain" width="100%">

### Every geometry gets its own legend symbol

Rasters get a colour bar; polygons, lines and points get swatches, line
keys and point symbols, each layer in its own legend section.

<img src="man/figures/readme-legend-symbols.png" alt="Luxembourg map with an elevation raster, district outlines, roads by class and canton centres, each with its own legend symbol" width="80%">

### Automatic, explained map design

`geo_automap()` chooses the projection, classification, colour ramp and
map furniture from the data, and `geo_automap_explain()` says why. Here,
world life expectancy on Equal Earth (spData `world`).

<img src="man/figures/readme-automap-world.png" alt="World life expectancy on the Equal Earth projection with five classes and a graticule" width="100%">

### Diversity surfaces with uncertainty

`geo_diversity_surface()` krigs coverage-standardised Hill numbers with
each plot's estimation error (Barro Colorado Island 50-ha plot, vegan
`BCI`).

<img src="man/figures/readme-diversity-surface.png" alt="Kriged tree diversity for q = 0, 1 and 2 across the Barro Colorado Island plot, with maps of the width of the 95% interval" width="100%">

The lower row is the uncertainty: the upper bound of each place's 95%
interval divided by its lower bound. Pale means a precise estimate (a
ratio near 1); dark means the true value could lie well above the low end
of the range (a ratio of 1.8 means up to 80% higher).

### Species distribution ensembles, with Maxent in C++

`sdm_maxent()` fits Maxent in C++ with the same answers as maxnet (no
Java, no glmnet), but standardises predictors first, so results do not
depend on units or on where zero lies. `sdm_ensemble()` combines Maxent,
GLM, GAM and a C++ random forest with spatial block cross-validation and
TSS weights, and maps where the algorithms disagree.

```r
ens <- sdm_ensemble(presence, climate, coords = xy)
predict(ens, bioclim_raster, what = "all")
```

<img src="man/figures/readme-sdm-ensemble.png" alt="Ensemble habitat suitability of the brown-throated sloth across Central and South America with its 116 records, and a map of disagreement between the four algorithms" width="100%">

The ensemble map (left) is the weighted average of the four algorithms'
suitability (0 to 1). The disagreement map (right) is how far apart they
are at each place (their weighted standard deviation): pale where they
agree and the map can be trusted, dark where they give different answers
and the prediction is uncertain.

### Spectral indices and spectral diversity

NDVI with an Otsu threshold and spectral diversity in Hill numbers from a
Sentinel-2 Level-2A scene of Luxembourg (shipped with terra).

<img src="man/figures/readme-spectral-diversity.png" alt="Two maps of Luxembourg: NDVI from Sentinel-2 and spectral diversity, q = 1" width="100%">

### Satellite imagery from STAC catalogues

`geo_stac_search()` and `geo_stac_read()` find and stream Sentinel-2,
Landsat or Copernicus DEM data from STAC catalogues, reading only your
area and taking the median of the clearest scenes. Here, NDVI of
Luxembourg City in summer 2024.

```r
city   <- c(6.08, 49.57, 6.18, 49.65)
scenes <- geo_stac_search("sentinel-2-l2a", city,
  datetime = c("2024-06-01", "2024-08-31"), cloud_cover = 10)
ndvi   <- geo_stac_read(scenes, c("red", "nir"), area = city, n = 4) |>
  geo_spectral_index("NDVI")
```

<img src="man/figures/readme-stac-ndvi.png" alt="NDVI of Luxembourg City in summer 2024 from Sentinel-2: built-up areas brown, parks, valleys and forest green, with main roads" width="80%">

### Labels that follow the feature

`map_curved_labels()` writes names along lines, across the long axis or
along the outline of polygons, and on an arc above points.
`map_contours()` labels contours at their straightest stretch.

<p>
<img src="man/figures/readme-curved-labels.png" alt="Luxembourg canton names curved across each canton, along boundaries and over points" width="49%">
<img src="man/figures/readme-contours.png" alt="Labelled 50 m contours over shaded relief in northern Luxembourg" width="49%">
</p>

### Clusters and fragmentation

`geo_dbscan()` finds clusters of points in C++, with distances in metres
anywhere on Earth; `geo_landscape()` measures habitat fragmentation with
the FRAGSTATS metrics, matching landscapemetrics and also working on
rasters in degrees. Here, earthquake clusters along the Tonga-Kermadec
and Vanuatu arcs (`datasets::quakes`).

<img src="man/figures/readme-dbscan.png" alt="Earthquake clusters near Fiji found with DBSCAN, coloured by cluster with outlines, along the Tonga-Kermadec trench and the Vanuatu arc" width="70%">

### Insets, inside legends and small multiples

`geo_inset()` and `geo_map(legend = "inside")` find corners that do not
hide the scale bar, the north arrow or the data. `geo_facet_map()` draws
small multiples with one classification shared by every panel (sudden
infant deaths in North Carolina, sf `nc`).

<p>
<img src="man/figures/readme-inset-legend.png" alt="Population of Luxembourg's cantons with the legend inside the map and a locator inset of Europe" width="42%">
<img src="man/figures/readme-small-multiples.png" alt="Two North Carolina county maps, 1974-78 and 1979-84, sharing one set of classes" width="56%">
</p>

### GeoSpaX recipes in R

`geo_recipe_run()` runs GeoSpaX recipes unchanged: kriging against IDW by
cross-validation with its standard error, and Getis-Ord hot spots (Meuse
soil samples, shipped with terra).

<p>
<img src="man/figures/readme-recipe-kriging.png" alt="Zinc in Meuse floodplain soils, kriged with an exponential variogram, with the sample sites" width="49%">
<img src="man/figures/readme-recipe-hotspots.png" alt="Getis-Ord hot and cold spots of zinc at the Meuse sample sites over a topographic basemap" width="49%">
</p>

See the [gallery](https://tidymapr.in4metrix.dev/articles/gallery.html)
for more maps with their code.

## Citation

If you use tidymapr in published work, please cite it. In R, `citation("tidymapr")`
prints the reference:

> Moses, J. (2026). tidymapr: Tidy Mapping, Spatial Analysis and Publication Cartography. R package version 0.1.0. https://github.com/jmozez/tidymapr

```bibtex
@Manual{tidymapr,
  title = {tidymapr: Tidy Mapping, Spatial Analysis and Publication Cartography},
  author = {Jimmy Moses},
  year = {2026},
  note = {R package version 0.1.0},
  url = {https://github.com/jmozez/tidymapr},
}
```

Please also cite the methods you use: each help page and User guide
chapter lists the original references.

## Licence

MIT © 2026 Jimmy Moses
