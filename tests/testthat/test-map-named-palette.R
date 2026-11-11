test_that("map_points() honours a named palette for categories", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(data.frame(x = 1:3, y = 1:3, g = c("hot", "cold", "not significant")),
                      coords = c("x", "y"), crs = 4326)
  pal <- c(hot = "#B2182B", cold = "#2166AC", "not significant" = "grey85")
  p <- map_build(geo_map() |> map_points(pts, fill = g, palette = pal))
  b <- ggplot2::ggplot_build(p)
  fills <- unlist(lapply(b$data, function(d) if ("fill" %in% names(d)) d$fill))
  sc <- b$plot$scales$get_scales("fill")
  vals <- sc$palette.cache %||% sc$palette(3)
  expect_equal(unname(vals[c("hot", "cold")]), c("#B2182B", "#2166AC"))
})
