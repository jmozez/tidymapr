#' Ensemble projections of range shifts
#'
#' @description
#' Climate projections differ between climate models (GCMs), emission
#' scenarios (SSPs) and, on mountains, the lapse rate used to bring coarse
#' climate down to the terrain. A single projection hides this
#' uncertainty. These functions run a range-shift model over every member of
#' an ensemble and report the results as probabilities:
#'
#' * `geo_climate_scenarios()` builds the ensemble of climates on a fine
#'   DEM: for each GCM, SSP and lapse rate, the baseline CHELSA climate is
#'   downscaled with [geo_downscale_lapse()] and the change projected by the GCM (future
#'   minus baseline, the delta method) is added, so every member shares the
#'   observed baseline.
#' * `geo_shift_ensemble()` predicts suitability for the present and every
#'   member with a niche model (such as [sdm_integrated()]), simulates
#'   colonisation and extinction with [geo_shift_simulate()], and also
#'   reports the unlimited-dispersal (suitability-only) range for
#'   comparison.
#' * `summary()` gives, per scenario and dispersal assumption, the median
#'   and range of the change in range area across members, and the
#'   probability that the range shrinks by more than set thresholds.
#'
#' @param area,dem Area to read and fine elevation `SpatRaster` (metres).
#' @param variables CHELSA temperature variables to downscale (e.g.
#'   `"bio1"`, `"bio5"`); others (e.g. `"bio12"`) are only resampled.
#' @param period Future period (see [geo_chelsa_area()]).
#' @param gcm,ssp GCMs and scenarios.
#' @param lapse_rates Lapse rates (degrees C per km) to try.
#' @param temperature Which of `variables` are temperatures (downscaled
#'   with the lapse rate); default bio1 to bio11 (the temperature variables).
#' @param reader Function used to read CHELSA (for testing).
#' @return `geo_climate_scenarios()`: a named list with `current` (a
#'   `SpatRaster` per lapse rate, in list `current`) and `members`, a named
#'   list of `SpatRaster`s, one per GCM x SSP x lapse rate, with layers
#'   named after `variables`; and a tibble `design` of the members.
#' @name geo-shift-ensemble
#' @seealso [geo_shift_simulate()], [sdm_integrated()], [geo_chelsa_area()].
NULL

#' @rdname geo-shift-ensemble
#' @export
geo_climate_scenarios <- function(area,
                                  dem,
                                  variables = "bio1",
                                  period = "2071-2100",
                                  gcm = c("mpi-esm1-2-hr", "ukesm1-0-ll"),
                                  ssp = c("ssp126", "ssp585"),
                                  lapse_rates = 5,
                                  temperature = grep("^bio([1-9]|1[01])$", variables, value = TRUE),
                                  reader = geo_chelsa_area) {
  rlang::check_installed("terra")
  z <- geo_as_raster(dem)[[1]][[1]]
  base <- reader(area, variables, "1981-2010")
  names(base) <- variables
  design <- expand.grid(gcm = gcm, ssp = ssp, lapse_rate = lapse_rates, stringsAsFactors = FALSE)
  futs <- list()
  for (g in gcm) {
    for (s in ssp) {
      f <- reader(area, variables, period, gcm = g, ssp = s)
      names(f) <- variables
      futs[[paste(g, s)]] <- f - base
    }
  }
  fine_base <- function(lr) {
    layers <- lapply(variables, function(v) {
      if (v %in% temperature) {
        geo_downscale_lapse(base[[v]], z, lapse_rate = lr)
      } else {
        terra::resample(base[[v]], z, method = "bilinear")
      }
    })
    out <- terra::rast(layers)
    names(out) <- variables
    out
  }
  current <- lapply(lapse_rates, fine_base)
  names(current) <- paste0("lapse_", lapse_rates)
  members <- lapply(seq_len(nrow(design)), function(i) {
    cb <- current[[paste0("lapse_", design$lapse_rate[i])]]
    delta <- terra::resample(futs[[paste(design$gcm[i], design$ssp[i])]], z, method = "bilinear")
    out <- cb + delta
    names(out) <- variables
    out
  })
  design$member <- paste(design$gcm, design$ssp, paste0("lapse", design$lapse_rate), sep = "_")
  names(members) <- design$member
  list(current = current, members = members, design = tibble::as_tibble(design), period = period)
}

