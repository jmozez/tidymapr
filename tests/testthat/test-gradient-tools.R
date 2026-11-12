# Synthetic fixtures only: no downloads

cone_dem <- function(n = 120) {
  dem <- terra::rast(nrows = n, ncols = n, xmin = 145, xmax = 146, ymin = -7, ymax = -6)
  xy <- terra::crds(dem)
  terra::values(dem) <- pmax(0, 3000 - 6000 * sqrt((xy[, 1] - 145.5)^2 + (xy[, 2] + 6.5)^2))
  dem
}

test_that("geo_elevation() mosaics every tile in a folder, tif or zip", {
  skip_if_not_installed("terra")
  d <- tempfile("tiles")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE))
  a <- terra::rast(nrows = 10, ncols = 10, xmin = 145, xmax = 146, ymin = -7, ymax = -6, vals = 1)
  b <- terra::rast(nrows = 10, ncols = 10, xmin = 146, xmax = 147, ymin = -7, ymax = -6, vals = 2)
  terra::writeRaster(a, file.path(d, "a.tif"))
  terra::writeRaster(b, file.path(d, "b.tif"))
  r <- geo_elevation(path = d)
  expect_equal(as.vector(terra::ext(r)), c(xmin = 145, xmax = 147, ymin = -7, ymax = -6))
  expect_equal(sort(unique(terra::values(r)[, 1])), c(1, 2))
  if (nzchar(Sys.which("zip"))) {
    z <- file.path(d, "b.zip")
    old <- setwd(d)
    utils::zip("b.zip", "b.tif", flags = "-q")
    setwd(old)
    r2 <- geo_elevation(path = c(file.path(d, "a.tif"), z))
    expect_equal(terra::ncol(r2), 20)
  }
  # Mismatched resolution is resampled with a warning
  c2 <- terra::rast(nrows = 5, ncols = 5, xmin = 146, xmax = 147, ymin = -7, ymax = -6, vals = 3)
  terra::writeRaster(c2, file.path(d, "b.tif"), overwrite = TRUE)
  two <- file.path(d, c("a.tif", "b.tif"))
  expect_warning(geo_elevation(path = two), "resolution")
})

test_that("SRTM tile names cover every degree cell of the box", {
  expect_setequal(
    geo_srtm_tile_names(c(145.4, -7, 147.3, -5.5)),
    c("S07E145", "S07E146", "S07E147", "S06E145", "S06E146", "S06E147")
  )
  expect_equal(geo_srtm_tile_names(c(146, -7, 147, -6)), "S07E146")
  expect_setequal(
    geo_worldcover_tiles(c(145.4, -7, 147.3, -5.5)),
    c("S09E144", "S09E147", "S06E144", "S06E147")
  )
})

test_that("crop and mask accept every kind of area", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  r <- cone_dem(40)
  want <- c(xmin = 145.25, xmax = 145.75, ymin = -6.75, ymax = -6.25)
  bb <- sf::st_bbox(c(xmin = 145.25, ymin = -6.75, xmax = 145.75, ymax = -6.25), crs = 4326)
  inputs <- list(
    terra::ext(145.25, 145.75, -6.75, -6.25), c(145.25, -6.75, 145.75, -6.25),
    c(ymax = -6.25, xmin = 145.25, ymin = -6.75, xmax = 145.75), bb,
    sf::st_as_sfc(bb), sf::st_as_sf(sf::st_as_sfc(bb)),
    terra::crop(r, terra::ext(145.25, 145.75, -6.75, -6.25))
  )
  for (y in inputs) {
    expect_equal(as.vector(terra::ext(geo_raster_crop(r, y))), want, tolerance = 1e-9)
  }
  expect_error(geo_raster_crop(r, c(145.25, 145.75, -6.75, -6.25)), "not valid")
})

test_that("geo_raster_resample() aligns to whole multiples, like aggregate()", {
  skip_if_not_installed("terra")
  set.seed(1)
  r <- terra::rast(nrows = 24, ncols = 24, xmin = 145.05, xmax = 147.05, ymin = -7.05, ymax = -5.05)
  terra::values(r) <- stats::runif(576)
  a <- geo_raster_resample(r, res = 0.5, method = "average")
  expect_equal(unname(terra::origin(a)), c(0, 0), tolerance = 1e-9)
  t <- terra::rast(nrows = 4, ncols = 4, xmin = 145.2, xmax = 147.2, ymin = -7.2, ymax = -5.2)
  b <- geo_raster_resample(r, align_to = t)
  expect_equal(unname(terra::origin(b)), unname(terra::origin(t)), tolerance = 1e-9)
})

