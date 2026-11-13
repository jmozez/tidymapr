#' tidyvisor: advice before the analysis, interpretation after it
#'
#' @description
#' `tidyvisor()` is the package's adviser. Give it **data** and a question,
#' and it recommends the analysis, checks the data for the usual pitfalls,
#' and names the plots and the code to run (`tmr_advise()`). Give it a
#' **result** (a growth rate, a spread rate, an epidemic or range-shift
#' simulation, a species distribution model or a Moran's I test), and it
#' explains the numbers and the figure in plain sentences
#' (`tmr_interpret()`).
#'
#' The advice gives its reasons, so it can be checked and overruled: the
#' question, which only the analyst knows, comes first.
#'
#' Questions:
#' * `"distribution"`: where can a species live? Species distribution
#'   models, from presence-only, presence-absence or both kinds of record.
#' * `"spread"`: how fast is an invasion or a range expansion moving?
#' * `"epidemic"`: how fast are cases growing, and what is the reproduction
#'   number? How could an infection spread across a landscape?
#' * `"range_shift"`: where will a species be under a future climate, given
#'   how far it can disperse?
#' * `"autocorrelation"`: are values at nearby sites more alike than
#'   expected?
#'
#' @param x A data frame of records (to be advised) or a result of
#'   [epi_growth_rate()], [geo_spread_rate()], [geo_epidemic_simulate()],
#'   [geo_shift_ensemble()], [sdm_ensemble()], [sdm_integrated()] or
#'   [geo_moran()] (to be interpreted).
#' @param ... Passed to `tmr_advise()` or `tmr_interpret()`.
#' @return A `tmr_advice` or a `tmr_interpretation` object, printed as
#'   sentences.
#' @export
#' @examples
#' # Advice on weekly case counts
#' cases <- data.frame(
#'   week = seq(as.Date("2024-01-01"), by = "week", length.out = 12),
#'   n = c(2, 3, 5, 4, 9, 12, 15, 24, 30, 41, 60, 77)
#' )
#' tidyvisor(cases, question = "epidemic", date = "week", cases = "n")
#' # ... and the interpretation of the fit
#' g <- epi_growth_rate(cases, date = week, cases = n, unit = "week")
#' tidyvisor(g)
tidyvisor <- function(x, ...) {
  if (inherits(x, tmr_interpretable)) {
    tmr_interpret(x, ...)
  } else if (is.data.frame(x)) {
    tmr_advise(x, ...)
  } else {
    cli::cli_abort(c(
      "{.fn tidyvisor} needs a data frame of records or a tidymapr result.",
      i = "Got an object of class {.cls {class(x)}}."
    ))
  }
}

tmr_interpretable <- c(
  "tmr_epi_growth", "tmr_spread_rate", "tmr_epidemic", "tmr_shift_ensemble",
  "tmr_sdm_ensemble", "tmr_sdm_integrated", "tmr_geo_moran"
)

# nolint start: line_length_linter. Advice sentences read better unbroken.

