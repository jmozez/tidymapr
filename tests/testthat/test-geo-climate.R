test_that("CHELSA URLs follow the archive layout", {
  now <- geo_chelsa_urls(c("bio1", "bio12"))
  expect_equal(now$name, c("bio1_1981-2010", "bio12_1981-2010"))
  expect_match(now$url[1], "climatologies/1981-2010/bio/CHELSA_bio1_1981-2010_V.2.1.tif$")
  fut <- geo_chelsa_urls("bio1", "2071-2100",
    gcm = c("mpi-esm1-2-hr", "ukesm1-0-ll"),
    ssp = c("ssp126", "ssp585")
  )
  expect_equal(nrow(fut), 4)
  expect_match(
    fut$url[1],
    "2071-2100/MPI-ESM1-2-HR/ssp126/bio/CHELSA_bio1_2071-2100_mpi-esm1-2-hr_ssp126_V.2.1.tif$"
  )
  expect_equal(nrow(geo_chelsa_urls("bio5", "2041-2070")), 5)
  expect_error(geo_chelsa_urls("bio1", gcm = "x"), "future")
  expect_error(geo_chelsa_urls("bio1", "2071-2100", gcm = "x"), "Unknown")
  expect_error(geo_chelsa_urls("bio1", "1999"), "period")
})

test_that("lapse-rate downscaling is exact on a synthetic slope", {
  skip_if_not_installed("terra")
  dem <- terra::rast(
    nrows = 40, ncols = 40, xmin = 0, xmax = 4000, ymin = 0, ymax = 4000,
    crs = "EPSG:32755"
  )
  terra::values(dem) <- rep(seq(0, 3900, by = 100), times = 40)
  coarse <- terra::aggregate(dem, 10)
  # Coarse temperature consistent with a 6 C/km lapse from 25 C at sea level
  tc <- 25 - 6 * terra::aggregate(dem, 10, fun = "mean") / 1000
  fine <- geo_downscale_lapse(tc, dem, lapse_rate = 6)
  expected <- 25 - 6 * dem / 1000
  d <- abs(terra::values(fine) - terra::values(expected))
  # Exact away from the outer half-cell where bilinear interpolation extrapolates
  inner <- terra::values(terra::init(dem, "col"))[, 1] %in% 6:35
  expect_lt(max(d[inner], na.rm = TRUE), 1e-5)
  expect_error(geo_downscale_lapse(tc, dem, lapse_rate = "a"), "lapse_rate")
})

test_that("canopy offset scales with canopy cover", {
  skip_if_not_installed("terra")
  t <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2, vals = 30)
  cv <- t
  terra::values(cv) <- c(0, 0.5, 1, 1)
  out <- geo_canopy_offset(t, cv, offset = -4)
  expect_equal(terra::values(out)[, 1], c(30, 28, 26, 26))
  forest <- cv >= 1
  expect_equal(terra::values(geo_canopy_offset(t, forest, -4))[, 1], c(30, 30, 26, 26))
  expect_error(geo_canopy_offset(t, cv * 2, -4), "between 0 and 1")
  expect_error(geo_canopy_offset(t, cv, c(1, 2)), "offset")
})

test_that("geo_chelsa_area reads a small real window", {
  skip_on_cran()
  skip_if_offline("os.zhdk.cloud.switch.ch")
  skip_if_not_installed("terra")
  r <- geo_chelsa_area(c(146.9, -6.3, 147, -6.2), "bio1")
  expect_equal(names(r), "bio1_1981-2010")
  v <- terra::values(r)
  expect_true(all(v > 0 & v < 30, na.rm = TRUE))
})

test_that("geo_chelsa() future climate uses CHELSA-CMIP6 periods", {
  expect_equal(tidymapr:::tmr_chelsa_period(2050), "2041-2070")
  expect_equal(tidymapr:::tmr_chelsa_period(2040), "2011-2040")
  expect_equal(tidymapr:::tmr_chelsa_period(2100), "2071-2100")
  expect_error(tidymapr:::tmr_chelsa_period(2200), "2011 to 2100")
  skip_if_not_installed("terra")
  expect_error(
    suppressMessages(geo_chelsa("bio1",
      scenario = "ssp585", year = 2050,
      cache_dir = tempfile(), download = FALSE
    )),
    "not cached"
  )
})
