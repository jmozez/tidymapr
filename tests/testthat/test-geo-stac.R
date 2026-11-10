skip_if_not_installed("sf")
skip_if_not_installed("jsonlite")

# A real Earth Search response (Sentinel-2 over Luxembourg City, August
# 2024), trimmed to four bands, so these tests need no network
fixture <- function() {
  jsonlite::read_json(test_path("fixtures", "stac-search.json"), simplifyVector = FALSE)
}

test_that("STAC items become an sf table of footprints, clearest first", {
  items <- tidymapr:::tmr_stac_items(fixture()$features)
  expect_s3_class(items, "sf")
  expect_equal(nrow(items), 4)
  cols <- c("id", "datetime", "cloud_cover", "platform", "offset_applied", "assets")
  expect_true(all(cols %in% names(items)))
  expect_false(is.unsorted(items$cloud_cover))
  expect_s3_class(items$datetime, "POSIXct")
  expect_true(all(items$offset_applied))
  expect_true(all(c("red", "nir") %in% names(items$assets[[1]])))
  expect_equal(sf::st_crs(items)$epsg, 4326L)
  expect_equal(nrow(tidymapr:::tmr_stac_items(list())), 0)
})

test_that("areas and periods are checked", {
  bb <- tidymapr:::tmr_stac_bbox(c(6.08, 49.57, 6.18, 49.65))
  expect_equal(unname(bb), c(6.08, 49.57, 6.18, 49.65))
  lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
  bb2 <- tidymapr:::tmr_stac_bbox(sf::st_transform(lux, 3035))
  expect_equal(unname(bb2), unname(as.numeric(sf::st_bbox(lux))), tolerance = 0.01)
  expect_error(tidymapr:::tmr_stac_bbox(c(10, 0, 5, 1)), "degrees")
  expect_error(tidymapr:::tmr_stac_bbox("x"), "sf or terra")
  expect_equal(
    tidymapr:::tmr_stac_datetime(c("2024-06-01", "2024-08-31")),
    "2024-06-01T00:00:00Z/2024-08-31T23:59:59Z"
  )
  expect_error(tidymapr:::tmr_stac_datetime("not a date"), "dates")
})

test_that("reading checks its input", {
  items <- tidymapr:::tmr_stac_items(fixture()$features)
  expect_error(geo_stac_read(data.frame(), "red"), "geo_stac_search")
  expect_error(geo_stac_read(items, "B99"), "not found")
  expect_error(geo_stac_search(c("a", "b"), c(0, 0, 1, 1)), "one collection")
})

test_that("STAC asset names work in spectral indices", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 2, vals = c(0.05, 0.05, 0, 0.1, 0.4, 0.4, 0, 0.1))
  names(r) <- c("red", "nir")
  v <- terra::values(geo_spectral_index(r, "NDVI"))
  expect_equal(v[1], (0.4 - 0.05) / (0.4 + 0.05))
  expect_true(is.na(v[3]))
})

test_that("live search and read work", {
  skip_on_cran()
  skip_if_offline("earth-search.aws.element84.com")
  skip_if_not_installed("httr2")
  skip_if_not_installed("terra")
  items <- geo_stac_search("sentinel-2-l2a", c(6.12, 49.60, 6.13, 49.61),
    datetime = c("2024-08-20", "2024-08-31"), cloud_cover = 10, limit = 2
  )
  expect_gt(nrow(items), 0)
  img <- geo_stac_read(items, c("red", "nir"), area = c(6.12, 49.60, 6.13, 49.61))
  expect_equal(names(img), c("red", "nir"))
  q <- terra::global(img, stats::median, na.rm = TRUE)[, 1]
  expect_true(all(q > 0 & q < 1))
})
