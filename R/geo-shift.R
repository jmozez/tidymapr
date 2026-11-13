#' Simulate range shifts with dispersal and colonisation-extinction dynamics
#'
#' @description
#' `geo_shift_simulate()` projects where a species can actually be, not
#' only where the climate suits it. Correlative niche models assume that a
#' species fills all suitable habitat at once; real species colonise new
#' habitat at the speed of their dispersal and lose populations where
#' conditions deteriorate, often with a lag. This function runs a spatially
#' explicit, stochastic colonisation-extinction model (a stochastic patch
#' occupancy model on a grid; Hanski 1999; Engler and Guisan 2009) over a
#' time series of habitat suitability, such as the output of a species
#' distribution model projected onto successive climate periods.
#'
#' In each step, an empty cell \eqn{j} is colonised with probability
#' \deqn{1 - \exp(-c \, s_j \sum_i K(d_{ij})),}{1 - exp(-c s_j sum_i K(d_ij)),}
#' where the sum runs over occupied cells \eqn{i} and \eqn{K} is the
#' dispersal kernel, truncated at `max_distance` and normalised to sum to 1
#' over the neighbourhood (so the sum is the kernel-weighted share of
#' occupied neighbours, and results do not depend on the cell size). Two
#' kernels are offered, both parameterised by their mean dispersal
#' distance \eqn{\bar d} in two dimensions:
#' * `"exponential"`: \eqn{K(d) \propto e^{-2d/\bar d}};
#' * `"2Dt"` (Clark et al. 1999): \eqn{K(d) \propto (1 + d^2/u)^{-(p+1)}},
#'   fat-tailed, so rare long-distance dispersal is far more likely than
#'   under the exponential; smaller `kernel_shape` (\eqn{p > 0.5}) gives a
#'   fatter tail. Use [geo_dispersal_kernel()] to see a kernel's realised
#'   mean and tail.
#'
#' Optional processes:
#' * `resistance`: movement costs. The distance is replaced by an
#'   effective distance, the straight-line distance times the mean
#'   resistance of the cells crossed (1 = baseline, 5 = five times harder,
#'   below 1 = corridor; `NA`, 0 or `Inf` = impassable barrier). This is a
#'   local, straight-line approximation, not a least-cost path.
#' * `jump_rate` and `jump_weights`: human-assisted or other long-distance
#'   jumps. Each step, a Poisson number of propagules with mean
#'   `jump_rate` times the number of occupied cells lands on cells chosen
#'   in proportion to `jump_weights` (for example road density, ports or
#'   towns), and establishes with probability equal to suitability.
#' * `disturbance`: the probability, per step, that an occupied cell is
#'   lost to clearing, fire or eradication, on top of the climate.
#'
#' \eqn{s_j} is the suitability
#' of the cell and \eqn{c} the colonisation rate. An occupied cell
#' persists with probability \eqn{s_j^p}. Cell sizes come from the grid's
#' true geometry, so the kernel is isotropic in metres on longitude/latitude
#' grids. Simulations run in parallel in C++ with independent random
#' streams; results depend on `seed` but not on the number of threads.
#'
#' The result is the probability that each cell is occupied at the end of
#' each period, over `nsim` simulations. Compare it with the suitability
#' itself (unlimited dispersal) to see the dispersal lag, the extinction
#' debt and whether a species can cross gaps in habitat.
#'
#' @param suitability A `SpatRaster` with one layer per time period
#'   (values 0 to 1; `NA` or negative values are unsuitable, e.g. sea).
#' @param initial Starting occupancy: a `SpatRaster` (cells > 0 occupied),
#'   an `sf` table of occurrence points, or a number, the suitability
#'   threshold applied to the first layer.
#' @param dispersal_mean Mean dispersal distance per step, in metres.
#' @param max_distance Largest dispersal distance in metres (kernel
#'   truncation); default five times the mean for the exponential kernel
#'   and ten times for the 2Dt kernel.
#' @param kernel `"exponential"` or `"2Dt"` (fat-tailed).
#' @param kernel_shape Shape \eqn{p} of the 2Dt kernel (above 0.5; smaller
#'   is fatter-tailed).
#' @param resistance Optional `SpatRaster` of movement resistance (1 =
#'   baseline; `NA`, 0 or `Inf` = barrier).
#' @param jump_rate Expected number of long-distance jumps per occupied cell
#'   per step (default 0, none).
#' @param jump_weights Optional `SpatRaster` of relative weights of jump
#'   destinations; default all cells equally.
#' @param disturbance Optional `SpatRaster` of the probability that an
#'   occupied cell is lost per step: one layer, or one per layer of
#'   `suitability`.
#' @param colonisation Colonisation rate \eqn{c}.
#' @param persistence Exponent \eqn{p} of local persistence; larger values
#'   make populations in marginal habitat more likely to disappear.
#' @param steps_per_layer Number of dispersal generations within each
#'   period (for example 10 for ten-year periods and a species that
#'   disperses once a year).
#' @param nsim Number of stochastic simulations.
#' @param seed Random seed.
#' @param threads Number of threads (0 = OpenMP default).
#' @return `geo_shift_simulate()`: a `SpatRaster` of occupancy
#'   probability, one layer per period, named after the layers of
#'   `suitability`, with the settings as attribute `"settings"`.
#' @references
#' Engler, R. and Guisan, A. (2009). MigClim: predicting plant distribution
#' and dispersal in a changing climate. Diversity and Distributions, 15,
#' 590-601.
#'
#' Hanski, I. (1999). Metapopulation Ecology. Oxford University Press.
#'
#' Clark, J. S., Silman, M., Kern, R., Macklin, E. and HilleRisLambers, J.
#' (1999). Seed dispersal near and far: patterns across temperate and
#' tropical forests. Ecology, 80, 1475-1494.
#' @seealso [geo_dispersal_kernel()], [geo_epidemic_simulate()],
#'   [geo_shift_summary()], [sdm_ensemble()], [geo_range_shift()].
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   # A virtual mountain: suitability is a band that moves upslope
#'   r <- terra::rast(
#'     nrows = 40, ncols = 40, xmin = 145, xmax = 145.4,
#'     ymin = -6.4, ymax = -6, crs = "EPSG:4326"
#'   )
#'   elev <- terra::init(r, "y")
#'   elev <- (elev - min(terra::values(elev))) * 10000
#'   band <- function(mid) exp(-((elev - mid) / 400)^2)
#'   suit <- c(band(1000), band(1400), band(1800))
#'   names(suit) <- c("2000", "2050", "2100")
#'   occ <- geo_shift_simulate(suit, 0.5, dispersal_mean = 2000, nsim = 20, seed = 1)
#'   geo_shift_summary(occ, elevation = elev)
#' }
#' }
geo_shift_simulate <- function(suitability,
                               initial = 0.5,
                               dispersal_mean,
                               max_distance = NULL,
                               colonisation = 1,
                               persistence = 1,
                               steps_per_layer = 1,
                               nsim = 100,
                               seed = NULL,
                               threads = 0,
                               kernel = c("exponential", "2Dt"),
                               kernel_shape = 1,
                               resistance = NULL,
                               jump_rate = 0,
                               jump_weights = NULL,
                               disturbance = NULL) {
  rlang::check_installed("terra")
  s <- geo_as_raster(suitability)[[1]]
  k <- tmr_kernel_args(dispersal_mean, max_distance, kernel, kernel_shape)
  tmr_chk_num(colonisation, "colonisation")
  tmr_chk_num(persistence, "persistence")
  tmr_chk_num(steps_per_layer, "steps_per_layer", 1)
  tmr_chk_num(nsim, "nsim", 1)
  tmr_chk_num(jump_rate, "jump_rate")
  seed <- seed %||% sample.int(.Machine$integer.max, 1)
  vals <- terra::values(s, mat = TRUE)
  if (any(vals > 1, na.rm = TRUE)) {
    cli::cli_abort("{.arg suitability} must lie between 0 and 1.")
  }
  vals[is.na(vals)] <- -1
  init <- tmr_shift_initial(initial, s)
  geom <- tmr_cell_dims(s)
  res <- tmr_layer_values(resistance, s, "resistance", na = 0)
  dist <- if (is.null(disturbance)) {
    matrix(0, 0, 0)
  } else {
    d <- geo_as_raster(disturbance)[[1]]
    if (!terra::compareGeom(d, s, stopOnError = FALSE)) {
      d <- terra::resample(d, s, method = "bilinear")
    }
    if (terra::nlyr(d) == 1) d <- rep(d, terra::nlyr(s))
    if (terra::nlyr(d) != terra::nlyr(s)) {
      cli::cli_abort("{.arg disturbance} needs one layer or one per layer of {.arg suitability}.")
    }
    m <- terra::values(d, mat = TRUE)
    if (any(m < 0 | m > 1, na.rm = TRUE)) {
      cli::cli_abort("{.arg disturbance} must be probabilities between 0 and 1.")
    }
    m[is.na(m)] <- 0
    m
  }
  jw <- if (jump_rate > 0) {
    if (is.null(jump_weights)) {
      rep(1, terra::ncell(s))
    } else {
      tmr_layer_values(jump_weights, s, "jump_weights", na = 0)
    }
  } else {
    numeric(0)
  }
  p <- shift_simulate_cpp(
    vals, as.integer(init), terra::nrow(s), terra::ncol(s), geom$width,
    geom$height, k$type, dispersal_mean, kernel_shape, k$max_distance,
    colonisation, persistence, as.integer(steps_per_layer), as.integer(nsim),
    as.numeric(seed), as.integer(threads), res, dist, jump_rate, jw
  )
  out <- terra::rast(s)
  terra::values(out) <- p
  out <- terra::mask(out, s)
  names(out) <- names(s)
  attr(out, "settings") <- list(
    dispersal_mean = dispersal_mean, max_distance = k$max_distance,
    kernel = k$kernel, kernel_shape = kernel_shape,
    colonisation = colonisation, persistence = persistence,
    steps_per_layer = steps_per_layer, nsim = nsim, seed = seed,
    resistance = !is.null(resistance), jump_rate = jump_rate,
    disturbance = !is.null(disturbance)
  )
  out
}