#' @rdname geo-shift-ensemble
#' @param model A niche model with a `predict()` method returning the
#'   probability of presence for a `SpatRaster` of covariates (such as
#'   [sdm_integrated()]), or a function taking a `SpatRaster` and returning
#'   one of suitability (0 to 1).
#' @param scenarios Result of `geo_climate_scenarios()`, or a list with
#'   `current` (one `SpatRaster`, or one per lapse rate) and `members` (a
#'   named list of `SpatRaster`s) and optionally `design`.
#' @param initial Initial occupancy, as in [geo_shift_simulate()]; by
#'   default the present suitability above 0.5.
#' @param dispersal_mean,steps,nsim,seed,... Passed to
#'   [geo_shift_simulate()]; `steps` is the number of dispersal generations
#'   between the present and the future period.
#' @param elevation Optional elevation `SpatRaster` for range edges.
#' @return `geo_shift_ensemble()`: an object of class `tmr_shift_ensemble`
#'   with `results`, a tibble with one row per member and dispersal
#'   assumption (`"limited"`, `"unlimited"`): `member`, `gcm`, `ssp`,
#'   `lapse_rate`, `dispersal`, `area_now`, `area_future`, `change` (%) and,
#'   with `elevation`, the shift of the lower edge, median and upper edge
#'   (m); and `occupancy`, the future occupancy (or suitability) rasters.
#' @export
geo_shift_ensemble <- function(model,
                               scenarios,
                               initial = 0.5,
                               dispersal_mean,
                               steps = 10,
                               nsim = 50,
                               seed = NULL,
                               elevation = NULL,
                               ...) {
  rlang::check_installed("terra")
  pred <- if (is.function(model)) model else function(x) stats::predict(model, x)
  current <- scenarios$current
  if (inherits(current, "SpatRaster")) current <- list(current)
  members <- scenarios$members
  if (!length(members) || is.null(names(members))) {
    cli::cli_abort("{.arg scenarios} needs a named list {.field members}.")
  }
  design <- scenarios$design %||% tibble::tibble(
    member = names(members), gcm = NA_character_, ssp = NA_character_,
    lapse_rate = NA_real_
  )
  pick_current <- function(i) {
    if (length(current) == 1) {
      return(current[[1]])
    }
    current[[paste0("lapse_", design$lapse_rate[i])]]
  }
  seed <- seed %||% sample.int(.Machine$integer.max, 1)
  rows <- list()
  occ <- list()
  for (i in seq_along(members)) {
    s_now <- pred(pick_current(i))
    s_fut <- pred(members[[i]])
    suit <- c(s_now, s_fut)
    names(suit) <- c("now", "future")
    sim <- geo_shift_simulate(suit,
      initial = initial, dispersal_mean = dispersal_mean,
      steps_per_layer = steps, nsim = nsim, seed = seed + i, ...
    )
    lim <- geo_shift_summary(sim, elevation)
    unl <- geo_shift_summary(suit, elevation)
    for (k in c("limited", "unlimited")) {
      s <- if (k == "limited") lim else unl
      row <- tibble::tibble(
        member = design$member[i], gcm = design$gcm[i], ssp = design$ssp[i],
        lapse_rate = design$lapse_rate[i], dispersal = k,
        area_now = s$area_km2[1], area_future = s$area_km2[2],
        change = 100 * (s$area_km2[2] - s$area_km2[1]) / s$area_km2[1]
      )
      if (!is.null(elevation)) {
        row$shift_lower <- s$lower[2] - s$lower[1]
        row$shift_median <- s$median[2] - s$median[1]
        row$shift_upper <- s$upper[2] - s$upper[1]
      }
      rows[[length(rows) + 1]] <- row
    }
    o <- c(sim[[2]], s_fut)
    names(o) <- c("limited", "unlimited")
    occ[[design$member[i]]] <- o
  }
  structure(
    list(results = vctrs::vec_rbind(!!!rows), occupancy = occ, seed = seed),
    class = "tmr_shift_ensemble"
  )
}

#' @rdname geo-shift-ensemble
#' @param object A `geo_shift_ensemble()` result.
#' @param loss Range-loss thresholds (%) for the probabilities.
#' @return `summary()`: a tibble per `ssp` (if known) and `dispersal`:
#'   number of members, median, minimum and maximum change (%), and
#'   `p_loss_<x>`, the share of members losing more than x% of the range.
#' @export
summary.tmr_shift_ensemble <- function(object, loss = c(30, 50, 80), ...) {
  r <- object$results
  key <- if (all(is.na(r$ssp))) "dispersal" else c("ssp", "dispersal")
  groups <- split(r, r[key], drop = TRUE)
  out <- lapply(groups, function(g) {
    row <- tibble::tibble(
      !!!as.list(g[1, key]),
      members = nrow(g),
      median_change = stats::median(g$change),
      min_change = min(g$change), max_change = max(g$change)
    )
    for (l in loss) row[[paste0("p_loss_", l)]] <- mean(g$change < -l)
    row
  })
  vctrs::vec_rbind(!!!out)
}

#' @export
print.tmr_shift_ensemble <- function(x, ...) {
  cli::cli_text(
    "Range-shift ensemble: {length(x$occupancy)} member{?s}, limited and unlimited dispersal"
  )
  print(summary(x))
  invisible(x)
}
