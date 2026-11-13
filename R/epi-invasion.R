#' Epidemic growth rate, doubling time and reproduction number
#'
#' @description
#' `epi_growth_rate()` estimates how fast an epidemic grows from counts of
#' cases (or a line list of case dates) during its early, exponential
#' phase. The daily (or weekly) incidence is modelled with a log-linear
#' Poisson or negative binomial generalised linear model,
#' \deqn{\log E[C_t] = \alpha + r t,}{log E[C_t] = alpha + r t,}
#' so the growth rate \eqn{r} and its standard error come directly from
#' the fitted model. From \eqn{r}:
#' * the doubling time is \eqn{\log 2 / r};
#' * the reproduction number follows from the generation interval
#'   (Wallinga and Lipsitch 2007). For a gamma-distributed generation
#'   interval with mean \eqn{\mu} and standard deviation \eqn{\sigma},
#'   \eqn{R = (1 + r \sigma^2/\mu)^{\mu^2/\sigma^2}}.
#'
#' Confidence intervals are formed for \eqn{r} on the scale of the linear
#' predictor (Wald) and carried through these monotone transformations.
#' The fitted incidence and its confidence band are likewise computed on
#' the link scale with the model's standard errors and back-transformed, so
#' they are never negative. Choose `window` to cover the growth phase only:
#' once susceptible hosts are depleted or control begins, growth slows and
#' a single exponential no longer fits.
#'
#' @param data A data frame: either a line list with one row per case, or
#'   counts per time with a `cases` column.
#' @param date Column of dates (class `Date`) or numeric times.
#' @param cases Optional column of case counts; if `NULL`, each row is one
#'   case.
#' @param window Optional length-2 vector (same class as `date`) giving the
#'   first and last time of the growth phase to fit.
#' @param unit Time unit of the counts and of \eqn{r}: `"day"` or `"week"`
#'   (dates only).
#' @param family `"poisson"` or `"negbin"` (negative binomial, for
#'   overdispersed counts; needs MASS).
#' @param generation_mean,generation_sd Mean and standard deviation of the
#'   generation (or serial) interval, in `unit`s. If omitted, \eqn{R} is
#'   not computed.
#' @param level Confidence level.
#' @return A list of class `tmr_epi_growth`: `estimates` (a tibble with the
#'   growth rate, doubling time and \eqn{R}, each with standard error or
#'   interval), `fitted` (incidence per time with the fitted value, its
#'   standard error on the link scale and confidence band), `model` (the
#'   fitted `glm`) and the settings. `plot()` draws the observed incidence
#'   with the fitted curve and band on a white background.
#' @references
#' Wallinga, J. and Lipsitch, M. (2007). How generation intervals shape the
#' relationship between growth rates and reproductive numbers. Proceedings
#' of the Royal Society B, 274, 599-604.
#'
#' WHO Ebola Response Team (2014). Ebola virus disease in West Africa: the
#' first 9 months of the epidemic and forward projections. New England
#' Journal of Medicine, 371, 1481-1495.
#' @export
#' @examplesIf rlang::is_installed("outbreaks")
#' ebola <- outbreaks::ebola_sierraleone_2014
#' g <- epi_growth_rate(ebola,
#'   date = date_of_onset,
#'   window = as.Date(c("2014-06-01", "2014-09-30")), unit = "week",
#'   family = "negbin", generation_mean = 15.3 / 7, generation_sd = 9.3 / 7
#' )
#' g$estimates
#' plot(g)
epi_growth_rate <- function(data,
                            date,
                            cases = NULL,
                            window = NULL,
                            unit = c("day", "week"),
                            family = c("poisson", "negbin"),
                            generation_mean = NULL,
                            generation_sd = NULL,
                            level = 0.95) {
  unit <- rlang::arg_match(unit)
  family <- rlang::arg_match(family)
  if (!is.data.frame(data)) cli::cli_abort("{.arg data} must be a data frame.")
  t_raw <- rlang::eval_tidy(rlang::enquo(date), data)
  cq <- rlang::enquo(cases)
  n <- if (rlang::quo_is_null(cq)) rep(1, length(t_raw)) else rlang::eval_tidy(cq, data)
  ok <- !is.na(t_raw) & !is.na(n)
  t_raw <- t_raw[ok]
  n <- n[ok]
  if (!is.null(window)) {
    keep <- t_raw >= window[1] & t_raw <= window[2]
    t_raw <- t_raw[keep]
    n <- n[keep]
  }
  is_date <- inherits(t_raw, "Date")
  t0 <- min(t_raw)
  tt <- as.numeric(t_raw - t0)
  if (is_date && unit == "week") tt <- tt / 7
  tt <- floor(tt)
  grid <- seq(0, max(tt))
  counts <- vapply(grid, function(g) sum(n[tt == g]), numeric(1))
  if (length(grid) < 3 || sum(counts) < 5) {
    cli::cli_abort("Too few cases or time steps in {.arg window} to estimate growth.")
  }
  d <- data.frame(time = grid, cases = counts)
  fit <- if (family == "poisson") {
    stats::glm(cases ~ time, family = stats::poisson(), data = d)
  } else {
    rlang::check_installed("MASS")
    MASS::glm.nb(cases ~ time, data = d)
  }
  z <- stats::qnorm(1 - (1 - level) / 2)
  r <- unname(stats::coef(fit)[["time"]])
  se <- unname(sqrt(stats::vcov(fit)["time", "time"]))
  r_ci <- r + c(-1, 1) * z * se
  dbl <- function(x) ifelse(x > 0, log(2) / x, NA_real_)
  est <- tibble::tibble(
    quantity = c("growth_rate", "doubling_time"),
    estimate = c(r, dbl(r)),
    std_error = c(se, NA_real_),
    lower = c(r_ci[1], dbl(r_ci[2])),
    upper = c(r_ci[2], dbl(r_ci[1])),
    unit = c(paste0("per ", unit), paste0(unit, "s"))
  )
  if (!is.null(generation_mean) && !is.null(generation_sd)) {
    a <- generation_mean^2 / generation_sd^2
    b <- generation_sd^2 / generation_mean
    rr <- function(x) (1 + x * b)^a
    est <- vctrs::vec_rbind(est, tibble::tibble(
      quantity = "reproduction_number", estimate = rr(r), std_error = NA_real_,
      lower = rr(r_ci[1]), upper = rr(r_ci[2]), unit = "secondary cases"
    ))
  }
  p <- stats::predict(fit, newdata = d, type = "link", se.fit = TRUE)
  fitted <- tibble::tibble(
    time = if (is_date) t0 + d$time * (if (unit == "week") 7 else 1) else t0 + d$time,
    cases = d$cases, fit = unname(exp(p$fit)), se_link = unname(p$se.fit),
    lower = unname(exp(p$fit - z * p$se.fit)), upper = unname(exp(p$fit + z * p$se.fit))
  )
  structure(list(
    estimates = est, fitted = fitted, model = fit,
    settings = list(unit = unit, family = family, level = level, window = window)
  ), class = "tmr_epi_growth")
}