#' @rdname tidyvisor
#' @param question What is asked (see above), or `"auto"` to guess it from
#'   the columns.
#' @param date,cases,lon,lat,presence,value Names (strings) of the columns
#'   holding the date, case counts, coordinates, presence (1) or absence (0),
#'   and a measured value. Guessed from common names when not given.
#' @export
tmr_advise <- function(x,
                       question = c("auto", "distribution", "spread", "epidemic", "range_shift", "autocorrelation"),
                       date = NULL, cases = NULL, lon = NULL, lat = NULL,
                       presence = NULL, value = NULL) {
  question <- rlang::arg_match(question)
  nm <- names(x)
  guess <- function(given, pats) {
    if (!is.null(given)) {
      return(given)
    }
    hit <- nm[tolower(nm) %in% pats]
    if (length(hit)) hit[1] else NULL
  }
  date <- guess(date, c("date", "eventdate", "time", "week", "day", "year"))
  cases <- guess(cases, c("cases", "count", "n", "incidence"))
  lon <- guess(lon, c("lon", "long", "longitude", "x", "decimallongitude"))
  lat <- guess(lat, c("lat", "latitude", "y", "decimallatitude"))
  presence <- guess(presence, c("presence", "pa", "occurrence", "detected"))
  if (question == "auto") {
    question <- if (!is.null(cases) && !is.null(date)) {
      "epidemic"
    } else if (!is.null(date) && !is.null(lon)) {
      "spread"
    } else if (!is.null(lon) && (!is.null(presence))) {
      "distribution"
    } else if (!is.null(lon) && !is.null(value)) {
      "autocorrelation"
    } else {
      cli::cli_abort("Give {.arg question}: the columns do not show what is asked.")
    }
  }
  ck <- new.env()
  ck$rows <- list(tibble::tibble(check = "Records", value = as.character(nrow(x)), meaning = ""))
  add <- function(check, value, meaning = "") {
    ck$rows[[length(ck$rows) + 1]] <- tibble::tibble(check = check, value = as.character(value), meaning = meaning)
  }
  step <- function(s, r, why, code) tibble::tibble(step = s, recommendation = r, reason = why, code = code)
  adv <- switch(question,
    epidemic = {
      if (is.null(cases) || is.null(date)) cli::cli_abort("Give the {.arg date} and {.arg cases} columns.")
      y <- x[[cases]]
      tt <- seq_along(y)
      # Dispersion about the exponential trend (Pearson chi-square / df)
      pf <- stats::glm(y ~ tt, family = stats::poisson())
      ratio <- sum(stats::residuals(pf, type = "pearson")^2) / pf$df.residual
      add("Time points", length(y), if (length(y) < 6) "few points: the growth rate will be uncertain" else "")
      add("Dispersion about the trend (Pearson)", sprintf("%.1f", ratio), if (ratio > 2) "overdispersed: use a negative binomial model" else "close to Poisson")
      fam <- if (ratio > 2) "negbin" else "poisson"
      vctrs::vec_rbind(
        step(
          "Approach", "Exponential growth rate from a log-linear count model",
          "Early in an outbreak cases grow exponentially; the slope of log cases on time is the growth rate r.", ""
        ),
        step(
          "Method", sprintf("%s generalised linear model over the exponential phase", if (fam == "negbin") "Negative binomial" else "Poisson"),
          "Choose a window where the log counts rise in a straight line; later, control and depletion bend the curve.",
          sprintf("g <- epi_growth_rate(data, date = %s, cases = %s, family = \"%s\", window = c(<start>, <end>))", date, cases, fam)
        ),
        step(
          "Reproduction number", "Convert r to R with the generation interval",
          "R depends on r and on the mean and standard deviation of the generation interval (Wallinga and Lipsitch 2007); take these from the literature for the pathogen.",
          "epi_growth_rate(..., generation_mean = <mean>, generation_sd = <sd>)"
        ),
        step(
          "Spatial spread", "Simulate spread across hosts with a dispersal kernel",
          "To ask where an infection could go, combine host density, transmission and a dispersal kernel.",
          "geo_epidemic_simulate(hosts, init_inf, beta = <beta>, gamma = <gamma>, dispersal_mean = <km>)"
        ),
        step(
          "Plots", "Observed counts with the fitted curve and its confidence band, on a log scale",
          "On a log scale exponential growth is a straight line, so departures from it are easy to see.",
          "plot(g)"
        ),
        step("Interpret", "Plain-language explanation of the estimates", "", "tidyvisor(g)")
      )
    },
    spread = {
      if (is.null(date) || is.null(lon)) cli::cli_abort("Give the {.arg date}, {.arg lon} and {.arg lat} columns.")
      yr <- as.numeric(format(as.Date(x[[date]]), "%Y"))
      per <- table(yr)
      add("Years with records", length(per), if (length(per) < 5) "few years: the rate will be uncertain" else "")
      add("Median records per year", stats::median(per), if (stats::median(per) < 5) "sparse: the front cannot be estimated each year" else "")
      meth <- if (stats::median(per) >= 5 && length(per) >= 5) "front" else "first_record"
      vctrs::vec_rbind(
        step(
          "Approach", "Rate of range expansion: distance from the origin against time",
          "The slope of distance on year estimates the speed of the invasion front in km per year.", ""
        ),
        step(
          "Method", sprintf("method = \"%s\"", meth),
          if (meth == "front") "There are enough records each year to take a high quantile of distance as the front." else "Records are sparse, so the first record in each cell is used; it lags behind the true front where sampling is poor.",
          sprintf("s <- geo_spread_rate(data, date = %s, method = \"%s\")", date, meth)
        ),
        step("Caution", "Sampling effort", "More recording in later years makes a range look as if it spreads faster; compare with the number of records per year.", ""),
        step(
          "Plots", "Distance against year with the fitted line and its confidence band; a map of first records coloured by period",
          "The line shows the rate; scatter above it in early years warns of records ahead of the front (e.g. human transport).",
          "plot(s)\nplot_geo(data, colour = <period class>)"
        ),
        step("Interpret", "Plain-language explanation of the rate", "", "tidyvisor(s)")
      )
    },
    distribution = {
      pa <- !is.null(presence) && all(x[[presence]] %in% c(0, 1))
      np <- if (pa) sum(x[[presence]] == 1) else nrow(x)
      na <- if (pa) sum(x[[presence]] == 0) else 0
      add("Presences", np, if (np < 30) "few presences: keep models simple (few predictors)" else "")
      add("Absences", na, if (na == 0) "presence-only: background points are needed, and sampling bias matters" else "")
      vctrs::vec_rbind(
        step(
          "Approach", if (na == 0) "Presence-only species distribution model" else "Presence-absence species distribution model",
          if (na == 0) "Without absences, the model contrasts presences with the available background; the result is relative suitability." else "With absences, the model estimates the probability of occurrence directly.", ""
        ),
        step(
          "Method", if (na == 0) "MaxEnt or an ensemble; an integrated model if survey data are also available" else "Ensemble of GLM, GAM and random forest, weighted by cross-validated TSS",
          "An ensemble averages over model uncertainty; integrated models combine opportunistic records with surveys and correct sampling bias (Fithian et al. 2015).",
          if (na == 0) "m <- sdm_ensemble(presence, data, coords = coords)\n# with surveys: sdm_integrated(presence, background, area, survey = ...)" else "m <- sdm_ensemble(presence, data, coords = coords)"
        ),
        step(
          "Validate", "Spatial cross-validation (blocks), not random folds",
          "Nearby records are not independent; random folds overstate accuracy.", "sdm_ensemble(..., coords = coords)   # spatial folds"
        ),
        step("Check", "Residual spatial autocorrelation", "Autocorrelated residuals mean a missing predictor or an overconfident model.", "geo_moran(residuals, value = resid)"),
        step(
          "Plots", "Map of predicted suitability (continuous ramp on the raster) with the records as points; response curves of the main predictors",
          "Rasters take continuous colour ramps; records are points of one colour; response curves show what the model has learnt.",
          "plot_sdm(pred)"
        ),
        step("Interpret", "Plain-language explanation of model performance", "", "tidyvisor(m)")
      )
    },
    range_shift = vctrs::vec_rbind(
      step(
        "Approach", "Simulate occupancy on present and future suitability, with dispersal",
        "Where a species will be depends on where conditions will be suitable and on whether it can get there in time.", ""
      ),
      step(
        "Dispersal kernel", "Exponential for local spread; 2Dt (fat-tailed) when rare long-distance jumps matter",
        "Fat tails make spread accelerate and reach isolated habitat; check the share of dispersal beyond 5 times the mean.",
        "geo_dispersal_kernel(dispersal_mean = <km>, cell_size = <km>, kernel = \"2Dt\")"
      ),
      step(
        "Scenarios", "An ensemble over climate models, emission scenarios (and lapse rates on mountains)",
        "Single projections hide the spread among climate models; report the range.",
        "e <- geo_shift_ensemble(model, scenarios, dispersal_mean = <km>)"
      ),
      step(
        "Bounds", "Compare limited dispersal with unlimited dispersal",
        "The two bracket the plausible future range: the truth lies between full tracking and the dispersal-limited result.", ""
      ),
      step(
        "Plots", "Maps of present and future occupancy; area change by scenario with limited and unlimited dispersal side by side",
        "Readers see where the range gains and loses, and how much depends on the scenario and on dispersal.",
        "print(e); plot_geo(...)"
      ),
      step("Interpret", "Plain-language explanation of the ensemble", "", "tidyvisor(e)")
    ),
    autocorrelation = vctrs::vec_rbind(
      step(
        "Approach", "Moran's I with a permutation test, and a correlogram",
        "Moran's I measures whether nearby values are more alike than chance; the correlogram shows over which distances.", ""
      ),
      step(
        "Method", "Inverse-distance weights, permutation p-value",
        "Permutation makes no assumption of normality.",
        sprintf("mi <- geo_moran(data, value = %s, correlogram = TRUE)", value %||% "<value>")
      ),
      step(
        "Plots", "Correlogram (Moran's I against distance class) and a map of the values in classes",
        "The correlogram shows the scale of patchiness; classed point symbols show where.",
        "plot_geo(data, colour = <value>)"
      ),
      step("Interpret", "Plain-language explanation", "", "tidyvisor(mi)")
    )
  )
  checks <- vctrs::vec_rbind(!!!ck$rows)
  structure(list(question = question, checks = checks, advice = adv), class = "tmr_advice")
}

