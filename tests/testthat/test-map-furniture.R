nc_base <- function() {
  skip_if_not_installed("sf")
  skip_if_not_installed("ggplot2")
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  ggplot2::ggplot(nc) + ggplot2::geom_sf()
}

test_that("every scale bar and north arrow style draws", {
  base <- nc_base()
  for (st in c("pill", "checker", "line", "ruler")) {
    for (u in c("metric", "imperial", "both")) {
      p <- base + annotation_scale_bar(st, location = "br", units = u)
      expect_no_error(ggplot2::ggplotGrob(p))
    }
  }
  for (st in c("needle", "compass", "rose", "minimal")) {
    p <- base + annotation_north_arrow(st, location = "tl")
    expect_no_error(ggplot2::ggplotGrob(p))
  }
  expect_error(annotation_scale_bar("zigzag"), "must be one of")
  expect_error(annotation_north_arrow("star"), "must be one of")
})

test_that("scale bar length is measured on the ground", {
  base <- nc_base()
  pp <- ggplot2::ggplot_build(base)$layout$panel_params[[1]]
  m <- tidymapr:::tmr_metres_per_npc(pp, "bl")
  # North Carolina's map panel is roughly 800-950 km wide
  expect_gt(m, 8e5)
  expect_lt(m, 9.5e5)
  # Same answer in a projected CRS (UTM 17N)
  proj <- base + ggplot2::coord_sf(crs = 32617)
  pp2 <- ggplot2::ggplot_build(proj)$layout$panel_params[[1]]
  expect_equal(tidymapr:::tmr_metres_per_npc(pp2, "bl"), m, tolerance = 0.1)
  expect_equal(tidymapr:::tmr_nice_floor(3700), 2000)
  expect_equal(tidymapr:::tmr_fmt_metric(5000), "5 km")
  expect_equal(tidymapr:::tmr_fmt_metric(500), "500 m")
})

test_that("plot_sites() takes style names and map_legend() positions legends", {
  skip_if_not_installed("sf")
  sites <- geo_example_sites()
  p <- plot_sites(sites, lon, lat,
    basemap = "none", colour = elevation_band,
    scale_bar = "ruler", north_arrow = "rose", scale_units = "both"
  )
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true(all(c("GeomTmrScaleBar", "GeomTmrNorthArrow") %in% geoms))
  p0 <- plot_sites(sites, lon, lat, basemap = "none", scale_bar = FALSE, north_arrow = FALSE)
  geoms0 <- vapply(p0$layers, function(l) class(l$geom)[1], character(1))
  expect_false(any(c("GeomTmrScaleBar", "GeomTmrNorthArrow") %in% geoms0))
  expect_error(plot_sites(sites, lon, lat, basemap = "none", scale_bar = "zigzag"), "scale_bar")
  base <- nc_base()
  for (pos in c("right", "bottom", "inside", "none")) {
    expect_s3_class(base + map_legend(pos, title = "Area"), "ggplot")
  }
})

test_that("map_legend() renames, hides and reorders legend entries", {
  base <- nc_base()
  nc <- base$data
  nc$cls <- ifelse(nc$AREA > 0.12, "big", "small")
  p <- ggplot2::ggplot(nc) +
    ggplot2::geom_sf(ggplot2::aes(fill = cls, linewidth = AREA)) +
    map_legend("bottom", title = "Counties", labels = c(big = "Big ones"), hide = "linewidth")
  b <- ggplot2::ggplot_build(p)
  fill_sc <- b$plot$scales$get_scales("fill")
  expect_true("Big ones" %in% fill_sc$get_labels())
  expect_identical(b$plot$labels$fill, "Counties")
  expect_identical(p$guides$guides$linewidth, "none")
  expect_no_error(ggplot2::ggplotGrob(p))
  expect_error(map_legend(labels = "x"), "named")
})
