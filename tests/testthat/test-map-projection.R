world_sf <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("spData")
  suppressPackageStartupMessages(library(sf))
  spData::world
}

test_that("geo_crs() resolves named projections", {
  skip_if_not_installed("sf")
  expect_equal(geo_crs("equal_earth")$input, "EPSG:8857")
  expect_equal(geo_crs("mercator")$input, "EPSG:3395")
  expect_equal(geo_crs("web_mercator")$epsg, 3857L)
  expect_equal(geo_crs("lonlat")$epsg, 4326L)
  expect_match(geo_crs("equal_earth", lon0 = 150)$proj4string, "lon_0=150")
  sites <- geo_as_sf(geo_example_sites(), lon, lat)
  expect_equal(geo_crs("utm", data = sites)$epsg, 32755L)
  expect_match(geo_crs("orthographic", data = sites)$proj4string, "proj=ortho")
  expect_equal(geo_crs(32755)$epsg, 32755L)
  expect_error(geo_crs("utm"), "data")
  expect_error(geo_crs("flat_earth"), "Unknown projection")
})

test_that("coord_projection() and map_graticule() keep the chosen projection", {
  world <- world_sf()
  for (pr in c("equal_earth", "mercator", "robinson", "mollweide", "winkel_tripel")) {
    p <- ggplot2::ggplot(world) + ggplot2::geom_sf() +
      coord_projection(pr) + map_graticule(30, outline = pr != "mercator")
    expect_false(is.na(sf::st_crs(p$coordinates$crs)), label = pr)
    expect_no_error(ggplot2::ggplotGrob(p))
  }
  png <- world[world$name_long == "Papua New Guinea", ]
  o <- ggplot2::ggplot(world) + ggplot2::geom_sf() +
    coord_projection("orthographic", data = png) + map_graticule(outline = TRUE)
  expect_identical(o$coordinates$label_axes$left, "")
  expect_no_error(ggplot2::ggplotGrob(o))
  expect_message(
    ggplot2::ggplot(world) + ggplot2::geom_sf() + coord_projection("robinson"),
    NA
  )
  expect_error(map_graticule(-5), "positive")
})
