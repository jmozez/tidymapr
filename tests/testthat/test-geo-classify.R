test_that("Fisher-Jenks breaks are optimal and match classInt", {
  set.seed(1)
  x <- c(rnorm(30, 10), rnorm(30, 30), rnorm(30, 60), runif(20, 0, 80))
  ssq <- function(b) {
    cl <- cut(x, b, include.lowest = TRUE)
    sum(tapply(x, cl, function(v) sum((v - mean(v))^2)))
  }
  for (k in 2:6) {
    b <- geo_breaks(x, k, "jenks")
    expect_length(b, k + 1)
    expect_equal(range(b), range(x))
    if (requireNamespace("classInt", quietly = TRUE)) {
      expect_equal(b, classInt::classIntervals(x, k, style = "jenks")$brks)
      fisher <- classInt::classIntervals(x, k, style = "fisher")$brks
      expect_equal(ssq(b), ssq(fisher))
    }
  }
})

test_that("geo_breaks() styles", {
  x <- c(1, 2, 3, 4, 10, 20, 30, 40)
  expect_equal(geo_breaks(x, 4, "quantile"), unname(quantile(x, 0:4 / 4)))
  expect_equal(geo_breaks(x, 3, "equal"), seq(1, 40, length.out = 4))
  p <- geo_breaks(x, 4, "pretty")
  expect_true(min(p) <= 1 && max(p) >= 40)
  s <- geo_breaks(x, style = "sd")
  expect_true(min(s) <= 1 && max(s) >= 40)
  expect_equal(geo_breaks(x, style = "fixed", breaks = c(40, 0, 15)), c(0, 15, 40))
  expect_error(geo_breaks(x, style = "fixed"), "breaks")
  expect_error(geo_breaks("a"), "numeric")
})

test_that("geo_classify() adds ordered classes and explains them", {
  sites <- geo_example_sites()
  out <- geo_classify(sites, elevation, n = 3, style = "equal")
  expect_s3_class(out$elevation_class, "ordered")
  expect_equal(nlevels(out$elevation_class), 3)
  info <- attr(out, "classification")
  expect_equal(sum(info$counts), nrow(sites))
  expect_true(info$gvf > 0 && info$gvf <= 1)
  named <- geo_classify(sites, elevation, n = 2, name = "band")
  expect_true("band" %in% names(named))
})
