test_that("tidyvisor() advises on data and interprets results", {
  cases <- data.frame(
    week = seq(as.Date("2024-01-01"), by = "week", length.out = 12),
    n = c(2, 3, 5, 4, 9, 12, 15, 24, 30, 41, 60, 77)
  )
  # case counts without locations are not claimed: they belong to tidyepidemio
  expect_false(tidyvisor:::tv_registry()$tidymapr$claims(cases, c("date", "cases")))
  a <- tidyvisor(cases, question = "epidemic", date = "week", cases = "n")
  expect_s3_class(a, "tmr_advice")
  expect_true(any(grepl("tidyepidemio", a$advice$recommendation)))
  expect_identical(a$question, "epidemic")
  # Counts close to an exponential trend are not overdispersed
  expect_true(any(grepl("family = \"poisson\"", a$advice$code)))
  g <- epi_growth_rate(cases,
    date = week, cases = n, unit = "week",
    generation_mean = 2, generation_sd = 1
  )
  i <- tidyvisor(g)
  expect_s3_class(i, "tmr_interpretation")
  r <- g$estimates$estimate[g$estimates$quantity == "reproduction_number"]
  expect_match(i$sections$`Reproduction number`[1], sprintf("%.2f", r), fixed = TRUE)
  expect_match(i$sections$Growth[2], "growing")
  set.seed(1)
  pts <- data.frame(lon = runif(40, 140, 150), lat = runif(40, -8, -2))
  pts$v <- pts$lon + stats::rnorm(40)
  expect_match(tidyvisor(geo_moran(pts, value = v))$sections$Result[2], "patchy")
  expect_identical(tidyvisor(pts, question = "distribution")$question, "distribution")
  expect_error(tidyvisor(1:3), "No advis[eo]r")
  expect_output(print(i), NA)
})

test_that("tidyvisor() hands tidydiversity's work to tidydiversity", {
  skip_if_not_installed("tidydiversity")
  skip_if_not_installed("vegan")
  frogs <- tidydiversity::png_frogs
  # community data with abundance: ordination advice from tidydiversity
  expect_s3_class(tidyvisor(frogs, abundance = abundance), "td_ord_advice")
  o <- tidydiversity::ord_fit(frogs, abundance = abundance, method = "pca", transform = "hellinger")
  expect_s3_class(tidyvisor(o), "td_ord_interpretation")
})

test_that("advice headings name the question and braces print safely", {
  cases <- data.frame(week = 1:8, n = c(2, 3, 5, 8, 13, 21, 34, 55))
  out <- cli::cli_fmt(print(tidyvisor(cases, question = "epidemic", date = "week", cases = "n")))
  expect_true(any(grepl("how fast is the epidemic growing", out)))
  a <- tidyvisor(cases, question = "epidemic", date = "week", cases = "n")
  a$checks$value[1] <- "{12}"
  expect_no_error(cli::cli_fmt(print(a)))
})

test_that("every interpretation ends with advice for after the test and for the paper", {
  set.seed(1)
  cases <- data.frame(week = 1:12, n = c(2, 3, 5, 4, 9, 12, 15, 24, 30, 41, 60, 77))
  g <- tidyvisor(epi_growth_rate(cases, date = week, cases = n))
  expect_match(g$sections$`For the paper`[1], "^Results: 'Cases grew by")
  expect_true(any(grepl("geo_save", g$sections$`For the paper`)))

  pts <- data.frame(lon = runif(40, 140, 150), lat = runif(40, -8, -2))
  pts$v <- pts$lon + rnorm(40)
  pts$w <- rnorm(40)
  sig <- tidyvisor(geo_moran(pts, value = v))
  expect_match(sig$sections$`After the overall test`[1], "correlogram")
  ns <- tidyvisor(geo_moran(pts, value = w))
  expect_match(ns$sections$`After the overall test`[1], "do not go on to search distance classes")
  expect_match(ns$sections$`For the paper`[1], "not detectably spatially autocorrelated")

  sr <- structure(list(
    estimate = data.frame(
      rate_km_per_year = 12, lower = 8, upper = 16, r_squared = 0.8, n = 10, method = "front"
    ),
    settings = list(level = 0.95)
  ), class = "tmr_spread_rate")
  expect_match(tidymapr:::tmr_paper(sr)[1], "expanded by 12.0 km per year")
  expect_match(tidymapr:::tmr_after(sr), "two periods")

  ens <- structure(list(
    summary = data.frame(
      algorithm = c("glm", "rf"), auc = c(0.8, 0.9), tss = c(0.5, 0.6), weight = c(0.4, 0.6)
    ),
    spatial = TRUE
  ), class = "tmr_sdm_ensemble")
  expect_match(tidymapr:::tmr_paper(ens)[1], "spatial block cross-validation")
  expect_true(any(grepl("ODMAP", tidymapr:::tmr_paper(ens))))

  sh <- structure(list(results = data.frame(
    dispersal = rep(c("limited", "unlimited"), each = 4),
    change = c(-30, -20, -10, 5, -5, 0, 10, 20),
    ssp = rep(c("ssp126", "ssp585"), 4)
  )), class = "tmr_shift_ensemble")
  expect_match(tidymapr:::tmr_paper(sh)[1], "3 of 4 members projected a loss")

  ep <- structure(list(
    curve = data.frame(time = 0:5, infected = c(1, 5, 20, 12, 4, 1)), attack = 0.3,
    settings = list(nsim = 10, R0 = 2.5, kernel = "exponential", dispersal_mean = 3)
  ), class = "tmr_epidemic")
  expect_match(tidymapr:::tmr_paper(ep)[1], "peaked at time 2")
})
