skip_if_not_installed("ggplot2")
skip_if_not_installed("ggnewscale")
skip_if_not_installed("terra")
skip_if_not_installed("sf")

lux <- function() sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)

test_that("layers stack and each gets a legend", {
  cantons <- lux()
  roads <- sf::st_as_sf(terra::unwrap(
    readRDS(system.file("ex/lux_highways.rds", package = "terra"))
  ))
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  m <- geo_map(title = "Luxembourg") |>
    map_raster(elev, name = "Elevation (m)", hillshade = TRUE) |>
    map_polygons(cantons, fill = NA, label = "Cantons") |>
    map_lines(roads, colour = highway, group = "Roads") |>
    map_labels(cantons, text = NAME_2)
  expect_s3_class(m, "tmr_map")
  expect_length(m$layers, 4)
  p <- map_build(m)
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  titles <- unlist(lapply(b$plot$scales$scales, function(s) s$name))
  expect_true(all(c("Elevation (m)", "Roads") %in% titles))
  expect_equal(p$labels$title, "Luxembourg")
})

test_that("numeric columns are classed and constants get one entry", {
  cantons <- lux()
  m <- geo_map(scale_bar = FALSE, north_arrow = FALSE) |>
    map_polygons(cantons, fill = POP, n = 4, group = "Population") |>
    map_points(suppressWarnings(sf::st_point_on_surface(cantons)), fill = "red", label = "Seats")
  b <- ggplot2::ggplot_build(map_build(m))
  sc <- b$plot$scales$scales
  pop <- Filter(function(s) identical(s$name, "Population"), sc)[[1]]
  expect_length(pop$get_limits(), 4)
  seats <- Filter(function(s) identical(s$get_limits(), "Seats"), sc)
  expect_length(seats, 1)
})

test_that("bad input is caught", {
  expect_error(map_polygons(list(), lux()), "geo_map")
  expect_error(geo_map() |> map_lines(data.frame(a = 1)), "sf")
  expect_error(geo_map() |> map_polygons(lux(), fill = "not_a_colour_or_column"), "colour")
  expect_error(map_build(geo_map()), "no layers")
})
