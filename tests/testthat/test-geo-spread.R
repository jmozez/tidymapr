grid_m <- function(nr, nc, res = 100) {
  terra::rast(
    nrows = nr, ncols = nc, xmin = 0, xmax = nc * res, ymin = 0, ymax = nr * res,
    crs = "EPSG:32755"
  )
}

test_that("kernels have the requested mean distance and the 2Dt a fatter tail", {
  e <- geo_dispersal_kernel(500, cell_size = 25, max_distance = 10000)
  t3 <- geo_dispersal_kernel(500,
    cell_size = 25, kernel = "2Dt", kernel_shape = 3, max_distance = 20000
  )
  expect_equal(e$realised_mean, 500, tolerance = 0.01)
  expect_equal(t3$realised_mean, 500, tolerance = 0.03)
  t1 <- geo_dispersal_kernel(500,
    cell_size = 25, kernel = "2Dt", kernel_shape = 1, max_distance = 10000
  )
  expect_lt(e$share_beyond_5mean, 0.001)
  expect_gt(t1$share_beyond_5mean, 20 * e$share_beyond_5mean)
  expect_error(geo_dispersal_kernel(500, 25, kernel = "2Dt", kernel_shape = 0.4), "0.5")
})

test_that("uniform resistance of 1 changes nothing; barriers stop spread", {
  skip_if_not_installed("terra")
  r <- grid_m(20, 40)
  suit <- terra::init(r, 0.9)
  init <- terra::init(r, 0)
  init[, 1:3] <- 1
  a <- geo_shift_simulate(suit, init,
    dispersal_mean = 200, steps_per_layer = 8, nsim = 20, seed = 4, persistence = 0
  )
  b <- geo_shift_simulate(suit, init,
    dispersal_mean = 200, steps_per_layer = 8, nsim = 20, seed = 4, persistence = 0,
    resistance = terra::init(r, 1)
  )
  expect_equal(terra::values(a), terra::values(b))
  # A wall of impassable cells (wider than the kernel reach) at columns 15-27
  wall <- terra::init(r, 1)
  wall[, 15:27] <- NA
  w <- geo_shift_simulate(suit, init,
    dispersal_mean = 200, steps_per_layer = 30, nsim = 10, seed = 4, persistence = 0,
    resistance = wall
  )
  m <- terra::as.matrix(w, wide = TRUE)
  expect_true(all(m[, 28:40] == 0))
  expect_gt(mean(m[, 10:14]), 0.5)
  # Higher resistance slows the invasion
  slow <- geo_shift_simulate(suit, init,
    dispersal_mean = 200, steps_per_layer = 8, nsim = 20, seed = 4, persistence = 0,
    resistance = terra::init(r, 3)
  )
  expect_lt(sum(terra::values(slow)), sum(terra::values(a)))
})

test_that("disturbance removes occupied cells at the given rate", {
  skip_if_not_installed("terra")
  r <- grid_m(41, 41)
  suit <- terra::init(r, 1)
  init <- terra::init(r, 0)
  init[21, 21] <- 1
  o <- geo_shift_simulate(suit, init,
    dispersal_mean = 100, colonisation = 0, nsim = 20000, seed = 2,
    disturbance = terra::init(r, 0.3)
  )
  expect_equal(o[21, 21][[1]], 0.7, tolerance = 0.02)
})

test_that("jumps reach only cells with jump weight, beyond the kernel", {
  skip_if_not_installed("terra")
  r <- grid_m(30, 30)
  suit <- terra::init(r, 1)
  init <- terra::init(r, 0)
  init[1, 1] <- 1
  wt <- terra::init(r, 0)
  wt[30, 30] <- 1
  o <- geo_shift_simulate(suit, init,
    dispersal_mean = 50, max_distance = 150, colonisation = 0,
    jump_rate = 0.5, jump_weights = wt, nsim = 2000, seed = 3
  )
  v <- terra::as.matrix(o, wide = TRUE)
  # P(at least one jump from one occupied cell) = 1 - exp(-0.5)
  expect_equal(v[30, 30], 1 - exp(-0.5), tolerance = 0.05)
  v[1, 1] <- 0
  v[30, 30] <- 0
  expect_true(all(v == 0))
})

test_that("the SIR final size matches theory in a well-mixed population", {
  skip_if_not_installed("terra")
  r <- grid_m(1, 1, 1000)
  for (beta in c(0.15, 0.3)) {
    ep <- geo_epidemic_simulate(terra::init(r, 20000), terra::init(r, 20),
      beta = beta, gamma = 0.1, coupling = 0, dispersal_mean = 100,
      times = 600, nsim = 200, seed = 1
    )
    r0 <- ep$settings$R0
    expect_equal(r0, beta / (1 - exp(-0.1)))
    z <- stats::uniroot(function(z) z - (1 - exp(-r0 * z)), c(1e-6, 1))$root
    expect_equal(stats::median(ep$attack), z, tolerance = 0.01)
  }
})

test_that("epidemics spread only with coupling and are thread-invariant", {
  skip_if_not_installed("terra")
  r <- grid_m(15, 15, 1000)
  h <- terra::init(r, 500)
  i0 <- terra::init(r, 0)
  i0[8, 8] <- 10
  none <- geo_epidemic_simulate(h, i0,
    beta = 0.5, gamma = 0.1, coupling = 0,
    dispersal_mean = 2000, times = 60, nsim = 5, seed = 1
  )
  m <- terra::as.matrix(none$reached, wide = TRUE)
  m[8, 8] <- 0
  expect_true(all(m == 0))
  a <- geo_epidemic_simulate(h, i0,
    beta = 0.5, gamma = 0.1, coupling = 0.3,
    dispersal_mean = 2000, times = c(20, 60), nsim = 8, seed = 1, threads = 1
  )
  b <- geo_epidemic_simulate(h, i0,
    beta = 0.5, gamma = 0.1, coupling = 0.3,
    dispersal_mean = 2000, times = c(20, 60), nsim = 8, seed = 1, threads = 3
  )
  expect_equal(terra::values(a$reached), terra::values(b$reached))
  expect_gt(mean(terra::values(a$reached[[2]])), 0.5)
  expect_true(all(diff(colMeans(terra::values(a$reached))) >= 0))
  expect_s3_class(a, "tmr_epidemic")
})
