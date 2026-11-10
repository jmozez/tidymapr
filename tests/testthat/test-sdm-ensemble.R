skip_if_not_installed("maxnet")

test_that("the C++ random forest separates classes and is reproducible", {
  set.seed(4)
  x <- matrix(stats::runif(400 * 3), 400)
  y <- as.numeric(x[, 1] + 0.2 * stats::rnorm(400) > 0.6)
  f1 <- tidymapr:::sdm_rf_fit_cpp(x, y, ntree = 100, mtry = 2, seed = 7)
  f2 <- tidymapr:::sdm_rf_fit_cpp(x, y, ntree = 100, mtry = 2, seed = 7)
  p1 <- tidymapr:::sdm_rf_predict_cpp(f1, x)
  expect_equal(p1, tidymapr:::sdm_rf_predict_cpp(f2, x))
  expect_gt(tidymapr:::sdm_auc(y, p1), 0.9)
  expect_true(all(p1 >= 0 & p1 <= 1))
})

test_that("spatial folds balance presences and background", {
  set.seed(5)
  xy <- cbind(stats::runif(2000, 0, 100), stats::runif(2000, 0, 100))
  y <- rep(c(1, 0), c(100, 1900))
  f <- tidymapr:::tmr_sdm_folds(y, xy, 5, NULL, 1)
  tab <- table(f, y)
  expect_equal(nrow(tab), 5)
  expect_lt(max(tab[, "1"]) / min(tab[, "1"]), 3)
  expect_lt(max(tab[, "0"]) / min(tab[, "0"]), 3)
})

test_that("ensembles score, weight and predict", {
  e <- new.env()
  utils::data("bradypus", package = "maxnet", envir = e)
  b <- e$bradypus
  d <- b[, c("tmp6190_ann", "pre6190_ann", "h_dem", "cld6190_ann", "vap6190_ann")]
  ens <- sdm_ensemble(b$presence, d,
    algorithms = c("maxent", "glm", "rf"),
    folds = 3, ntree = 100
  )
  expect_s3_class(ens, "tmr_sdm_ensemble")
  expect_equal(ens$summary$algorithm, c("maxent", "glm", "rf"))
  expect_equal(sum(ens$summary$weight), 1)
  expect_true(all(ens$summary$auc > 0.7))
  pr <- predict(ens, d)
  expect_length(pr, nrow(d))
  all <- predict(ens, d, what = "all")
  expect_true(all(c("maxent", "glm", "rf", "mean", "sd") %in% names(all)))
  expect_message(print(ens), "SDM ensemble")
  expect_gt(tidymapr:::tmr_tss(b$presence, pr), 0.4)
})
