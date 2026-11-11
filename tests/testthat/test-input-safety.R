# Two classes of silent error, tested across the whole package:
# 1. coordinates: the same places must give the same answer whether they
#    come as longitude/latitude columns, a longitude/latitude sf table or a
#    projected sf table; projected numbers in plain columns must be refused,
#    never read as degrees;
# 2. colours: a named palette must colour each category by its name.

meuse_inputs <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  m <- as.data.frame(terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra"))))
  m$v <- log(m$zinc)
  m$site <- paste0("s", seq_len(nrow(m)))
  proj <- sf::st_as_sf(m, coords = c("x", "y"), crs = 28992, remove = FALSE)
  ll_sf <- sf::st_transform(proj, 4326)
  xy <- sf::st_coordinates(ll_sf)
  ll_df <- sf::st_drop_geometry(ll_sf)
  ll_df$lon <- xy[, 1]
  ll_df$lat <- xy[, 2]
  metres_df <- m
  metres_df$lon <- m$x
  metres_df$lat <- m$y
  list(ll_df = ll_df, ll_sf = ll_sf, proj = proj, metres_df = metres_df)
}

same_answer <- function(f, inputs, tolerance = 1e-6) {
  r <- lapply(inputs[c("ll_df", "ll_sf", "proj")], f)
  expect_equal(r$ll_sf, r$ll_df, tolerance = tolerance)
  expect_equal(r$proj, r$ll_df, tolerance = tolerance)
  expect_error(f(inputs$metres_df), "not a longitude")
}

test_that("distance-based functions agree across coordinate formats", {
  d <- meuse_inputs()
  same_answer(function(x) geo_moran(x, v, nperm = 0)$statistic, d, tolerance = 0.01)
  same_answer(function(x) as.character(geo_hotspot(x, v, k = 8)$hotspot), d)
  same_answer(function(x) as.character(geo_lisa(x, v, k = 8, nperm = 99, seed = 1)$cluster), d)
  lisa_dist <- function(x) suppressWarnings(geo_lisa(x, v, dist = 300, nperm = 99, seed = 1))
  same_answer(function(x) as.character(lisa_dist(x)$cluster), d)
  same_answer(function(x) geo_dbscan(x, eps = 150, min_pts = 5)$cluster, d)
  same_answer(function(x) ncol(as.data.frame(geo_mem(x))), d)
  same_answer(function(x) mean(geo_distance(x[1:20, ], site = site)$distance), d,
    tolerance = 0.01
  )
  same_answer(function(x) nrow(geo_rarefy_spatial(x, site = site, species = site)), d)
  same_answer(function(x) as.numeric(sf::st_area(geo_buffer(x[1, ], 100))), d, tolerance = 0.01)
})

test_that("projected numbers in plain columns are refused with advice", {
  d <- meuse_inputs()
  expect_error(geo_hotspot(d$metres_df, v), "sf::st_as_sf")
  expect_error(geo_as_sf(d$metres_df), "not a longitude")
  # ... but allowed where the CRS is given or distances are Euclidean
  expect_s3_class(geo_as_sf(d$metres_df, crs = 28992), "sf")
  expect_no_error(geo_distance(d$metres_df[1:10, ], site = site, method = "euclidean"))
  expect_no_error(geo_mem(d$metres_df, method = "euclidean"))
  # Longitudes 0-360 (Pacific data) are valid
  expect_no_error(geo_dbscan(datasets::quakes, eps = 50000, min_pts = 15, lon = long, lat = lat))
})

fill_values <- function(p) {
  b <- ggplot2::ggplot_build(p)
  sc <- b$plot$scales$get_scales("fill") %||% b$plot$scales$get_scales("colour")
  sc$palette.cache %||% sc$palette(length(sc$get_limits()))
}

test_that("named palettes colour categories by name on every layer type", {
  skip_if_not_installed("sf")
  pal <- c(hot = "#B2182B", cold = "#2166AC", "not significant" = "grey85")
  g <- c("not significant", "hot", "cold")
  pts <- sf::st_as_sf(data.frame(x = 1:3, y = 1:3, g = g), coords = c("x", "y"), crs = 4326)
  polys <- sf::st_buffer(sf::st_transform(pts, 3857), 1000)
  lines <- suppressWarnings(sf::st_cast(polys, "LINESTRING"))
  for (layer in list(
    map_points = function(m) map_points(m, pts, fill = g, palette = pal),
    map_polygons = function(m) map_polygons(m, polys, fill = g, palette = pal),
    map_lines = function(m) map_lines(m, lines, colour = g, palette = pal)
  )) {
    v <- fill_values(map_build(layer(geo_map())))
    expect_equal(unname(v[c("hot", "cold", "not significant")]), unname(pal))
  }
  # Interactive web map uses the same colours
  w <- tidymapr:::tmr_category_colours(pal, sort(g), function(n) rep("black", n))
  expect_equal(unname(w[c("hot", "cold")]), c("#B2182B", "#2166AC"))
})

test_that("a named palette missing a category is an error, not a guess", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(data.frame(x = 1:3, y = 1:3, g = c("a", "b", "c")),
    coords = c("x", "y"), crs = 4326
  )
  expect_error(
    map_build(geo_map() |> map_points(pts, fill = g, palette = c(a = "red", b = "blue"))),
    "no colour for"
  )
})

test_that("factor categories keep their level order", {
  skip_if_not_installed("sf")
  g <- factor(c("low", "mid", "high"), levels = c("low", "mid", "high"))
  pts <- sf::st_as_sf(data.frame(x = 1:3, y = 1:3, g = g), coords = c("x", "y"), crs = 4326)
  v <- fill_values(map_build(geo_map() |> map_points(pts, fill = g)))
  expect_equal(names(v)[1:3], c("low", "mid", "high"))
})
