# Changelog

## tidymapr 0.0.0.9000

### Interactive web maps (November 2026)

- [`geo_webmap()`](https://tidymapr.in4metrix.dev/reference/geo_webmap.md)
  turns a
  [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md) (or
  one `sf` or raster layer) into a self-contained interactive web page
  built on Leaflet: pan and zoom, four basemaps, layers that switch on
  and off, attribute pop-ups, permanent labels, a scale bar and a legend
  with the same symbols, classes and presets as the printed map.
  Features are embedded as GeoJSON and rasters as images, so the single
  HTML file can be emailed or published; Leaflet is loaded with
  Subresource Integrity.

### Symbology presets (November 2026)

- [`map_polygons()`](https://tidymapr.in4metrix.dev/reference/geo-map.md),
  [`map_lines()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  and
  [`map_points()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  take `preset`, a standard cartographic symbol by name (water, forest,
  protected area, administrative unit, river, main road, railway,
  boundary, contour, town, peak, sample site and more); arguments you
  set yourself override it.
  [`map_presets()`](https://tidymapr.in4metrix.dev/reference/map_presets.md)
  lists them. Polygons gain `linetype` for dashed outlines.

### GeoSpaX plug-in tools (November 2026)

- [`geo_dbscan()`](https://tidymapr.in4metrix.dev/reference/geo_dbscan.md)
  clusters points with DBSCAN in C++ (grid index), with `eps` in metres
  on the ground for geographic data and a convex-hull outline per
  cluster. It gives the same partition as the dbscan package.
- [`geo_landscape()`](https://tidymapr.in4metrix.dev/reference/geo_landscape.md)
  computes FRAGSTATS fragmentation metrics by class (np, ca, pland, lpi,
  area_mn, ed, ai, mesh) and for the landscape (with Shannon’s and
  Simpson’s diversity). They match landscapemetrics on projected rasters
  to machine precision, and unlike landscapemetrics they measure
  geographic (degree) rasters in true hectares and metres.
- Projections chosen from data that cross the antimeridian (Fiji, New
  Zealand, Kiribati) now centre on the data, not on longitude 0.

### 3D terrain maps (November 2026)

- [`geo_map3d()`](https://tidymapr.in4metrix.dev/reference/geo_map3d.md)
  renders a DEM as a 3D block diagram with sun lighting and cast
  shadows, any viewing direction and angle, automatic vertical
  exaggeration, hypsometric tints or any raster draped on the surface,
  and sites or routes placed on the terrain and hidden behind hills. The
  renderer is written in C++ (no OpenGL, rgl or rayshader), so it runs
  on servers and in reports and returns an ordinary ggplot. Empty wedges
  left by reprojection are trimmed so the block has clean sides.

### Maxent and ensemble models in C++ (November 2026)

- [`sdm_maxent()`](https://tidymapr.in4metrix.dev/reference/sdm_maxent.md)
  fits Maxent as maxnet does (infinitely weighted logistic regression
  with the lasso, the same feature classes and default regularisation),
  with the lasso path solved in C++ (coordinate descent with strong
  rules and active sets, on several cores): no Java and no glmnet. It
  agrees with maxnet to a correlation of 0.999 or more on the Bradypus
  data (Phillips et al. 2006). It fixes three weaknesses of maxnet:

  - predictors are standardised to 0-1 before features are built (as in
    the original Java Maxent), so quadratic and product features no
    longer depend on where zero lies: in maxnet, temperatures in Kelvin
    instead of Celsius change predicted suitability by up to 0.13 on the
    Bradypus data; here they change nothing. `standardize = FALSE`
    reproduces maxnet;
  - the duplicated outermost hinge feature that maxnet builds for every
    predictor is kept once;
  - the solver centres features internally, which makes it converge
    reliably where unscaled features stall coordinate descent.

- [`sdm_ensemble()`](https://tidymapr.in4metrix.dev/reference/sdm_ensemble.md)
  combines Maxent, GLM, GAM and a C++ random forest in the spirit of
  biomod2: spatial block cross-validation with folds balanced for
  presences and background, AUC, TSS and the continuous Boyce index,
  weights from cross-validated TSS above `min_tss`, balanced weighting
  of presences and background for every algorithm, and predictions of
  the weighted mean and the weighted disagreement (SD) between
  algorithms. The C++ random forest matches randomForest’s accuracy and
  is about 18 times faster.

- `geo_map(crs = "laea")` and other named projections now centre on
  raster layers too.

- [`geo_stac_search()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  finds scenes in any STAC catalogue (default: Element 84 Earth Search:
  Sentinel-2, Landsat, Copernicus DEM) by area, period and cloud cover,
  and returns their footprints as an `sf` table.

- [`geo_stac_read()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  reads chosen bands over an area only (windowed reads of
  cloud-optimised GeoTIFFs), applies the catalogue’s scale and offset
  (skipping it where Earth Search has already applied it), mosaics tiles
  and takes the per-pixel median of several scenes to remove clouds.
  [`geo_stac_collections()`](https://tidymapr.in4metrix.dev/reference/geo-stac.md)
  lists a catalogue’s collections. Needs the suggested package httr2.

- [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md)
  recognises STAC band names (`red`, `nir`, …) and returns `NA` where a
  normalised difference has no signal.

### Curved labels (November 2026)

- The README shows a new gallery of maps made from real data: layered
  maps, automatic world maps, diversity surfaces, spectral diversity,
  curved labels, contours, insets, small multiples and GeoSpaX recipes.
- [`map_curved_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  writes labels that follow the shape of any feature: along lines (road
  and river names), along the long axis or the outline of polygons, or
  on an arc above points. Text stays upright, jagged paths are smoothed,
  and labels that do not fit are left out.
  [`map_line_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  is the same for lines. Needs the suggested package geomtextpath.
- [`map_contours()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  draws contour lines of a raster, with every second contour thicker and
  labelled with its height at its straightest stretch.

### Multi-panel figures (November 2026)

- [`map_zoom()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  zooms a
  [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md) in
  or out (`zoom = 2` is twice as close), on the centre or on a
  `centre = c(lon, lat)`, or shows an exact `extent`; the scale bar
  follows the zoom.
- [`geo_panels()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  arranges maps from
  [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md),
  [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  or any ggplot in a grid, tagged (a), (b), …, with matching legends
  collected into one and a figure title and caption.
- [`geo_facet_map()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  draws small multiples (by a grouping column, or one panel per value
  column) with one classification shared by all panels, one legend, and
  the scale bar and north arrow in the first panel only.
- [`geo_inset()`](https://tidymapr.in4metrix.dev/reference/geo-panels.md)
  places a locator map on a larger map. By default (`location = "auto"`)
  it takes a corner free of the scale bar, north arrow and any legend
  inside the map, and of those the one hiding the least of the mapped
  features; a corner name or any `c(x, y)` position also works.
- `geo_map(legend = "inside")` puts the legend in a framed box on the
  map, in a corner chosen the same way (or set with `legend_corner`).
  `map_legend(position = "inside")` does the same for any map.

### Layered maps (November 2026)

- New layered-map builder in the style of a desktop GIS layout: start
  with
  [`geo_map()`](https://tidymapr.in4metrix.dev/reference/geo-map.md) and
  add
  [`map_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  (gradient legend, optional hillshade),
  [`map_polygons()`](https://tidymapr.in4metrix.dev/reference/geo-map.md),
  [`map_lines()`](https://tidymapr.in4metrix.dev/reference/geo-map.md),
  [`map_points()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  and
  [`map_labels()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  (labels with a white halo). Each layer gets its own legend section
  with the right symbol for its geometry, listed top layer first;
  numbers are classed with
  [`geo_classify()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md).
  [`map_build()`](https://tidymapr.in4metrix.dev/reference/geo-map.md)
  returns an ordinary ggplot. Needs the suggested package ggnewscale.
- Named sequential palettes now run light (low) to dark (high), except
  terrain and viridis-type ramps, which keep their own order.

### Recipe exchange with GeoSpaX (November 2026)

- New
  [`geo_recipe_read()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md),
  [`geo_recipe_write()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md),
  [`geo_recipe_validate()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  and
  [`geo_recipe_run()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  read, write, check and run GeoSpaX recipes (version 1 and 2 YAML), so
  a workflow built in GeoSpaX runs in R and the other way round.
  [`geo_recipe()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md),
  [`recipe_input()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  and
  [`recipe_step()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md)
  build recipes in R.
- Supported steps: `io.open`, `interpolate.idw`, `interpolate.auto`
  (kriging against IDW by leave-one-out error, with a standard-error
  map), `aggregate.hexbin`, `stats.hotspots` (Getis-Ord Gi\* with
  FDR-corrected 90/95/99% classes), `automap.style`, `style.apply`,
  `layout.auto`, `terrain.derive`, `rs.index`,
  `export.map`/`png`/`svg`/`pdf`, `export.data` and `export.report` (an
  HTML report with the maps, decisions and run log). Steps that only
  GeoSpaX can run are reported by
  [`geo_recipe_validate()`](https://tidymapr.in4metrix.dev/reference/geo-recipe.md).
- Three GeoSpaX recipes ship in `inst/recipes`: interpolate-samples,
  points-to-hotspots and points-to-hexbins.
- Hot spot maps use the conventional diverging colours (reds for hot,
  blues for cold, grey for not significant).
- GeoSpaX is now linked: <https://geospax.in4metrix.dev>.

### A wider scope (November 2026)

- tidymapr is now a general toolkit for mapping, spatial analysis and
  publication cartography, not only for biodiversity: new title “Tidy
  Mapping, Spatial Analysis and Publication Cartography”. It is
  compatible with the GeoSpaX desktop GIS (same cartographic
  conventions, same formats through GDAL) and remains the mapping
  companion to tidydiversity for ecology. No functions were renamed.
- The reference is regrouped into Maps and cartography, Spatial
  analysis, Terrain and hydrology, Remote sensing, Data input and
  output, and Ecology with tidydiversity.

Install the latest version with
`pak::pak("gitlab::jimmy.moses/tidymapr")`.

### New maps (November 2026)

- New
  [`plot_choropleth()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md)
  shades polygons by a numeric column, grouped into classes with
  [`geo_classify()`](https://tidymapr.in4metrix.dev/reference/geo_breaks.md)
  (quantile, equal, Fisher-Jenks, pretty, standard deviation or fixed
  breaks). It uses colour-blind-safe sequential palettes from
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)
  (default `"YlGnBu"`, light for low values and dark for high). The
  breaks, counts per class and goodness of variance fit are kept with
  the plot.
- New
  [`plot_bubble()`](https://tidymapr.in4metrix.dev/reference/thematic-maps.md)
  draws proportional-area circles for counts such as species richness or
  abundance, from an `sf` point table or a lon/lat data frame,
  optionally coloured by group and over a background layer. Sites with a
  value of zero (sampled, nothing found) are shown as small open
  circles, so absences stay on the map. The example maps ant species on
  the 16 Mt Wilhelm transects, where no ants were found above 2,200 m.
- [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md),
  [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
  [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md),
  [`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md)
  and [`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md)
  gain new basemaps, all free and needing no API key:
  - topographic and street tiles: `"topo"` (OpenTopoMap, with contours
    and hillshade), `"osm_hot"` (OpenStreetMap Humanitarian),
    `"carto_voyager"`, `"esri_street"`, `"esri_relief"` (shaded relief),
    `"esri_terrain"` and `"esri_natgeo"` (National Geographic),
    alongside the existing `"esri"`, `"esri_topo"`, `"osm"`, `"carto"`
    and `"carto_dark"`;
  - built from an elevation model: `"hillshade"`, `"contour"` (labelled
    contour lines) and `"terrain"` (both). Pass your own DEM with `dem`
    (works offline), or let
    [`geo_elevation()`](https://tidymapr.in4metrix.dev/reference/geo_elevation.md)
    download one for the map extent; set the contour interval with
    `contour_breaks`.
- Map furniture in the GeoSpaX styles, for any ggplot map with
  [`coord_sf()`](https://rdrr.io/pkg/ggplot2/man/ggsf.html). You pick
  the style:
  - [`annotation_scale_bar()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md):
    `"pill"`, `"checker"`, `"line"` or `"ruler"`, in `"metric"`,
    `"imperial"` or `"both"` units. Its length is measured on the ground
    when the map is drawn, so it is right on longitude/latitude and
    projected maps and in every facet.
  - [`annotation_north_arrow()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md):
    `"needle"`, `"compass"`, `"rose"` or `"minimal"`.
  - [`map_legend()`](https://tidymapr.in4metrix.dev/reference/map-furniture.md):
    legend `"right"`, `"bottom"`, `"inside"` a chosen corner or
    `"none"`, with its title, renamed entries (`labels`), hidden legends
    (`hide`), frame, text, title and key sizes, columns, direction and
    order.
- [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
  [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md)
  and [`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md)
  accept these style names in `scale_bar` and `north_arrow` (`TRUE`
  keeps the default, `FALSE` turns them off), and
  [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md)
  and
  [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md)
  gain `scale_units`. Their maps keep the full planned extent around the
  sites.
- Tile maps now carry each provider’s required attribution (for example
  “© OpenStreetMap contributors”) as the plot caption.

### Spectral diversity and spectral indices (November 2026)

- New
  [`geo_spectral_diversity()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_diversity.md)
  maps diversity from satellite or drone imagery in Hill numbers (q = 0,
  1, 2), on the same scale as species diversity: bands are reduced by
  principal components, pixels grouped into spectral species by k-means
  (Féret and Asner 2014), and Hill numbers computed in a moving window
  in C++ on several cores. Results equal direct Hill-number calculations
  to machine precision.
- New
  [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md)
  computes NDVI, GNDVI, NDRE, NDWI, MNDWI, NDMI, NBR and NDBI
  (Sentinel-2 bands recognised automatically), with an optional Otsu
  threshold that reports the area above the cut, as in GeoSpaX’s
  Forestry plug-in.
- Examples use the Sentinel-2 Level-2A scene of Luxembourg shipped with
  terra.

### Automatic publication maps (November 2026)

- New
  [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  draws a finished map from one call and explains every choice;
  [`geo_automap_explain()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  returns the decisions as a table for a methods section. Following
  GeoSpaX’s AutoMap and ArcGIS/QGIS practice:
  - projection by extent: Equal Earth for world data, Lambert equal-area
    for regions, the local UTM zone for study areas (longitude/latitude
    when raster tiles or a surface are drawn);
  - numbers on points, lines and polygons get graduated colours in
    classes (a classed legend, never a continuous ramp): equal intervals
    when roughly symmetric, natural breaks when skewed, quantiles when
    heavy-tailed; 5 classes for 30 or more features, fewer for small
    samples; the colour ramp follows the field’s meaning (blues for
    water, greens for vegetation, viridis for elevation, diverging
    across zero);
  - small counts on points get proportional circles, categories get
    Okabe-Ito colours, plain sites a single symbol;
  - a continuous surface (a raster, or a new `background` such as a DEM
    under the sites) gets a stretched ramp with a gradient legend, while
    the sites keep their own symbol legend;
  - topographic tiles as muted context for study areas; graticule and
    world outline on world maps; scale bar and north arrow in the
    emptiest corners on regional and local maps.
- [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md)
  takes `palette` and `background_palette`: `"auto"`, any
  [`grDevices::hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html)
  name (for example `"viridis"`, `"Blues 3"`, `"Terrain 2"`) or your own
  colours. Every map is also a ggplot, so any `scale_fill_*()` or
  `scale_colour_*()` can replace a ramp with `+`.
- Scale bars drop the middle label when the bar is short, so labels
  never collide.

### Diversity surfaces with uncertainty (November 2026)

- New
  [`geo_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/geo_diversity_surface.md)
  turns a community table into continuous maps of Hill-number diversity
  (q = 0, 1, 2) with 95% intervals:
  1.  each site’s diversity is standardised to a common sample coverage
      with
      [`tidydiversity::div_standardise()`](https://rdrr.io/pkg/tidydiversity/man/div_standardise.html)
      (Chao and Jost 2012), keeping its bootstrap standard error;
  2.  each order q is interpolated by kriging with measurement error
      (Cressie 1993) on the log scale, so poorly sampled sites count for
      less and the map shows the underlying diversity rather than
      sampling noise;
  3.  the interval combines spatial and estimation uncertainty. The
      example maps tree diversity across the 50-ha Barro Colorado Island
      forest plot
      ([`vegan::BCI`](https://rdrr.io/pkg/vegan/man/BCI.html)).
- New
  [`plot_diversity_surface()`](https://tidymapr.in4metrix.dev/reference/plot_diversity_surface.md)
  draws the surfaces with a matching row of uncertainty maps and the
  sampled sites.
- Kriging now accepts per-site measurement-error variances (C++); with a
  common error it equals gstat’s `"Err"` variogram model.

### Faster: C++ and multi-core (November 2026)

- The most demanding calculations now run in C++ and use several CPU
  cores (OpenMP). Set the number with `options(tidymapr.threads = n)`;
  by default tidymapr uses all cores but one. Timings on 4 cores:
  - [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
    permutation test (500 sites, 999 permutations): 5 s to 0.05 s;
  - kriging in
    [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md)
    (300 points to 40,000 cells): 20 s to 0.9 s; new `variance = FALSE`
    skips the kriging variance for even larger grids;
  - inverse-distance weighting: 0.8 s to 0.04 s;
  - nearest-neighbour search for
    [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
    and
    [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md):
    about 4 times faster;
  - [`geo_mem()`](https://tidymapr.in4metrix.dev/reference/geo_mem.md)
    minimum spanning tree (Prim’s algorithm): about 10 times faster and
    now scales to thousands of sites.
- Results are unchanged: they still equal spdep and gstat, and
  permutation p-values are the same for a given seed whatever the number
  of cores.

### Projections and graticules (November 2026)

- New
  [`coord_projection()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  draws any tidymapr or ggplot map in a named projection, added with
  `+`: `"equal_earth"` (true areas, recommended for world choropleths),
  `"mercator"` (World Mercator), `"web_mercator"` (matches online
  tiles), `"robinson"`, `"mollweide"`, `"winkel_tripel"`, `"lonlat"`,
  `"utm"` (zone picked from your data), and `"laea"`, `"albers"` and
  `"orthographic"` centred on your data. Any EPSG code or PROJ string
  also works, and world projections take `lon0`, for example
  `lon0 = 150` for a Pacific-centred map.
- New
  [`geo_crs()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  returns the CRS for those names, for reprojecting data.
- New
  [`map_graticule()`](https://tidymapr.in4metrix.dev/reference/map-projection.md)
  sets the latitude/longitude grid interval and line style, labels
  latitudes, longitudes, both or neither (on curved world projections it
  labels latitudes only, so longitude labels do not crowd the pole
  line), and can draw the edge of the world or, on orthographic maps,
  the horizon circle.
- Examples use
  [`spData::world`](https://rdrr.io/pkg/spData/man/world.html) (Natural
  Earth and World Bank, free to use) for world maps.

### Reading GIS, CAD and remote sensing files (November 2026)

- [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md) now
  reads many more formats through GDAL:
  - remote sensing and climate rasters: netCDF (`.nc`, `.nc4`, `.cdf`),
    HDF4/HDF5 (MODIS, VIIRS, GEDI), GRIB weather files, Sentinel-2
    `.SAFE` folders and zips, JPEG 2000, ENVI cubes (a `.dat`/`.bin`
    with its `.hdr`), ERDAS Imagine, Zarr, VRT, IDRISI, SAGA and ER
    Mapper;
  - several band files at once (for example Landsat or Sentinel-2
    bands), stacked into one multi-band raster;
  - CAD drawings: AutoCAD `.dxf` and `.dwg` and MicroStation `.dgn`,
    with `cad_layer` to keep chosen AutoCAD layers (DGN levels) and
    `crs` to set the coordinate system CAD files do not store;
  - vector formats: FlatGeobuf, GPX, MapInfo, SpatiaLite, TopoJSON,
    OpenStreetMap `.osm`/`.pbf`, S-57 nautical charts and spreadsheets
    (`.xlsx`, `.xls`, `.ods`).
- New `var` argument to pick netCDF, HDF and GRIB variables by name or
  number; several variables are combined into one raster, and time steps
  stay in [`terra::time()`](https://rdrr.io/pkg/terra/man/time.html).
- New
  [`geo_layers()`](https://tidymapr.in4metrix.dev/reference/geo_layers.md)
  shows what a file holds before you read it: vector layers, netCDF/HDF
  variables and subdatasets, CAD layers or raster bands.

### Earlier additions

- New local spatial statistics:
  [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
  (Getis-Ord Gi\*) and
  [`geo_lisa()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)
  (local Moran’s I with cluster types, analytical or permutation
  p-values) on k-nearest or distance-band neighbours. Results equal
  [`spdep::localG()`](https://rdrr.io/pkg/spdep/man/localG.html) and
  [`spdep::localmoran()`](https://rdrr.io/pkg/spdep/man/localmoran.html).
- New
  [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md)
  predicts a numeric column at raster cells or points by
  inverse-distance weighting or ordinary kriging (exponential, spherical
  or Gaussian variogram, fitted with gstat when not given). Results
  equal [`gstat::idw()`](https://rdrr.io/pkg/gstat/man/krige.html) and
  [`gstat::krige()`](https://rdrr.io/pkg/gstat/man/krige.html) to
  numerical precision.
- New terrain hydrology verbs:
  [`geo_flow_direction()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  (D8),
  [`geo_flow_accumulation()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md),
  [`geo_watershed()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  (with outlet snapping) and
  [`geo_twi()`](https://tidymapr.in4metrix.dev/reference/geo-hydrology.md)
  (topographic wetness index). Accumulation and watersheds equal
  [`terra::flowAccumulation()`](https://rdrr.io/pkg/terra/man/flowAccumulation.html)
  and
  [`terra::watershed()`](https://rdrr.io/pkg/terra/man/watershed.html)
  for the same flow directions.
- Maps use real, published records only. New dataset `png_ants_sites`
  holds the published bait GPS of the 16 Mt Wilhelm ant transects
  (Mottl, Moses and Klimes 2023, <doi:10.5281/zenodo.8191946>), and
  [`geo_example_sites()`](https://tidymapr.in4metrix.dev/reference/geo_example_sites.md)
  returns their band centroids. The invented Wanang coordinates and the
  simulated Wanang stem case study are gone.
- The Gallery now shows the real-data site, Hill-number, SRTM elevation
  and *Oecophylla smaragdina* species distribution maps (GBIF CC0/CC BY
  records in `inst/extdata`, WorldClim 2.1), rendered by
  `data-raw/gallery_maps.R`. Basemap tiles are drawn in the right
  projection and their zoom follows the map extent.
- First version. All mapping, geospatial and spatial-ecology verbs move
  here from tidydiversity, which stays the home of diversity estimation.
  The two packages are designed to be loaded together:
  - Sites and occurrences:
    [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md),
    [`geo_drop_geometry()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md),
    [`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md),
    [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md),
    [`geo_gbif()`](https://tidymapr.in4metrix.dev/reference/geo_gbif.md),
    [`as_sf()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md),
    [`as_spat_raster()`](https://tidymapr.in4metrix.dev/reference/geo-map-interop.md),
    [`geo_as_features()`](https://tidymapr.in4metrix.dev/reference/geo_as_features.md).
  - Distances and spatial statistics:
    [`geo_distance()`](https://tidymapr.in4metrix.dev/reference/geo_distance.md),
    [`geo_decay()`](https://tidymapr.in4metrix.dev/reference/geo_decay.md)
    (pairs with
    [`tidydiversity::beta_decay_model()`](https://rdrr.io/pkg/tidydiversity/man/beta_decay_model.html)),
    [`geo_moran()`](https://tidymapr.in4metrix.dev/reference/geo_moran.md),
    [`geo_mem()`](https://tidymapr.in4metrix.dev/reference/geo_mem.md),
    [`geo_rarefy_spatial()`](https://tidymapr.in4metrix.dev/reference/geo_rarefy_spatial.md),
    [`geo_grain()`](https://tidymapr.in4metrix.dev/reference/geo_grain.md),
    [`geo_middomain()`](https://tidymapr.in4metrix.dev/reference/geo_middomain.md).
  - Maps:
    [`plot_sites()`](https://tidymapr.in4metrix.dev/reference/plot_sites.md),
    [`plot_geo()`](https://tidymapr.in4metrix.dev/reference/plot_geo.md),
    [`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md),
    [`geo_basemap()`](https://tidymapr.in4metrix.dev/reference/geo_basemap.md),
    [`geo_save()`](https://tidymapr.in4metrix.dev/reference/geo_save.md)
    and
    [`theme_tidymapr()`](https://tidymapr.in4metrix.dev/reference/theme_tidymapr.md).
  - Vector, raster and file verbs:
    [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md),
    [`geo_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md),
    `geo_vector_*()`, `geo_raster_*()`,
    [`geo_buffer()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md),
    [`geo_crop()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md),
    [`geo_union()`](https://tidymapr.in4metrix.dev/reference/geo-vector.md)
    and friends.
  - Environmental layers:
    [`geo_bioclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md),
    [`geo_worldclim()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md),
    [`geo_chelsa()`](https://tidymapr.in4metrix.dev/reference/geo-bioclim.md),
    [`geo_elevation()`](https://tidymapr.in4metrix.dev/reference/geo_elevation.md),
    [`geo_gadm()`](https://tidymapr.in4metrix.dev/reference/geo_gadm.md),
    cached under `tools::R_user_dir("tidymapr", "cache")`.
  - Forest plot stem maps:
    [`stems_quadrat()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md),
    [`stems_habitat()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md),
    [`stems_neighbours()`](https://tidymapr.in4metrix.dev/reference/stems_spatial.md)
    and the torus-translation
    [`stems_habitat_test()`](https://tidymapr.in4metrix.dev/reference/stems_habitat_test.md);
    census summaries stay in tidydiversity.
  - Species distribution models:
    [`sdm_fit()`](https://tidymapr.in4metrix.dev/reference/sdm.md),
    [`sdm_predict()`](https://tidymapr.in4metrix.dev/reference/sdm.md),
    [`sdm_evaluate()`](https://tidymapr.in4metrix.dev/reference/sdm.md),
    [`plot_sdm()`](https://tidymapr.in4metrix.dev/reference/sdm.md).
  - Example data:
    [`geo_example_sites()`](https://tidymapr.in4metrix.dev/reference/geo_example_sites.md),
    [`geo_example_stems()`](https://tidymapr.in4metrix.dev/reference/geo_example_stems.md),
    [`geo_example_dem()`](https://tidymapr.in4metrix.dev/reference/geo_example_dem.md),
    [`geo_example_censuses()`](https://tidymapr.in4metrix.dev/reference/geo_example_censuses.md).
