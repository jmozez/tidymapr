# Package index

## tidyvisor (advice and interpretation)

- [`tidyvisor()`](https://tidymapr.in4metrix.dev/reference/tidyvisor.md)
  [`tmr_advise()`](https://tidymapr.in4metrix.dev/reference/tidyvisor.md)
  [`tmr_interpret()`](https://tidymapr.in4metrix.dev/reference/tidyvisor.md)
  : tidyvisor: advice before the analysis, interpretation after it

## Maps and cartography

Automatic, explained maps, thematic maps, projections, graticules,
basemaps and GeoSpaX-style map furniture.

- [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  [`geo_automap_explain()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  : Automatic publication maps that explain their choices
- [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_polygons()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_lines()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_points()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_curved_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_line_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_contours()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_zoom()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  [`map_build()`](https://tidymapr.in4metrix.dev/reference/geo-map.md) :
  Layered maps, built one layer at a time
- [`map_presets()`](https://tidymapr.in4metrix.dev/reference/map_presets.md)
  : Standard cartographic symbols
- [`geo_panels()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  [`geo_facet_map()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  [`geo_inset()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  : Multi-panel map layouts
- [`geo_map3d()`](https://tidymapr.in4metrix.dev/reference/geo_map3d.md)
  : 3D terrain maps
- [`geo_webmap()`](https://tidymapr.in4metrix.dev/reference/geo_webmap.md)
  : Interactive web maps
- [`plot_choropleth()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md)
  [`plot_bubble()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md)
  : Choropleth and bubble maps
- [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md)
  : Publication-ready study-site maps
- [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md) :
  Map Hill numbers (and coverage) in geographic space
- [`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md)
  : Map tree stems over topography
- [`geo_crs()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  [`coord_projection()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  [`map_graticule()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  : Map projections and graticules
- [`annotation_scale_bar()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md)
  [`annotation_north_arrow()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md)
  [`map_legend()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md)
  : Scale bars, north arrows and legends in GeoSpaX styles
- [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md)
  : Basemaps for study-site and diversity maps
- [`geo_breaks()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md)
  [`geo_classify()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md)
  : Classify a numeric column into map classes
- [`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md) :
  Save a map figure (PNG, PDF, SVG, TIFF, JPEG)
- [`theme_tidymapr()`](https://tidymapr.in4metrix.dev/reference/theme_tidymapr.md)
  : Map theme
- [`ggplot_add(`*`<tmr_geo_basemap>`*`)`](https://tidymapr.in4metrix.dev/reference/ggplot_add.tmr_geo_basemap.md)
  : Add a tidymapr basemap to a ggplot

## Spatial analysis

Interpolation and kriging, spatial autocorrelation and hotspots,
distances, computed in C++ on several cores.

- [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md)
  : Interpolate point measurements onto a grid
- [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
  [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
  : Local spatial statistics: hotspots and LISA clusters
- [`geo_dbscan()`](https://tidymapr.in4metrix.dev/reference/geo_dbscan.md)
  : Point clusters with DBSCAN
- [`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md)
  : Landscape fragmentation metrics
- [`geo_moran()`](https://tidymapr.in4metrix.dev/reference/geo_moran.md)
  : Moran's I for spatial autocorrelation of diversity
- [`geo_distance()`](https://tidymapr.in4metrix.dev/reference/geo_distance.md)
  : Pairwise geographic or elevational distances
- [`geo_decay()`](https://tidymapr.in4metrix.dev/reference/geo_decay.md)
  : Distance decay with geographic, elevational or environmental
  distance
- [`geo_mem()`](https://tidymapr.in4metrix.dev/reference/geo_mem.md) :
  Distance-based Moran's eigenvector maps (dbMEM)
- [`geo_mde()`](https://tidymapr.in4metrix.dev/reference/geo_mde.md) :
  Two-dimensional mid-domain null model of species richness
- [`geo_mde_3d()`](https://tidymapr.in4metrix.dev/reference/geo_mde_3d.md)
  : Three-dimensional mid-domain null model for marine and other volumes

## Terrain and hydrology

D8 flow direction, flow accumulation, watersheds, the topographic
wetness index and terrain derivatives.

- [`geo_flow_direction()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  [`geo_flow_accumulation()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  [`geo_watershed()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  [`geo_twi()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  : Terrain hydrology: flow direction, accumulation, watersheds and TWI
- [`geo_elevation()`](https://tidymapr.in4metrix.dev/reference/geo_elevation.md)
  : Download or read elevation (SRTM-style DEM)

## Remote sensing

Spectral indices with Otsu thresholds and spectral diversity in Hill
numbers.

- [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md)
  : Spectral indices from satellite bands
- [`geo_spectral_diversity()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_diversity.md)
  : Spectral diversity in Hill numbers
- [`geo_stac_collections()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  [`geo_stac_search()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  [`geo_stac_read()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  : Satellite imagery from STAC catalogues

## Data input and output

GIS, CAD and remote sensing formats through GDAL, rasters and vectors as
tidy objects, and environmental layers.

- [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  [`geo_vector_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  [`geo_raster_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  [`geo_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  [`geo_vector_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  [`geo_raster_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md)
  : Read and write spatial files through GDAL
- [`geo_layers()`](https://tidymapr.in4metrix.dev/reference/geo_layers.md)
  : List what a spatial file contains
- [`geo_buffer()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_intersection()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_difference()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_union()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_crop()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_area()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_centroid()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_bbox()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_join()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  [`geo_distance_to()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
  : Tidy vector geometry verbs
- [`geo_raster_crop()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_mask()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_resample()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_project()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_terrain()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_focal()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  [`geo_raster_zonal()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md)
  : Tidy raster analysis verbs
- [`geo_hypsometry()`](https://tidymapr.in4metrix.dev/reference/geo-hypsometry.md)
  [`geo_range_shift()`](https://tidymapr.in4metrix.dev/reference/geo-hypsometry.md)
  [`geo_patches()`](https://tidymapr.in4metrix.dev/reference/geo-hypsometry.md)
  [`geo_largest_patch()`](https://tidymapr.in4metrix.dev/reference/geo-hypsometry.md)
  : Land area by elevation and climate-driven range shifts
- [`geo_landcover()`](https://tidymapr.in4metrix.dev/reference/geo_landcover.md)
  [`geo_worldcover_tiles()`](https://tidymapr.in4metrix.dev/reference/geo_landcover.md)
  : ESA WorldCover land cover
- [`geo_srtm_tile_names()`](https://tidymapr.in4metrix.dev/reference/geo_srtm_tile_names.md)
  : Names of the 1 x 1 degree SRTM tiles that intersect a bounding box
- [`geo_shift_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md)
  [`geo_shift_summary()`](https://tidymapr.in4metrix.dev/reference/geo_shift_simulate.md)
  : Simulate range shifts with dispersal and colonisation-extinction
  dynamics
- [`geo_chelsa_area()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)
  [`geo_chelsa_urls()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)
  [`geo_downscale_lapse()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)
  [`geo_canopy_offset()`](https://tidymapr.in4metrix.dev/reference/geo-climate.md)
  : Present and future climate: CHELSA, lapse-rate downscaling and
  canopy buffering
- [`geo_climate_scenarios()`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md)
  [`geo_shift_ensemble()`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md)
  [`summary(`*`<tmr_shift_ensemble>`*`)`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md)
  : Ensemble projections of range shifts
- [`geo_dispersal_kernel()`](https://tidymapr.in4metrix.dev/reference/geo_dispersal_kernel.md)
  : Dispersal kernels
- [`geo_epidemic_simulate()`](https://tidymapr.in4metrix.dev/reference/geo_epidemic_simulate.md)
  : Simulate the spread of a disease across a landscape
- [`geo_spread_rate()`](https://tidymapr.in4metrix.dev/reference/geo_spread_rate.md)
  : Spread rate of a biological invasion
- [`epi_growth_rate()`](https://tidymapr.in4metrix.dev/reference/epi_growth_rate.md)
  : Epidemic growth rate, doubling time and reproduction number
- [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md)
  [`geo_drop_geometry()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md)
  : Convert site coordinates to an sf tibble
- [`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md)
  : Extract raster values at sites
- [`as_sf()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md)
  [`as_spat_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md)
  : Hand off spatial objects to tmap, leaflet and friends
- [`geo_bioclim_vars()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)
  [`geo_bioclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)
  [`geo_worldclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)
  [`geo_chelsa()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md)
  : Bioclimatic rasters (WorldClim and CHELSA)
- [`geo_gadm()`](https://tidymapr.in4metrix.dev/reference/geo_gadm.md) :
  Administrative boundaries from GADM

## Ecology with tidydiversity

Diversity surfaces, occurrence records, spatial diversity patterns,
species distribution models and forest plot maps.

- [`geo_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/geo_diversity_surface.md)
  : Map diversity as a continuous surface, with its uncertainty
- [`plot_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/plot_diversity_surface.md)
  : Plot diversity surfaces and their uncertainty
- [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md)
  : Clean occurrence coordinates
- [`geo_gbif()`](https://tidymapr.in4metrix.dev/reference/geo_gbif.md) :
  Import GBIF-style occurrence records
- [`geo_as_features()`](https://tidymapr.in4metrix.dev/reference/geo_as_features.md)
  : Export a site-by-feature matrix for conservation planning
- [`geo_rarefy_spatial()`](https://tidymapr.in4metrix.dev/reference/geo_rarefy_spatial.md)
  : Spatially constrained rarefaction
- [`geo_grain()`](https://tidymapr.in4metrix.dev/reference/geo_grain.md)
  : Aggregate sites or rasters across grains (MAUP helpers)
- [`geo_middomain()`](https://tidymapr.in4metrix.dev/reference/geo_middomain.md)
  : Geometric mid-domain null for elevational richness
- [`sdm_fit()`](https://tidymapr.in4metrix.dev/reference/sdm.md)
  [`sdm_predict()`](https://tidymapr.in4metrix.dev/reference/sdm.md)
  [`sdm_evaluate()`](https://tidymapr.in4metrix.dev/reference/sdm.md)
  [`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md) : Tidy
  species distribution models (presence-background / presence-absence)
- [`sdm_maxent()`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md)
  [`predict(`*`<tmr_maxent>`*`)`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md)
  : Maxent species distribution models, in C++
- [`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md)
  [`predict(`*`<tmr_sdm_ensemble>`*`)`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md)
  : Ensembles of species distribution models
- [`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)
  [`predict(`*`<tmr_sdm_integrated>`*`)`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)
  : Integrated species distribution model with physiological limits
- [`stems_quadrat()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md)
  [`stems_habitat()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md)
  [`stems_neighbours()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md)
  : Spatial verbs for ForestGEO-style stem maps
- [`stems_habitat_test()`](https://tidymapr.in4metrix.dev/reference/stems_habitat_test.md)
  : Torus-translation habitat association test (ForestGEO)

## Recipes

Read, write, check and run GeoSpaX recipes, shareable YAML workflows
from data to map and report.

- [`geo_recipe_read()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`geo_recipe()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`recipe_input()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`recipe_step()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`geo_recipe_write()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`geo_recipe_validate()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  [`geo_recipe_run()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  : GeoSpaX recipes: read, validate, run and write

## Example data

- [`png_ants_sites`](https://tidymapr.in4metrix.dev/reference/png_ants_sites.md)
  : GPS positions of the Mt Wilhelm ant bait transects
- [`geo_example_sites()`](https://tidymapr.in4metrix.dev/reference/geo_example_sites.md)
  : Published GPS coordinates for the Mt Wilhelm study sites
- [`geo_example_stems()`](https://tidymapr.in4metrix.dev/reference/geo_example_stems.md)
  : Simulated ForestGEO-style stem table for tests
- [`geo_example_dem()`](https://tidymapr.in4metrix.dev/reference/geo_example_dem.md)
  : Simulated DEM for testing local metre stem maps
- [`geo_example_censuses()`](https://tidymapr.in4metrix.dev/reference/geo_example_censuses.md)
  : Two simulated censuses for testing demography code

## Package

- [`tidymapr`](https://tidymapr.in4metrix.dev/reference/tidymapr-package.md)
  [`tidymapr-package`](https://tidymapr.in4metrix.dev/reference/tidymapr-package.md)
  : tidymapr: Tidy Mapping, Spatial Analysis and Publication Cartography
- [`geo`](https://tidymapr.in4metrix.dev/reference/geo.md) : Geospatial
  helpers for tidy biodiversity workflows
