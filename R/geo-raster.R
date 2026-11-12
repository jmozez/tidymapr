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
#' @param y What to crop, mask or summarise by: an `sf` or `sfc` object, a
#'   terra `SpatVector`, `SpatExtent` or `SpatRaster` (its extent), an sf
#'   `bbox`, or four numbers. Unnamed numbers are read as
#'   `c(xmin, ymin, xmax, ymax)`, the order of [sf::st_bbox()]; note that
#'   [terra::ext()] uses `xmin, xmax, ymin, ymax`. Named numbers
#'   (`xmin`, `ymin`, `xmax`, `ymax`) may be in any order.
#' @param ... Passed to the underlying terra helper.
#' @return `geo_raster_crop()`, `geo_raster_mask()`, `geo_raster_resample()`,
#'   `geo_raster_project()`, `geo_raster_terrain()` and `geo_raster_focal()`
#'   return a `terra::SpatRaster`. `geo_raster_zonal()` returns a tibble with
#'   one row per feature of `y` (its attributes and the summary statistic),
#'   or the raw `terra::extract()` result when `as_tibble = FALSE`.
#' @name geo-raster
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' r <- terra::rast(
#'   ncols = 20, nrows = 20, xmin = 144.8, xmax = 145.4,
#'   ymin = -6.0, ymax = -5.5, crs = "EPSG:4326"
#' )
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
#' @param method Resampling method passed to terra (`"average"` gives the
#'   same values as [terra::aggregate()] when the grids are aligned).
#' @param origin Grid origin for `geo_raster_resample()`: cell edges fall
#'   on `origin + k * res`. The default, `c(0, 0)`, aligns cells to whole
#'   multiples of the resolution (for example whole degrees for 1/120
#'   degree), so results match [terra::aggregate()] or [terra::resample()]
#'   on an aligned template. Earlier versions started the grid at the
#'   raster's edge, which could shift results by part of a cell.
#' @param align_to Optional template `SpatRaster` whose grid (origin and,
#'   unless `res` is given, resolution) the result should share.
#' @export
geo_raster_resample <- function(raster, res = NULL, method = "bilinear", ...,
                                origin = c(0, 0), align_to = NULL) {
  rlang::check_installed("terra")
  r <- geo_as_raster(raster)[[1]]
  if (!is.null(align_to)) {
    align_to <- geo_as_raster(align_to)[[1]]
    res <- res %||% terra::res(align_to)
    origin <- terra::origin(align_to)
  }
  if (is.null(res)) {
    cli::cli_abort("{.arg res} or {.arg align_to} is required for resampling.")
  }
  res <- rep_len(res, 2)
  origin <- rep_len(origin, 2)
  e <- as.vector(terra::ext(r))
  snap_lo <- function(v, o, d) o + floor((v - o) / d + 1e-9) * d
  snap_hi <- function(v, o, d) o + ceiling((v - o) / d - 1e-9) * d
  target <- terra::rast(
    xmin = snap_lo(e[["xmin"]], origin[1], res[1]),
    xmax = snap_hi(e[["xmax"]], origin[1], res[1]),
    ymin = snap_lo(e[["ymin"]], origin[2], res[2]),
    ymax = snap_hi(e[["ymax"]], origin[2], res[2]),
    resolution = res, crs = terra::crs(r)
  )
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
#' @param weight For `geo_raster_zonal()` with a zone raster: `"area"`
#'   weights each cell by its true area ([terra::cellSize()]), which matters
#'   for longitude/latitude grids whose cells shrink away from the equator;
#'   `"none"` gives every cell equal weight. With `"area"`, `fun` must be
#'   `"mean"` or `"sum"` (the area-weighted sum is the integral, e.g. km2
#'   for an indicator raster).
#' @details
#' `geo_raster_zonal()` accepts polygons (sf, sfc, SpatVector) or a
#' **zone raster** as `y`: a categorical `SpatRaster` (for example
#' elevation bands or land-cover classes). A zone raster on a different
#' grid is resampled to the value raster with nearest-neighbour first.
#' @export
geo_raster_zonal <- function(raster, y, fun = "mean", ..., as_tibble = TRUE,
                             weight = c("none", "area")) {
  rlang::check_installed("terra")
  weight <- rlang::arg_match(weight)
  r <- geo_as_raster(raster)[[1]]
  if (inherits(y, "SpatRaster")) {
    return(tmr_zonal_raster(r, y[[1]], fun, weight, as_tibble, ...))
  }
  rlang::check_installed("sf")
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

geo_raster_vect <- function(y, raster, call = caller_env()) {
  if (inherits(y, "SpatVector") || inherits(y, "SpatExtent")) {
    return(y)
  }
  if (inherits(y, "SpatRaster")) {
    return(terra::ext(y))
  }
  if (inherits(y, "sf") || inherits(y, "sfc")) {
    if (inherits(y, "sfc")) {
      y <- sf::st_sf(geometry = y)
    }
    # terra::vect methods dispatch on class; drop tidymapr subclass
    class(y) <- setdiff(class(y), "tmr_geo_sf")
    has_r <- !is.na(terra::crs(raster))
    has_y <- !is.na(sf::st_crs(y))
    if (!has_y && has_r) {
      y <- sf::st_set_crs(y, terra::crs(raster))
    } else if (has_y && has_r && sf::st_crs(y) != sf::st_crs(terra::crs(raster))) {
      y <- sf::st_transform(y, terra::crs(raster))
    }
    return(terra::vect(y))
  }
  if (inherits(y, "bbox") || (is.numeric(y) && length(y) == 4)) {
    return(tmr_as_extent(y, call = call))
  }
  cli::cli_abort(
    "{.arg y} must be sf, sfc, an sf bbox, a SpatVector, SpatExtent or SpatRaster, \\
    or four numbers.",
    call = call
  )
}

# Four numbers as a terra extent. Named vectors may be in any order;
# unnamed ones are read as c(xmin, ymin, xmax, ymax), the order of
# sf::st_bbox() (terra::ext() itself uses xmin, xmax, ymin, ymax).
tmr_as_extent <- function(y, call = caller_env()) {
  nm <- names(y)
  if (!is.null(nm) && all(c("xmin", "ymin", "xmax", "ymax") %in% nm)) {
    v <- unname(c(y["xmin"], y["ymin"], y["xmax"], y["ymax"]))
  } else {
    v <- unname(as.numeric(y))
  }
  if (anyNA(v) || v[1] >= v[3] || v[2] >= v[4]) {
    cli::cli_abort(c(
      "The bounding box is not valid.",
      "i" = "Unnamed numbers are read as {.code c(xmin, ymin, xmax, ymax)}, the \\
      order of {.fn sf::st_bbox}; {.fn terra::ext} uses {.code xmin, xmax, ymin, ymax}.",
      "i" = "Name them to avoid ambiguity, e.g. \\
      {.code c(xmin = 145, xmax = 147, ymin = -7, ymax = -5)}."
    ), call = call)
  }
  terra::ext(v[1], v[3], v[2], v[4])
}

tmr_zonal_raster <- function(r, z, fun, weight, as_tibble, ..., call = caller_env()) {
  if (!terra::compareGeom(r, z, stopOnError = FALSE)) {
    z <- terra::resample(z, r, method = "near")
  }
  names(z) <- "zone"
  if (weight == "area") {
    if (!is.character(fun) || !fun %in% c("mean", "sum")) {
      cli::cli_abort('With {.code weight = "area"}, {.arg fun} must be "mean" or "sum".',
        call = call
      )
    }
    a <- terra::cellSize(r, unit = "km", mask = FALSE)
    ok <- !is.na(r) & !is.na(z)
    a <- terra::mask(a, ok, maskvalues = 0)
    num <- terra::zonal(r * a, z, fun = "sum", na.rm = TRUE)
    den <- terra::zonal(a, z, fun = "sum", na.rm = TRUE)
    out <- data.frame(zone = num[[1]])
    out[[names(r)]] <- if (fun == "sum") num[[2]] else num[[2]] / den[[2]]
    out$area_km2 <- den[[2]]
  } else {
    out <- terra::zonal(r, z, fun = fun, ...)
    names(out)[1] <- "zone"
  }
  if (isTRUE(as_tibble)) tibble::as_tibble(out) else out
}
