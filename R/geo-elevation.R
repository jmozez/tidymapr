#' Download or read elevation (SRTM-style DEM)
#'
#' Fetches a digital elevation model for a bounding box or set of sites,
#' with an on-disk cache and an offline `path` for local GeoTIFFs. Prefers
#' **geodata** (SRTM via `elevation_*`) when installed, then **elevatr**,
#' then a user-supplied file. Cite Jarvis et al. (2008) / NASA SRTM when
#' publishing maps that use these surfaces.
#'
#' @param data Optional data frame of sites with `lon`/`lat` used to build
#'   the bounding box when `bbox` is `NULL`.
#' @param lon,lat Coordinate columns of `data`.
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)` in WGS84, or an
#'   `sf` / `SpatExtent` object.
#' @param path Local GeoTIFF (or directory of GeoTIFFs) for offline use.
#' @param cache_dir Cache directory. Defaults to
#'   `tools::R_user_dir("tidymapr", "cache")/elevation`.
#' @param download Download when the cache is empty? Set `FALSE` on CRAN
#'   or offline runners.
#' @param z Zoom / resolution hint for elevatr (1-14). Ignored by geodata.
#' @param buffer Extra degrees added around the site bbox (default 0.1).
#' @return A `terra::SpatRaster` elevation surface (metres).
#' @references
#' Jarvis, A., Reuter, H. I., Nelson, A. and Guevara, E. (2008). Hole-filled
#' SRTM for the globe Version 4. CGIAR-CSI.
#' <https://srtm.csi.cgiar.org/>
#' @export
#' @examplesIf requireNamespace("terra", quietly = TRUE)
#' dem <- geo_example_dem()
#' terra::nlyr(dem)
geo_elevation <- function(data = NULL,
                          lon = lon,
                          lat = lat,
                          bbox = NULL,
                          path = NULL,
                          cache_dir = NULL,
                          download = TRUE,
                          z = 5,
                          buffer = 0.1) {
  rlang::check_installed("terra")
  if (!is.null(path)) {
    return(geo_elevation_from_path(path))
  }
  bb <- geo_elevation_bbox(data, lon = {{ lon }}, lat = {{ lat }},
                           bbox = bbox, buffer = buffer)
  cache_dir <- cache_dir %||% file.path(
    tools::R_user_dir("tidymapr", "cache"), "elevation"
  )
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  key <- sprintf("elev_%.4f_%.4f_%.4f_%.4f_z%s.tif",
                 bb[1], bb[2], bb[3], bb[4], as.character(z))
  dest <- file.path(cache_dir, key)
  if (file.exists(dest)) {
    r <- terra::rast(dest)
    names(r) <- "elevation"
    return(r)
  }
  if (!isTRUE(download)) {
    cli::cli_abort(
      c(
        "No cached elevation raster for this bbox and {.arg download} is FALSE.",
        "i" = "Pass {.arg path} to a local GeoTIFF when offline."
      )
    )
  }
  r <- geo_elevation_download(bb, cache_dir = cache_dir, z = z)
  terra::writeRaster(r, dest, overwrite = TRUE)
  names(r) <- "elevation"
  r
}

geo_elevation_from_path <- function(path) {
  if (length(path) == 1 && dir.exists(path)) {
    files <- list.files(path, pattern = "\\.(tif|tiff|grd|nc)$",
                        full.names = TRUE, ignore.case = TRUE)
    if (length(files) == 0) {
      cli::cli_abort("No raster files found in {.path {path}}.")
    }
    r <- terra::rast(files)
  } else {
    r <- terra::rast(path)
  }
  if (terra::nlyr(r) > 1) r <- r[[1]]
  names(r) <- "elevation"
  r
}

geo_elevation_bbox <- function(data, lon, lat, bbox, buffer) {
  if (!is.null(bbox)) {
    if (inherits(bbox, "sf") || inherits(bbox, "sfc")) {
      rlang::check_installed("sf")
      b <- sf::st_bbox(sf::st_transform(bbox, 4326))
      return(c(b["xmin"], b["ymin"], b["xmax"], b["ymax"]))
    }
    if (inherits(bbox, "SpatExtent")) {
      e <- terra::ext(bbox)
      return(c(e$xmin, e$ymin, e$xmax, e$ymax))
    }
    if (is.numeric(bbox) && length(bbox) == 4) {
      return(as.numeric(bbox))
    }
    cli::cli_abort("{.arg bbox} must be c(xmin, ymin, xmax, ymax) or sf/SpatExtent.")
  }
  if (is.null(data)) {
    cli::cli_abort("Provide {.arg data} with coordinates or an explicit {.arg bbox}.")
  }
  tmr_check_data(data)
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  x <- data[[lon_col]]
  y <- data[[lat_col]]
  ok <- is.finite(x) & is.finite(y)
  if (!any(ok)) cli::cli_abort("No finite coordinates to build an elevation bbox.")
  c(
    min(x[ok]) - buffer, min(y[ok]) - buffer,
    max(x[ok]) + buffer, max(y[ok]) + buffer
  )
}

geo_elevation_download <- function(bb, cache_dir, z) {
  # Prefer geodata SRTM tiles when available
  if (requireNamespace("geodata", quietly = TRUE)) {
    out <- tryCatch({
      lon <- mean(c(bb[1], bb[3]))
      lat <- mean(c(bb[2], bb[4]))
      r <- geodata::elevation_3s(lon = lon, lat = lat, path = file.path(cache_dir, "geodata"))
      r <- terra::crop(r, terra::ext(bb[1], bb[3], bb[2], bb[4]))
      names(r) <- "elevation"
      r
    }, error = function(e) NULL)
    if (!is.null(out)) return(out)
  }
  if (requireNamespace("elevatr", quietly = TRUE) &&
        requireNamespace("sf", quietly = TRUE)) {
    out <- tryCatch({
      poly <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
        c(xmin = bb[1], ymin = bb[2], xmax = bb[3], ymax = bb[4]),
        crs = 4326
      )))
      r <- elevatr::get_elev_raster(poly, z = z, clip = "bbox")
      r <- terra::rast(r)
      names(r) <- "elevation"
      r
    }, error = function(e) NULL)
    if (!is.null(out)) return(out)
  }
  cli::cli_abort(
    c(
      "Could not download elevation data.",
      "i" = "Install {.pkg geodata} or {.pkg elevatr}, or pass {.arg path}."
    )
  )
}
