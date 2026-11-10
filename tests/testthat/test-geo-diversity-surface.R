bci_data <- function() {
  skip_if_not_installed("vegan")
  skip_if_not_installed("tidydiversity")
  skip_if_not_installed("gstat")
  skip_if_not_installed("terra")
  e <- new.env()
  utils::data(BCI, BCI.env, package = "vegan", envir = e)
  trees <- tibble::tibble(
    plot = rep(sprintf("P%02d", 1:50), ncol(e$BCI)),
    species = rep(colnames(e$BCI), each = 50),
    n = as.vector(as.matrix(e$BCI))
  )
  list(
    trees = trees[trees$n > 0, ],
    plots = tibble::tibble(
      plot = sprintf("P%02d", 1:50),
      x = e$BCI.env$UTM.EW, y = e$BCI.env$UTM.NS
    )
  )
}

test_that("kriging with measurement error equals gstat's Err model", {
  skip_if_not_installed("gstat")
  skip_if_not_installed("sf")
  s <- sf::st_transform(geo_as_sf(geo_example_sites(), lon, lat), 32755)
  xy <- sf::st_coordinates(s)
  g <- sf::st_as_sf(expand.grid(
    x = seq(min(xy[, 1]), max(xy[, 1]), length.out = 10),
    y = seq(min(xy[, 2]), max(xy[, 2]), length.out = 10)
  ), coords = c("x", "y"), crs = 32755)
  gxy <- sf::st_coordinates(g)
  e <- 5e4
  mine <- tidymapr:::geo_krige_cpp(
    xy[, 1], xy[, 2], s$elevation, gxy[, 1], gxy[, 2], 1L, 0, 4e5, 8000,
    FALSE, TRUE, 1L, rep(e, nrow(s))
  )
  vm <- gstat::vgm(4e5, "Exp", 8000, add.to = gstat::vgm(e, "Err", 0))
  ref <- suppressWarnings(gstat::krige(elevation ~ 1, s, g, model = vm, debug.level = 0))
  expect_equal(mine$prediction, ref$var1.pred, tolerance = 1e-8)
  expect_equal(mine$variance, ref$var1.var, tolerance = 1e-8)
  # A very noisy site is smoothed; exact sites are honoured
  at <- tidymapr:::geo_krige_cpp(
    xy[, 1], xy[, 2], s$elevation, xy[, 1], xy[, 2], 1L, 0, 4e5, 8000,
    FALSE, TRUE, 1L, c(1e6, rep(0, nrow(s) - 1))
  )
  expect_gt(abs(at$prediction[1] - s$elevation[1]), 100)
  expect_equal(at$prediction[-1], s$elevation[-1], tolerance = 1e-8)
})

test_that("geo_diversity_surface() maps coverage-standardised Hill numbers", {
  d <- bci_data()
  set.seed(1)
  surf <- geo_diversity_surface(d$trees, plot, species, n,
    sites = d$plots, lon = x, lat = y, crs = 32617, grid = 20, nboot = 10
  )
  expect_s4_class(surf, "SpatRaster")
  expect_identical(
    names(surf),
    c("q0", "q0_lower", "q0_upper", "q1", "q1_lower", "q1_upper", "q2", "q2_lower", "q2_upper")
  )
  st <- attr(surf, "sites")
  expect_equal(length(unique(st$plot)), 50)
  # Every site is standardised to the same coverage
  expect_lt(diff(range(st$coverage)), 1e-4)
  v <- terra::values(surf)
  # Hill numbers decrease with q, and intervals contain the prediction
  expect_true(all(v[, "q0"] >= v[, "q1"] & v[, "q1"] >= v[, "q2"]))
  expect_true(all(v[, "q1_lower"] <= v[, "q1"] & v[, "q1"] <= v[, "q1_upper"]))
  # Predictions stay within the range of the site estimates
  for (qq in 0:2) {
    r <- range(st$diversity[st$q == qq])
    p <- v[, paste0("q", qq)]
    expect_true(all(p > 0.8 * r[1] & p < 1.2 * r[2]))
  }
  expect_named(attr(surf, "variograms"), c("q0", "q1", "q2"))
  skip_if_not_installed("ggplot2")
  expect_no_error(plot_diversity_surface(surf))
  expect_error(plot_diversity_surface(terra::rast()), "geo_diversity_surface")
})
