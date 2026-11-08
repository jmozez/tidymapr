dem_lux <- function() {
  skip_if_not_installed("terra")
  r <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  terra::project(r, "EPSG:2169")
}

test_that("flow direction agrees with terra on a real DEM", {
  dem <- dem_lux()
  mine <- terra::values(geo_flow_direction(dem), mat = FALSE)
  ref <- terra::values(terra::terrain(dem, "flowdir"), mat = FALSE)
  ok <- !is.na(mine) & !is.na(ref)
  # Only flat-cell tie-breaking may differ
  expect_gt(mean(mine[ok] == ref[ok]), 0.999)
  expect_true(all(mine[ok] %in% c(0, 2^(0:7))))
})

test_that("flow accumulation and watersheds equal terra for the same directions", {
  dem <- dem_lux()
  dir <- terra::terrain(dem, "flowdir")
  acc <- geo_flow_accumulation(dem, direction = dir)
  ref <- terra::flowAccumulation(dir)
  # terra also fills cells outside the DEM; compare where there is land
  land <- !is.na(terra::values(dem, mat = FALSE))
  expect_equal(
    terra::values(acc, mat = FALSE)[land], terra::values(ref, mat = FALSE)[land]
  )
  cell <- terra::where.max(acc)[1, "cell"]
  xy <- terra::xyFromCell(dem, cell)
  ws <- geo_watershed(dem, xy, direction = dir)
  ref_ws <- terra::watershed(dir, xy)
  expect_identical(
    !is.na(terra::values(ws, mat = FALSE)),
    terra::values(ref_ws, mat = FALSE) %in% 1
  )
  expect_equal(sum(!is.na(terra::values(ws))), max(terra::values(acc), na.rm = TRUE))
})

test_that("weights, snapping and TWI behave", {
  dem <- dem_lux()
  w <- terra::rast(dem)
  terra::values(w) <- 2
  a1 <- geo_flow_accumulation(dem)
  a2 <- geo_flow_accumulation(dem, weight = w)
  expect_equal(terra::values(a2), 2 * terra::values(a1))
  # An outlet one cell off the stream snaps onto it
  cell <- terra::where.max(a1)[1, "cell"]
  rc <- terra::rowColFromCell(dem, cell)
  off <- terra::xyFromCell(dem, terra::cellFromRowCol(dem, rc[1], rc[2] - 1))
  big <- sum(!is.na(terra::values(geo_watershed(dem, off, snap = 1))))
  expect_equal(big, max(terra::values(a1), na.rm = TRUE))
  twi <- geo_twi(dem)
  expect_named(twi, "twi")
  expect_true(all(is.finite(terra::values(twi)[!is.na(terra::values(dem))])))
  expect_error(geo_watershed(dem, cbind(0, 0)), "outside")
})
