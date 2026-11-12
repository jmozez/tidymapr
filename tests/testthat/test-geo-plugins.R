skip_if_not_installed("sf")

test_that("DBSCAN matches the dbscan package", {
  skip_if_not_installed("dbscan")
  q <- sf::st_as_sf(datasets::quakes, coords = c("long", "lat"), crs = 4326)
  xy <- sf::st_coordinates(sf::st_transform(q, geo_crs("laea", data = q)))
  for (e in c(30000, 50000, 80000)) {
    a <- dbscan::dbscan(xy, eps = e, minPts = 15)$cluster
    res <- tidymapr:::dbscan_cpp(xy[, 1], xy[, 2], e, 15L)
    b <- res$cluster
    core <- dbscan::is.corepoint(xy, eps = e, minPts = 15)
    # Same core points, same noise, and the same partition of core points
    expect_identical(as.logical(res$core), core)
    expect_identical(a == 0, b == 0)
    tab <- table(a[core], b[core])
    expect_true(all(rowSums(tab > 0) == 1) && all(colSums(tab > 0) == 1))
    # Border points may join any cluster they reach (Ester et al. 1996):
    # each must lie within eps of a core point of its own cluster
    d <- as.matrix(stats::dist(xy))
    border <- which(!core & b > 0)
    ok <- vapply(border, function(i) any(d[i, core & b == b[i]] <= e), logical(1))
    expect_true(all(ok))
  }
})

test_that("geo_dbscan returns clusters, cores and hulls", {
  cl <- geo_dbscan(datasets::quakes, eps = 50000, min_pts = 15, lon = long, lat = lat)
  expect_s3_class(cl, "sf")
  expect_true(all(c("cluster", "core") %in% names(cl)))
  h <- attr(cl, "hulls")
  expect_equal(nrow(h), max(cl$cluster))
  expect_equal(sum(h$n), sum(cl$cluster > 0))
  expect_true(all(!cl$core[cl$cluster == 0]))
  expect_error(geo_dbscan(datasets::quakes, eps = -1, lon = long, lat = lat), "eps")
})

test_that("landscape metrics match landscapemetrics on projected rasters", {
  skip_if_not_installed("landscapemetrics")
  skip_if_not_installed("terra")
  e <- new.env()
  utils::data("augusta_nlcd", package = "landscapemetrics", envir = e)
  r <- e$augusta_nlcd
  if (inherits(r, "PackedSpatRaster")) r <- terra::unwrap(r)
  ours <- geo_landscape(r)
  ref <- suppressWarnings(landscapemetrics::calculate_lsm(r,
    level = "class",
    what = c("lsm_c_np", "lsm_c_ca", "lsm_c_lpi", "lsm_c_ed", "lsm_c_ai", "lsm_c_mesh")
  ))
  for (m in c("np", "ca", "lpi", "ed", "ai", "mesh")) {
    rr <- ref[ref$metric == m, ]
    expect_equal(ours[[m]][match(rr$class, ours$class)], rr$value, tolerance = 1e-8)
  }
  land <- geo_landscape(r, "landscape")
  expect_equal(land$np, sum(ours$np))
  expect_true(land$shdi > 0 && land$sidi > 0 && land$sidi < 1)
})

test_that("geographic rasters are measured on the ground", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 0.1, ymin = 0, ymax = 0.1)
  terra::values(r) <- rep(1:2, each = 50)
  m <- geo_landscape(r)
  # 0.1 x 0.1 degrees at the equator is about 123 km2 = 12,300 ha
  expect_equal(sum(m$ca), 12300, tolerance = 0.01)
  expect_error(geo_landscape(r * 1.5), "integer")
})

test_that("projections centre on data that cross the antimeridian", {
  w <- sf::st_read(system.file("shapes/world.gpkg", package = "spData"), quiet = TRUE)
  fj <- w[w$name_long %in% c("Fiji", "New Zealand", "Vanuatu"), ]
  ctr <- tidymapr:::geo_crs_centre(fj)
  expect_gt(abs(ctr[1]), 150)
})
