#' Spatial verbs for ForestGEO-style stem maps
#'
#' @description
#' Stems in forest dynamics plots (ForestGEO / CTFS) are mapped in local
#' metre coordinates (`gx`, `gy`). These verbs are the spatial part of a stem
#' workflow:
#'
#' * `stems_quadrat()` assigns each stem to a square quadrat (ForestGEO
#'   default 20 m) and adds `quadrat`, `quadrat_x`, `quadrat_y`,
#'   `quadrat_col` and `quadrat_row`.
#' * `stems_habitat()` joins quadrat-level habitat or topography by
#'   `quadrat` or by `quadrat_x`/`quadrat_y`.
#' * `stems_neighbours()` counts neighbours within `radius` metres of each
#'   stem, either all stems or conspecifics only.
#'
#' Census summaries (`stems_abundance()`, `stems_basal_area()`,
#' `stems_demography()`, `stems_as_community()`) live in tidydiversity. Map
#' stems with [plot_topo()] and test habitat associations with
#' [stems_habitat_test()].
#'
#' @param data A ForestGEO-like stem or tree table with species and local
#'   coordinates (`gx`/`gy` or `x`/`y`).
#' @param grid Quadrat size in metres (ForestGEO default 20).
#' @param gx,gy Bare column names for local metre coordinates.
#' @param habitat A data frame of quadrat-level habitat or topography
#'   (`quadrat`, or `quadrat_x`/`quadrat_y`, plus covariates).
#' @param radius Neighbourhood radius in metres.
#' @param conspecific Count only neighbours of the same species (`TRUE`) or
#'   all neighbours (`FALSE`).
#' @param alive_only Keep only stems whose `status` is in `alive`?
#' @param alive Character codes of `status` that mean alive (default `"A"`).
#' @return A tibble: `data` with the new quadrat, habitat or neighbour
#'   columns.
#' @references Condit, R. (1998). *Tropical Forest Census Plots*. Springer.
#'   Anderson-Teixeira, K. J. et al. (2015). CTFS-ForestGEO: a worldwide
#'   network monitoring forests in an era of global change. *Global Change
#'   Biology*, 21, 528-549. \doi{10.1111/gcb.12712}.
#' @name stems_spatial
#' @examples
#' stems <- geo_example_stems()
#' q <- stems_quadrat(stems, grid = 20)
#' head(q[c("gx", "gy", "quadrat", "quadrat_col", "quadrat_row")])
#'
#' hab <- unique(q[c("quadrat", "quadrat_x", "quadrat_y")])
#' hab$elev <- hab$quadrat_x + hab$quadrat_y
#' head(stems_habitat(stems, hab))
#'
#' head(stems_neighbours(stems, radius = 10))
NULL

tmr_stems_find_col <- function(data, candidates, arg, required = TRUE,
                               call = caller_env()) {
  nms <- names(data)
  low <- tolower(nms)
  hit <- candidates[candidates %in% low]
  if (length(hit) == 0) {
    if (required) {
      cli::cli_abort(
        "{.arg data} needs a {.field {arg}} column (tried {.val {candidates}}).",
        call = call
      )
    }
    return(NULL)
  }
  nms[match(hit[1], low)]
}

tmr_stems_prepare <- function(data, call = caller_env()) {
  tmr_check_data(data, call = call)
  find <- function(candidates, arg, required = FALSE) {
    tmr_stems_find_col(data, candidates, arg, required = required, call = call)
  }
  list(
    data = tibble::as_tibble(dplyr::ungroup(data)),
    species = find(c("species", "sp", "mnemonic"), "species", required = TRUE),
    dbh = find(c("dbh", "dbh_mm", "dbh_cm"), "dbh"),
    status = find(c("status", "dfstatus"), "status"),
    gx = find(c("gx", "x"), "gx"),
    gy = find(c("gy", "y"), "gy")
  )
}

#' @rdname stems_spatial
#' @export
stems_quadrat <- function(data, grid = 20, gx = gx, gy = gy) {
  tmr_check_number(grid, "grid", 0)
  prep <- tmr_stems_prepare(data)
  d <- prep$data
  gx_col <- tryCatch(tmr_pick(enquo(gx), d, "gx"), error = function(e) prep$gx)
  gy_col <- tryCatch(tmr_pick(enquo(gy), d, "gy"), error = function(e) prep$gy)
  if (is.null(gx_col) || is.null(gy_col)) {
    cli::cli_abort("{.fn stems_quadrat} needs {.field gx} and {.field gy} columns.")
  }
  qx <- floor(as.numeric(d[[gx_col]]) / grid) * grid
  qy <- floor(as.numeric(d[[gy_col]]) / grid) * grid
  d$quadrat_x <- qx
  d$quadrat_y <- qy
  d$quadrat <- paste(qx, qy, sep = "_")
  d$quadrat_col <- as.integer(qx / grid)
  d$quadrat_row <- as.integer(qy / grid)
  tibble::as_tibble(d)
}