#' @export
print.tmr_epi_growth <- function(x, ...) {
  cli::cli_text(
    "Exponential growth ({x$settings$family} GLM, {length(x$fitted$time)} {x$settings$unit}s):"
  )
  print(x$estimates)
  invisible(x)
}

#' @export
plot.tmr_epi_growth <- function(x, ...) {
  f <- x$fitted
  ggplot2::ggplot(f, ggplot2::aes(.data$time)) +
    ggplot2::geom_col(ggplot2::aes(y = .data$cases), fill = "grey75") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
      fill = "#B2182B", alpha = 0.25
    ) +
    ggplot2::geom_line(ggplot2::aes(y = .data$fit), colour = "#B2182B", linewidth = 1) +
    ggplot2::labs(
      x = NULL, y = paste("Cases per", x$settings$unit),
      subtitle = sprintf(
        "Fitted exponential growth with %d%% confidence band", round(100 * x$settings$level)
      )
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA))
}

#' Spread rate of a biological invasion
#'
#' @description
#' `geo_spread_rate()` estimates how fast an invading species (or disease)
#' expands its range, from dated occurrence records, with two standard
#' methods:
#' * `"first_record"` (default): the study area is divided into cells of
#'   `cell_size` km, the first record in each cell is kept, and the distance
#'   of each cell from the point of introduction is regressed on the date
#'   of its first record. The slope is the spread rate. Using first records
#'   per cell reduces the effect of uneven sampling effort.
#' * `"front"`: for each year with at least 5 records, the distance of the
#'   invasion front, taken as the `front_quantile` (default 0.99) of the
#'   distances of that year's records from the point of introduction,
#'   regressed on year. Records from behind the front do not matter, but
#'   records far ahead of it (hitchhikers, mislabelled localities) do:
#'   clean the data first ([geo_clean()]) and inspect the plot.
#' * `"area"`: the cumulative area of occupied cells is converted to the
#'   radius of a circle of the same area, \eqn{\sqrt{A/\pi}}, and regressed
#'   on time (Shigesada and Kawasaki 1997). This assumes nearly every
#'   invaded cell has a record; with sparse sampling it underestimates
#'   the rate badly.
#'
#' Distances are geodesic. The rate, its standard error and confidence
#' interval come from the fitted linear model, and so do the fitted
#' distances and their confidence band (`fitted`). Look at the plot before
#' trusting a single rate: many invasions accelerate (Phillips et al.
#' 2006), so fit separate periods with `period` if the relationship is
#' curved.
#'
#' @param data An `sf` table of points, or a data frame with `lon` and
#'   `lat` (WGS84).
#' @param date Column of dates (`Date`) or decimal years.
#' @param origin Point of introduction, `c(lon, lat)`; default the earliest
#'   record.
#' @param method `"first_record"` or `"area"`.
#' @param cell_size Cell size in km for first records and occupied area.
#' @param front_quantile Quantile of record distances taken as the front
#'   (`method = "front"`).
#' @param period Optional length-2 vector of years to fit.
#' @param level Confidence level.
#' @return A list of class `tmr_spread_rate`: `estimate` (a tibble with the
#'   rate in km per year, its standard error and interval, and \eqn{R^2}),
#'   `fitted` (the data used, with fitted values and confidence band),
#'   `model` (the `lm`) and the settings. `plot()` draws the data and fit.
#' @references
#' Phillips, B. L., Brown, G. P., Webb, J. K. and Shine, R. (2006).
#' Invasion and the evolution of speed in toads. Nature, 439, 803.
#'
#' Shigesada, N. and Kawasaki, K. (1997). Biological Invasions: Theory and
#' Practice. Oxford University Press.
#' @export
geo_spread_rate <- function(data,
                            date,
                            origin = NULL,
                            method = c("first_record", "front", "area"),
                            cell_size = 25,
                            front_quantile = 0.99,
                            period = NULL,
                            level = 0.95) {
  method <- rlang::arg_match(method)
  tmr_chk_num(cell_size, "cell_size", 1e-9)
  tq <- rlang::enquo(date)
  if (inherits(data, "sf")) {
    rlang::check_installed("sf")
    xy <- sf::st_coordinates(sf::st_transform(data, 4326))
    tv <- rlang::eval_tidy(tq, sf::st_drop_geometry(data))
  } else {
    if (!all(c("lon", "lat") %in% names(data))) {
      cli::cli_abort("{.arg data} needs {.field lon} and {.field lat}, or must be {.cls sf}.")
    }
    xy <- cbind(data$lon, data$lat)
    tv <- rlang::eval_tidy(tq, data)
  }
  year <- if (inherits(tv, "Date")) {
    as.numeric(format(tv, "%Y")) + (as.numeric(format(tv, "%j")) - 0.5) / 365.25
  } else {
    as.numeric(tv)
  }
  ok <- stats::complete.cases(xy, year)
  xy <- xy[ok, , drop = FALSE]
  year <- year[ok]
  if (length(year) < 5) cli::cli_abort("At least 5 dated records are needed.")
  o <- if (is.null(origin)) xy[which.min(year), ] else origin
  # Equidistant-ish grid in km around the origin
  ky <- 111.32
  kx <- 111.32 * cos(o[2] * pi / 180)
  gx <- floor((xy[, 1] - o[1]) * kx / cell_size)
  gy <- floor((xy[, 2] - o[2]) * ky / cell_size)
  cell <- paste(gx, gy)
  first <- tapply(seq_along(year), cell, function(i) i[which.min(year[i])])
  fi <- unlist(first)
  dist_km <- function(p) {
    rad <- pi / 180
    dl <- (p[, 1] - o[1]) * rad
    a <- sin((p[, 2] - o[2]) * rad / 2)^2 + cos(o[2] * rad) * cos(p[, 2] * rad) * sin(dl / 2)^2
    2 * 6371.0088 * asin(pmin(1, sqrt(a)))
  }
  if (method == "first_record") {
    d <- data.frame(year = year[fi], distance = dist_km(xy[fi, , drop = FALSE]))
  } else if (method == "front") {
    dk <- dist_km(xy)
    yb <- floor(year)
    yrs <- sort(unique(yb))
    nyr <- vapply(yrs, function(y) sum(yb == y), numeric(1))
    yrs <- yrs[nyr >= 5]
    fr <- vapply(yrs, function(y) {
      stats::quantile(dk[yb == y], front_quantile, names = FALSE)
    }, numeric(1))
    d <- data.frame(year = yrs + 0.5, distance = fr)
  } else {
    yrs <- sort(unique(floor(year[fi])))
    cum <- vapply(yrs, function(y) sum(floor(year[fi]) <= y), numeric(1))
    d <- data.frame(year = yrs, distance = sqrt(cum * cell_size^2 / pi))
  }
  if (!is.null(period)) d <- d[d$year >= period[1] & d$year <= period[2] + 1, , drop = FALSE]
  if (nrow(d) < 3) cli::cli_abort("Too few cells or years to fit a spread rate.")
  fit <- stats::lm(distance ~ year, data = d)
  ci <- stats::confint(fit, "year", level = level)
  sm <- summary(fit)
  est <- tibble::tibble(
    method = method, rate_km_per_year = unname(stats::coef(fit)[["year"]]),
    std_error = sm$coefficients["year", "Std. Error"],
    lower = ci[1, 1], upper = ci[1, 2], r_squared = sm$r.squared, n = nrow(d)
  )
  pr <- stats::predict(fit, d, interval = "confidence", level = level, se.fit = TRUE)
  fitted <- tibble::tibble(
    year = d$year, distance = d$distance, fit = unname(pr$fit[, "fit"]),
    se = unname(pr$se.fit), lower = unname(pr$fit[, "lwr"]), upper = unname(pr$fit[, "upr"])
  )
  structure(list(
    estimate = est, fitted = fitted, model = fit,
    settings = list(origin = o, method = method, cell_size = cell_size, level = level)
  ), class = "tmr_spread_rate")
}

