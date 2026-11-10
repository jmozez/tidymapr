#' Interpolate point measurements onto a grid
#'
#' @description
#' Predicts a numeric column of a point table at new locations by
#' inverse-distance weighting (IDW) or ordinary kriging, both computed in
#' C++. Distances are great-circle metres on longitude/latitude data and
#' map units otherwise.
#'
#' For kriging, give the variogram (`model`, `nugget`, `psill`, `range`)
#' or leave `psill` and `range` as `NULL` to fit it from the data with
#' **gstat** (`gstat::fit.variogram()`). The predictions and kriging
#' variances match `gstat::krige()` for the same variogram. The fitted or
#' given variogram is stored in attribute `"variogram"`.
#'
#' Both methods run in C++ on several cores; set the number with
#' `options(tidymapr.threads = n)`.
#'
#' @param data An `sf` point table.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Numeric
#'   column to interpolate.
#' @param grid Where to predict: a `terra::SpatRaster` template (every cell
#'   centre is predicted) or an `sf` point table.
#' @param method `"idw"` or `"kriging"`.
#' @param power IDW distance power (default 2).
#' @param maxdist IDW search radius; samples farther away are ignored
#'   (default `Inf`, all samples).
#' @param model Kriging variogram model: `"Exp"` (exponential), `"Sph"`
#'   (spherical) or `"Gau"` (Gaussian), with gstat's parameterisation.
#' @param nugget,psill,range Variogram nugget, partial sill and range.
#'   `psill` and `range` default to a fit with gstat. `range` is in metres
#'   on longitude/latitude data and in map units otherwise.
#' @param variance For kriging, also return the kriging variance? Skipping
#'   it (`FALSE`) makes large grids much faster.
#' @param name Name of the prediction layer or column.
#' @return For a raster `grid`, a `SpatRaster` with layer `name` (and
#'   `"variance"` for kriging). For an `sf` `grid`, the same table with
#'   these columns added.
#' @references Isaaks, E. H. and Srivastava, R. M. (1989). *An Introduction
#'   to Applied Geostatistics*. Oxford University Press.
#' @export
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
#' bb <- sf::st_bbox(sites)
#' grid <- terra::rast(nrows = 20, ncols = 20, xmin = bb[["xmin"]],
#'   xmax = bb[["xmax"]], ymin = bb[["ymin"]], ymax = bb[["ymax"]],
#'   crs = "EPSG:4326")
#' idw <- geo_interpolate(sites, elevation, grid, power = 2)
#' idw
#'
#' # Kriging with a given variogram (fit one with gstat by leaving
#' # psill and range NULL)
#' geo_interpolate(sites, elevation, grid, method = "kriging",
#'   model = "Exp", psill = 4e5, range = 8000)
geo_interpolate <- function(data,
                            value,
                            grid,
                            method = c("idw", "kriging"),
                            power = 2,
                            maxdist = Inf,
                            model = c("Exp", "Sph", "Gau"),
                            nugget = 0,
                            psill = NULL,
                            range = NULL,
                            variance = TRUE,
                            name = "prediction") {
  rlang::check_installed("sf")
  method <- rlang::arg_match(method)
  model <- rlang::arg_match(model)
  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} point table.")
  }
  col <- tmr_pick(enquo(value), data, "value")
  z <- data[[col]]
  if (!is.numeric(z)) {
    cli::cli_abort("{.arg value} must be a numeric column.")
  }
  keep <- is.finite(z)
  data <- data[keep, ]
  z <- z[keep]
  if (length(z) < 2) {
    cli::cli_abort("{.arg value} needs at least two finite values.")
  }
  lonlat <- isTRUE(sf::st_is_longlat(data))
  xs <- sf::st_coordinates(sf::st_geometry(data))[, 1:2, drop = FALSE]
  target <- tmr_interp_target(grid, data)

  if (method == "idw") {
    tmr_check_number(power, "power", 0)
    tmr_check_number(maxdist, "maxdist", 0)
    pred <- geo_idw_cpp(
      xs[, 1], xs[, 2], z, target$xy[, 1], target$xy[, 2], power, lonlat,
      if (is.finite(maxdist)) maxdist else 0,
      threads = tmr_threads()
    )
    res <- stats::setNames(list(pred), name)
    vg <- NULL
  } else {
    if (anyDuplicated(xs)) {
      cli::cli_abort("Kriging needs distinct locations; {.arg data} has duplicates.")
    }
    vg <- tmr_variogram(data, col, model, nugget, psill, range)
    k <- geo_krige_cpp(
      xs[, 1], xs[, 2], z, target$xy[, 1], target$xy[, 2],
      match(model, c("Exp", "Sph", "Gau")), vg$nugget, vg$psill, vg$range,
      lonlat,
      variance = isTRUE(variance), threads = tmr_threads()
    )
    res <- if (isTRUE(variance)) {
      stats::setNames(list(k$prediction, k$variance), c(name, "variance"))
    } else {
      stats::setNames(list(k$prediction), name)
    }
  }
  out <- target$finish(res)
  attr(out, "variogram") <- vg
  out
}