#' @rdname geo_shift_simulate
#' @param occupancy Result of `geo_shift_simulate()` (or a suitability
#'   raster, for comparison).
#' @param elevation Optional elevation `SpatRaster` on the same grid; adds
#'   the occupancy-weighted 5%, 50% and 95% elevations (lower edge,
#'   centre and upper edge).
#' @return `geo_shift_summary()`: a tibble with one row per period:
#'   `period`, `area_km2` (expected occupied area), and with `elevation`,
#'   `lower`, `median` and `upper`.
#' @export
geo_shift_summary <- function(occupancy, elevation = NULL) {
  rlang::check_installed("terra")
  o <- geo_as_raster(occupancy)[[1]]
  a <- terra::values(terra::cellSize(o[[1]], unit = "km", mask = FALSE), mat = FALSE)
  v <- terra::values(o, mat = TRUE)
  out <- tibble::tibble(
    period = names(o),
    area_km2 = colSums(v * a, na.rm = TRUE)
  )
  if (!is.null(elevation)) {
    e <- terra::values(geo_as_raster(elevation)[[1]][[1]], mat = FALSE)
    q <- t(apply(v, 2, function(w) {
      w <- w * a
      ok <- !is.na(w) & !is.na(e) & w > 0
      if (!any(ok)) {
        return(c(NA_real_, NA_real_, NA_real_))
      }
      tmr_wquantile(e[ok], w[ok], c(0.05, 0.5, 0.95))
    }))
    out$lower <- q[, 1]
    out$median <- q[, 2]
    out$upper <- q[, 3]
  }
  out
}

