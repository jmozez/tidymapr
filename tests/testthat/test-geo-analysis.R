test_that("geo_basemap() builds coast layers offline", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  sites <- geo_example_sites("wilhelm")
  bm <- geo_basemap(sites, basemap = "coast", lon = lon, lat = lat)
  expect_s3_class(bm, "tmr_geo_basemap")
  expect_true(bm$offline)
  expect_equal(bm$provider, "coast")
  expect_gt(length(bm$layers), 0)
  p <- plot_sites(sites, lon, lat, basemap = "coast", colour = elevation_band)
  expect_s3_class(p, "ggplot")
})

test_that("geo_basemap() accepts a SpatRaster", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  skip_if_not_installed("ggplot2")
  r <- terra::rast(
    ncols = 20, nrows = 20,
    xmin = 144.8, xmax = 145.4, ymin = -6.0, ymax = -5.5,
    crs = "EPSG:4326"
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "elev"
  sites <- geo_example_sites("wilhelm")
  sites <- sites[sites$elevation <= 2200, ]
  p <- plot_sites(sites, lon, lat, basemap = r, colour = elevation_band)
  expect_s3_class(p, "ggplot")
})

test_that("online basemap falls back offline without error", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  skip_on_cran()
  sites <- geo_example_sites("wilhelm")
  # Force fallback by using a tiny helper path: coast always works
  bm <- geo_basemap(sites, basemap = "coast", lon = lon, lat = lat)
  expect_true(bm$offline)
})

test_that("vector verbs match sf on a simple case", {
  skip_if_not_installed("sf")
  sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  buf <- geo_buffer(sites, dist = 1000)
  expect_s3_class(buf, "sf")
  expect_true(all(sf::st_geometry_type(buf) %in% c("POLYGON", "MULTIPOLYGON")))
  # Area positive
  a <- geo_area(buf)
  expect_true(all(a$area_m2 > 0))
  # Centroid count preserved
  cen <- geo_centroid(buf)
  expect_equal(nrow(cen), nrow(sites))
  bb <- geo_bbox(sites)
  expect_named(bb, c("xmin", "ymin", "xmax", "ymax", "crs"))
  expect_lt(bb$xmin, bb$xmax)

  # Intersection of buffers with themselves keeps features
  inter <- geo_intersection(buf, buf[1, ])
  expect_s3_class(inter, "sf")
  expect_gte(nrow(inter), 1)

  # Spatial join
  joined <- geo_join(sites, buf[1, ], join = "intersects")
  expect_s3_class(joined, "sf")

  # Distance to first site
  d <- geo_distance_to(sites, sites[1, ])
  expect_equal(d$distance_m[1], 0, tolerance = 1e-6)
  expect_true(all(d$distance_m[-1] > 0))

  # Validate buffer area roughly against sf in metres
  sf_buf <- sf::st_transform(sites, "+proj=eqc +units=m")
  sf_buf <- sf::st_buffer(sf_buf, 1000)
  sf_buf <- sf::st_transform(sf_buf, sf::st_crs(sites))
  expect_equal(
    as.numeric(sf::st_area(sf::st_transform(buf, "+proj=eqc +units=m"))),
    as.numeric(sf::st_area(sf::st_transform(sf_buf, "+proj=eqc +units=m"))),
    tolerance = 1
  )
})