#' @export
print.tmr_advice <- function(x, ...) {
  cli::cli_h1("tidyvisor: which analysis?")
  cli::cli_text("Question: {.strong {x$question}}")
  cli::cli_h2("What the data show")
  for (i in seq_len(nrow(x$checks))) {
    r <- x$checks[i, ]
    note <- if (nzchar(r$meaning)) paste0(" \u2014 ", r$meaning) else ""
    cli::cli_bullets(c("*" = paste0(r$check, ": ", r$value, note)))
  }
  cli::cli_h2("Recommended")
  for (i in seq_len(nrow(x$advice))) {
    r <- x$advice[i, ]
    cli::cli_text("{.strong {r$step}}: {r$recommendation}")
    if (nzchar(r$reason)) cli::cli_text("  {.emph {r$reason}}")
    if (nzchar(r$code)) cli::cli_code(strsplit(r$code, "\n")[[1]])
  }
  invisible(x)
}

#' @rdname tidyvisor
#' @export
tmr_interpret <- function(x, ...) UseMethod("tmr_interpret")

tmr_interp <- function(sections, tables = list()) {
  structure(list(sections = sections, tables = tables), class = "tmr_interpretation")
}

tmr_fp <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)

#' @export
tmr_interpret.tmr_epi_growth <- function(x, ...) {
  e <- x$estimates
  u <- x$settings$unit
  r <- e[e$quantity == "growth_rate", ]
  s <- list(Overview = sprintf(
    "Exponential growth fitted to %d %ss of counts with a %s model.",
    nrow(x$fitted), u, if (x$settings$family == "negbin") "negative binomial" else "Poisson"
  ))
  g <- sprintf(
    "Cases change by %.1f%% per %s (growth rate r = %.3f, %d%% CI %.3f to %.3f).",
    100 * (exp(r$estimate) - 1), u, r$estimate, round(100 * x$settings$level), r$lower, r$upper
  )
  g <- c(g, if (r$lower > 0) {
    d <- e[e$quantity == "doubling_time", ]
    sprintf("The epidemic is growing: cases double every %.1f %ss (%.1f to %.1f).", d$estimate, u, d$lower, d$upper)
  } else if (r$upper < 0) {
    sprintf("The epidemic is declining: cases halve every %.1f %ss.", log(2) / -r$estimate, u)
  } else {
    "The interval includes zero: the data cannot tell growth from decline."
  })
  s$Growth <- g
  rr <- e[e$quantity == "reproduction_number", ]
  if (nrow(rr)) {
    s$`Reproduction number` <- c(
      sprintf("Each case causes on average %.2f new cases (R, %.2f to %.2f).", rr$estimate, rr$lower, rr$upper),
      if (rr$lower > 1) "R is above 1: the outbreak grows unless transmission falls." else if (rr$upper < 1) "R is below 1: the outbreak is dying out." else "The interval spans 1.",
      if (rr$estimate > 1) sprintf("To stop growth, transmission must fall by about %.0f%% (1 - 1/R).", 100 * (1 - 1 / rr$estimate))
    )
  }
  s$`Reading the plot` <- c(
    "Points are the observed counts; the line is the fitted exponential curve and the band its confidence interval, computed on the log scale and back-transformed.",
    "On a log scale the curve is straight; counts bending below it late in the window suggest control measures or depletion of susceptibles."
  )
  tmr_interp(s, list(estimates = e))
}