tmr_interp_target <- function(grid, data, call = caller_env()) {
  if (inherits(grid, "SpatRaster") || is.character(grid)) {
    rlang::check_installed("terra")
    g <- geo_as_raster(grid, call = call)[[1]][[1]]
    crs <- terra::crs(g)
    clash <- nzchar(crs) && !is.na(sf::st_crs(data)) &&
      sf::st_crs(crs) != sf::st_crs(data)
    if (clash) {
      cli::cli_abort(
        "{.arg grid} and {.arg data} must share a CRS; reproject one first.",
        call = call
      )
    }
    xy <- terra::xyFromCell(g, seq_len(terra::ncell(g)))
    finish <- function(res) {
      layers <- lapply(names(res), function(nm) {
        r <- terra::rast(g)
        terra::values(r) <- res[[nm]]
        names(r) <- nm
        r
      })
      terra::rast(layers)
    }
    return(list(xy = xy, finish = finish))
  }
  if (inherits(grid, "sf")) {
    grid <- sf::st_transform(grid, sf::st_crs(data))
    xy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(grid)))[, 1:2, drop = FALSE]
    finish <- function(res) {
      for (nm in names(res)) grid[[nm]] <- res[[nm]]
      grid
    }
    return(list(xy = xy, finish = finish))
  }
  cli::cli_abort(
    "{.arg grid} must be a {.cls SpatRaster} or an {.cls sf} table.",
    call = call
  )
}

tmr_variogram <- function(data, col, model, nugget, psill, range,
                          call = caller_env()) {
  tmr_check_number(nugget, "nugget", 0, call = call)
  if (!is.null(psill) && !is.null(range)) {
    tmr_check_number(psill, "psill", 0, call = call)
    tmr_check_number(range, "range", 0, call = call)
    if (psill <= 0 || range <= 0) {
      cli::cli_abort("{.arg psill} and {.arg range} must be positive.", call = call)
    }
    return(list(model = model, nugget = nugget, psill = psill, range = range))
  }
  rlang::check_installed("gstat", "to fit a variogram for kriging.")
  f <- stats::as.formula(paste(col, "~ 1"))
  ev <- gstat::variogram(f, data)
  init <- gstat::vgm(
    psill = stats::var(data[[col]]), model = model,
    range = max(ev$dist) / 3, nugget = nugget
  )
  fit <- gstat::fit.variogram(ev, init)
  part <- fit[fit$model == model, ]
  nug <- fit[fit$model == "Nug", "psill"]
  # gstat reports great-circle ranges in km; the C++ code works in metres
  scale <- if (isTRUE(sf::st_is_longlat(data))) 1000 else 1
  list(
    model = model,
    nugget = if (length(nug)) nug else 0,
    psill = part$psill,
    range = part$range * scale
  )
}
