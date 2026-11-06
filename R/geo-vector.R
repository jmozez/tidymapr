#' Tidy vector geometry verbs
#'
#' @description
#' Native tidyverse-style wrappers around common **sf** operations. Inputs
#' accept `sf` tables or data frames with lon/lat (converted with
#' [geo_as_sf()]); outputs are `sf` tibbles. sf reads and writes through
#' **GDAL/OGR**, so GeoPackage, shapefile, GeoJSON and similar formats work
#' via [geo_vector_read()] / [geo_vector_write()] without calling GDAL
#' utilities or the retired **rgdal** package. Prefer GeoPackage over
#' shapefile for new work.
#'
#' @param data An `sf` object or a data frame with coordinates.
#' @param lon,lat Coordinate columns when `data` is not `sf`.
#' @param dist Buffer distance. For geographic CRS, metres (passed through
#'   `sf::st_buffer` with `sf::st_transform` to an equidistant projection
#'   when needed).
#' @param y Second geometry table for binary operations and joins.
#' @param join Spatial predicate for [geo_join()]: `"intersects"`,
#'   `"within"`, `"contains"`, or `"nearest"`.
#' @param ... Passed to the underlying sf helper.
#' @name geo-vector
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' sites <- geo_as_sf(geo_example_sites("wilhelm"), lon, lat)
#' buf <- geo_buffer(sites, dist = 5000)
#' geo_area(buf)
NULL

geo_vector_as_sf <- function(data, lon = NULL, lat = NULL, call = caller_env()) {
  rlang::check_installed("sf", call = call)
  if (inherits(data, "sf")) {
    return(geo_as_sf(data, drop_na = FALSE))
  }
  if (is.null(lon) || is.null(lat)) {
    cli::cli_abort(
      "{.arg data} must be sf, or supply {.arg lon} and {.arg lat}.",
      call = call
    )
  }
  geo_as_sf(data, lon = !!lon, lat = !!lat, drop_na = TRUE)
}

#' @rdname geo-vector
#' @export
geo_buffer <- function(data, dist, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  tmr_check_number(dist, "dist", 0)
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  crs <- sf::st_crs(x)
  # Buffer in metres: project geographic data to equidistant cylindrical
  if (sf::st_is_longlat(x)) {
    x_m <- sf::st_transform(x, "+proj=eqc +units=m")
    out <- sf::st_buffer(x_m, dist = dist, ...)
    out <- sf::st_transform(out, crs)
  } else {
    out <- sf::st_buffer(x, dist = dist, ...)
  }
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_intersection <- function(data, y, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  y <- geo_match_crs(y, x)
  out <- suppressWarnings(sf::st_intersection(x, y, ...))
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_difference <- function(data, y, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  y <- geo_match_crs(y, x)
  out <- suppressWarnings(sf::st_difference(x, y, ...))
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_union <- function(data, y = NULL, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  if (is.null(y)) {
    geom <- sf::st_union(x, ...)
    out <- sf::st_sf(geometry = sf::st_sfc(geom, crs = sf::st_crs(x)))
  } else {
    y <- geo_match_crs(y, x)
    out <- sf::st_union(x, y, ...)
    if (!inherits(out, "sf")) {
      out <- sf::st_sf(geometry = sf::st_sfc(out, crs = sf::st_crs(x)))
    }
  }
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_crop <- function(data, y, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  if (inherits(y, "bbox") || (is.numeric(y) && length(y) == 4)) {
    if (is.numeric(y) && is.null(names(y))) {
      names(y) <- c("xmin", "ymin", "xmax", "ymax")
    }
    y <- sf::st_as_sfc(sf::st_bbox(y, crs = sf::st_crs(x)))
  } else {
    y <- geo_match_crs(y, x)
  }
  out <- sf::st_crop(x, y, ...)
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_area <- function(data, lon = lon, lat = lat) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  if (sf::st_is_longlat(x)) {
    a <- sf::st_area(sf::st_transform(x, "+proj=eqc +units=m"))
  } else {
    a <- sf::st_area(x)
  }
  out <- geo_drop_geometry(x)
  out$area_m2 <- as.numeric(a)
  tibble::as_tibble(out)
}

#' @rdname geo-vector
#' @export
geo_centroid <- function(data, lon = lon, lat = lat) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  geom <- sf::st_centroid(sf::st_geometry(x))
  out <- geo_drop_geometry(x)
  out <- sf::st_sf(out, geometry = geom)
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @export
geo_bbox <- function(data, lon = lon, lat = lat) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  bb <- sf::st_bbox(x)
  tibble::tibble(
    xmin = unname(bb["xmin"]),
    ymin = unname(bb["ymin"]),
    xmax = unname(bb["xmax"]),
    ymax = unname(bb["ymax"]),
    crs = sf::st_crs(x)$input %||% as.character(sf::st_crs(x)$epsg)
  )
}

#' @rdname geo-vector
#' @export
geo_join <- function(data,
                     y,
                     join = c("intersects", "within", "contains", "nearest"),
                     lon = lon,
                     lat = lat,
                     ...) {
  rlang::check_installed("sf")
  join <- rlang::arg_match(join)
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  y <- geo_match_crs(y, x)
  out <- switch(
    join,
    intersects = sf::st_join(x, y, join = sf::st_intersects, ...),
    within = sf::st_join(x, y, join = sf::st_within, ...),
    contains = sf::st_join(x, y, join = sf::st_contains, ...),
    nearest = sf::st_join(x, y, join = sf::st_nearest_feature, ...)
  )
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

#' @rdname geo-vector
#' @param to Geometry or coordinates to measure distance to.
#' @export
geo_distance_to <- function(data, to, lon = lon, lat = lat, ...) {
  rlang::check_installed("sf")
  x <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  to <- geo_match_crs(to, x)
  if (sf::st_is_longlat(x)) {
    d <- sf::st_distance(
      sf::st_transform(x, "+proj=eqc +units=m"),
      sf::st_transform(to, "+proj=eqc +units=m"),
      ...
    )
  } else {
    d <- sf::st_distance(x, to, ...)
  }
  out <- geo_drop_geometry(x)
  # Distance to nearest feature when `to` has multiple rows
  if (ncol(d) == 1) {
    out$distance_m <- as.numeric(d[, 1])
  } else {
    out$distance_m <- as.numeric(apply(d, 1, min))
  }
  tibble::as_tibble(out)
}

geo_match_crs <- function(y, x) {
  if (!inherits(y, "sf")) {
    if (inherits(y, "sfc") || inherits(y, "sfg")) {
      y <- sf::st_sf(geometry = sf::st_sfc(y, crs = sf::st_crs(x)))
    } else {
      cli::cli_abort("{.arg y}/{.arg to} must be an sf or sfc object.")
    }
  }
  if (is.na(sf::st_crs(y))) {
    y <- sf::st_set_crs(y, sf::st_crs(x))
  } else if (sf::st_crs(y) != sf::st_crs(x)) {
    y <- sf::st_transform(y, sf::st_crs(x))
  }
  y
}
