test_that("the 2D spreading dye reduces to the 1D model of rangemodelR", {
  skip_if_not_installed("rangemodelR")
  n <- 8
  size <- c(1, 2, 3, 5, 8, 4, 6, 2, 7, 3)
  set.seed(1)
  s <- geo_mde_cpp(rep(1L, n), 1L, as.integer(n), as.integer(size), 20000L)
  m <- vapply(seq_along(size), function(j) as.numeric(seq_len(n) <= size[j]), numeric(n))
  rownames(m) <- seq_len(n)
  set.seed(2)
  ref <- rangemodelR::rangemod1d(m, cohesion = TRUE, reps = 5000)$mod.rich
  expect_equal(rowMeans(s$richness), unname(ref), tolerance = 0.02)
  expect_equal(sum(rowMeans(s$richness)), sum(size))
  expect_equal(s$truncated, 0)
})

test_that("ranges stay contiguous and inside the domain", {
  # An L-shaped domain on a 4 x 4 grid; one range fills it exactly
  dom <- c(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1)
  set.seed(3)
  s <- geo_mde_cpp(as.integer(dom), 4L, 4L, c(7L, 1L), 200L)
  expect_equal(nrow(s$richness), 7)
  expect_true(all(s$richness >= 1 & s$richness <= 2))
  # A range larger than the domain is truncated, not placed outside it
  t <- geo_mde_cpp(as.integer(dom), 4L, 4L, 9L, 10L)
  expect_equal(t$truncated, 10)
  expect_true(all(t$richness == 1))
})

test_that("geo_mde returns observed, expected and effect sizes", {
  skip_if_not_installed("terra")
  lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
  set.seed(1)
  pts <- sf::st_sample(sf::st_union(lux), 200)
  occ <- sf::st_sf(species = sample(paste0("sp", 1:15), 200, TRUE), geometry = pts)
  m <- geo_mde(occ, lux, res = 6000, nsim = 49)
  expect_s4_class(m, "SpatRaster")
  expect_equal(names(m), c("observed", "expected", "sd", "lower", "upper", "ses"))
  f <- attr(m, "fit")
  expect_equal(f$n_species, 15)
  v <- terra::values(m)
  ok <- !is.na(v[, "expected"])
  expect_equal(sum(v[ok, "expected"]), sum(v[ok, "observed"]), tolerance = 1e-8)
  expect_true(all(v[ok, "lower"] <= v[ok, "upper"]))
  cells <- geo_mde(occ, lux, res = 6000, nsim = 9, range = "cells")
  expect_lte(sum(terra::values(cells$observed), na.rm = TRUE), sum(v[ok, "observed"]))
  expect_error(geo_mde(occ, lux, res = 1e6), "fewer than 4")
})
