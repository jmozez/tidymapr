
test_that("geo_vector_read/write round-trips via GDAL/OGR", {
  skip_if_not_installed("sf")
  sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  tmp <- tempfile(fileext = ".gpkg")
  on.exit(unlink(tmp), add = TRUE)
  expect_identical(geo_vector_write(sites, tmp, overwrite = TRUE), tmp)
  got <- geo_vector_read(tmp)
  expect_s3_class(got, "sf")
  expect_equal(nrow(got), nrow(sites))
  expect_equal(sf::st_crs(got)$epsg, sf::st_crs(sites)$epsg)
})

test_that("geo_raster_read/write round-trips via GDAL", {
  skip_if_not_installed("terra")
  r <- terra::rast(
    ncols = 8, nrows = 8, xmin = 144.8, xmax = 145.4,
    ymin = -6.0, ymax = -5.5, crs = "EPSG:4326"
  )
  terra::values(r) <- seq_len(terra::ncell(r))
  names(r) <- "elev"
  tmp <- tempfile(fileext = ".tif")
  on.exit(unlink(tmp), add = TRUE)
  expect_identical(geo_raster_write(r, tmp, overwrite = TRUE), tmp)
  got <- geo_raster_read(tmp)
  expect_s4_class(got, "SpatRaster")
  expect_equal(terra::ncell(got), terra::ncell(r))
  # project / crop / mask are GDAL warps
  pr <- geo_raster_project(got, "EPSG:32755")
  expect_false(terra::is.lonlat(pr))
  sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
  buf <- geo_buffer(sites[1:3, ], dist = 2000)
  expect_s4_class(geo_raster_crop(got, buf), "SpatRaster")
  expect_s4_class(geo_raster_mask(got, buf), "SpatRaster")
})

test_that("geo_gadm respects download = FALSE and path", {
  skip_if_not_installed("sf")
  expect_error(geo_gadm("PNG", level = 0, download = FALSE), "download")
  # path round-trip pretending to be a cached GADM file
  poly <- sf::st_sf(
    NAME_0 = "Demo",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(144, -6), c(146, -6), c(146, -5), c(144, -5), c(144, -6)
    ))), crs = 4326)
  )
  tmp <- tempfile(fileext = ".gpkg")
  on.exit(unlink(tmp), add = TRUE)
  geo_vector_write(poly, tmp, overwrite = TRUE)
  got <- geo_gadm("PNG", level = 0, path = tmp, download = FALSE)
  expect_s3_class(got, "sf")
  expect_equal(nrow(got), 1)
})

test_that("plot_sites draws admin borders from sf without network", {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  sites <- geo_example_sites("wilhelm")
  admin <- sf::st_sf(
    NAME_1 = c("A", "B"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(rbind(
        c(144.8, -6.0), c(145.2, -6.0), c(145.2, -5.7), c(144.8, -5.7), c(144.8, -6.0)
      ))),
      sf::st_polygon(list(rbind(
        c(145.0, -5.9), c(145.4, -5.9), c(145.4, -5.5), c(145.0, -5.5), c(145.0, -5.9)
      ))),
      crs = 4326
    )
  )
  p <- plot_sites(
    sites, lon, lat, colour = elevation_band,
    admin = admin, admin_fill = TRUE,
    basemap = "none", scale_bar = TRUE, north_arrow = TRUE,
    inset = FALSE, legend_position = "outside"
  )
  expect_s3_class(p, "ggplot")
  # Build to ensure admin layer is valid
  built <- ggplot2::ggplot_build(p)
  expect_true(length(built$data) >= 2)
})

test_that("geo_gadm network download is skipped on CRAN", {
  skip_on_cran()
  skip_if_not_installed("geodata")
  skip_if_offline()
  png0 <- geo_gadm("PNG", level = 0, download = TRUE)
  expect_s3_class(png0, "sf")
  expect_true(nrow(png0) >= 1)
})
