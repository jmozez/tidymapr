test_that("epi_growth_rate recovers a known growth rate and R", {
  set.seed(1)
  t <- 0:60
  d <- data.frame(day = t, n = stats::rpois(length(t), 5 * exp(0.05 * t)))
  g <- epi_growth_rate(d, date = day, cases = n, generation_mean = 10, generation_sd = 10)
  e <- g$estimates
  r <- e$estimate[e$quantity == "growth_rate"]
  expect_lt(abs(r - 0.05) / e$std_error[1], 3)
  # Exponential generation interval (sd = mean): R = 1 + r * mean
  expect_equal(e$estimate[e$quantity == "reproduction_number"], 1 + r * 10)
  expect_equal(e$estimate[e$quantity == "doubling_time"], log(2) / r)
  # Fitted band comes from the GLM on the link scale
  p <- stats::predict(g$model, type = "link", se.fit = TRUE)
  expect_equal(g$fitted$fit, unname(exp(p$fit)))
  expect_equal(g$fitted$upper, unname(exp(p$fit + stats::qnorm(0.975) * p$se.fit)))
  expect_true(all(g$fitted$lower > 0))
  expect_s3_class(plot(g), "ggplot")
})

test_that("a line list gives the same fit as counts", {
  d <- data.frame(day = rep(0:9, times = c(1, 2, 2, 3, 5, 6, 9, 12, 15, 20)))
  a <- epi_growth_rate(d, date = day)
  cnt <- as.data.frame(table(day = d$day))
  cnt$day <- as.numeric(as.character(cnt$day))
  b <- epi_growth_rate(cnt, date = day, cases = Freq)
  expect_equal(a$estimates, b$estimates)
})

test_that("geo_spread_rate recovers the speed of a synthetic invasion", {
  set.seed(2)
  speed <- 20 # km per year
  n <- 4000
  yr <- stats::runif(n, 1950, 2000)
  front <- speed * (yr - 1950) + 5
  dist <- front * sqrt(stats::runif(n)) # uniform within the invaded disc
  ang <- stats::runif(n, 0, 2 * pi)
  o <- c(145, -17)
  lat <- o[2] + dist * sin(ang) / 111.32
  lon <- o[1] + dist * cos(ang) / (111.32 * cos(o[2] * pi / 180))
  d <- data.frame(lon = lon, lat = lat, year = yr)
  fr <- geo_spread_rate(d, date = year, origin = o, method = "front")
  # 0.99 quantile of a uniform disc of radius f is f * sqrt(0.99)
  expect_equal(fr$estimate$rate_km_per_year, speed * sqrt(0.99), tolerance = 0.03)
  expect_true(fr$estimate$lower < speed && fr$estimate$upper > speed * 0.95)
  # First records per cell: positive, but lag behind the front when sampling is sparse
  fi <- geo_spread_rate(d, date = year, origin = o, method = "first_record", cell_size = 20)
  expect_gt(fi$estimate$lower, 0)
  expect_lt(fi$estimate$rate_km_per_year, speed)
  pr <- stats::predict(fr$model, interval = "confidence")
  # The area method needs saturated sampling: a small, densely recorded invasion
  yr2 <- stats::runif(30000, 1990, 2010)
  r2 <- (2 * (yr2 - 1990) + 2) * sqrt(stats::runif(30000))
  a2 <- stats::runif(30000, 0, 2 * pi)
  d2 <- data.frame(
    lon = o[1] + r2 * cos(a2) / (111.32 * cos(o[2] * pi / 180)),
    lat = o[2] + r2 * sin(a2) / 111.32, year = yr2
  )
  ar <- geo_spread_rate(d2, date = year, origin = o, method = "area", cell_size = 2)
  expect_equal(ar$estimate$rate_km_per_year, 2, tolerance = 0.1)
  expect_equal(fr$fitted$upper, unname(pr[, "upr"]))
  expect_s3_class(plot(fr), "ggplot")
})