tmr_wquantile <- function(x, w, probs) {
  o <- order(x)
  x <- x[o]
  cw <- cumsum(w[o]) / sum(w)
  vapply(probs, function(p) x[which(cw >= p)[1]], numeric(1))
}

# Cell width (per row) and height in metres
tmr_cell_dims <- function(r) {
  if (isTRUE(suppressWarnings(terra::is.lonlat(r)))) {
    y <- terra::yFromRow(r, seq_len(terra::nrow(r)))
    rad <- pi / 180
    # WGS84 lengths of one degree of longitude and latitude
    a <- 6378137
    e2 <- 0.00669437999014
    phi <- y * rad
    den <- sqrt(1 - e2 * sin(phi)^2)
    lon_m <- rad * a * cos(phi) / den
    lat_m <- rad * a * (1 - e2) / den^3
    list(
      width = lon_m * terra::res(r)[1],
      height = mean(lat_m) * terra::res(r)[2]
    )
  } else {
    list(width = rep(terra::res(r)[1], terra::nrow(r)), height = terra::res(r)[2])
  }
}

tmr_shift_initial <- function(initial, s, call = caller_env()) {
  if (is.numeric(initial) && length(initial) == 1) {
    v <- terra::values(s[[1]], mat = FALSE)
    return(!is.na(v) & v >= initial)
  }
  if (inherits(initial, "SpatRaster")) {
    i <- initial[[1]]
    if (!terra::compareGeom(i, s, stopOnError = FALSE)) {
      i <- terra::resample(i, s, method = "near")
    }
    v <- terra::values(i, mat = FALSE)
    return(!is.na(v) & v > 0)
  }
  if (inherits(initial, "sf") || inherits(initial, "SpatVector")) {
    v <- geo_raster_vect(initial, s, call = call)
    cells <- terra::cells(s[[1]], v)[, "cell"]
    out <- rep(FALSE, terra::ncell(s))
    out[cells[!is.na(cells)]] <- TRUE
    return(out)
  }
  cli::cli_abort(
    "{.arg initial} must be a raster, occurrence points or a suitability threshold.",
    call = call
  )
}

