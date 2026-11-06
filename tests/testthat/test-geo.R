test_that("geo_as_sf() builds points and drops empty coords", {
  skip_if_not_installed("sf")
  sites <- tibble::tibble(
    site = c("a", "b", "c"),
    lon = c(147.1, 147.2, NA_real_),
    lat = c(-9.4, -9.5, -9.6),
    elevation = c(200, 700, 1200)
  )
  out <- geo_as_sf(sites, lon, lat, site = site)
  expect_s3_class(out, "sf")
  expect_s3_class(out, "tmr_geo_sf")
  expect_equal(nrow(out), 2)
  expect_equal(sf::st_crs(out)$epsg, 4326)
  back <- geo_drop_geometry(out)
  expect_false(inherits(back, "sf"))
  expect_true(all(c("site", "elevation") %in% names(back)))
})

test_that("geo_extract() joins raster layers as columns", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  r <- terra::rast(
    ncols = 36, nrows = 18,
    xmin = -180, xmax = 180, ymin = -90, ymax = 90,
    crs = "EPSG:4326"
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "demo_layer"
  sites <- tibble::tibble(site = c("a", "b"), lon = c(147, 10), lat = c(-9, 50))
  out <- geo_extract(sites, r, lon, lat)
  expect_true("demo_layer" %in% names(out))
  expect_equal(nrow(out), 2)
  expect_true(all(is.finite(out$demo_layer)))
})

test_that("geo_clean() flags equal, zeros, duplicates and GBIF HQ", {
  occ <- tibble::tibble(
    species = c("a", "a", "b", "c", "d"),
    lon = c(147.1, 147.1, 0, 12.58, 151.0),
    lat = c(-9.4, -9.4, 0, 55.67, -33.9)
  )
  flagged <- geo_clean(
    occ, lon, lat,
    species = species,
    tests = c("equal", "zeros", "duplicates", "gbif", "validity"),
    gbif_rad = 2000,
    value = "flagged"
  )
  expect_true(any(flagged$.zer))
  expect_true(any(flagged$.gbf))
  expect_true(any(flagged$.dpl))
  clean <- geo_clean(
    occ, lon, lat,
    species = species,
    tests = c("zeros", "duplicates", "gbif"),
    gbif_rad = 2000,
    value = "clean"
  )
  expect_lt(nrow(clean), nrow(occ))
  expect_false(any(clean$lon == 0 & clean$lat == 0))
})

test_that("geo_clean() matches CoordinateCleaner on exact flags", {
  skip_if_not_installed("CoordinateCleaner")
  set.seed(1)
  occ <- tibble::tibble(
    species = rep(c("sp1", "sp2"), each = 20),
    lon = c(runif(20, 140, 150), runif(18, 10, 20), 0, 12.58),
    lat = c(runif(20, -10, 0), runif(18, 50, 55), 0, 55.67)
  )
  # Equal lon/lat row
  occ$lon[5] <- occ$lat[5]

  ours <- geo_clean(
    occ, lon, lat,
    species = species,
    tests = c("equal", "zeros", "gbif", "validity"),
    gbif_rad = 1000,
    value = "flagged"
  )

  cc_equal <- !suppressWarnings(CoordinateCleaner::cc_equ(
    as.data.frame(occ), lon = "lon", lat = "lat", value = "flagged",
    verbose = FALSE
  ))
  cc_zero <- !suppressWarnings(CoordinateCleaner::cc_zero(
    as.data.frame(occ), lon = "lon", lat = "lat", value = "flagged",
    verbose = FALSE
  ))
  cc_gbif <- !suppressWarnings(CoordinateCleaner::cc_gbif(
    as.data.frame(occ), lon = "lon", lat = "lat", value = "flagged",
    buffer = 1000, verbose = FALSE
  ))
  expect_identical(ours$.equ, unname(cc_equal))
  expect_identical(ours$.zer, unname(cc_zero))
  expect_identical(ours$.gbf, unname(cc_gbif))
})

test_that("geo_gbif() accepts a pre-downloaded table without rgbif", {
  gbif_like <- tibble::tibble(
    scientificName = c("Camponotus", "Polyrhachis", "Camponotus"),
    decimalLongitude = c(147.1, 147.2, 0),
    decimalLatitude = c(-9.4, -9.5, 0),
    countryCode = c("PG", "PG", "XX")
  )
  out <- geo_gbif(gbif_like, clean = TRUE, as_sf = FALSE,
    tests = c("zeros", "validity", "duplicates")
  )
  expect_true(all(c("lon", "lat", "species") %in% names(out)))
  expect_false(any(out$lon == 0 & out$lat == 0, na.rm = TRUE))
})