test_that("geo_raster_zonal() takes a zone raster, area-weighted", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 60, ncols = 60, xmin = 145, xmax = 147, ymin = -8, ymax = -6, vals = 1)
  z <- terra::rast(r)
  terra::values(z) <- rep(1:2, each = 1800)
  s <- geo_raster_zonal(r, z, fun = "sum", weight = "area")
  expect_equal(sum(s$area_km2), sum(terra::values(terra::cellSize(r, unit = "km"))))
  # Northern rows (closer to the equator) are larger
  expect_gt(s$area_km2[1], s$area_km2[2])
  expect_equal(geo_raster_zonal(r, z)$lyr.1, c(1, 1))
  expect_error(geo_raster_zonal(r, z, fun = "max", weight = "area"), "mean")
})

test_that("geo_hypsometry() band areas sum to terra::cellSize()", {
  skip_if_not_installed("terra")
  dem <- cone_dem()
  h <- geo_hypsometry(dem, band_width = 500)
  land <- terra::mask(terra::cellSize(dem, unit = "km"), dem >= 0, maskvalues = FALSE)
  expect_equal(sum(h$area), sum(terra::values(land), na.rm = TRUE))
  expect_equal(h$lower, seq(0, 2500, 500))
  expect_equal(h$area_above[1], sum(h$area))
  expect_equal(sum(h$share), 1)
  expect_equal(attr(h, "summit"), max(terra::values(dem)))
  # A region halves the cone
  half <- terra::ext(145, 145.5, -7, -6)
  expect_equal(sum(geo_hypsometry(dem, half)$area), sum(h$area) / 2, tolerance = 0.02)
  expect_warning(geo_hypsometry(dem, area = "planar"), "square degrees")
})

test_that("geo_range_shift() flags gaps and truncation", {
  skip_if_not_installed("terra")
  h <- geo_hypsometry(cone_dem(), band_width = 100)
  rg <- data.frame(
    species = c("wide", "narrow", "top"),
    lower = c(0, 1500, 2500), upper = c(1000, 1600, 2900)
  )
  s <- geo_range_shift(h, rg, warming = c(1.8, 3.7), lapse_rate = 5)
  expect_equal(nrow(s), 6)
  expect_equal(unique(s$shift), c(360, 740))
  expect_true(s$gap[s$species == "narrow" & s$warming == 1.8])
  expect_false(s$gap[s$species == "wide" & s$warming == 3.7])
  expect_true(all(s$truncated[s$species == "top"]))
  expect_true(all(s$change < 0))
  # Padding widens ranges; a padded narrow range overlaps after a small shift
  p <- geo_range_shift(h, rg, 1.8, lapse_rate = 5, pad = 250)
  expect_equal(p$lower[1], 0)
  expect_false(p$gap[p$species == "narrow"])
  # Lowland species keep their lower limit
  l <- geo_range_shift(h, rg, 1.8, lapse_rate = 5, lowland = 0)
  expect_equal(l$new_lower[1], 0)
  expect_gt(l$change[1], 0)
  expect_error(geo_range_shift(data.frame(), rg, 1), "geo_hypsometry")
})

test_that("geo_patches() and geo_largest_patch() keep the main land mass", {
  skip_if_not_installed("terra")
  m <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 1, ymin = 0, ymax = 1, vals = NA)
  m[3:12, 3:12] <- 1
  m[17:18, 17:18] <- 1
  p <- geo_patches(m)
  expect_equal(nrow(p$areas), 2)
  expect_gt(p$areas$area[1], p$areas$area[2])
  expect_equal(nrow(geo_patches(m, min_area = p$areas$area[2] + 1)$areas), 1)
  big <- geo_largest_patch(m)
  expect_equal(terra::global(big, "notNA")[[1]], 100)
})

test_that("default legend labels never show an object dump", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(data.frame(x = 0:1, y = 0:1), coords = c("x", "y"), crs = 4326)
  labs <- function(m) {
    b <- ggplot2::ggplot_build(map_build(m))
    unlist(lapply(b$plot$scales$scales, function(s) {
      if (any(s$aesthetics %in% c("fill", "colour")) && !identical(s$guide, "none")) s$get_labels()
    }))
  }
  expect_equal(labs(geo_map() |> map_points(pts)), "pts")
  expect_equal(labs(geo_map() |> map_points(pts[1:2, ])), "Points")
  expect_equal(labs(geo_map() |> map_points(pts, label = "Sites")), "Sites")
  expect_null(labs(geo_map() |> map_points(pts, label = NULL)))
})