#' @export
tmr_interpret.tmr_spread_rate <- function(x, ...) {
  e <- x$estimate
  s <- list(
    Overview = sprintf("Rate of spread from %d years of records (method \"%s\").", e$n, e$method),
    Rate = c(
      sprintf("The range expands by %.1f km per year (%d%% CI %.1f to %.1f; R\u00b2 = %.2f).", e$rate_km_per_year, round(100 * x$settings$level), e$lower, e$upper, e$r_squared),
      if (e$lower > 0) "The expansion is clear: the interval excludes zero." else "The interval includes zero: no clear expansion.",
      switch(e$method,
        first_record = "First records lag behind the true front where recording is sparse, so this rate is a lower bound when effort is constant and can be inflated when effort grows.",
        front = "The front is a high quantile of distance each year; isolated records far ahead (jumps) are discounted.",
        area = "The rate from occupied area assumes spread in a circle; sparse sampling underestimates the area."
      )
    ),
    `Reading the plot` = "Each point is a year's distance from the origin; the line is the fitted rate and the band its confidence interval. Points well above the line early on suggest long-distance jumps."
  )
  tmr_interp(s, list(estimate = e))
}

#' @export
tmr_interpret.tmr_epidemic <- function(x, ...) {
  st <- x$settings
  cu <- x$curve
  pk <- cu[which.max(cu$infected), ]
  s <- list(
    Overview = sprintf("Spatial SIR simulation, %d run%s, %s dispersal kernel with mean %.1f km.", st$nsim, if (st$nsim > 1) "s" else "", st$kernel, st$dispersal_mean),
    Dynamics = c(
      sprintf("Local reproduction number R0 = %.2f: %s", st$R0, if (st$R0 > 1) "an infection can take off where hosts are dense." else "an infection dies out locally."),
      sprintf("Infections peak at time %d with %.0f infected hosts.", pk$time, pk$infected),
      sprintf("Overall, %.1f%% of hosts are infected (attack rate).", 100 * x$attack)
    ),
    `Reading the maps` = c(
      "The prevalence map shows the share of hosts infected in each cell; the reached map the share of runs in which the infection reached each cell, i.e. the risk of arrival.",
      if (st$kernel == "2Dt") "With a fat-tailed kernel, rare long jumps seed distant patches ahead of the main front." else "With an exponential kernel, the infection spreads as a fairly regular front."
    )
  )
  tmr_interp(s, list(curve = cu))
}

