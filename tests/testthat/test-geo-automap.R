nc_sids <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  nc$sids_rate <- 1000 * nc$SID74 / nc$BIR74
  nc
}

test_that("graduated classes follow the GeoSpaX rules", {
  set.seed(1)
  sym <- tidymapr:::tmr_graduated(rnorm(200), "value")
  expect_identical(sym$style, "equal")
  expect_identical(sym$n, 5L)
  expect_identical(sym$palette, "RdYlBu") # crosses zero: diverging
  skew <- tidymapr:::tmr_graduated(rgamma(500, shape = 4), "rainfall")
  expect_identical(skew$style, "jenks")
  expect_identical(skew$palette, "Blues 3")
  heavy <- tidymapr:::tmr_graduated(exp(rnorm(200, sd = 2)), "count")
  expect_identical(heavy$style, "quantile")
  expect_identical(tidymapr:::tmr_graduated(1:10 * 100, "elevation")$palette, "viridis")
  expect_lt(tidymapr:::tmr_graduated(1:8, "x")$n, 5L)
})

test_that("geo_automap() picks projection, classes and furniture by scale", {
  nc <- nc_sids()
  m <- geo_automap(nc, sids_rate)
  ex <- geo_automap_explain(m)
  expect_identical(ex$choice[ex$element == "projection"], "laea")
  expect_match(ex$choice[ex$element == "symbology"], "graduated colours \\(jenks")
  expect_true(all(c("scale bar", "north arrow") %in% ex$element))
  expect_no_error(ggplot2::ggplotGrob(m))
  sites <- geo_as_sf(png_ants_sites, lon, lat)
  ms <- suppressMessages(geo_automap(sites, elevation, basemap = "none"))
  exs <- geo_automap_explain(ms)
  expect_identical(exs$choice[exs$element == "projection"], "utm")
  expect_match(exs$choice[exs$element == "symbology"], "graduated")
  # Classed legend on points, never a continuous colourbar
  b <- ggplot2::ggplot_build(ms)
  expect_s3_class(b$plot$scales$get_scales("fill"), "ScaleDiscrete")
  expect_error(geo_automap(data.frame(a = 1)), "sf")
})

test_that("a background surface takes the gradient legend; sites keep symbols", {
  skip_if_not_installed("terra")
  nc_sids()
  dem <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
  towns <- suppressWarnings(sf::st_centroid(lux))
  m <- geo_automap(towns, background = dem, background_title = "Elevation (m)")
  ex <- geo_automap_explain(m)
  expect_true("background" %in% ex$element)
  expect_identical(ex$choice[ex$element == "basemap"], "none")
  b <- ggplot2::ggplot_build(m)
  expect_s3_class(b$plot$scales$get_scales("fill"), "ScaleContinuous")
  expect_s3_class(b$plot$scales$get_scales("shape"), "ScaleDiscrete")
  expect_no_error(ggplot2::ggplotGrob(m))
})

test_that("bbox falls back when a datum shift cannot be computed", {
  nc <- nc_sids()
  b <- tidymapr:::tmr_bbox_lonlat(nc)
  expect_true(all(is.finite(b)) && b["ymax"] > b["ymin"])
})

test_that("users can choose their own colour ramps", {
  nc <- nc_sids()
  a <- geo_automap(nc, sids_rate, palette = "Purples 3")
  expect_match(geo_automap_explain(a)$choice[2], "Purples 3")
  cols <- c("white", "orange", "darkred")
  b <- geo_automap(nc, sids_rate, palette = cols)
  fill <- ggplot2::ggplot_build(b)$data[[1]]$fill
  expect_true(all(fill %in% grDevices::colorRampPalette(cols)(4)))
  expect_identical(tidymapr:::tmr_ramp(cols, NULL, 3), cols)
  expect_length(tidymapr:::tmr_ramp("viridis", NULL, 7), 7)
  expect_error(geo_automap(nc, sids_rate, palette = "notapalette"), "hcl.pals")
})
