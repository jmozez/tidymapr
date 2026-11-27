test_that("GWR with a very wide kernel equals ordinary least squares", {
  set.seed(1)
  d <- data.frame(x = runif(40), y = runif(40), z = rnorm(40))
  d$v <- 2 + 3 * d$z + rnorm(40, sd = 0.1)
  fit <- geo_gwr(
    d, v ~ z,
    lon = x, lat = y, bandwidth = 1e6,
    kernel = "gaussian", adaptive = FALSE, lonlat = FALSE
  )
  ols <- stats::coef(stats::lm(v ~ z, d))
  expect_s3_class(fit, "tmr_gwr")
  expect_equal(fit$intercept, rep(unname(ols[1]), 40), tolerance = 1e-6)
  expect_equal(fit$z, rep(unname(ols[2]), 40), tolerance = 1e-6)
  expect_equal(attr(fit, "gwr")$enp, 2, tolerance = 1e-4)
})

test_that("GWR recovers a coefficient that varies in space", {
  set.seed(2)
  g <- expand.grid(x = 1:15, y = 1:15)
  g$z <- rnorm(nrow(g))
  g$v <- (g$x / 5) * g$z + rnorm(nrow(g), sd = 0.2)
  fit <- geo_gwr(g, v ~ z, lon = x, lat = y, lonlat = FALSE)
  expect_gt(stats::cor(fit$z, g$x / 5), 0.9)
  expect_lt(attr(fit, "gwr")$aicc, attr(fit, "gwr")$aicc_global)
  expect_true(all(is.finite(fit$se_z)))
  expect_message(print(fit), "bandwidth")
  cv <- geo_gwr(g, v ~ z, lon = x, lat = y, lonlat = FALSE, criterion = "cv")
  expect_true(attr(cv, "gwr")$bandwidth >= 4)
})

# Reference values from GWmodel 2.4 (gwr.basic, bisquare, adaptive 30,
# longlat = TRUE); small differences come from the great-circle distance.
test_that("GWR agrees with GWmodel on the Boston housing data", {
  skip_if_not_installed("spData")
  b <- spData::boston.c
  fit <- geo_gwr(b, log(CMEDV) ~ RM + LSTAT, lon = LON, lat = LAT, bandwidth = 30)
  expect_equal(fit$LSTAT[1:5], c(-0.022775, -0.029827, -0.029554, -0.017254, -0.01813),
    tolerance = 5e-3
  )
  expect_equal(fit$se_LSTAT[1:5], c(0.009067, 0.008047, 0.008988, 0.007665, 0.007911),
    tolerance = 5e-3
  )
  expect_equal(attr(fit, "gwr")$aicc, -410.9476, tolerance = 1e-3)
  expect_error(geo_gwr(b, "CMEDV", lon = LON, lat = LAT), "formula")
})

test_that("sdm_mess() matches the Elith et al. definition", {
  train <- data.frame(a = 1:10, b = seq(10, 100, by = 10))
  new <- data.frame(a = c(5.5, 0, 12, 1), b = c(50, 50, 55, 100))
  m <- sdm_mess(train, new, predictors = c("a", "b"))
  # For a 5.5, f is 50 so the similarity is 100; for b 50, f is 40 so 80
  expect_equal(m$mess[1], 80)
  expect_equal(m$mod[1], "b")
  # a = 0 below the range: (0 - 1) / 9 * 100
  expect_equal(m$mess[2], -100 / 9)
  expect_equal(m$mod[2], "a")
  # a = 12 above the range: (10 - 12) / 9 * 100
  expect_equal(m$mess[3], -200 / 9)
  # b = 100 is the maximum: f = 90 -> 20; a = 1 is the minimum: f = 0 -> 0
  expect_equal(m$mess[4], 0)
})

test_that("sdm_aoa() follows Meyer and Pebesma (2021)", {
  set.seed(1)
  train <- data.frame(temp = runif(60, 18, 24), rain = runif(60, 2000, 3000))
  new <- data.frame(temp = c(21, 21, 35), rain = c(2500, 2500, 6000))
  a <- sdm_aoa(train, new, predictors = c("temp", "rain"))
  expect_equal(a$aoa, c(TRUE, TRUE, FALSE))
  expect_gt(a$di[3], 3)
  # Hand computation of DI for the first new point
  s <- scale(train)
  z <- (unlist(new[1, ]) - attr(s, "scaled:center")) / attr(s, "scaled:scale")
  dd <- stats::dist(s)
  expect_equal(a$di[1], sqrt(min(colSums((t(s) - z)^2))) / mean(dd))
  thr <- attr(a, "threshold")
  expect_true(is.numeric(thr) && thr > 0)
  # Cross-validation folds raise the training DI and so the threshold
  folds <- rep(1:3, each = 20)
  f <- sdm_aoa(train, new, predictors = c("temp", "rain"), folds = folds)
  expect_gte(attr(f, "threshold"), thr)
  # Zero weight removes a predictor
  w <- sdm_aoa(train, new, predictors = c("temp", "rain"), weights = c(temp = 1, rain = 0))
  expect_lt(w$di[3], a$di[3])
  expect_error(sdm_aoa(train, new), "predictors")
  expect_error(sdm_aoa(train, new, c("temp", "rain"), weights = c(1, 1)), "named")
})