#' @export
print.tmr_spread_rate <- function(x, ...) {
  e <- x$estimate
  cli::cli_text(
    "Spread rate ({e$method}): {signif(e$rate_km_per_year, 3)} km per year ",
    "({round(100 * x$settings$level)}% CI {signif(e$lower, 3)} to {signif(e$upper, 3)}), ",
    "R2 = {signif(e$r_squared, 2)}, n = {e$n}."
  )
  invisible(x)
}

#' @export
plot.tmr_spread_rate <- function(x, ...) {
  f <- x$fitted
  ggplot2::ggplot(f, ggplot2::aes(.data$year, .data$distance)) +
    ggplot2::geom_point(colour = "grey40", alpha = 0.6, size = 1.4) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$lower, ymax = .data$upper),
      fill = "#B2182B", alpha = 0.25
    ) +
    ggplot2::geom_line(ggplot2::aes(y = .data$fit), colour = "#B2182B", linewidth = 1) +
    ggplot2::labs(
      x = "Year", y = if (x$settings$method == "area") "Range radius (km)" else
        "Distance from introduction (km)",
      subtitle = sprintf(
        "%.1f km per year (%d%% CI %.1f to %.1f)", x$estimate$rate_km_per_year,
        round(100 * x$settings$level), x$estimate$lower, x$estimate$upper
      )
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA))
}
