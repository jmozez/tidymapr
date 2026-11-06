# tidymapr 0.0.0.9000

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
  * Species distribution models: `sdm_fit()`, `sdm_predict()`,
    `sdm_evaluate()`, `plot_sdm()`.
  * Example data: `geo_example_sites()`, `geo_example_stems()`,
    `geo_example_dem()`, `geo_example_censuses()`.
