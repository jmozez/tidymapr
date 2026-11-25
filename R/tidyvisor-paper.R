# "After the overall test" and "For the paper" for tidymapr's results, as
# tidyvisor gives them for tests and models: what to do after the result
# (and what not to), and how to report it in a publication (a sentence, the
# figure or map, the table and the Methods).
# nolint start: line_length_linter. Advice strings read better unbroken.

tmr_map_rules <- "Map style for journals: state the coordinate reference system; add a scale bar and a north arrow (annotation_scale_bar(), annotation_north_arrow()); a colour-blind-safe palette (viridis) with the units in the legend; an inset locating the study area if it is not obvious; the full page width (about 180 mm) for maps, text at least 8 pt; vector PDF, or 600 dpi for raster layers."

tmr_save <- function(what = "p", height = 140) sprintf('geo_save(%s, "figure1.pdf", width = 180, height = %d)   # full page width, in mm', what, height)

tmr_rv <- function() paste(R.version$major, R.version$minor, sep = ".")

tmr_after <- function(x) {
  if (inherits(x, "tmr_geo_moran")) {
    if (x$p.value < 0.05) {
      return(c(
        "The test shows that the values are autocorrelated, not over which distances. Follow up with a correlogram, which tests Moran's I in distance classes (geo_moran(..., correlogram = TRUE)); the p-values of the classes are many tests, so adjust them (Holm) or read the correlogram as a description.",
        "If these are model residuals, add the missing spatial structure (a spatial predictor, spatial eigenvectors with geo_mem(), or a spatial random effect) and test the residuals again."
      ))
    }
    return("No evidence of autocorrelation: do not go on to search distance classes for one that is significant, which is a search for something significant. Report the test with its weights and number of permutations.")
  }
  if (inherits(x, "tmr_epi_growth")) {
    r <- x$estimates[x$estimates$quantity == "growth_rate", ]
    if (r$lower <= 0 && r$upper >= 0) {
      return("The interval of the growth rate includes zero: do not report a doubling time or an R, which would describe growth the data do not show. Report the rate with its interval, and collect more weeks of counts.")
    }
    return("To compare growth between places or periods, fit each and compare the rates with their intervals, or fit one model with an interaction of time and place; do not compare doubling times by eye.")
  }
  if (inherits(x, "tmr_spread_rate")) {
    e <- x$estimate
    if (e$lower <= 0) return("The interval of the rate includes zero: do not report a rate of spread as established. Report it with its interval, and check that recording effort is even over the years.")
    return("To ask whether spread has sped up or slowed down, fit the rate in two periods (or a breakpoint model) and compare the rates with their intervals.")
  }
  if (inherits(x, "tmr_sdm_integrated")) {
    z <- x$coef[seq_len(x$p_env)] / x$se[seq_len(x$p_env)]
    return(c(
      if (any(abs(z) >= 1.96)) "For the predictors with clear effects, plot the response curve of intensity against each one, holding the others at their means.",
      "Do not drop the predictors without clear effects and refit until everything is significant: report the model chosen before seeing the data, and compare alternatives with AIC if needed."
    ))
  }
  NULL
}