#' @rdname stems_spatial
#' @export
stems_habitat <- function(data, habitat, grid = 20) {
  tmr_check_data(habitat)
  d <- stems_quadrat(data, grid = grid)
  h <- tibble::as_tibble(dplyr::ungroup(habitat))
  if ("quadrat" %in% names(h)) {
    out <- dplyr::left_join(d, h, by = "quadrat")
  } else if (all(c("quadrat_x", "quadrat_y") %in% names(h))) {
    out <- dplyr::left_join(d, h, by = c("quadrat_x", "quadrat_y"))
  } else {
    cli::cli_abort(
      "{.arg habitat} needs {.field quadrat} or {.field quadrat_x}/{.field quadrat_y}."
    )
  }
  tibble::as_tibble(out)
}

#' @rdname stems_spatial
#' @export
stems_neighbours <- function(data,
                             radius = 10,
                             conspecific = TRUE,
                             alive_only = TRUE,
                             alive = "A") {
  tmr_check_number(radius, "radius", 0)
  prep <- tmr_stems_prepare(data)
  d <- prep$data
  if (is.null(prep$gx) || is.null(prep$gy)) {
    cli::cli_abort("{.fn stems_neighbours} needs {.field gx} and {.field gy}.")
  }
  if (isTRUE(alive_only) && !is.null(prep$status)) {
    d <- d[d[[prep$status]] %in% alive, , drop = FALSE]
  }
  x <- as.numeric(d[[prep$gx]])
  y <- as.numeric(d[[prep$gy]])
  count <- integer(nrow(d))
  groups <- if (isTRUE(conspecific)) {
    split(seq_len(nrow(d)), as.character(d[[prep$species]]))
  } else {
    list(seq_len(nrow(d)))
  }
  for (idx in groups) {
    count[idx] <- geo_neighbour_count_cpp(x[idx], y[idx], radius)
  }
  d$n_neighbours <- count
  d$neighbour_radius <- radius
  d$conspecific <- conspecific
  tibble::as_tibble(d)
}

