# tidymapr

**Tidy mapping, spatial analysis and publication cartography.**

tidymapr makes publication-quality maps and does spatial analysis in R,
in the style of a desktop GIS: one call can choose the projection,
classification, colour ramps, legends, scale bar and north arrow, and
explain each choice. It is compatible with the
[GeoSpaX](https://geospax.in4metrix.dev) desktop GIS, following the same
cartographic conventions, reading and writing the same formats and
running the same recipes. For ecology, it is the mapping companion to
[tidydiversity](https://tidydiversity.in4metrix.dev/): tidydiversity
estimates diversity, tidymapr puts it on a map. Every verb takes a data
frame and returns a tibble, an `sf` table, a `SpatRaster` or a ggplot.

### Maps and cartography

Automatic, explained maps with
[`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md);
choropleth, bubble and layered maps; Equal Earth, Mercator, UTM and
other projections; graticules; GeoSpaX-style scale bars, north arrows
and legends; topographic and DEM basemaps.

### Spatial analysis and remote sensing

Kriging with measurement error, inverse-distance weighting, Getis-Ord
hotspots, local Moran’s I, terrain hydrology, NDVI and other spectral
indices, spectral diversity, all in fast multi-core C++.

### Data and ecology

GIS, CAD and remote sensing formats (netCDF, HDF, Sentinel-2, AutoCAD
DXF and more); diversity surfaces with uncertainty, distance decay,
species distribution models and forest plot maps with tidydiversity.

## Installation

Install the development version from GitLab:

``` r
# install.packages("pak")
pak::pak("gitlab::jimmy.moses/tidymapr")
```

The source code lives on GitHub, <https://github.com/jmozez/tidymapr>,
with a mirror on GitLab, <https://gitlab.com/jimmy.moses/tidymapr>.

**sf**, **terra** and the other spatial packages are optional; install
the ones you need with `install.packages(c("sf", "terra"))`.

## Example

A layered map in the style of a desktop GIS layout: each layer gets its
own legend section with the symbol for its geometry, and the scale bar,
north arrow and projection are set for you. Real data shipped with
terra:

``` r
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

![Layered map of Luxembourg: elevation over a hillshade, canton
boundaries, roads by class and canton names, with scale bar, north arrow
and a legend section for each
layer](reference/figures/readme-layered-map.png)

## Functions

| Family                     | Functions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Layered maps               | [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_polygons()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_lines()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_points()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_curved_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_contours()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_zoom()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`map_build()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), [`geo_map3d()`](https://tidymapr.in4metrix.dev/reference/geo_map3d.md), [`geo_webmap()`](https://tidymapr.in4metrix.dev/reference/geo_webmap.md) |
| Automatic maps             | [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md), [`geo_automap_explain()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md), [`plot_choropleth()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md), [`plot_bubble()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md), [`geo_classify()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Figures and furniture      | [`geo_panels()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md), [`geo_facet_map()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md), [`geo_inset()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md), [`annotation_scale_bar()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md), [`annotation_north_arrow()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md), [`map_legend()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md), [`map_graticule()`](https://tidymapr.in4metrix.dev/reference/map-projection.md), [`coord_projection()`](https://tidymapr.in4metrix.dev/reference/map-projection.md), [`theme_tidymapr()`](https://tidymapr.in4metrix.dev/reference/theme_tidymapr.md), [`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md)                                                                   |
| GeoSpaX recipes            | [`geo_recipe_read()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md), [`geo_recipe_validate()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md), [`geo_recipe_run()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md), [`geo_recipe_write()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md), [`geo_recipe()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md), [`recipe_step()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)                                                                                                                                                                                                                                                                                                                                                                                                        |
| Spatial analysis           | [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md) (kriging with measurement error, IDW), [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md), [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md), [`geo_moran()`](https://tidymapr.in4metrix.dev/reference/geo_moran.md), [`geo_dbscan()`](https://tidymapr.in4metrix.dev/reference/geo_dbscan.md), [`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md), [`geo_distance()`](https://tidymapr.in4metrix.dev/reference/geo_distance.md), [`geo_decay()`](https://tidymapr.in4metrix.dev/reference/geo_decay.md), [`geo_mem()`](https://tidymapr.in4metrix.dev/reference/geo_mem.md)                                                                                                                                                      |
| Terrain and remote sensing | [`geo_flow_direction()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md) and other hydrology tools, [`geo_stac_search()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md), [`geo_stac_read()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md), [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md), [`geo_spectral_diversity()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_diversity.md)                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Data input and output      | [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md), [`geo_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md), [`geo_layers()`](https://tidymapr.in4metrix.dev/reference/geo_layers.md), [`geo_raster_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md), [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md), [`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md), [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md)                                                                                                                                                                                                                                                                                                                                                               |
| Ecology with tidydiversity | [`geo_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/geo_diversity_surface.md), [`plot_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/plot_diversity_surface.md), [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md), [`geo_gbif()`](https://tidymapr.in4metrix.dev/reference/geo_gbif.md), [`geo_rarefy_spatial()`](https://tidymapr.in4metrix.dev/reference/geo_rarefy_spatial.md), [`sdm_maxent()`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md), [`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md), [`sdm_fit()`](https://tidymapr.in4metrix.dev/reference/sdm.md), [`stems_habitat_test()`](https://tidymapr.in4metrix.dev/reference/stems_habitat_test.md)                                                                                                                                 |

## Gallery

Every map below is made with tidymapr from real, openly licensed data.

### Interactive web maps

[`geo_webmap()`](https://tidymapr.in4metrix.dev/reference/geo_webmap.md)
turns the same layered map into one interactive HTML page with basemaps,
switchable layers, pop-ups and a matching legend.

``` r
geo_webmap(m, file = "luxembourg.html")
```

![Interactive web map of Luxembourg in a browser: cantons classed by
population over an Esri topographic basemap, main roads, canton centres
and labels, a layer menu and a
legend](reference/figures/readme-webmap.png)

### 3D terrain maps

[`geo_map3d()`](https://tidymapr.in4metrix.dev/reference/geo_map3d.md)
renders a DEM as a lit, shaded 3D block in C++ (no OpenGL), with sites
placed on the terrain. Here, the Mt Wilhelm ant survey transect on the
Copernicus 30 m DEM, fetched with
[`geo_stac_read()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md).

``` r
dem <- geo_stac_search("cop-dem-glo-30", area, cloud_cover = NULL) |>
  geo_stac_read("data", area = area, n = 2)
geo_map3d(dem, theta = 190, phi = 30, points = sites, label = "site")
```

![3D block diagram of Mt Wilhelm, Papua New Guinea, from the Copernicus
30 m DEM with the eight ant survey sites from 200 m to 3700 m labelled
on the terrain](reference/figures/readme-map3d.png)

### Every geometry gets its own legend symbol

Rasters get a colour bar; polygons, lines and points get swatches, line
keys and point symbols, each layer in its own legend section.

![Luxembourg map with an elevation raster, district outlines, roads by
class and canton centres, each with its own legend
symbol](reference/figures/readme-legend-symbols.png)

### Automatic, explained map design

[`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
chooses the projection, classification, colour ramp and map furniture
from the data, and
[`geo_automap_explain()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
says why. Here, world life expectancy on Equal Earth (spData `world`).

![World life expectancy on the Equal Earth projection with five classes
and a graticule](reference/figures/readme-automap-world.png)

### Diversity surfaces with uncertainty

[`geo_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/geo_diversity_surface.md)
krigs coverage-standardised Hill numbers with each plot’s estimation
error (Barro Colorado Island 50-ha plot, vegan `BCI`).

![Kriged tree diversity for q = 0, 1 and 2 across the Barro Colorado
Island plot, with maps of the width of the 95%
interval](reference/figures/readme-diversity-surface.png)

The lower row is the uncertainty: the upper bound of each place’s 95%
interval divided by its lower bound. Pale means a precise estimate (a
ratio near 1); dark means the true value could lie well above the low
end of the range (a ratio of 1.8 means up to 80% higher).

### Species distribution ensembles, with Maxent in C++

[`sdm_maxent()`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md)
fits Maxent in C++ with the same answers as maxnet (no Java, no glmnet),
but standardises predictors first, so results do not depend on units or
on where zero lies.
[`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md)
combines Maxent, GLM, GAM and a C++ random forest with spatial block
cross-validation and TSS weights, and maps where the algorithms
disagree.

``` r
ens <- sdm_ensemble(presence, climate, coords = xy)
predict(ens, bioclim_raster, what = "all")
```

![Ensemble habitat suitability of the brown-throated sloth across
Central and South America with its 116 records, and a map of
disagreement between the four
algorithms](reference/figures/readme-sdm-ensemble.png)

The ensemble map (left) is the weighted average of the four algorithms’
suitability (0 to 1). The disagreement map (right) is how far apart they
are at each place (their weighted standard deviation): pale where they
agree and the map can be trusted, dark where they give different answers
and the prediction is uncertain.

### Spectral indices and spectral diversity

NDVI with an Otsu threshold and spectral diversity in Hill numbers from
a Sentinel-2 Level-2A scene of Luxembourg (shipped with terra).

![Two maps of Luxembourg: NDVI from Sentinel-2 and spectral diversity, q
= 1](reference/figures/readme-spectral-diversity.png)

### Satellite imagery from STAC catalogues

[`geo_stac_search()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
and
[`geo_stac_read()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
find and stream Sentinel-2, Landsat or Copernicus DEM data from STAC
catalogues, reading only your area and taking the median of the clearest
scenes. Here, NDVI of Luxembourg City in summer 2024.

``` r
city   <- c(6.08, 49.57, 6.18, 49.65)
scenes <- geo_stac_search("sentinel-2-l2a", city,
  datetime = c("2024-06-01", "2024-08-31"), cloud_cover = 10)
ndvi   <- geo_stac_read(scenes, c("red", "nir"), area = city, n = 4) |>
  geo_spectral_index("NDVI")
```

![NDVI of Luxembourg City in summer 2024 from Sentinel-2: built-up areas
brown, parks, valleys and forest green, with main
roads](reference/figures/readme-stac-ndvi.png)

### Labels that follow the feature

[`map_curved_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
writes names along lines, across the long axis or along the outline of
polygons, and on an arc above points.
[`map_contours()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
labels contours at their straightest stretch.

![Luxembourg canton names curved across each canton, along boundaries
and over points](reference/figures/readme-curved-labels.png)![Labelled
50 m contours over shaded relief in northern
Luxembourg](reference/figures/readme-contours.png)

### Clusters and fragmentation

[`geo_dbscan()`](https://tidymapr.in4metrix.dev/reference/geo_dbscan.md)
finds clusters of points in C++, with distances in metres anywhere on
Earth;
[`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md)
measures habitat fragmentation with the FRAGSTATS metrics, matching
landscapemetrics and also working on rasters in degrees. Here,
earthquake clusters along the Tonga-Kermadec and Vanuatu arcs
([`datasets::quakes`](https://rdrr.io/r/datasets/quakes.html)).

![Earthquake clusters near Fiji found with DBSCAN, coloured by cluster
with outlines, along the Tonga-Kermadec trench and the Vanuatu
arc](reference/figures/readme-dbscan.png)

### Insets, inside legends and small multiples

[`geo_inset()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
and `geo_map(legend = "inside")` find corners that do not hide the scale
bar, the north arrow or the data.
[`geo_facet_map()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
draws small multiples with one classification shared by every panel
(sudden infant deaths in North Carolina, sf `nc`).

![Population of Luxembourg's cantons with the legend inside the map and
a locator inset of
Europe](reference/figures/readme-inset-legend.png)![Two North Carolina
county maps, 1974-78 and 1979-84, sharing one set of
classes](reference/figures/readme-small-multiples.png)

### GeoSpaX recipes in R

[`geo_recipe_run()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
runs GeoSpaX recipes unchanged: kriging against IDW by cross-validation
with its standard error, and Getis-Ord hot spots (Meuse soil samples,
shipped with terra).

![Zinc in Meuse floodplain soils, kriged with an exponential variogram,
with the sample
sites](reference/figures/readme-recipe-kriging.png)![Getis-Ord hot and
cold spots of zinc at the Meuse sample sites over a topographic
basemap](reference/figures/readme-recipe-hotspots.png)

See the [gallery](https://tidymapr.in4metrix.dev/articles/gallery.html)
for more maps with their code.

## Licence

MIT © 2026 Jimmy Moses
