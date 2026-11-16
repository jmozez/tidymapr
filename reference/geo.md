# Geospatial helpers for tidy biodiversity workflows

Native tidyverse-style verbs for spatial biodiversity analysis. Sites
become [sf](https://r-spatial.github.io/sf/reference/st_as_sf.html)
tables, rasters join as columns, occurrence records are cleaned without
calling CoordinateCleaner, distances feed
[`tidydiversity::beta_decay()`](https://tidydiversity.in4metrix.dev/reference/beta_decay.html),
Hill numbers map with ggplot2, and Moran's I diagnoses spatial
autocorrelation without requiring spdep at run time.

Suggested packages: **sf** (site tables and maps), **terra** (raster
extraction). **rgbif** is optional for live downloads; **spdep** and
**CoordinateCleaner** are used only in tests when installed.
