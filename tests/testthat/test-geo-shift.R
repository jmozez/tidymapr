# Virtual species on a synthetic slope: no real data needed

shift_fixture <- function() {
  r <- terra::rast(
    nrows = 30, ncols = 30, xmin = 145, xmax = 145.3,
    ymin = -6.3, ymax = -6, crs = "EPSG:4326"
  )
  elev <- terra::init(r, "y")
  elev <- (elev - min(terra::values(elev))) * 10000
  band <- function(mid) exp(-((elev - mid) / 400)^2)
  suit <- c(band(1000), band(1400), band(1800))
  names(suit) <- c("t0", "t1", "t2")
  list(elev = elev, suit = suit)
}

test_that("perfect persistence and no dispersal keep the initial range", {
  skip_if_not_installed("terra")
  f <- shift_fixture()
  one <- f$suit
  terra::values(one) <- 1
  init <- f$suit[[1]] > 0.5
  o <- geo_shift_simulate(one, init, dispersal_mean = 1, max_distance = 0, nsim = 5, seed = 1)
  expect_equal(terra::values(o[[3]])[, 1], as.numeric(terra::values(init)[, 1]))
})

test_that("fast dispersers track the climate; slow ones are left behind", {
  skip_if_not_installed("terra")
  f <- shift_fixture()
  fast <- geo_shift_summary(
    geo_shift_simulate(f$suit, 0.5, 3000, nsim = 30, seed = 1, steps_per_layer = 5),
    f$elev
  )
  slow <- geo_shift_summary(
    geo_shift_simulate(f$suit, 0.5, 50, nsim = 30, seed = 1, steps_per_layer = 5),
    f$elev
  )
  expect_gt(fast$median[3], fast$median[1] + 600)
  expect_lt(slow$area_km2[3], 0.1 * fast$area_km2[3])
})

test_that("results depend on the seed, not on the number of threads", {
  skip_if_not_installed("terra")
  f <- shift_fixture()
  a <- geo_shift_simulate(f$suit, 0.5, 2000, nsim = 12, seed = 7, threads = 1)
  b <- geo_shift_simulate(f$suit, 0.5, 2000, nsim = 12, seed = 7, threads = 3)
  expect_equal(terra::values(a), terra::values(b))
  expect_equal(attr(a, "settings")$seed, 7)
  expect_true(all(terra::values(a) >= 0 & terra::values(a) <= 1, na.rm = TRUE))
})

test_that("colonisation probability follows the kernel formula", {
  skip_if_not_installed("terra")
  # One occupied cell, one empty neighbour at a known distance, one step
  r <- terra::rast(
    nrows = 1, ncols = 2, xmin = 0, xmax = 2000, ymin = 0, ymax = 1000,
    crs = "EPSG:32755"
  )
  terra::values(r) <- c(1, 0.6)
  init <- r
  terra::values(init) <- c(1, 0)
  o <- geo_shift_simulate(r, init,
    dispersal_mean = 500, max_distance = 5000,
    colonisation = 2, nsim = 20000, seed = 1
  )
  expected <- 1 - exp(-2 * 0.6 * exp(-1000 / 500))
  expect_equal(unname(terra::values(o)[2, 1]), expected, tolerance = 0.02)
})

test_that("bad inputs are rejected", {
  skip_if_not_installed("terra")
  f <- shift_fixture()
  bad <- f$suit * 2
  expect_error(geo_shift_simulate(bad, 0.5, 1000), "between 0 and 1")
  expect_error(geo_shift_simulate(f$suit, 0.5, -1), "dispersal_mean")
  expect_error(geo_shift_simulate(f$suit, "x", 1000), "initial")
})
