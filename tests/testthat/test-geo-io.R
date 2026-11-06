test_that("geo_write/read round-trip tif, gpkg, shp, geojson, csv", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")

  sites <- geo_example_sites("wilhelm")
  pts <- geo_as_sf(sites, lon, lat)

  # GeoPackage
  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  expect_identical(geo_write(pts, gpkg, overwrite = TRUE), gpkg)
  got <- geo_read(gpkg)
  expect_s3_class(got, "sf")
  expect_equal(nrow(got), nrow(pts))
  expect_equal(sf::st_crs(got)$epsg, 4326L)

  # GeoJSON
  gj <- tempfile(fileext = ".geojson")
  on.exit(unlink(gj), add = TRUE)
  geo_vector_write(pts, gj, overwrite = TRUE)
  expect_equal(nrow(geo_vector_read(gj)), nrow(pts))

  # Shapefile (sidecars)
  shp_dir <- tempfile("shp")
  dir.create(shp_dir)
  on.exit(unlink(shp_dir, recursive = TRUE), add = TRUE)
  shp <- file.path(shp_dir, "sites.shp")
  suppressWarnings(geo_vector_write(pts, shp, overwrite = TRUE))
  expect_true(file.exists(shp))
  expect_equal(nrow(geo_vector_read(shp)), nrow(pts))

  # CSV lon/lat
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv), add = TRUE)
  geo_write(sites, csv, overwrite = TRUE)
  got_csv <- geo_read(csv)
  expect_s3_class(got_csv, "sf")
  expect_equal(nrow(got_csv), nrow(sites))

  # GeoTIFF
  r <- terra::rast(
    ncols = 6, nrows = 6, xmin = 144.8, xmax = 145.4,
    ymin = -6.0, ymax = -5.5, crs = "EPSG:4326"
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "elev"
  tif <- tempfile(fileext = ".tif")
  on.exit(unlink(tif), add = TRUE)
  geo_raster_write(r, tif, overwrite = TRUE)
  got_r <- geo_raster_read(tif)
  expect_s4_class(got_r, "SpatRaster")
  expect_equal(terra::ncell(got_r), terra::ncell(r))
  expect_s4_class(geo_read(tif), "SpatRaster")
})

test_that("geo_write refuses overwrite by default", {
  skip_if_not_installed("sf")
  pts <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  geo_write(pts, gpkg, overwrite = TRUE)
  expect_error(geo_write(pts, gpkg), "overwrite")
})

test_that("geo_save and plot_save write PNG and PDF maps", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  p <- plot_sites(
    geo_example_sites("wilhelm"), lon, lat,
    colour = elevation_band, basemap = "none",
    scale_bar = FALSE, north_arrow = FALSE,
    legend_position = "outside"
  )
  png <- tempfile(fileext = ".png")
  pdf <- tempfile(fileext = ".pdf")
  on.exit(unlink(c(png, pdf)), add = TRUE)
  expect_identical(geo_save(p, png, width = 80, height = 60, units = "mm", dpi = 72), png)
  expect_true(file.exists(png))
  expect_gt(file.info(png)$size, 0)
  expect_identical(geo_save(p, pdf, width = 80, height = 60, units = "mm"), pdf)
  expect_true(file.exists(pdf))
  expect_gt(file.info(pdf)$size, 0)
  # tidydiversity::plot_save still works for the same object
  skip_if_not_installed("tidydiversity")
  png2 <- tempfile(fileext = ".png")
  on.exit(unlink(png2), add = TRUE)
  tidydiversity::plot_save(p, png2, width = 80, height = 60, units = "mm", dpi = 72)
  expect_gt(file.info(png2)$size, 0)
})
