# tidymapr 0.0.0.9000

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
