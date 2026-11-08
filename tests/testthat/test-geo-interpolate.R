wilhelm_utm <- function() {
  skip_if_not_installed("sf")
  s <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  sf::st_transform(s, 32755)
}

grid_points <- function(s, n = 12) {
  bb <- sf::st_bbox(s)
  xy <- expand.grid(
    x = seq(bb[["xmin"]], bb[["xmax"]], length.out = n),
    y = seq(bb[["ymin"]], bb[["ymax"]], length.out = n)
  )
  sf::st_as_sf(xy, coords = c("x", "y"), crs = sf::st_crs(s))
}

test_that("IDW equals gstat::idw()", {
  skip_if_not_installed("gstat")
  s <- wilhelm_utm()
  g <- grid_points(s)
  mine <- geo_interpolate(s, elevation, g, power = 2)
  ref <- gstat::idw(elevation ~ 1, s, g, idp = 2, debug.level = 0)
  expect_equal(mine$prediction, ref$var1.pred, tolerance = 1e-9)
  # A target on a sample takes its value
  at <- geo_interpolate(s, elevation, s[1:3, ])
  expect_equal(at$prediction, s$elevation[1:3])
})

test_that("ordinary kriging equals gstat::krige() for each model", {
  skip_if_not_installed("gstat")
  s <- wilhelm_utm()
  g <- grid_points(s)
  for (m in c("Exp", "Sph", "Gau")) {
    mine <- geo_interpolate(s, elevation, g,
      method = "kriging", model = m,
      nugget = 100, psill = 4e5, range = 8000
    )
    ref <- suppressWarnings(gstat::krige(elevation ~ 1, s, g,
      model = gstat::vgm(4e5, m, 8000, 100), debug.level = 0
    ))
    expect_equal(mine$prediction, ref$var1.pred, tolerance = 1e-8)
    expect_equal(mine$variance, ref$var1.var, tolerance = 1e-8)
  }
})

test_that("raster grids, fitted variograms and errors", {
  skip_if_not_installed("terra")
  skip_if_not_installed("gstat")
  s <- wilhelm_utm()
  bb <- sf::st_bbox(s)
  r <- terra::rast(
    nrows = 8, ncols = 8, xmin = bb[["xmin"]], xmax = bb[["xmax"]],
    ymin = bb[["ymin"]], ymax = bb[["ymax"]], crs = "EPSG:32755"
  )
  k <- geo_interpolate(s, elevation, r, method = "kriging")
  expect_s4_class(k, "SpatRaster")
  expect_named(k, c("prediction", "variance"))
  vg <- attr(k, "variogram")
  expect_true(vg$psill > 0 && vg$range > 0)
  expect_error(geo_interpolate(as.data.frame(s), elevation, r), "sf")
  expect_error(geo_interpolate(s, site, r), "numeric")
})
