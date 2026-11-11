# User guide

This guide explains how to use tidymapr **and** what its results mean.
Each chapter follows the same plan:

1.  **The concept**: the question the method answers, and the theory
    behind it, with its key formula and original references.
2.  **Code** you can copy into RStudio, run on real, openly licensed
    data shipped with R packages.
3.  **Figures and tables**, made by that code.
4.  **How to interpret them**: what the numbers and colours mean, and
    what they do not.
5.  **How to report them**: a model paragraph for a methods or results
    section, with the numbers filled in from the analysis.

| Chapter                                                                                                     | You will learn                                                                                                                                             | Main functions                                                                                                                                                                                                                                                                                                                                                                                                                       |
|-------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [1. Install and run in RStudio](https://tidymapr.in4metrix.dev/articles/guide-01-install.md)                | Set up R, RStudio and build tools; a first map; your own data; saving figures; troubleshooting                                                             | [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md), `map_*()`, [`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md)                                                                                                                                                                                                                                                                                  |
| [2. Cartography concepts](https://tidymapr.in4metrix.dev/articles/guide-02-cartography.md)                  | Projections and their distortions; classification methods and GVF; colour schemes; map elements                                                            | [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md), [`geo_automap_explain()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md), [`geo_classify()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md), [`coord_projection()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)                                                                                                       |
| [3. Spatial autocorrelation](https://tidymapr.in4metrix.dev/articles/guide-03-autocorrelation.md)           | Global Moran’s I and the correlogram; local Moran’s I (LISA); Getis-Ord Gi\* hot spots                                                                     | [`geo_moran()`](https://tidymapr.in4metrix.dev/reference/geo_moran.md), [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md), [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)                                                                                                                                                                                                              |
| [4. Interpolation](https://tidymapr.in4metrix.dev/articles/guide-04-interpolation.md)                       | Variograms; ordinary kriging and its variance; IDW; cross-validation; kriging with measurement error                                                       | [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md), [`geo_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/geo_diversity_surface.md)                                                                                                                                                                                                                                                   |
| [5. Species distribution models](https://tidymapr.in4metrix.dev/articles/guide-05-sdm.md)                   | Presence-background modelling; Maxent theory and features; response curves; AUC, TSS and Boyce; spatial block cross-validation; ensembles and disagreement | [`sdm_maxent()`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md), [`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md)                                                                                                                                                                                                                                                                               |
| [6. Remote sensing and terrain](https://tidymapr.in4metrix.dev/articles/guide-06-remote-sensing-terrain.md) | Spectral indices; Otsu thresholds; spectral diversity; D8 flow; topographic wetness; 3D terrain                                                            | [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md), [`geo_spectral_diversity()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_diversity.md), [`geo_flow_accumulation()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md), [`geo_twi()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md), [`geo_map3d()`](https://tidymapr.in4metrix.dev/reference/geo_map3d.md) |
| [7. Point clusters and landscapes](https://tidymapr.in4metrix.dev/articles/guide-07-patterns-landscapes.md) | DBSCAN and its parameters; FRAGSTATS fragmentation metrics                                                                                                 | [`geo_dbscan()`](https://tidymapr.in4metrix.dev/reference/geo_dbscan.md), [`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md)                                                                                                                                                                                                                                                                             |

**Where to start.** New to R: Chapter 1, then Chapter 2. Need a map for
a paper: Chapter 2. Analysing field samples: Chapters 3 and 4. Working
with species records: Chapter 5. Working with imagery or elevation:
Chapter 6.

**Going further.** The [case
studies](https://tidymapr.in4metrix.dev/articles/tutorials.md) apply
these methods to complete research questions, the
[Gallery](https://tidymapr.in4metrix.dev/articles/gallery.md) shows the
code of every map, and the
[Reference](https://tidymapr.in4metrix.dev/reference/index.md) lists
every function and argument. For diversity estimation itself, see the
companion package [tidydiversity](https://tidydiversity.in4metrix.dev);
for a point-and-click desktop GIS with the same conventions, see
[GeoSpaX](https://geospax.in4metrix.dev).

**How to cite.** Run `citation("tidymapr")` in R.
