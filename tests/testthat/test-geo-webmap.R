skip_if_not_installed("sf")
skip_if_not_installed("jsonlite")
skip_if_not_installed("png")

lux_map <- function() {
  cantons <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
  seats <- suppressWarnings(sf::st_point_on_surface(cantons))
  geo_map(title = "Luxembourg") |>
    map_polygons(cantons, fill = POP, n = 4, group = "Inhabitants") |>
    map_points(seats, preset = "town") |>
    map_labels(seats, text = NAME_2)
}

test_that("web maps are self-contained pages with every layer", {
  w <- geo_webmap(lux_map())
  expect_s3_class(w, "tmr_webmap")
  h <- w$html
  expect_match(h, "<!doctype html>", fixed = TRUE)
  expect_match(h, 'integrity="sha512-', fixed = TRUE)
  expect_match(h, "addFeatures(\"L1\"", fixed = TRUE)
  expect_match(h, "addFeatures(\"L2\"", fixed = TRUE)
  expect_match(h, "addLabels(\"L3\"", fixed = TRUE)
  expect_match(h, "Inhabitants", fixed = TRUE)
  expect_match(h, "Esch-sur-Alzette", fixed = TRUE)
  # Colours are CSS hex codes, never R names such as grey10
  expect_false(grepl("grey10|grey30", h))
  f <- tempfile(fileext = ".html")
  expect_equal(geo_webmap(lux_map(), file = f), f)
  expect_true(file.size(f) > 1000)
})

test_that("rasters are embedded as images without line breaks", {
  skip_if_not_installed("terra")
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  h <- geo_webmap(elev)$html
  img <- regmatches(h, regexpr("data:image/png;base64,[^']*", h))
  expect_length(img, 1)
  expect_false(grepl("\n", img))
  expect_match(h, "linear-gradient", fixed = TRUE)
})

test_that("single layers and checks work", {
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  expect_match(geo_webmap(nc)$html, "Polygons", fixed = TRUE)
  expect_error(geo_webmap(1), "geo_map")
  expect_equal(tidymapr:::tmr_web_dash("42"), "8,4")
  expect_null(tidymapr:::tmr_web_dash("solid"))
  expect_equal(tidymapr:::tmr_web_hex("grey10"), "#1A1A1A")
})
