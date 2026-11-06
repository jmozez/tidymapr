test_that("stems_quadrat builds 20 m keys", {
  stems <- geo_example_stems(20)
  q <- stems_quadrat(stems, grid = 20)
  expect_true(all(c("quadrat", "quadrat_x", "quadrat_y") %in% names(q)))
  expect_true(all(q$quadrat_x %% 20 == 0))
})

test_that("stems_neighbours counts conspecifics and all stems", {
  stems <- tibble::tibble(
    treeID = 1:4, stemID = 1:4,
    gx = c(0, 1, 50, 2), gy = c(0, 0, 50, 1),
    dbh = 10, species = c("a", "a", "b", "a"), status = "A"
  )
  nb <- stems_neighbours(stems, radius = 5, conspecific = TRUE)
  expect_equal(nb$n_neighbours, c(2L, 2L, 0L, 2L))
  stems$species[2] <- "b"
  nb_all <- stems_neighbours(stems, radius = 5, conspecific = FALSE)
  expect_equal(nb_all$n_neighbours, c(2L, 2L, 0L, 2L))
  expect_equal(stems_neighbours(stems, radius = 5)$n_neighbours[1], 1L)
})

test_that("stems_habitat joins quadrat topo", {
  stems <- stems_quadrat(geo_example_stems(30))
  hab <- unique(stems[c("quadrat", "quadrat_x", "quadrat_y")])
  hab$elev <- hab$quadrat_x + hab$quadrat_y
  joined <- stems_habitat(geo_example_stems(30), hab)
  expect_true("elev" %in% names(joined))
  expect_false(all(is.na(joined$elev)))
})

test_that("stems_habitat_test detects toy association", {
  stems <- geo_example_stems()
  q <- stems_quadrat(stems)
  hab <- unique(q[c("quadrat", "gx", "gy")])
  hab$habitat <- ifelse(hab$gx >= 50, "ridge", "valley")
  stems$species <- ifelse(stems$gx >= 50, "ridge_sp", "valley_sp")
  out <- stems_habitat_test(stems, habitat = hab, nperm = 99, seed = 1)
  expect_s3_class(out, "tmr_stems_habitat_test")
  ridge <- out[out$species == "ridge_sp" & out$habitat == "ridge", ]
  expect_equal(nrow(ridge), 1)
  expect_true(ridge$density > ridge$null_mean || ridge$p_value < 0.2)
})

test_that("torus and neighbour kernels match R", {
  grid <- as.integer(1:12)
  s <- geo_torus_shift_cpp(grid, 3L, 4L, 1L, 0L)
  expect_equal(s[2], 1L)
  expect_equal(sort(s), grid)
  expect_equal(geo_neighbour_count_cpp(c(0, 1, 10), c(0, 0, 0), 2), c(1L, 1L, 0L))
})
