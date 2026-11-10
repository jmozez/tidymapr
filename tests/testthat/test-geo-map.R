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

test_that("map_zoom narrows or widens the view", {
  cantons <- lux()
  m <- geo_map() |> map_polygons(cantons, fill = "grey80", label = "Cantons")
  crs <- tidymapr:::tmr_map_crs(m)
  full <- tidymapr:::tmr_map_limits(map_zoom(m, 1), crs)
  z4 <- tidymapr:::tmr_map_limits(map_zoom(m, 4), crs)
  expect_equal(diff(z4$x), diff(full$x) / 4)
  expect_equal(mean(z4$x), mean(full$x))
  c4 <- tidymapr:::tmr_map_limits(map_zoom(m, 4, centre = c(6.13, 49.61)), crs)
  expect_false(isTRUE(all.equal(mean(c4$x), mean(full$x))))
  ex <- tidymapr:::tmr_map_limits(map_zoom(m, extent = c(6, 49.5, 6.2, 49.7)), crs)
  expect_true(diff(ex$x) < diff(full$x))
  expect_s3_class(map_build(map_zoom(m, 0.5)), "ggplot")
  expect_error(map_zoom(m, extent = "x"), "extent")
  expect_error(map_zoom(m, centre = 1), "centre")
})

test_that("curved labels follow lines, polygons and points", {
  skip_if_not_installed("geomtextpath")
  cantons <- lux()
  bnd <- sf::st_cast(sf::st_boundary(cantons[1:3, ]), "MULTILINESTRING")
  pts <- suppressWarnings(sf::st_point_on_surface(cantons[1:3, ]))
  m <- geo_map(scale_bar = FALSE, north_arrow = FALSE) |>
    map_polygons(cantons, fill = "grey90", label = "Cantons") |>
    map_curved_labels(cantons, text = NAME_2) |>
    map_curved_labels(cantons[1:2, ], text = NAME_2, polygon = "outline") |>
    map_line_labels(bnd, text = NAME_2) |>
    map_curved_labels(pts, text = NAME_2)
  geoms <- vapply(m$layers[-1], function(l) l$geom, "")
  expect_equal(geoms, c("polygon", "polygon", "line", "point"))
  p <- map_build(m)
  n_text <- sum(vapply(p$layers, function(l) inherits(l$geom, "GeomTextSf"), TRUE))
  expect_equal(n_text, 4)
  # Label paths are lines, left to right
  crs <- tidymapr:::tmr_map_crs(m)
  ax <- tidymapr:::tmr_polygon_label_path(sf::st_transform(cantons, crs), "axis")
  expect_true(all(sf::st_geometry_type(ax) == "LINESTRING"))
  xy <- sf::st_coordinates(ax[1, ])
  expect_lt(xy[1, "X"], xy[nrow(xy), "X"])
  arcs <- tidymapr:::tmr_point_arcs(sf::st_transform(pts, crs), 1000)
  expect_equal(nrow(arcs), 3)
  expect_error(map_curved_labels(geo_map(), sf::st_sf(geometry = c(
    sf::st_geometry(pts)[1], sf::st_geometry(bnd)[1]
  )), text = 1), "one kind")
})

test_that("contours are drawn and labelled", {
  skip_if_not_installed("geomtextpath")
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  m <- geo_map() |> map_contours(elev, interval = 100)
  expect_true(length(m$layers) %in% 1:2)
  lab <- m$layers[[length(m$layers)]]
  expect_true(all(lab$data$level %% 200 == 100 | lab$data$level %% 200 == 0))
  expect_s3_class(map_build(m), "ggplot")
  expect_error(geo_map() |> map_contours(elev, breaks = 9999), "No contour")
  # Chaikin keeps the ends and adds points
  g <- sf::st_sfc(sf::st_linestring(rbind(c(0, 0), c(1, 1), c(2, 0))))
  s <- tidymapr:::tmr_chaikin(g, 2)[[1]]
  expect_equal(unclass(s)[1, ], c(0, 0))
  expect_gt(nrow(unclass(s)), 3)
  expect_equal(tidymapr:::tmr_straightest(sf::st_linestring(rbind(c(0, 0), c(1, 0)))), 0.5)
})