#' @export
tmr_interpret.tmr_shift_ensemble <- function(x, ...) {
  r <- x$results
  lim <- r[r$dispersal == "limited", ]
  unl <- r[r$dispersal == "unlimited", ]
  s <- list(
    Overview = sprintf("Range-shift ensemble of %d members (climate models x scenarios x lapse rates).", nrow(lim)),
    Area = c(
      sprintf("With limited dispersal, the range changes by %.0f%% (median; %.0f%% to %.0f%% across members).", stats::median(lim$change), min(lim$change), max(lim$change)),
      sprintf("With unlimited dispersal, by %.0f%% (%.0f%% to %.0f%%).", stats::median(unl$change), min(unl$change), max(unl$change)),
      "The truth lies between the two: the gap is the habitat the species may fail to reach in time.",
      sprintf("%d of %d members predict a loss of range under limited dispersal.", sum(lim$change < 0), nrow(lim))
    )
  )
  if ("shift_median" %in% names(r)) {
    s$Elevation <- sprintf(
      "The median elevation of the range moves by %.0f m (limited) and %.0f m (unlimited dispersal); the lower edge by %.0f m.",
      stats::median(lim$shift_median), stats::median(unl$shift_median), stats::median(lim$shift_lower)
    )
  }
  if ("ssp" %in% names(r)) {
    by <- tapply(lim$change, lim$ssp, stats::median)
    s$Scenarios <- paste0(names(by), ": ", sprintf("%.0f%%", by), collapse = "; ")
  }
  tmr_interp(s, list(results = r))
}

