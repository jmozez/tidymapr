s2_lux <- function() {
  skip_if_not_installed("terra")
  terra::rast(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
}

test_that("spectral indices equal their formulas and Otsu splits the histogram", {
  s2 <- s2_lux()
  nd <- geo_spectral_index(s2, "NDVI", threshold = "otsu")
  ref <- (s2$B08 - s2$B04) / (s2$B08 + s2$B04)
  expect_equal(terra::values(nd[[1]]), terra::values(ref), ignore_attr = TRUE)
  th <- attr(nd, "threshold")
  expect_true(th$cut > 0.1 && th$cut < 0.65)
  expect_true(th$share_above > 0 && th$share_above < 1)
  ndwi <- geo_spectral_index(s2, "NDWI")
  expect_equal(
    terra::values(ndwi), terra::values((s2$B03 - s2$B08) / (s2$B03 + s2$B08)),
    ignore_attr = TRUE
  )
  expect_error(geo_spectral_index(s2, "NBR"), "swir2")
  # Otsu finds the gap between two clear modes
  set.seed(1)
  v <- c(rnorm(500, 0.2, 0.03), rnorm(500, 0.7, 0.03))
  expect_true(abs(tidymapr:::tmr_otsu(v) - 0.45) < 0.1)
})

test_that("spectral diversity equals direct Hill numbers in each window", {
  s2 <- s2_lux()
  set.seed(1)
  sd <- geo_spectral_diversity(s2, window = 5, k = 12)
  expect_named(sd, c("q0", "q1", "q2", "spectral_species"))
  cls <- terra::values(sd$spectral_species, mat = FALSE)
  nr <- terra::nrow(s2)
  nc <- terra::ncol(s2)
  valid <- which(!is.na(cls) & !is.na(terra::values(sd$q0, mat = FALSE)))
  for (i in valid[round(seq(1, length(valid), length.out = 6))]) {
    r <- (i - 1) %/% nc
    c <- (i - 1) %% nc
    rr <- max(0, r - 2):min(nr - 1, r + 2)
    cc <- max(0, c - 2):min(nc - 1, c + 2)
    v <- cls[as.vector(outer(cc, rr * nc, "+")) + 1]
    p <- table(v[!is.na(v)]) / sum(!is.na(v))
    expect_equal(terra::values(sd$q0)[i], length(p))
    expect_equal(terra::values(sd$q1)[i], exp(-sum(p * log(p))), tolerance = 1e-12)
    expect_equal(terra::values(sd$q2)[i], 1 / sum(p^2), tolerance = 1e-12)
  }
  v <- terra::values(sd)
  ok <- stats::complete.cases(v)
  expect_true(all(v[ok, "q0"] >= v[ok, "q1"] - 1e-9 & v[ok, "q1"] >= v[ok, "q2"] - 1e-9))
  expect_error(geo_spectral_diversity(s2, window = 4), "odd")
})