tmr_chk_num <- function(x, nm, lower = 0, call = caller_env()) {
  if (!is.numeric(x) || length(x) != 1 || is.na(x) || x < lower) {
    cli::cli_abort("{.arg {nm}} must be one number of at least {lower}.", call = call)
  }
}

tmr_kernel_args <- function(dispersal_mean, max_distance, kernel, kernel_shape,
                            call = caller_env()) {
  kernel <- rlang::arg_match(kernel, c("exponential", "2Dt"), error_call = call)
  tmr_chk_num(dispersal_mean, "dispersal_mean", 1e-9, call = call)
  bad_shape <- !is.numeric(kernel_shape) || length(kernel_shape) != 1 ||
    is.na(kernel_shape) || kernel_shape <= 0.5
  if (kernel == "2Dt" && bad_shape) {
    cli::cli_abort("{.arg kernel_shape} must be one number above 0.5.", call = call)
  }
  max_distance <- max_distance %||% ((if (kernel == "2Dt") 10 else 5) * dispersal_mean)
  tmr_chk_num(max_distance, "max_distance", 0, call = call)
  list(kernel = kernel, type = if (kernel == "2Dt") 1L else 0L, max_distance = max_distance)
}

# Values of an optional single-layer raster on the grid of s
tmr_layer_values <- function(x, s, nm, na = 0, call = caller_env()) {
  if (is.null(x)) {
    return(numeric(0))
  }
  r <- geo_as_raster(x)[[1]][[1]]
  if (!terra::compareGeom(r, s, stopOnError = FALSE)) {
    r <- terra::resample(r, s, method = "bilinear")
  }
  v <- terra::values(r, mat = FALSE)
  if (any(v < 0, na.rm = TRUE)) {
    cli::cli_abort("{.arg {nm}} must not be negative.", call = call)
  }
  v[is.na(v)] <- na
  v
}
