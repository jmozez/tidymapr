ants_nb <- function(k) {
  skip_if_not_installed("spdep")
  xy <- cbind(png_ants_sites$lon, png_ants_sites$lat)
  spdep::knn2nb(spdep::knearneigh(xy, k = k, longlat = TRUE))
}

test_that("Gi* equals spdep::localG() for k-nearest and distance bands", {
  nb <- ants_nb(3)
  h <- geo_hotspot(png_ants_sites, elevation, k = 3)
  ref <- spdep::localG(
    png_ants_sites$elevation,
    spdep::nb2listw(spdep::include.self(nb), style = "B")
  )
  expect_equal(h$gi_star, as.numeric(ref), tolerance = 1e-10)
  xy <- cbind(png_ants_sites$lon, png_ants_sites$lat)
  nbd <- spdep::dnearneigh(xy, 0, 3, longlat = TRUE)
  hd <- geo_hotspot(png_ants_sites, elevation, dist = 3000)
  refd <- spdep::localG(
    png_ants_sites$elevation,
    spdep::nb2listw(spdep::include.self(nbd), style = "B")
  )
  expect_equal(hd$gi_star, as.numeric(refd), tolerance = 1e-10)
  expect_s3_class(h$hotspot, "factor")
  expect_identical(attr(h, "neighbours"), "3 nearest neighbours")
})

test_that("local Moran's I and its moments equal spdep::localmoran()", {
  for (k in c(3, 5)) {
    nb <- ants_nb(k)
    l <- geo_lisa(png_ants_sites, elevation, k = k)
    ref <- spdep::localmoran(png_ants_sites$elevation, spdep::nb2listw(nb))
    expect_equal(l$lisa, unname(ref[, "Ii"]), tolerance = 1e-10)
    expect_equal(l$lisa_expected, unname(ref[, "E.Ii"]), tolerance = 1e-10)
    expect_equal(l$lisa_variance, unname(ref[, "Var.Ii"]), tolerance = 1e-10)
    expect_equal(l$p_value, unname(ref[, 5]), tolerance = 1e-10)
  }
})

test_that("permutation p-values, missing rows and errors", {
  l <- geo_lisa(png_ants_sites, elevation, k = 3, nperm = 199, seed = 1)
  expect_true(all(l$p_value > 0 & l$p_value <= 1))
  d <- png_ants_sites
  d$elevation[2] <- NA
  h <- geo_hotspot(d, elevation, k = 3)
  expect_true(is.na(h$gi_star[2]) && is.na(h$hotspot[2]))
  expect_equal(sum(!is.na(h$gi_star)), 15)
  expect_error(geo_hotspot(png_ants_sites, site), "numeric")
  expect_error(geo_lisa(png_ants_sites[1:2, ], elevation), "three")
  expect_warning(geo_hotspot(png_ants_sites, elevation, dist = 10), "no neighbour")
})
