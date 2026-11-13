#' Dispersal kernels
#'
#' `geo_dispersal_kernel()` describes the dispersal kernel used by
#' [geo_shift_simulate()] and [geo_epidemic_simulate()] on a grid of a
#' given cell size: its realised mean distance (after truncation at
#' `max_distance` and discretisation on the grid), the share of dispersal
#' beyond five times the mean (the long-distance tail), and the number of neighbouring cells
#' it reaches. Use it to choose between the exponential and the
#' fat-tailed 2Dt kernel and to check that the grid resolves the kernel
#' (cells much smaller than the mean distance).
#'
#' @inheritParams geo_shift_simulate
#' @param cell_size Cell size in metres.
#' @return A one-row tibble: `kernel`, `kernel_shape`, `dispersal_mean`,
#'   `max_distance`, `realised_mean`, `share_beyond_5mean`, `neighbours`.
#' @export
#' @examples
#' geo_dispersal_kernel(500, cell_size = 50)
#' geo_dispersal_kernel(500, cell_size = 50, kernel = "2Dt", kernel_shape = 1)
geo_dispersal_kernel <- function(dispersal_mean,
                                 cell_size,
                                 kernel = c("exponential", "2Dt"),
                                 kernel_shape = 1,
                                 max_distance = NULL) {
  k <- tmr_kernel_args(dispersal_mean, max_distance, kernel, kernel_shape)
  tmr_chk_num(cell_size, "cell_size", 1e-9)
  info <- kernel_info_cpp(
    1L, cell_size, cell_size, k$type, dispersal_mean,
    kernel_shape, k$max_distance
  )
  tibble::tibble(
    kernel = k$kernel, kernel_shape = if (k$kernel == "2Dt") kernel_shape else NA_real_,
    dispersal_mean = dispersal_mean, max_distance = k$max_distance,
    realised_mean = info$realised_mean, share_beyond_5mean = info$share_beyond_5mean,
    neighbours = info$n_neighbours
  )
}