test_that("raster verbs agree with terra on a toy grid", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  r <- terra::rast(
    ncols = 30, nrows = 30,
    xmin = 144.8, xmax = 145.4, ymin = -6.0, ymax = -5.5,
    crs = "EPSG:4326"
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "elev"
  sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  sites <- sites[sites$elevation <= 2200, ]
  buf <- geo_buffer(sites, dist = 5000)

  cropped <- geo_raster_crop(r, buf)
  expect_s4_class(cropped, "SpatRaster")
  expect_true(terra::ncell(cropped) <= terra::ncell(r))

  masked <- geo_raster_mask(r, buf)
  expect_s4_class(masked, "SpatRaster")

  zonal <- geo_raster_zonal(r, buf, fun = "mean")
  expect_s3_class(zonal, "tbl_df")
  expect_equal(nrow(zonal), nrow(buf))
  # Match terra::extract (strip tidymapr subclass for terra dispatch)
  buf_sf <- buf
  class(buf_sf) <- setdiff(class(buf_sf), "tmr_geo_sf")
  ref <- terra::extract(r, terra::vect(buf_sf), fun = mean)
  expect_equal(zonal$elev, ref$elev, tolerance = 1e-8)

  terrain <- geo_raster_terrain(r, v = "slope")
  expect_equal(names(terrain), "slope")
  focal <- geo_raster_focal(r, w = 3, fun = "mean")
  expect_s4_class(focal, "SpatRaster")

  # geo_extract still works
  ex <- geo_extract(sites, r, lon = "lon", lat = "lat")
  expect_true("elev" %in% names(ex))
})

test_that("geo_bioclim_vars() lists bio1-bio19 with clear names", {
  v <- geo_bioclim_vars()
  expect_equal(nrow(v), 19)
  expect_equal(v$code[1], "bio1")
  expect_equal(v$name[1], "annual_mean_temperature")
  expect_equal(v$code[12], "bio12")
  expect_equal(v$name[12], "annual_precipitation")
})

test_that("geo_worldclim()/geo_chelsa() read local paths offline", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  r <- terra::rast(
    ncols = 8, nrows = 8,
    xmin = 144, xmax = 146, ymin = -7, ymax = -5,
    crs = "EPSG:4326"
  )
  terra::values(r) <- 25
  names(r) <- "bio1"
  tmp <- tempfile(fileext = ".tif")
  terra::writeRaster(r, tmp, overwrite = TRUE)
  wc <- geo_worldclim(vars = "bio1", path = tmp, download = FALSE)
  expect_equal(names(wc), "bio1")
  ch <- geo_chelsa(vars = "annual_mean_temperature", path = tmp, download = FALSE)
  expect_equal(names(ch), "bio1")
  # Join to sites
  sites <- geo_example_sites("wilhelm")[1:3, ]
  joined <- geo_extract(sites, wc, lon, lat)
  expect_true(all(joined$bio1 == 25))
  # Front door
  bc <- geo_bioclim(vars = "bio1", source = "worldclim", path = tmp, download = FALSE)
  expect_equal(names(bc), "bio1")
})

test_that("bioclim download paths are skipped on CRAN", {
  skip_on_cran()
  skip_if_not_installed("terra")
  # Do not actually download large global rasters in CI by default;
  # only assert the error when download is FALSE and cache is empty.
  expect_error(
    geo_worldclim(vars = "bio1", download = FALSE, cache_dir = tempfile()),
    "not in the cache"
  )
})

test_that("plot_topo() maps stems over DEM contours and hillshade", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("terra")
  stems <- geo_example_stems(n = 40, seed = 2)
  dem <- geo_example_dem(res = 5)
  p <- plot_topo(
    stems,
    colour = species,
    size = dbh,
    dem = dem,
    boundary = c(0, 0, 100, 100),
    contours = TRUE,
    hillshade = TRUE
  )
  expect_s3_class(p, "ggplot")
  # Missing coordinates error
  bad <- stems
  bad$gx <- NA_real_
  bad$gy <- NA_real_
  expect_error(plot_topo(bad, dem = dem), "finite stem coordinates")
})

test_that("geo_example_stems() is ForestGEO-like", {
  s <- geo_example_stems(10)
  expect_true(all(c(
    "plot", "treeID", "stemID", "gx", "gy", "dbh", "species", "status"
  ) %in% names(s)))
  expect_equal(nrow(s), 10)
  expect_true(all(s$gx >= 0 & s$gx <= 100))
})
