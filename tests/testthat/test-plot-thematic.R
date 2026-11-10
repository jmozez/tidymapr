nc_sids <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc$sids_rate <- 1000 * nc$SID74 / nc$BIR74
  nc
}

ant_richness <- function() {
  skip_if_not_installed("tidydiversity")
  richness <- tidydiversity::png_ants |>
    dplyr::distinct(site, transect, species) |>
    dplyr::count(site, transect, name = "species")
  png_ants_sites |>
    dplyr::left_join(richness, by = c("site", "transect")) |>
    dplyr::mutate(species = dplyr::coalesce(species, 0L))
}

test_that("plot_choropleth() classes polygons with geo_classify()", {
  nc <- nc_sids()
  p <- plot_choropleth(nc, sids_rate, n = 4, style = "quantile")
  expect_s3_class(p, "ggplot")
  ref <- geo_classify(nc, sids_rate, n = 4, style = "quantile")
  expect_equal(attr(p, "classification")$breaks, attr(ref, "classification")$breaks)
  built <- ggplot2::ggplot_build(p)
  expect_length(unique(built$data[[1]]$fill), 4)
  expect_error(plot_choropleth(as.data.frame(nc), sids_rate), "sf")
  expect_error(plot_choropleth(suppressWarnings(sf::st_centroid(nc)), sids_rate), "polygons")
  expect_error(plot_choropleth(nc, sids_rate, palette = "nope"), "palette")
})

test_that("plot_bubble() maps area, keeps zeros and accepts lon/lat tables", {
  sites <- ant_richness()
  expect_true(any(sites$species == 0))
  p <- plot_bubble(sites, species)
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  # Bubbles for transects with ants, open circles for the six without
  expect_equal(nrow(built$data[[1]]), sum(sites$species > 0))
  expect_equal(nrow(built$data[[2]]), sum(sites$species == 0))
  expect_s3_class(plot_bubble(sites, species, colour = site), "ggplot")
  expect_error(plot_bubble(sites, site), "numeric")
  bad <- sites
  bad$species[1] <- -1L
  expect_error(plot_bubble(bad, species), "negative")
})

test_that("DEM basemaps work offline and tile providers are listed", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  dem <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  bb <- c(xmin = 5.75, ymin = 49.45, xmax = 6.5, ymax = 50.18)
  for (b in c("hillshade", "contour", "terrain")) {
    bm <- geo_basemap(bb, basemap = b, dem = dem)
    expect_s3_class(bm, "tmr_geo_basemap")
    expect_true(bm$offline)
    expect_s3_class(ggplot2::ggplot() + bm, "ggplot")
  }
  geoms <- function(b) {
    vapply(geo_basemap(bb, basemap = b, dem = dem)$layers, function(l) {
      class(l$geom)[1]
    }, character(1))
  }
  expect_true("GeomRaster" %in% geoms("hillshade"))
  expect_true("GeomContour" %in% geoms("contour"))
  expect_true(all(c("GeomRaster", "GeomContour") %in% geoms("terrain")))
  prov <- tidymapr:::geo_tile_providers()
  expect_true(all(c("topo", "osm", "osm_hot", "esri_relief", "carto_voyager") %in% names(prov)))
  expect_match(tidymapr:::geo_tile_attribution("OpenStreetMap"), "OpenStreetMap contributors")
  expect_error(geo_basemap(bb, basemap = "nonsense"), "Unknown basemap")
})