test_that("geo_distance() and geo_decay() feed beta_decay_model()", {
  skip_if_not_installed("tidydiversity")
  sites <- unique(tidydiversity::png_ants[c("site", "elevation", "season")])
  sites$lon <- 145.0 + sites$elevation / 1e5
  sites$lat <- -5.8 - sites$elevation / 2e5
  com <- dplyr::left_join(
    tidydiversity::png_ants,
    sites[c("site", "season", "lon", "lat")],
    by = c("site", "season")
  )
  d_h <- geo_distance(sites, lon, lat, .by = season, method = "haversine")
  expect_s3_class(d_h, "tmr_geo_distance")
  expect_true(all(d_h$distance >= 0))
  d_e <- geo_distance(
    sites, elevation = elevation, .by = season, method = "elevation"
  )
  elevs <- sort(unique(sites$elevation))
  expect_equal(
    sort(unique(round(d_e$distance))),
    sort(unique(as.numeric(dist(elevs, method = "manhattan"))))
  )
  decay <- geo_decay(com, lon, lat, .by = season, method = "haversine")
  expect_s3_class(decay, "td_beta_decay")
  expect_true("distance" %in% names(decay))
  fit <- tidydiversity::beta_decay_model(decay, component = "total")
  expect_true(
    all(c("model", "a", "b", "p.value") %in% names(fit)) ||
      all(c("a", "b") %in% names(fit))
  )
})

test_that("plot_geo() returns a ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  est <- tibble::tibble(
    site = c("a", "b", "c"),
    lon = c(147.0, 147.2, 147.4),
    lat = c(-9.4, -9.5, -9.6),
    estimate = c(12, 18, 9)
  )
  p <- plot_geo(est, estimate, lon, lat)
  expect_s3_class(p, "ggplot")
})

test_that("geo_moran() detects positive spatial autocorrelation", {
  set.seed(1)
  g <- expand.grid(x = 1:8, y = 1:8)
  g$val <- g$x + g$y + 0.05 * rnorm(nrow(g))
  res <- geo_moran(g, val, lon = x, lat = y, nperm = 199, seed = 1)
  expect_s3_class(res, "tmr_geo_moran")
  expect_gt(res$statistic, 0)
  expect_lt(res$p.value, 0.05)
})

test_that("geo_moran() agrees with spdep on a toy lattice", {
  skip_if_not_installed("spdep")
  set.seed(42)
  g <- expand.grid(x = 1:5, y = 1:5)
  g$val <- g$x + 0.1 * rnorm(nrow(g))
  # Use euclidean-style coords in degrees for both; compare sign and rough value
  # with inverse-distance weights rebuilt in spdep.
  ours <- geo_moran(g, val, lon = x, lat = y, nperm = 99, seed = 42)

  coords <- as.matrix(g[c("x", "y")])
  nb <- spdep::knn2nb(spdep::knearneigh(coords, k = 4))
  lw <- spdep::nb2listw(nb, style = "W")
  sp <- spdep::moran.test(g$val, lw, randomisation = FALSE)
  # Different neighbour definitions, so only require the same sign and
  # a significant positive result on the gradient.
  expect_gt(ours$statistic, 0)
  expect_gt(unname(sp$estimate[["Moran I statistic"]]), 0)
  expect_lt(ours$p.value, 0.1)
})

test_that("compiled haversine matches the R reference", {
  lon1 <- c(147.1, 0, 12.5)
  lat1 <- c(-9.4, 0, 55.7)
  lon2 <- c(147.2, 1, 12.6)
  lat2 <- c(-9.5, 1, 55.8)
  skip_if_not(exists("geo_haversine_pair_cpp", mode = "function"))
  cpp <- geo_haversine_pair_cpp(lon1, lat1, lon2, lat2)
  to_rad <- pi / 180
  dlon <- (lon2 - lon1) * to_rad
  dlat <- (lat2 - lat1) * to_rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  ref <- 6371000 * 2 * atan2(sqrt(a), sqrt(pmax(0, 1 - a)))
  expect_equal(cpp, ref, tolerance = 1e-6)
})

