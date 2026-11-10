skip_if_not_installed("maxnet")

brady <- function() {
  e <- new.env()
  utils::data("bradypus", package = "maxnet", envir = e)
  e$bradypus
}

test_that("the C++ lasso path matches glmnet", {
  skip_if_not_installed("glmnet")
  set.seed(3)
  n <- 300
  x <- matrix(stats::runif(n * 6), n)
  y <- stats::rbinom(n, 1, stats::plogis(-1 + 2 * x[, 1] - 1.5 * x[, 2]))
  w <- y + (1 - y) * 5
  pf <- c(1, 1, 2, 2, 0.5, 1)
  lam <- 10^seq(-1, -3, length.out = 30)
  ref <- glmnet::glmnet(x, factor(y),
    family = "binomial", weights = w,
    penalty.factor = pf, lambda = lam, standardize = FALSE, thresh = 1e-12
  )
  ours <- tidymapr:::sdm_lasso_logit_cpp(x, y, w, pf, lam, thresh = 1e-12)
  expect_equal(unname(ours$beta[, 30]), unname(as.vector(ref$beta[, 30])), tolerance = 1e-3)
  expect_equal(ours$a0[30], unname(ref$a0[30]), tolerance = 1e-3)
})

test_that("sdm_maxent reproduces maxnet without standardisation", {
  b <- brady()
  p <- b$presence
  d <- b[, -1]
  ref <- maxnet::maxnet(p, d, maxnet::maxnet.formula(p, d, classes = "lqh"))
  fit <- sdm_maxent(p, d, features = "lqh", standardize = FALSE)
  pr <- as.vector(predict(ref, d, type = "cloglog"))
  pt <- predict(fit, d)
  expect_gt(stats::cor(pr, pt), 0.999)
  expect_lt(max(abs(pr - pt)), 0.05)
  expect_s3_class(fit, "tmr_maxent")
  expect_true(all(pt >= 0 & pt <= 1))
  expect_message(print(fit), "Maxent")
})

test_that("standardised Maxent does not depend on where zero lies", {
  b <- brady()
  p <- b$presence
  d <- b[, c("tmp6190_ann", "pre6190_ann", "h_dem", "cld6190_ann")]
  d2 <- d
  d2$tmp6190_ann <- d2$tmp6190_ann + 2731.5 # tenths of degrees C to K
  s1 <- predict(sdm_maxent(p, d, features = "lqp"), d)
  s2 <- predict(sdm_maxent(p, d2, features = "lqp"), d2)
  expect_equal(s1, s2, tolerance = 1e-8)
})

test_that("Maxent checks its input and predicts on rasters", {
  b <- brady()
  expect_error(sdm_maxent(c(1, 2), b[1:2, -1]), "0/1")
  expect_error(sdm_maxent(b$presence, b[, -1], features = "xyz"), "letters")
  d <- b[, c("tmp6190_ann", "pre6190_ann")]
  fit <- sdm_maxent(b$presence, d, features = "lq")
  skip_if_not_installed("terra")
  r <- terra::rast(
    nrows = 5, ncols = 5, nlyrs = 2,
    vals = c(seq(150, 280, length.out = 25), seq(10, 300, length.out = 25))
  )
  names(r) <- names(d)
  pr <- predict(fit, r)
  expect_s4_class(pr, "SpatRaster")
  expect_true(all(terra::values(pr) >= 0 & terra::values(pr) <= 1))
})