tmr_paper <- function(x) {
  lvl <- function(z) round(100 * (z$settings$level %||% 0.95))
  if (inherits(x, "tmr_epi_growth")) {
    e <- x$estimates
    r <- e[e$quantity == "growth_rate", ]
    d <- e[e$quantity == "doubling_time", ]
    rr <- e[e$quantity == "reproduction_number", ]
    u <- x$settings$unit
    return(c(
      sprintf("Results: 'Cases grew by %.1f%% per %s (growth rate r = %.3f, %d%% CI %.3f to %.3f)%s%s.'", 100 * (exp(r$estimate) - 1), u, r$estimate, lvl(x), r$lower, r$upper,
              if (nrow(d) && r$lower > 0) sprintf(", doubling every %.1f %ss (%.1f to %.1f)", d$estimate, u, d$lower, d$upper) else "",
              if (nrow(rr)) sprintf("; the reproduction number was %.2f (%.2f to %.2f)", rr$estimate, rr$lower, rr$upper) else ""),
      "Figure: the counts with the fitted curve and its confidence band, on a log scale:",
      "p <- plot(g)", tmr_save("p", 100),
      "Table: the growth rate, doubling time and R, each with its interval.",
      sprintf("Methods: the %s model, the window of exponential growth and how it was chosen, the generation interval (mean and SD) and its source for R (Wallinga and Lipsitch 2007), and the software (R %s; citation(\"tidymapr\")).", if (x$settings$family == "negbin") "negative binomial" else "Poisson", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_spread_rate")) {
    e <- x$estimate
    return(c(
      sprintf("Results: 'The range expanded by %.1f km per year (%d%% CI %.1f to %.1f; R\u00b2 = %.2f; %d years, %s method).'", e$rate_km_per_year, lvl(x), e$lower, e$upper, e$r_squared, e$n, e$method),
      "Figure: the distance from the origin against year with the fitted rate, beside a map of the records coloured by year:",
      "p <- plot(s)", tmr_save("p", 100), tmr_map_rules,
      "Table: the rate with its interval, R-squared and the number of years, for each method if more than one is used.",
      sprintf("Methods: the method (first record, front or area), the origin and how it was chosen, the source of the records and how recording effort changed, and the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_epidemic")) {
    st <- x$settings
    pk <- x$curve[which.max(x$curve$infected), ]
    return(c(
      sprintf("Results: 'In %d simulations (R0 = %.2f, %s dispersal kernel with a mean of %.1f km), infections peaked at time %d and %.1f%% of hosts were infected.'", st$nsim, st$R0, st$kernel, st$dispersal_mean, pk$time, 100 * x$attack),
      "Figure: the epidemic curve, and maps of prevalence and of the share of runs reaching each cell:",
      "p <- ggplot2::ggplot(sim$curve, ggplot2::aes(time, infected)) + ggplot2::geom_line() + ggplot2::theme_classic(base_size = 9)",
      tmr_save("p", 80), tmr_map_rules,
      "Table: every parameter (transmission, recovery, dispersal kernel and mean, host density) with its value and source, and the outputs (peak, attack rate) across runs.",
      sprintf("Methods: the model (spatial SIR on a grid), each parameter and its source, the number of runs and the seed, and a sensitivity analysis of the parameters least known; the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_shift_ensemble")) {
    r <- x$results
    lim <- r[r$dispersal == "limited", ]
    return(c(
      sprintf("Results: 'Across %d ensemble members, the range was projected to change by %.0f%% with limited dispersal (median; %.0f%% to %.0f%%) and by %.0f%% with unlimited dispersal; %d of %d members projected a loss.'", nrow(lim), stats::median(lim$change), min(lim$change), max(lim$change), stats::median(r$change[r$dispersal == "unlimited"]), sum(lim$change < 0), nrow(lim)),
      "Report the spread across climate models and scenarios, not only the median: it is the uncertainty of the projection.",
      "Figure: a map of agreement (the share of members predicting presence) for each scenario, and the change in range by scenario and dispersal:",
      sprintf("p <- ggplot2::ggplot(ens$results, ggplot2::aes(%s, change, fill = dispersal)) + ggplot2::geom_boxplot() + ggplot2::labs(y = \"Change in range (%%)\") + ggplot2::scale_fill_viridis_d() + ggplot2::theme_classic(base_size = 9)", if ("ssp" %in% names(r)) "ssp" else "dispersal"),
      tmr_save("p", 100), tmr_map_rules,
      "Table: the change in range (and elevation) for each climate model, scenario and period.",
      sprintf("Methods: the climate data and version (CHELSA or WorldClim, cited), the climate models, scenarios and periods, the lapse rates, the dispersal assumptions, and the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_sdm_ensemble")) {
    sm <- x$summary
    return(c(
      sprintf("Results: 'The ensemble of %d algorithms predicted the distribution well under %s cross-validation (AUC %.2f to %.2f; TSS %.2f to %.2f).'", nrow(sm), if (x$spatial) "spatial block" else "random", min(sm$auc), max(sm$auc), min(sm$tss), max(sm$tss)),
      "Figure: the map of predicted suitability (and the thresholded map, with the threshold stated), and the response curve of each important predictor.",
      tmr_save("p"), tmr_map_rules,
      "Table: each algorithm with its AUC, TSS and ensemble weight, and the importance of each predictor.",
      sprintf("Methods: follow the ODMAP protocol (Zurell et al. 2020): the occurrence data and cleaning, the background or absence points, the predictors and why, the algorithms and settings, the cross-validation, the threshold, and the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_sdm_integrated")) {
    cf <- x$coef[seq_len(x$p_env)]
    se <- x$se[seq_len(x$p_env)]
    k <- which.max(abs(cf / se))
    return(c(
      sprintf("Results: 'Intensity was %.2f times as high per unit of %s (coefficient %.2f, SE %.2f).'", exp(cf[k]), names(cf)[k], cf[k], se[k]),
      "Report every predictor with its coefficient, SE and exp(coefficient), and say which terms model the sampling bias.",
      "Figure: the map of predicted intensity, and the response curve of each predictor.",
      tmr_save("p"), tmr_map_rules,
      "Table: each environmental and bias term with its coefficient, SE and exp(coefficient).",
      sprintf("Methods: the data sets combined and how each enters the likelihood, the bias covariates, the predictors, and the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  if (inherits(x, "tmr_geo_moran")) {
    return(c(
      sprintf("Results: 'Values were %sspatially autocorrelated (Moran's I = %.3f, expected %.3f, p = %s, %d permutations).'", if (x$p.value < 0.05) "" else "not detectably ", x$statistic, x$expectation, tmr_fp(x$p.value), x$nperm %||% 999L),
      "Figure: a map of the values in classes beside the correlogram (Moran's I against distance class).",
      tmr_save("p", 90), tmr_map_rules,
      sprintf("Methods: the spatial weights (inverse distance) and any distance cut-off, the number of permutations, and the software (R %s; citation(\"tidymapr\")).", tmr_rv())
    ))
  }
  NULL
}
# nolint end
