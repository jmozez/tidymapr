# Virtual species: intensity exp(1 - 0.06 (temp - 20)^2), optimum 20 C
isdm_fixture <- function(confounded = FALSE, seed = 1) {
  set.seed(seed)
  n <- 20000
  bg <- data.frame(temp = stats::runif(n, 5, 30))
  # Observers favour warm, accessible lowlands when confounded
  bg$road <- if (confounded) (30 - bg$temp) / 25 * 0.8 + stats::runif(n) * 0.2 else stats::runif(n)
  eta <- function(d) 1 - 0.06 * (d$temp - 20)^2
  lam <- exp(eta(bg)) * exp(-4 * bg$road)
  po <- bg[stats::runif(n) < lam / max(lam) * 0.08, ]
  sv <- data.frame(temp = stats::runif(200, 5, 30), road = stats::runif(200))
  sv$present <- stats::rbinom(200, 1, 1 - exp(-exp(eta(sv))))
  list(po = po, bg = bg, sv = sv, eta = eta)
}
isdm_optimum <- function(f) {
  b1 <- f$coef[["temp"]]
  b2 <- f$coef[["temp^2"]]
  f$spec$centre[["temp"]] + f$spec$scale[["temp"]] * (-b1 / (2 * b2))
}

test_that("the integrated model recovers the niche and absolute probabilities", {
  d <- isdm_fixture()
  f <- sdm_integrated(d$po, d$bg, 1000, d$sv,
    covariates = "temp", unimodal = "temp", bias = "road"
  )
  expect_equal(f$convergence, 0)
  expect_equal(isdm_optimum(f), 20, tolerance = 0.05)
  expect_lt(f$coef[["road"]], 0)
  nd <- data.frame(temp = c(15, 20, 25))
  truth <- 1 - exp(-exp(d$eta(nd)))
  expect_equal(predict(f, nd), truth, tolerance = 0.15)
  expect_true(all(f$se > 0))
})

test_that("surveys and bias covariates correct confounded sampling", {
  d <- isdm_fixture(confounded = TRUE)
  naive <- sdm_integrated(d$po, d$bg, 1000, covariates = "temp", unimodal = "temp")
  full <- sdm_integrated(d$po, d$bg, 1000, d$sv,
    covariates = "temp", unimodal = "temp", bias = "road"
  )
  # Records are pulled towards the warm, accessible end without correction
  expect_gt(abs(isdm_optimum(naive) - 20), abs(isdm_optimum(full) - 20))
  expect_equal(isdm_optimum(full), 20, tolerance = 0.06)
})

test_that("unimodal responses and physiological limits constrain projections", {
  d <- isdm_fixture()
  # Only the cool half of the niche observed: responses could rise forever
  po <- d$po[d$po$temp < 18, ]
  bg <- d$bg[d$bg$temp < 18, ]
  f <- sdm_integrated(po, bg, 500, covariates = "temp", unimodal = "temp")
  expect_lt(f$coef[["temp^2"]], 0)
  g <- sdm_integrated(d$po, d$bg, 1000, d$sv,
    covariates = "temp", unimodal = "temp",
    limits = list(temp = c(NA, 24)), limit_width = 1
  )
  p <- predict(g, data.frame(temp = c(20, 23, 24, 25)))
  expect_gt(p[1], 0.5)
  expect_lt(p[4], 0.02 * p[1])
  lim <- predict(g, data.frame(temp = 24), type = "intensity") /
    exp(predict(g, data.frame(temp = 24), type = "link") - log(stats::plogis(-2.2)))
  expect_equal(unname(lim), stats::plogis(-2.2), tolerance = 1e-8)
})

test_that("prediction works on rasters and inputs are checked", {
  skip_if_not_installed("terra")
  d <- isdm_fixture()
  f <- sdm_integrated(d$po, d$bg, 1000, d$sv, covariates = "temp", unimodal = "temp")
  r <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  terra::values(r) <- seq(5, 30, length.out = 25)
  names(r) <- "temp"
  pr <- predict(f, r)
  expect_s4_class(pr, "SpatRaster")
  expect_equal(terra::values(pr)[, 1], predict(f, data.frame(temp = terra::values(r)[, 1])))
  expect_error(sdm_integrated(d$po, d$bg, 1000, covariates = "x"), "missing")
  expect_error(sdm_integrated(d$po, d$bg, -1, covariates = "temp"), "area")
  bad <- d$sv
  bad$present <- 2
  expect_error(sdm_integrated(d$po, d$bg, 1000, bad, covariates = "temp"), "0 or 1")
  expect_error(
    sdm_integrated(d$po, d$bg, 1000,
      covariates = "temp", quadratic = character(), unimodal = "temp"
    ),
    "unimodal"
  )
})