#' @export
tmr_interpret.tmr_sdm_ensemble <- function(x, ...) {
  sm <- x$summary
  best <- sm[which.max(sm$tss), ]
  grade <- function(a) if (a >= 0.9) "excellent" else if (a >= 0.8) "good" else if (a >= 0.7) "fair" else "poor"
  s <- list(
    Overview = sprintf("Ensemble of %d algorithms from %d presences and %d background or absence points, %s cross-validation.", nrow(sm), x$n_presence, x$n_background, if (x$spatial) "spatial (block)" else "random"),
    Performance = c(
      sprintf("%s: AUC %.2f (%s), TSS %.2f, weight %.0f%%.", sm$algorithm, sm$auc, vapply(sm$auc, grade, ""), sm$tss, 100 * sm$weight),
      sprintf("The best single algorithm is %s (TSS %.2f).", best$algorithm, best$tss),
      "AUC is the chance a presence scores higher than a background point; TSS (sensitivity + specificity - 1) ranges from -1 to 1, with 0 no better than chance.",
      if (!x$spatial) "Random folds overstate accuracy when records are clustered; give coords for spatial folds."
    ),
    `Reading the map` = "Predicted values are relative suitability (presence-only) or probability of occurrence (presence-absence); a threshold turns them into a presence-absence map, which should be stated."
  )
  tmr_interp(s, list(summary = sm))
}

#' @export
tmr_interpret.tmr_sdm_integrated <- function(x, ...) {
  cf <- x$coef[seq_len(x$p_env)]
  se <- x$se[seq_len(x$p_env)]
  z <- cf / se
  s <- list(
    Overview = sprintf("Integrated species distribution model of %d presences%s.", x$n[["presence"]], if (x$has_survey) sprintf(" and %d survey sites", x$n[["survey"]]) else ""),
    Effects = sprintf(
      "%s: coefficient %.2f (SE %.2f): %s.", names(cf), cf, se,
      ifelse(abs(z) < 1.96, "no clear effect", ifelse(cf > 0, "intensity rises with it", "intensity falls with it"))
    ),
    Notes = c(
      if (x$convergence != 0) "The optimiser did not converge: treat the estimates with caution.",
      "Coefficients are on the log scale of intensity: exp(coefficient) is the multiplicative change per unit of the predictor.",
      "Sampling-bias terms absorb uneven recording effort, so the environmental effects describe the species, not the observers."
    )
  )
  tmr_interp(s, list(coefficients = tibble::tibble(term = names(cf), estimate = cf, std_error = se)))
}

#' @export
tmr_interpret.tmr_geo_moran <- function(x, ...) {
  s <- list(
    Result = c(
      sprintf("Moran's I = %.3f (expected %.3f under no autocorrelation), p = %s.", x$statistic, x$expectation, tmr_fp(x$p.value)),
      if (x$p.value < 0.05 && x$statistic > x$expectation) {
        "Nearby sites have more similar values than expected: the pattern is patchy."
      } else if (x$p.value < 0.05) {
        "Nearby sites are more different than expected: a regular, checkerboard pattern."
      } else {
        "No evidence of spatial autocorrelation."
      },
      "For model residuals, autocorrelation means a missing spatial predictor and overconfident p-values."
    )
  )
  tmr_interp(s, list(test = x))
}

#' @export
print.tmr_interpretation <- function(x, ...) {
  cli::cli_h1("tidyvisor: what the results show")
  for (s in names(x$sections)) {
    cli::cli_h2(s)
    for (line in x$sections[[s]]) cli::cli_bullets(c("*" = gsub("([{}])", "\\1\\1", line)))
  }
  invisible(x)
}
# nolint end