#' Simulate the spread of a disease across a landscape
#'
#' @description
#' `geo_epidemic_simulate()` runs a stochastic, spatially explicit SIR
#' (susceptible-infected-recovered) model on a grid of host populations,
#' for example a wildlife disease such as chytridiomycosis in frogs, a
#' plant pathogen in a forest, or an outbreak among villages. Each cell
#' holds `hosts` individuals. In each time step a susceptible host in cell
#' \eqn{j} is infected with probability \eqn{1 - e^{-\lambda_j}},
#' \deqn{\lambda_j = \beta \left[(1 - m) \frac{I_j}{N_j} + m \sum_i K(d_{ij})
#' \frac{I_i}{N_i}\right],}{lambda_j = beta [(1 - m) I_j / N_j + m sum_i K(d_ij) I_i / N_i],}
#' where \eqn{\beta} is the transmission rate, \eqn{m} the share of
#' contacts made outside the home cell (`coupling`) and \eqn{K} the
#' normalised dispersal kernel of [geo_shift_simulate()] (exponential or
#' fat-tailed 2Dt, with optional resistance). Infected hosts recover with
#' probability \eqn{1 - e^{-\gamma}} per step, and recovered hosts lose
#' immunity with probability \eqn{1 - e^{-\omega}} (`omega = 0`: lasting
#' immunity). Time runs in discrete steps, so an infected host stays
#' infectious for \eqn{1 / (1 - e^{-\gamma})} steps on average (close to
#' \eqn{1/\gamma} when \eqn{\gamma} is small), and in a single well-mixed
#' population the basic reproduction number is
#' \eqn{R_0 = \beta / (1 - e^{-\gamma})}. The expected final share
#' infected \eqn{z} then solves \eqn{z = 1 - e^{-R_0 z}}; the tests check
#' the simulation against this.
#'
#' @inheritParams geo_shift_simulate
#' @param hosts `SpatRaster` of the number of hosts per cell (rounded to
#'   whole numbers; `NA` or 0 = no hosts).
#' @param initial Initially infected hosts: a `SpatRaster` of counts, or an
#'   `sf`/`SpatVector` of points, each infecting `initial_count` hosts in
#'   its cell.
#' @param initial_count Hosts infected at each starting point.
#' @param beta Transmission rate per time step.
#' @param gamma Recovery rate per time step (mean infectious period
#'   \eqn{1 / (1 - e^{-\gamma})} steps).
#' @param omega Rate of loss of immunity per step (0 = lasting immunity).
#' @param coupling Share of contacts outside the home cell, 0 to 1.
#' @param dispersal_mean Mean distance of contacts outside the cell, in
#'   metres.
#' @param times Time steps at which to record the maps (increasing
#'   integers).
#' @return A list of class `tmr_epidemic`:
#'   * `prevalence`: `SpatRaster`, mean share of hosts infected at each of
#'     `times`;
#'   * `reached`: `SpatRaster`, probability that the disease has reached
#'     each cell by each of `times`;
#'   * `curve`: tibble of `time` and mean number `infected` per step;
#'   * `attack`: share of all hosts ever infected, per simulation;
#'   * `settings`.
#' @references
#' Keeling, M. J. and Rohani, P. (2008). Modeling Infectious Diseases in
#' Humans and Animals. Princeton University Press.
#' @seealso [geo_shift_simulate()], [geo_dispersal_kernel()].
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   r <- terra::rast(
#'     nrows = 30, ncols = 30, xmin = 0, xmax = 30000,
#'     ymin = 0, ymax = 30000, crs = "EPSG:32755"
#'   )
#'   hosts <- terra::init(r, 200)
#'   seed <- terra::init(r, 0)
#'   seed[15, 15] <- 5
#'   ep <- geo_epidemic_simulate(hosts, seed,
#'     beta = 0.4, gamma = 0.1, coupling = 0.3,
#'     dispersal_mean = 2000, times = c(20, 40, 80), nsim = 10, seed = 1
#'   )
#'   terra::plot(ep$reached)
#'   mean(ep$attack)
#' }
#' }
geo_epidemic_simulate <- function(hosts,
                                  initial,
                                  beta,
                                  gamma,
                                  omega = 0,
                                  coupling = 0.1,
                                  dispersal_mean,
                                  times,
                                  kernel = c("exponential", "2Dt"),
                                  kernel_shape = 1,
                                  max_distance = NULL,
                                  resistance = NULL,
                                  initial_count = 1,
                                  nsim = 100,
                                  seed = NULL,
                                  threads = 0) {
  rlang::check_installed("terra")
  h <- geo_as_raster(hosts)[[1]][[1]]
  k <- tmr_kernel_args(dispersal_mean, max_distance, kernel, kernel_shape)
  tmr_chk_num(beta, "beta")
  tmr_chk_num(gamma, "gamma")
  tmr_chk_num(omega, "omega")
  tmr_chk_num(nsim, "nsim", 1)
  bad_coupling <- !is.numeric(coupling) || length(coupling) != 1 || is.na(coupling) ||
    coupling < 0 || coupling > 1
  if (bad_coupling) {
    cli::cli_abort("{.arg coupling} must be one number between 0 and 1.")
  }
  times <- as.integer(times)
  if (!length(times) || anyNA(times) || any(times < 1) || is.unsorted(times, strictly = TRUE)) {
    cli::cli_abort("{.arg times} must be increasing whole numbers of at least 1.")
  }
  seed <- seed %||% sample.int(.Machine$integer.max, 1)
  nv <- terra::values(h, mat = FALSE)
  nv[is.na(nv) | nv < 0] <- 0
  nv <- as.integer(round(nv))
  iv <- if (inherits(initial, "SpatRaster")) {
    i <- initial[[1]]
    if (!terra::compareGeom(i, h, stopOnError = FALSE)) i <- terra::resample(i, h, method = "near")
    v <- terra::values(i, mat = FALSE)
    v[is.na(v)] <- 0
    as.integer(round(v))
  } else {
    as.integer(tmr_shift_initial(initial, h)) * as.integer(initial_count)
  }
  if (sum(pmin(iv, nv)) == 0) {
    cli::cli_abort("No infected hosts at the start: check {.arg initial} and {.arg hosts}.")
  }
  geom <- tmr_cell_dims(h)
  res <- tmr_layer_values(resistance, h, "resistance", na = 0)
  out <- epidemic_simulate_cpp(
    nv, iv, terra::nrow(h), terra::ncol(h), geom$width, geom$height, k$type,
    dispersal_mean, kernel_shape, k$max_distance, beta, gamma, omega, coupling,
    times, as.integer(nsim), as.numeric(seed), as.integer(threads), res
  )
  to_rast <- function(m) {
    r <- terra::rast(h, nlyrs = length(times))
    terra::values(r) <- m
    names(r) <- paste0("t", times)
    terra::mask(r, h)
  }
  structure(list(
    prevalence = to_rast(out$prevalence),
    reached = to_rast(out$reached),
    curve = tibble::tibble(time = seq_along(out$infected) - 1L, infected = out$infected),
    attack = out$attack,
    settings = list(
      beta = beta, gamma = gamma, omega = omega, coupling = coupling,
      R0 = if (gamma > 0) beta / (1 - exp(-gamma)) else Inf, dispersal_mean = dispersal_mean,
      kernel = k$kernel, kernel_shape = kernel_shape, max_distance = k$max_distance,
      nsim = nsim, seed = seed
    )
  ), class = "tmr_epidemic")
}

#' @export
print.tmr_epidemic <- function(x, ...) {
  s <- x$settings
  cli::cli_text(
    "Spatial SIR epidemic: R0 = {signif(s$R0, 3)}, {s$nsim} simulation{?s}, ",
    "{s$kernel} contacts (mean {s$dispersal_mean} m)."
  )
  cli::cli_text(
    "Share of hosts ever infected: median {signif(stats::median(x$attack), 3)} ",
    "(range {signif(min(x$attack), 3)} to {signif(max(x$attack), 3)})."
  )
  invisible(x)
}
