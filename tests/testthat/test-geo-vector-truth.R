# Results checked against known true values, not just against each other:
# a method that is consistently wrong passes a consistency test.

lonlat_square <- function(lat) {
  sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, lat), c(1, lat), c(1, lat + 1), c(0, lat + 1), c(0, lat)
  ))), crs = 4326))
}

test_that("geo_area() gives true areas at every latitude", {
  skip_if_not_installed("sf")
  for (lat in c(0, 30, 60)) {
    sq <- lonlat_square(lat)
    expect_equal(geo_area(sq)$area_m2, as.numeric(sf::st_area(sq)), tolerance = 1e-9)
  }
  # A 1 x 1 degree cell at 60N is about half the size of one at the equator
  ratio <- geo_area(lonlat_square(60))$area_m2 / geo_area(lonlat_square(0))$area_m2
  expect_equal(ratio, 0.49, tolerance = 0.02)
})

test_that("geo_distance_to() gives great-circle distances", {
  skip_if_not_installed("sf")
  p <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_point(c(0, 60)), crs = 4326))
  q <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_point(c(1, 60)), crs = 4326))
  # One degree of longitude at 60N is about 55.6 km, not 111 km
  expect_equal(geo_distance_to(p, q)$distance_m, 55597, tolerance = 0.002)
})

test_that("geo_buffer() buffers by the true distance at any latitude", {
  skip_if_not_installed("sf")
  for (lat in c(0, 51, 70)) {
    p <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_point(c(5, lat)), crs = 4326))
    b <- geo_buffer(p, 100)
    # A 100 m circle has area pi * 100^2
    expect_equal(as.numeric(sf::st_area(b)), pi * 100^2, tolerance = 0.01)
    # ... and reaches 100 m in every direction
    edge <- suppressWarnings(sf::st_cast(sf::st_cast(b, "MULTILINESTRING"), "POINT"))
    d <- as.numeric(sf::st_distance(p, edge))
    expect_true(all(abs(d - 100) < 1.5))
  }
})
