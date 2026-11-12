#' Tidy raster analysis verbs
#'
#' @description
#' Native tidyverse-style wrappers around common **terra** operations for
#' elevation and climate rasters. terra (and therefore these helpers) reads
#' and writes through **GDAL**, so GeoTIFF, COG, netCDF and similar formats
#' work without calling `gdal_translate` yourself. Do not use the retired
#' **rgdal** package. Pair with [geo_extract()] to join raster values to
#' sites, and with [geo_buffer()] plus [geo_raster_zonal()] for mean
#' elevation in a site buffer. [geo_raster_project()], [geo_raster_crop()]
#' and [geo_raster_mask()] are the tidy entry points for GDAL warps / clips.
#'
#' @param raster A `terra::SpatRaster` or a file path.
#' @param y An `sf` polygon/line used to crop, mask or summarise.
#' @param ... Passed to the underlying terra helper.
#' @return `geo_raster_crop()`, `geo_raster_mask()`, `geo_raster_resample()`,
#'   `geo_raster_project()`, `geo_raster_terrain()` and `geo_raster_focal()`
#'   return a `terra::SpatRaster`. `geo_raster_zonal()` returns a tibble with
#'   one row per feature of `y` (its attributes and the summary statistic),
#'   or the raw `terra::extract()` result when `as_tibble = FALSE`.
#' @name geo-raster
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' r <- terra::rast(ncols = 20, nrows = 20, xmin = 144.8, xmax = 145.4,
#'   ymin = -6.0, ymax = -5.5, crs = "EPSG:4326")
#' terra::values(r) <- seq_len(terra::ncell(r))
#' names(r) <- "elev"
#' sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
#' sites <- sites[sites$elevation <= 2200, ]
#' geo_raster_zonal(r, geo_buffer(sites, dist = 2000), fun = "mean")
NULL


#' @rdname geo-raster
#' @export
geo_raster_crop <- function(raster, y, ...) {
  rlang::check_installed("terra")
  rlang::check_installed("sf")
  r <- geo_as_raster(raster)[[1]]
  v <- geo_raster_vect(y, r)
  terra::crop(r, v, ...)
}

#' @rdname geo-raster
#' @export
geo_raster_mask <- function(raster, y, ...) {
  rlang::check_installed("terra")
  rlang::check_installed("sf")
  r <- geo_as_raster(raster)[[1]]
  v <- geo_raster_vect(y, r)
  terra::mask(r, v, ...)
}

#' @rdname geo-raster
#' @param res Target resolution (one or two numbers) for resampling.
#' @param method Resampling method passed to terra.
#' @export
geo_raster_resample <- function(raster, res = NULL, method = "bilinear", ...) {
  rlang::check_installed("terra")
  r <- geo_as_raster(raster)[[1]]
  if (is.null(res)) {
    cli::cli_abort("{.arg res} is required for resampling.")
  }
  target <- terra::rast(r)
  terra::res(target) <- res
  terra::resample(r, target, method = method, ...)
}

#' @rdname geo-raster
#' @param crs Target CRS (EPSG code, WKT or proj string).
#' @export
geo_raster_project <- function(raster, crs, method = "bilinear", ...) {
  rlang::check_installed("terra")
  r <- geo_as_raster(raster)[[1]]
  terra::project(r, crs, method = method, ...)
}

#' @rdname geo-raster
#' @param v Terrain variables: `"slope"`, `"aspect"`, `"TPI"`, `"TRI"`,
#'   `"roughness"`, `"flowdir"`.
#' @param unit Unit for slope/aspect (`"degrees"` or `"radians"`).
#' @export
geo_raster_terrain <- function(raster,
                               v = c("slope", "aspect", "TPI"),
                               unit = "degrees",
                               ...) {
  rlang::check_installed("terra")
  r <- geo_as_raster(raster)[[1]]
  v <- match.arg(v, c(
    "slope", "aspect", "TPI", "TRI", "roughness", "flowdir"
  ), several.ok = TRUE)
  out <- lapply(v, function(vi) {
    terra::terrain(r, v = vi, unit = unit, ...)
  })
  terra::rast(out)
}

#' @rdname geo-raster
#' @param w Window size (odd integer or matrix) for the focal filter.
#' @param fun Summary function name or function.
#' @export
geo_raster_focal <- function(raster, w = 3, fun = "mean", ...) {
  rlang::check_installed("terra")
  r <- geo_as_raster(raster)[[1]]
  terra::focal(r, w = w, fun = fun, ...)
}

#' @rdname geo-raster
#' @param as_tibble Return a tibble (default) instead of the raw terra extract matrix?
#' @export
geo_raster_zonal <- function(raster, y, fun = "mean", ..., as_tibble = TRUE) {
  rlang::check_installed("terra")
  rlang::check_installed("sf")
  r <- geo_as_raster(raster)[[1]]
  v <- geo_raster_vect(y, r)
  z <- terra::extract(r, v, fun = fun, ...)
  if (!isTRUE(as_tibble)) {
    return(z)
  }
  out <- tibble::as_tibble(z)
  # Attach non-geometry columns from y when present
  if (inherits(y, "sf")) {
    attrs <- geo_drop_geometry(y)
    if (nrow(attrs) == nrow(out)) {
      out <- dplyr::bind_cols(attrs, out[, setdiff(names(out), "ID"), drop = FALSE])
    }
  }
  out
}

geo_raster_vect <- function(y, raster) {
  if (inherits(y, "SpatVector")) {
    return(y)
  }
  if (inherits(y, "sf") || inherits(y, "sfc")) {
    if (inherits(y, "sfc")) {
      y <- sf::st_sf(geometry = y)
    }
    # terra::vect methods dispatch on class; drop tidymapr subclass
    class(y) <- setdiff(class(y), "tmr_geo_sf")
    if (is.na(sf::st_crs(y)) && !is.na(terra::crs(raster))) {
      y <- sf::st_set_crs(y, terra::crs(raster))
    } else if (!is.na(sf::st_crs(y)) &&
                 !is.na(terra::crs(raster)) &&
                 sf::st_crs(y) != sf::st_crs(terra::crs(raster))) {
      y <- sf::st_transform(y, terra::crs(raster))
    }
    return(terra::vect(y))
  }
  if (inherits(y, "bbox") || (is.numeric(y) && length(y) == 4)) {
    if (is.numeric(y) && is.null(names(y))) {
      names(y) <- c("xmin", "ymin", "xmax", "ymax")
    }
    e <- terra::ext(unname(y["xmin"]), unname(y["xmax"]),
      unname(y["ymin"]), unname(y["ymax"])
    )
    return(e)
  }
  cli::cli_abort("{.arg y} must be sf, SpatVector, bbox or extent numbers.")
}
