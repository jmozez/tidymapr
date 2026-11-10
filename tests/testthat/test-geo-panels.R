skip_if_not_installed("ggplot2")
skip_if_not_installed("patchwork")
skip_if_not_installed("sf")

nc <- function() {
  x <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
  x$p74 <- 1000 * x$SID74 / x$BIR74
  x$p79 <- 1000 * x$SID79 / x$BIR79
  x
}

test_that("small multiples share one classification", {
  x <- nc()
  p <- geo_facet_map(x, c(p74, p79), n = 4)
  expect_s3_class(p, "ggplot")
  b <- ggplot2::ggplot_build(p)
  expect_equal(length(unique(b$data[[1]]$PANEL)), 2)
  cls <- attr(p, "classification")
  all_vals <- c(x$p74, x$p79)
  expect_equal(min(cls$breaks), min(all_vals))
  expect_equal(max(cls$breaks), max(all_vals))
})

test_that("facet by a grouping column works", {
  x <- nc()
  long <- rbind(
    transform(x[, "p74"], period = "1974", rate = p74)[, c("period", "rate")],
    transform(x[, "p79"], period = "1979", rate = p79)[, c("period", "rate")]
  )
  p <- geo_facet_map(long, rate, by = period, scale_bar = FALSE, north_arrow = FALSE)
  expect_s3_class(p, "ggplot")
  expect_error(geo_facet_map(x, p74), "by")
})

test_that("panels and insets combine maps", {
  x <- nc()
  a <- geo_automap(x, p74, basemap = "none")
  m <- geo_map(scale_bar = FALSE, north_arrow = FALSE) |>
    map_polygons(x, fill = "grey80", label = "Counties")
  pw <- geo_panels(a, m, ncol = 2, title = "NC")
  expect_s3_class(pw, "patchwork")
  expect_equal(pw$patches$annotation$tag_levels, "a")
  expect_s3_class(geo_inset(a, m, location = "bl"), "patchwork")
  expect_error(geo_panels(1), "ggplot")
  expect_error(geo_panels(), "at least one")
})

test_that("auto inset and inside legend avoid the furniture", {
  skip_if_not_installed("ggnewscale")
  x <- nc()
  main <- geo_map(legend = "inside") |>
    map_polygons(x, fill = p74, n = 4, group = "Rate")
  p <- map_build(main)
  taken <- tidymapr:::tmr_taken_corners(p)
  expect_true(all(c("bl", "tr") %in% taken))
  expect_length(taken, 3)
  corner <- tidymapr:::tmr_inset_corner(p, 0.3, 0.02)
  expect_false(corner %in% taken)
  loc <- geo_map(scale_bar = FALSE, north_arrow = FALSE, legend = "none") |>
    map_polygons(x, fill = "grey80", label = "NC")
  expect_s3_class(geo_inset(p, loc, location = c(0.4, 0.4), size = 0.2), "patchwork")
  expect_error(geo_inset(p, loc, location = c(0.9, 0.9), size = 0.3), "lower-left")
})
