test_that("tidyvisor() advises on data and interprets results", {
  cases <- data.frame(
    week = seq(as.Date("2024-01-01"), by = "week", length.out = 12),
    n = c(2, 3, 5, 4, 9, 12, 15, 24, 30, 41, 60, 77)
  )
  a <- tidyvisor(cases, date = "week", cases = "n")
  expect_s3_class(a, "tmr_advice")
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
  expect_error(tidyvisor(1:3), "data frame")
  expect_output(print(i), NA)
})
