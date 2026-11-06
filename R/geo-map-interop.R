#' Hand off spatial objects to tmap, leaflet and friends
#'
#' tidymapr keeps mapping in ggplot via [plot_sites()], [plot_geo()] and
#' [plot_topo()], but never blocks **tmap**, **leaflet** or other spatial
#' viewers. These helpers return plain [sf][sf::sf] and
#' [terra][terra::SpatRaster] objects (with a CRS) so
#' `tmap::tm_shape()`, `leaflet::addTiles()`, `leaflet::addCircleMarkers()`
#' and `leaflet::addRasterImage()` work without extra wrangling. Neither
#' tmap nor leaflet is a hard Import; examples are wrapped in
#' `requireNamespace()`.
#'
#' @param x A data frame with coordinates, an `sf` object, a SpatRaster,
#'   a `tmr_sdm` prediction tibble, or another supported spatial result.
#' @param lon,lat Coordinate columns when `x` is a data frame.
#' @param crs Target CRS (default EPSG:4326).
#' @param value Column to place in a single-layer SpatRaster when converting
#'   a point table with a numeric attribute (optional).
#' @param ... Passed to [geo_as_sf()] or ignored.
#' @return `as_sf()` returns an `sf` object (subclass `tmr_geo_sf` when built
#'   from coordinates). `as_spat_raster()` returns a `terra::SpatRaster`
#'   with a CRS.
#' @name geo-map-interop
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' sites <- geo_example_sites()
#' sites <- sites[!is.na(sites$lon), ]
#' pts <- as_sf(sites)
#' inherits(pts, "sf")
#' sf::st_crs(pts)$epsg
#'
#' @examplesIf requireNamespace("sf", quietly = TRUE) && requireNamespace("tmap", quietly = TRUE)
#' # Optional: same sites in tmap (skipped when tmap is not installed)
#' # tmap::tm_shape(as_sf(sites)) + tmap::tm_dots(col = "elevation")
#'
#' @examplesIf requireNamespace("sf", quietly = TRUE) && requireNamespace("leaflet", quietly = TRUE)
#' # Optional: leaflet (skipped when leaflet is not installed)
#' # leaflet::leaflet(as_sf(sites)) |>
#' #   leaflet::addTiles() |>
#' #   leaflet::addCircleMarkers()
NULL

#' @rdname geo-map-interop
#' @export
as_sf <- function(x, ...) {
  UseMethod("as_sf")
}

#' @rdname geo-map-interop
#' @export
as_sf.default <- function(x, lon = lon, lat = lat, crs = 4326, ...) {
  geo_as_sf(x, lon = {{ lon }}, lat = {{ lat }}, crs = crs, ...)
}

#' @rdname geo-map-interop
#' @export
as_sf.sf <- function(x, crs = NULL, ...) {
  rlang::check_installed("sf")
  if (!is.null(crs)) {
    target <- sf::st_crs(crs)
    cur <- sf::st_crs(x)
    if (is.na(cur)) {
      x <- sf::st_set_crs(x, target)
    } else if (!is.na(target) && cur != target) {
      x <- sf::st_transform(x, target)
    }
  } else if (is.na(sf::st_crs(x))) {
    cli::cli_warn("sf object has no CRS; setting EPSG:4326.")
    x <- sf::st_set_crs(x, 4326)
  }
  x
}

#' @rdname geo-map-interop
#' @export
as_sf.tmr_geo_sf <- function(x, ...) as_sf.sf(x, ...)

#' @rdname geo-map-interop
#' @export
as_sf.tmr_sdm <- function(x, ...) {
  pred <- sdm_predict(x, type = "response")
  as_sf(pred, ...)
}

#' @rdname geo-map-interop
#' @export
as_spat_raster <- function(x, ...) {
  UseMethod("as_spat_raster")
}

#' @rdname geo-map-interop
#' @export
as_spat_raster.default <- function(x, ...) {
  cli::cli_abort(
    "No {.fn as_spat_raster} method for class {.cls {class(x)}}."
  )
}

#' @rdname geo-map-interop
#' @export
as_spat_raster.SpatRaster <- function(x, crs = NULL, ...) {
  rlang::check_installed("terra")
  if (is.null(terra::crs(x)) || !nzchar(terra::crs(x))) {
    if (is.null(crs)) crs <- "EPSG:4326"
    terra::crs(x) <- crs
  } else if (!is.null(crs)) {
    x <- terra::project(x, crs)
  }
  x
}

#' @rdname geo-map-interop
#' @export
as_spat_raster.data.frame <- function(x,
                                      lon = lon,
                                      lat = lat,
                                      value = NULL,
                                      crs = "EPSG:4326",
                                      ...) {
  rlang::check_installed("terra")
  tmr_check_data(x)
  lon_col <- tmr_pick(enquo(lon), x, "lon")
  lat_col <- tmr_pick(enquo(lat), x, "lat")
  val_q <- enquo(value)
  if (quo_is_null(val_q)) {
    candidates <- c("suitability", "diversity", "estimate", "elevation", "value")
    hit <- candidates[candidates %in% names(x)]
    if (length(hit) == 0) {
      cli::cli_abort("{.arg value} is required to build a SpatRaster from a table.")
    }
    val_col <- hit[[1]]
  } else {
    val_col <- tmr_pick(val_q, x, "value")
  }
  pts <- terra::vect(
    as.data.frame(x[c(lon_col, lat_col, val_col)]),
    geom = c(lon_col, lat_col),
    crs = crs
  )
  # Rasterise to a fine grid covering the points
  ext <- terra::ext(pts)
  nx <- max(10L, min(200L, length(unique(round(x[[lon_col]], 4)))))
  ny <- max(10L, min(200L, length(unique(round(x[[lat_col]], 4)))))
  r <- terra::rast(ext, ncols = nx, nrows = ny, crs = crs)
  out <- terra::rasterize(pts, r, field = val_col)
  names(out) <- val_col
  out
}

#' @rdname geo-map-interop
#' @export
as_spat_raster.tmr_sdm <- function(x, ...) {
  pred <- sdm_predict(x)
  if (inherits(pred, "SpatRaster")) {
    return(as_spat_raster(pred, ...))
  }
  as_spat_raster(pred, value = "suitability", ...)
}