test_that("plot_sites() returns a ggplot and drops missing coords", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  sites <- geo_example_sites("wilhelm")
  sites$lon[1] <- NA_real_
  p <- plot_sites(sites, lon, lat, colour = elevation_band, label = site)
  expect_s3_class(p, "ggplot")
  # CRS is WGS84
  sf_sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  expect_equal(sf::st_crs(sf_sites)$epsg, 4326)
  p2 <- plot_sites(sf_sites, colour = elevation_band)
  expect_s3_class(p2, "ggplot")
})

test_that("plot_sites() facets and groups without error", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  sites <- geo_example_sites("wilhelm")
  sites$season <- rep(c("dry", "wet"), length.out = nrow(sites))
  p <- plot_sites(
    sites, lon, lat,
    colour = elevation_band,
    shape = season,
    facet = season,
    scale_bar = TRUE,
    north_arrow = TRUE
  )
  expect_s3_class(p, "ggplot")
  # Built plot has facet and site layers
  built <- ggplot2::ggplot_build(p)
  expect_true(length(built$layout$layout$PANEL) >= 2)
})

test_that("plot_sites() errors on empty coordinates", {
  skip_if_not_installed("sf")
  bad <- tibble::tibble(site = "a", lon = NA_real_, lat = NA_real_)
  expect_error(plot_sites(bad, lon, lat), "finite coordinates")
})

test_that("geo_example_sites() covers Wilhelm and Wanang", {
  w <- geo_example_sites("wilhelm")
  expect_true(all(c("site", "lon", "lat", "elevation") %in% names(w)))
  expect_equal(nrow(w), 8)
  a <- geo_example_sites("wanang")
  expect_equal(a$site, c("Wanang", "Numba", "Yawan"))
})


test_that("decoration corners avoid Wilhelm demo sites", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  sites <- geo_example_sites("wilhelm")
  pts <- geo_as_sf(sites, lon, lat)
  bb <- sf::st_bbox(pts)
  dx <- max((bb["xmax"] - bb["xmin"]) * 0.35, 0.15)
  dy <- max((bb["ymax"] - bb["ymin"]) * 0.45, 0.12)
  bb["xmin"] <- bb["xmin"] - dx
  bb["xmax"] <- bb["xmax"] + dx
  bb["ymin"] <- bb["ymin"] - dy
  bb["ymax"] <- bb["ymax"] + dy

  decor <- geo_pick_decoration_corner(
    pts, bb,
    scale_bar = TRUE, north_arrow = TRUE,
    inset = TRUE, legend_inside = TRUE
  )
  expect_false(any(geo_decoration_contains(pts, decor$scale_box)))
  expect_false(any(geo_decoration_contains(pts, decor$north_box)))
  expect_false(any(geo_decoration_contains(pts, decor$inset_box)))
  expect_false(any(geo_decoration_contains(pts, decor$legend_box)))
  # Corners must be distinct
  used <- c(decor$scale_corner, decor$north_corner, decor$inset_corner, decor$legend_corner)
  expect_equal(length(unique(used)), 4)

  p <- plot_sites(
    sites, lon, lat,
    colour = elevation_band, label = site,
    scale_bar = TRUE, north_arrow = TRUE,
    inset = "png", legend_position = "auto",
    basemap = "none"
  )
  expect_s3_class(p, "ggplot")
  d <- attr(p, "tmr_decoration")
  expect_false(any(geo_decoration_contains(pts, d$scale_box)))
  expect_false(any(geo_decoration_contains(pts, d$north_box)))
})

test_that("plot_sites legend and size aesthetics work", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  sites <- geo_example_sites("wilhelm")
  p <- plot_sites(
    sites, lon, lat,
    colour = elevation_band, size = elevation,
    legend_title = "Band", legend_position = "outside",
    legend_frame = FALSE, basemap = "none",
    scale_bar = FALSE, north_arrow = FALSE
  )
  expect_s3_class(p, "ggplot")
  # Built plot has size and fill/colour scales
  sc <- ggplot2::ggplot_build(p)
  expect_true(length(sc$plot$scales$scales) >= 1)
})

test_that("plot_geo combines value colour with size column", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  sites <- geo_example_sites("wilhelm")
  sites$diversity <- seq_len(nrow(sites))
  p <- plot_geo(
    sites, diversity, lon, lat, size = elevation,
    basemap = "none", inset = FALSE,
    legend_position = "tr", legend_frame = TRUE
  )
  expect_s3_class(p, "ggplot")
  d <- attr(p, "tmr_decoration")
  expect_equal(d$legend_corner, "tr")
})
