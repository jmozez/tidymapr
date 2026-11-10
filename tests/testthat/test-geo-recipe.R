skip_if_not_installed("yaml")

recipe_path <- function(id) system.file("recipes", paste0(id, ".yaml"), package = "tidymapr")

meuse_samples <- function() {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  m <- terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra")))
  sf::st_as_sf(as.data.frame(m), coords = c("x", "y"), crs = 28992)
}

test_that("the bundled GeoSpaX recipes validate", {
  for (id in c("interpolate-samples", "points-to-hotspots", "points-to-hexbins")) {
    rec <- geo_recipe_read(recipe_path(id))
    expect_s3_class(rec, "tmr_recipe")
    expect_equal(nrow(geo_recipe_validate(rec)), 0)
  }
})

test_that("validation reports broken recipes", {
  rec <- geo_recipe("Bad id!") |>
    recipe_step("a", "no.such.step") |>
    recipe_step("b", "export.map", layers = list("${missing.layer}"))
  v <- geo_recipe_validate(rec)
  expect_true(nrow(v) >= 3)
  expect_true(all(v$severity %in% c("error", "geospax-only")))
})

test_that("recipes round-trip through YAML", {
  rec <- geo_recipe_read(recipe_path("points-to-hexbins"))
  f <- tempfile(fileext = ".yaml")
  geo_recipe_write(rec, f)
  rec2 <- geo_recipe_read(f)
  expect_equal(rec2$recipe, rec$recipe)
  expect_equal(length(rec2$steps), length(rec$steps))
})

test_that("interpolate-samples krigs Meuse zinc and writes maps and a report", {
  skip_on_cran()
  skip_if_not_installed("ggplot2")
  d <- tempfile()
  out <- geo_recipe_run(geo_recipe_read(recipe_path("interpolate-samples")),
    inputs = list(layer = meuse_samples(), field = "zinc"), dir = d, quiet = TRUE
  )
  expect_s4_class(out$surface$raster, "SpatRaster")
  expect_true(all(c("map.png", "report.html") %in% list.files(d)))
  expect_true(all(out$log$status == "done"))
})

test_that("hotspot and hexbin recipes run", {
  skip_on_cran()
  skip_if_not_installed("ggplot2")
  s <- meuse_samples()
  h <- geo_recipe_run(geo_recipe_read(recipe_path("points-to-hotspots")),
    inputs = list(layer = s, field = "zinc"), dir = tempfile(), quiet = TRUE
  )
  expect_true("hotspot" %in% names(h$hot$layer))
  x <- geo_recipe_run(geo_recipe_read(recipe_path("points-to-hexbins")),
    inputs = list(layer = s), dir = tempfile(), quiet = TRUE
  )
  expect_equal(sum(x$hex$layer$count), nrow(s))
})
