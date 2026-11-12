test_that("geo_mem() reproduces adespatial::dbmem()", {
  skip_if_not_installed("adespatial")
  skip_if_not_installed("terra")
  meuse <- as.data.frame(terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra"))))
  xy <- meuse[, c("x", "y")]
  ref <- adespatial::dbmem(xy, silent = TRUE)
  ours <- geo_mem(meuse, lon = x, lat = y, method = "euclidean")
  mo <- as.matrix(ours[grep("^MEM", names(ours))])
  mr <- as.matrix(ref)
  expect_equal(ncol(mo), ncol(mr))
  expect_equal(attr(ours, "eigenvalues"), unname(attr(ref, "values")), tolerance = 1e-8)
  # Eigenvectors are defined up to sign
  expect_equal(unname(abs(colSums(mo * mr))), rep(nrow(mo), ncol(mo)), tolerance = 1e-6)
})

test_that("dbMEMs are centred, have variance 1 and are uncorrelated", {
  g <- expand.grid(lon = 1:6, lat = 1:5)
  m <- as.matrix(geo_mem(g, method = "euclidean")[-(1:2)])
  expect_equal(unname(colMeans(m)), rep(0, ncol(m)), tolerance = 1e-10)
  expect_equal(unname(crossprod(m)), diag(nrow(g), ncol(m)), tolerance = 1e-8)
})
