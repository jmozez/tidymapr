# tidymapr 0.0.0.9000

Install the latest version with `pak::pak("gitlab::jimmy.moses/tidymapr")`.

## New maps (November 2026)

* New `plot_choropleth()` shades polygons by a numeric column, grouped into
  classes with `geo_classify()` (quantile, equal, Fisher-Jenks, pretty,
  standard deviation or fixed breaks). It uses colour-blind-safe sequential
  palettes from `grDevices::hcl.colors()` (default `"YlGnBu"`, light for
  low values and dark for high). The breaks, counts per class and goodness
  of variance fit are kept with the plot.
* New `plot_bubble()` draws proportional-area circles for counts such as
  species richness or abundance, from an `sf` point table or a lon/lat data
  frame, optionally coloured by group and over a background layer. Sites
  with a value of zero (sampled, nothing found) are shown as small open
  circles, so absences stay on the map. The example maps ant species on the
  16 Mt Wilhelm transects, where no ants were found above 2,200 m.
* `geo_basemap()`, `plot_sites()`, `plot_geo()`, `plot_topo()` and
  `plot_sdm()` gain new basemaps, all free and needing no API key:
  - topographic and street tiles: `"topo"` (OpenTopoMap, with contours and
    hillshade), `"osm_hot"` (OpenStreetMap Humanitarian), `"carto_voyager"`,
    `"esri_street"`, `"esri_relief"` (shaded relief), `"esri_terrain"` and
    `"esri_natgeo"` (National Geographic), alongside the existing
    `"esri"`, `"esri_topo"`, `"osm"`, `"carto"` and `"carto_dark"`;
  - built from an elevation model: `"hillshade"`, `"contour"` (labelled
    contour lines) and `"terrain"` (both). Pass your own DEM with `dem`
    (works offline), or let `geo_elevation()` download one for the map
    extent; set the contour interval with `contour_breaks`.
* Tile maps now carry each provider's required attribution (for example
  "© OpenStreetMap contributors") as the plot caption.

## Earlier additions

* New local spatial statistics: `geo_hotspot()` (Getis-Ord Gi*) and
  `geo_lisa()` (local Moran's I with cluster types, analytical or
  permutation p-values) on k-nearest or distance-band neighbours. Results
  equal `spdep::localG()` and `spdep::localmoran()`.
* New `geo_interpolate()` predicts a numeric column at raster cells or
  points by inverse-distance weighting or ordinary kriging (exponential,
  spherical or Gaussian variogram, fitted with gstat when not given).
  Results equal `gstat::idw()` and `gstat::krige()` to numerical precision.
* New terrain hydrology verbs: `geo_flow_direction()` (D8),
  `geo_flow_accumulation()`, `geo_watershed()` (with outlet snapping) and
  `geo_twi()` (topographic wetness index). Accumulation and watersheds equal
  `terra::flowAccumulation()` and `terra::watershed()` for the same flow
  directions.
* Maps use real, published records only. New dataset `png_ants_sites`
  holds the published bait GPS of the 16 Mt Wilhelm ant transects (Mottl,
  Moses and Klimes 2023, doi:10.5281/zenodo.8191946), and
  `geo_example_sites()` returns their band centroids. The invented Wanang
  coordinates and the simulated Wanang stem case study are gone.
* The Gallery now shows the real-data site, Hill-number, SRTM elevation
  and *Oecophylla smaragdina* species distribution maps (GBIF CC0/CC BY
  records in `inst/extdata`, WorldClim 2.1), rendered by
  `data-raw/gallery_maps.R`. Basemap tiles are drawn in the right
  projection and their zoom follows the map extent.
* First version. All mapping, geospatial and spatial-ecology verbs move here
  from tidydiversity, which stays the home of diversity estimation. The two
  packages are designed to be loaded together:
  * Sites and occurrences: `geo_as_sf()`, `geo_drop_geometry()`,
    `geo_extract()`, `geo_clean()`, `geo_gbif()`, `as_sf()`,
    `as_spat_raster()`, `geo_as_features()`.
  * Distances and spatial statistics: `geo_distance()`, `geo_decay()`
    (pairs with `tidydiversity::beta_decay_model()`), `geo_moran()`,
    `geo_mem()`, `geo_rarefy_spatial()`, `geo_grain()`, `geo_middomain()`.
  * Maps: `plot_sites()`, `plot_geo()`, `plot_topo()`, `geo_basemap()`,
    `geo_save()` and `theme_tidymapr()`.
  * Vector, raster and file verbs: `geo_read()`, `geo_write()`,
    `geo_vector_*()`, `geo_raster_*()`, `geo_buffer()`, `geo_crop()`,
    `geo_union()` and friends.
  * Environmental layers: `geo_bioclim()`, `geo_worldclim()`,
    `geo_chelsa()`, `geo_elevation()`, `geo_gadm()`, cached under
    `tools::R_user_dir("tidymapr", "cache")`.
  * Forest plot stem maps: `stems_quadrat()`, `stems_habitat()`,
    `stems_neighbours()` and the torus-translation `stems_habitat_test()`;
    census summaries stay in tidydiversity.
  * Species distribution models: `sdm_fit()`, `sdm_predict()`,
    `sdm_evaluate()`, `plot_sdm()`.
  * Example data: `geo_example_sites()`, `geo_example_stems()`,
    `geo_example_dem()`, `geo_example_censuses()`.
