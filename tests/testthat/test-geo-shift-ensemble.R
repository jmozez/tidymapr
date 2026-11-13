# A stub CHELSA reader: uniform warming by GCM and SSP, no network
stub_reader <- function(area, variables, period, gcm = NULL, ssp = NULL) {
  r <- terra::rast(
    nrows = 4, ncols = 4, xmin = 145, xmax = 145.4, ymin = -6.4, ymax = -6,
    crs = "EPSG:4326"
  )
  terra::values(r) <- 20
  warm <- 0
  if (!is.null(gcm)) {
    warm <- c("gcm-a" = 1, "gcm-b" = 3)[[gcm]] * c(ssp126 = 0.5, ssp585 = 1)[[ssp]]
  }
  out <- r + warm
  names(out) <- variables
  out
}
ens_dem <- function() {
  dem <- terra::rast(
    nrows = 40, ncols = 40, xmin = 145, xmax = 145.4, ymin = -6.4, ymax = -6,
    crs = "EPSG:4326"
  )
  y <- terra::init(dem, "y")
  (y - min(terra::values(y))) * 8000
}

test_that("climate scenarios add GCM deltas to a downscaled baseline", {
  skip_if_not_installed("terra")
  dem <- ens_dem()
  sc <- geo_climate_scenarios(c(145, -6.4, 145.4, -6), dem, "bio1",
    gcm = c("gcm-a", "gcm-b"), ssp = c("ssp126", "ssp585"), lapse_rates = c(5, 6),
    reader = stub_reader
  )
  expect_equal(nrow(sc$design), 8)
  expect_length(sc$members, 8)
  m <- sc$members[["gcm-b_ssp585_lapse6"]]
  b <- sc$current[["lapse_6"]]
  expect_equal(unname(terra::global(m - b, "mean", na.rm = TRUE)[[1]]), 3, tolerance = 1e-6)
  # Steeper lapse rate gives a wider temperature range across the slope
  r5 <- diff(unlist(terra::global(sc$current$lapse_5, "range", na.rm = TRUE)))
  r6 <- diff(unlist(terra::global(sc$current$lapse_6, "range", na.rm = TRUE)))
  expect_gt(r6, r5)
})

test_that("ensembles report range change and loss probabilities", {
  skip_if_not_installed("terra")
  dem <- ens_dem()
  sc <- geo_climate_scenarios(c(145, -6.4, 145.4, -6), dem, "bio1",
    gcm = c("gcm-a", "gcm-b"), ssp = c("ssp126", "ssp585"),
    reader = stub_reader
  )
  # Niche: a thermal band around 20.5 C (the stub climate spans 18 to 22 C)
  niche <- function(x) exp(-((x[["bio1"]] - 20.5) / 1.5)^2)
  ens <- geo_shift_ensemble(niche, sc,
    dispersal_mean = 2000, steps = 5, nsim = 10,
    seed = 1, elevation = dem
  )
  r <- ens$results
  expect_equal(nrow(r), 8)
  expect_setequal(unique(r$dispersal), c("limited", "unlimited"))
  # More warming shifts the band further upslope
  u <- r[r$dispersal == "unlimited", ]
  expect_gt(
    u$shift_median[u$gcm == "gcm-b" & u$ssp == "ssp585"],
    u$shift_median[u$gcm == "gcm-a" & u$ssp == "ssp126"]
  )
  # Limited dispersal cannot occupy more than all suitable habitat
  lim <- r[r$dispersal == "limited", ]
  expect_true(all(lim$area_future <= u$area_future[match(lim$member, u$member)] + 1e-6))
  s <- summary(ens, loss = 50)
  expect_equal(nrow(s), 4)
  expect_true(all(s$p_loss_50 >= 0 & s$p_loss_50 <= 1))
  expect_true(all(c("limited", "unlimited") %in% names(ens$occupancy[[1]])))
  expect_error(
    geo_shift_ensemble(niche, list(current = sc$current, members = list()), 1000),
    "members"
  )
})
