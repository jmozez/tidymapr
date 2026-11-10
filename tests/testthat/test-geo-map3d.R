skip_if_not_installed("terra")
skip_if_not_installed("ggplot2")

test_that("3D maps render a lit, shaded block", {
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  p <- geo_map3d(elev, width = 400, height = 300, title = "Luxembourg")
  expect_s3_class(p, "ggplot")
  r <- attr(p, "render")
  img <- as.matrix(r$image)
  expect_equal(dim(img), c(300, 400))
  drawn <- img != "#FFFFFF00" & img != "transparent"
  # Luxembourg's DEM is country-shaped: the terrain fills part of the frame
  expect_gt(mean(drawn), 0.05)
  expect_gt(r$exaggeration, 1)
  expect_equal(p$labels$title, "Luxembourg")
})

test_that("shadows darken the terrain and views differ", {
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  lum <- function(p) {
    m <- grDevices::col2rgb(as.vector(attr(p, "render")$image), alpha = TRUE)
    mean(colSums(m[1:3, m[4, ] > 0]))
  }
  a <- geo_map3d(elev, width = 300, height = 200, shadow = FALSE, base = FALSE)
  b <- geo_map3d(elev, width = 300, height = 200, shadow = TRUE, ambient = 0, base = FALSE)
  expect_lt(lum(b), lum(a))
  c <- geo_map3d(elev, width = 300, height = 200, theta = 90, base = FALSE)
  expect_false(identical(attr(a, "render")$image, attr(c, "render")$image))
})

test_that("drapes, overlays and checks work", {
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  slope <- terra::terrain(elev, "slope")
  pts <- sf::st_as_sf(data.frame(x = c(6.0, 6.2), y = c(49.8, 49.6), id = c("a", "b")),
    coords = c("x", "y"), crs = 4326
  )
  p <- geo_map3d(elev, drape = slope, points = pts, label = "id", width = 300, height = 200)
  expect_s3_class(p, "ggplot")
  expect_error(geo_map3d(1), "SpatRaster")
  expect_error(geo_map3d(elev, phi = 0), "phi")
  flat <- terra::rast(
    nrows = 5, ncols = 5, vals = 1, crs = "EPSG:32631",
    extent = terra::ext(0, 500, 0, 500)
  )
  expect_error(geo_map3d(flat), "relief")
})

test_that("NA borders are trimmed", {
  r <- terra::rast(nrows = 6, ncols = 6, vals = 1:36)
  r[1, ] <- NA
  r[, 6] <- NA
  t <- tidymapr:::tmr_trim_na_border(r)
  expect_equal(dim(t)[1:2], c(5, 5))
  expect_false(anyNA(terra::values(t)))
})

test_that("irregular outlines are not trimmed away", {
  elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  t <- tidymapr:::tmr_trim_na_border(elev)
  expect_gt(terra::ncol(t), 0.7 * terra::ncol(elev))
  expect_gt(terra::nrow(t), 0.7 * terra::nrow(elev))
})