#' Torus-translation habitat association test (ForestGEO)
#'
#' Tests whether a species' density differs among habitat classes by
#' shifting the habitat map on a torus while keeping relative habitat
#' structure (Harms et al. 2001). Observed mean density per habitat is
#' compared to the null distribution from torus shifts.
#'
#' @param data Stem or tree table with `gx`, `gy` and species.
#' @param habitat Either a data frame with `gx`, `gy` (quadrat centres) and
#'   a habitat class column, or a column name already on `data` after
#'   [stems_habitat()].
#' @param species Species column.
#' @param habitat_col Name of the habitat class column in `habitat` (or in
#'   `data` when `habitat` is a column name).
#' @param grid Quadrat size in metres (ForestGEO default 20).
#' @param nperm Number of torus shifts.
#' @param mindbh Optional minimum DBH filter.
#' @param dbh_unit `"mm"` or `"cm"`.
#' @param seed Optional RNG seed.
#' @return A tibble (`tmr_stems_habitat_test`) with species, habitat,
#'   observed density, null mean, and two-sided permutation p-value.
#' @references
#' Harms, K. E., Condit, R., Hubbell, S. P. and Foster, R. B. (2001). Habitat
#' associations of trees and shrubs in a 50-ha neotropical forest plot.
#' *Journal of Ecology*, 89, 947-959. \doi{10.1111/j.1365-2745.2001.00615.x}
#' @export
#' @examples
#' stems <- geo_example_stems()
#' q <- stems_quadrat(stems)
#' hab <- unique(q[c("quadrat", "gx", "gy")])
#' hab$habitat <- ifelse(hab$gx + hab$gy > 100, "ridge", "valley")
#' stems_habitat_test(stems, habitat = hab, nperm = 49, seed = 1)
stems_habitat_test <- function(data,
                               habitat,
                               species = species,
                               habitat_col = "habitat",
                               grid = 20,
                               nperm = 999,
                               mindbh = NULL,
                               dbh_unit = c("mm", "cm"),
                               seed = NULL) {
  dbh_unit <- rlang::arg_match(dbh_unit)
  tmr_check_data(data)
  tmr_check_number(nperm, "nperm", 0, whole = TRUE)
  tmr_check_number(grid, "grid", 0)
  sp_col <- tmr_pick(enquo(species), data, "species")
  prep <- tmr_stems_prepare(data)
  data <- prep$data
  if (!is.null(mindbh)) {
    dbh_col <- prep$dbh %||% tmr_stems_find_col(data, "dbh", "dbh")
    dbh <- as.numeric(data[[dbh_col]])
    if (identical(dbh_unit, "cm")) dbh <- dbh * 10
    data <- data[is.finite(dbh) & dbh >= mindbh, , drop = FALSE]
  }
  if (!is.null(seed)) set.seed(seed)

  if (is.character(habitat) && length(habitat) == 1) {
    habitat_col <- habitat
    if (!habitat_col %in% names(data)) {
      cli::cli_abort("Column {.val {habitat_col}} not found on {.arg data}.")
    }
    q <- stems_quadrat(data, grid = grid)
    hab <- unique(q[c("quadrat", "gx", "gy", habitat_col)])
  } else {
    tmr_check_data(habitat)
    if (!habitat_col %in% names(habitat)) {
      cli::cli_abort("{.arg habitat} needs column {.val {habitat_col}}.")
    }
    hab <- habitat
  }
  if (!all(c("gx", "gy") %in% names(hab))) {
    cli::cli_abort("{.arg habitat} needs {.val gx} and {.val gy} columns.")
  }

  # Habitat classes on a row-major quadrat grid
  ix <- as.integer(floor(as.numeric(hab$gx) / grid))
  iy <- as.integer(floor(as.numeric(hab$gy) / grid))
  ux <- sort(unique(ix))
  uy <- sort(unique(iy))
  ncol <- length(ux)
  nrow <- length(uy)
  hab_levels <- sort(unique(as.character(hab[[habitat_col]])))
  hab_id <- match(as.character(hab[[habitat_col]]), hab_levels)
  grid_vec <- rep(NA_integer_, nrow * ncol)
  grid_vec[(match(iy, uy) - 1L) * ncol + match(ix, ux)] <- hab_id

  stems_q <- stems_quadrat(data, grid = grid)
  r <- match(as.integer(floor(as.numeric(stems_q$gy) / grid)), uy)
  c <- match(as.integer(floor(as.numeric(stems_q$gx) / grid)), ux)
  ok <- !is.na(r) & !is.na(c)
  cell <- ((r - 1L) * ncol + c)[ok]
  sp <- as.character(stems_q[[sp_col]])[ok]
  spp <- sort(unique(sp))
  sp_i <- match(sp, spp)
  n_hab <- length(hab_levels)

  tally <- function(map) {
    h <- map[cell]
    keep <- !is.na(h)
    counts <- matrix(0, length(spp), n_hab, dimnames = list(spp, hab_levels))
    tab <- table(factor(sp_i[keep], seq_along(spp)), factor(h[keep], seq_len(n_hab)))
    counts[] <- as.numeric(tab)
    counts
  }
  area_obs <- tabulate(grid_vec, nbins = n_hab)
  obs_counts <- tally(grid_vec)
  dens_obs <- sweep(obs_counts, 2, pmax(area_obs, 1), "/")

  null_dens <- array(0, dim = c(nperm, length(spp), n_hab))
  for (b in seq_len(nperm)) {
    dx <- sample.int(ncol, 1) - 1L
    dy <- sample.int(nrow, 1) - 1L
    shifted <- geo_torus_shift_cpp(
      as.integer(grid_vec), as.integer(nrow), as.integer(ncol),
      as.integer(dx), as.integer(dy)
    )
    area_b <- tabulate(shifted, nbins = n_hab)
    null_dens[b, , ] <- sweep(tally(shifted), 2, pmax(area_b, 1), "/")
  }

  grid_rows <- expand.grid(hi = seq_len(n_hab), si = seq_along(spp))
  rows <- lapply(seq_len(nrow(grid_rows)), function(k) {
    si <- grid_rows$si[k]
    hi <- grid_rows$hi[k]
    obs <- dens_obs[si, hi]
    if (nperm > 0) {
      null_v <- null_dens[, si, hi]
      null_mean <- mean(null_v)
      p <- (1 + sum(abs(null_v - null_mean) >= abs(obs - null_mean))) /
        (1 + nperm)
    } else {
      p <- NA_real_
      null_mean <- NA_real_
    }
    tibble::tibble(
      species = spp[si],
      habitat = hab_levels[hi],
      density = obs,
      null_mean = null_mean,
      p_value = p,
      n_stems = obs_counts[si, hi],
      n_quadrats = as.integer(area_obs[hi])
    )
  })
  tmr_new(vctrs::vec_rbind(!!!rows), "tmr_stems_habitat_test")
}
