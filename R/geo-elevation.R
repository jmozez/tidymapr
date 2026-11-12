#' Download or read elevation (SRTM-style DEM)
#'
#' Fetches a digital elevation model for a bounding box or set of sites,
#' with an on-disk cache, or reads local files.
#'
#' **Local files.** `path` may be one raster file or a folder of tiles:
#' GeoTIFF (`.tif`), SRTM height files (`.hgt`, also gzipped `.hgt.gz`) or
#' `.zip` archives containing them. Adjacent tiles are mosaicked into one
#' surface (earlier versions kept only the first tile). A warning is given
#' when tiles differ in coordinate reference system or resolution.
#'
#' **Download.** Every 1 x 1 degree SRTM tile that intersects the bounding
#' box is fetched (1 arc-second where available, from the public
#' "skadi" archive of the AWS Terrain Tiles), cached in `cache_dir`,
#' mosaicked and cropped to the box. If that archive cannot be reached,
#' the tiles of **geodata** (`elevation_3s()`, every tile intersecting the
#' box) or **elevatr** are used. Cite NASA SRTM (Farr et al. 2007) when
#' publishing maps that use these surfaces.
#'
#' @param data Optional data frame of sites with `lon`/`lat` used to build
#'   the bounding box when `bbox` is `NULL`.
#' @param lon,lat Coordinate columns of `data`.
#' @param bbox Numeric vector `c(xmin, ymin, xmax, ymax)` in WGS84 (the
#'   order of [sf::st_bbox()], not of [terra::ext()]), or an `sf`,
#'   `SpatExtent` or `SpatRaster` object.
#' @param path Local raster file, folder of tiles, or vector of files.
#' @param cache_dir Cache directory. Defaults to
#'   `tools::R_user_dir("tidymapr", "cache")/elevation`.
#' @param download Download when the cache is empty? Set `FALSE` on CRAN
#'   or offline runners.
#' @param z Zoom / resolution hint for elevatr (1-14), the last fallback.
#' @param buffer Extra degrees added around the site bbox (default 0.1).
#' @return A one-layer `terra::SpatRaster` elevation surface (metres).
#' @references
#' Farr, T. G. et al. (2007). The Shuttle Radar Topography Mission.
#' Reviews of Geophysics, 45, RG2004. \doi{10.1029/2005RG000183}
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
  bb <- geo_elevation_bbox(data,
    lon = {{ lon }}, lat = {{ lat }},
    bbox = bbox, buffer = buffer
  )
  cache_dir <- cache_dir %||% file.path(
    tools::R_user_dir("tidymapr", "cache"), "elevation"
  )
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  key <- sprintf(
    "elev_%.4f_%.4f_%.4f_%.4f_z%s.tif",
    bb[1], bb[2], bb[3], bb[4], as.character(z)
  )
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
  files <- if (length(path) == 1 && dir.exists(path)) {
    list.files(path,
      pattern = "\\.(tif|tiff|hgt|hgt\\.gz|zip|grd|nc)$",
      full.names = TRUE, ignore.case = TRUE
    )
  } else {
    path
  }
  if (length(files) == 0) {
    cli::cli_abort("No raster files found in {.path {path}}.")
  }
  missing <- files[!file.exists(files)]
  if (length(missing)) {
    cli::cli_abort("File{?s} not found: {.path {missing}}.")
  }
  files <- unlist(lapply(files, tmr_unpack_tile), use.names = FALSE)
  r <- tmr_mosaic(files)
  names(r) <- "elevation"
  r
}

# Unzip or gunzip a tile into a temporary folder; return raster file paths.
tmr_unpack_tile <- function(f) {
  if (grepl("\\.zip$", f, ignore.case = TRUE)) {
    d <- file.path(tempdir(), paste0("tmr_tile_", tools::file_path_sans_ext(basename(f))))
    utils::unzip(f, exdir = d)
    return(list.files(d, "\\.(hgt|tif|tiff)$",
      full.names = TRUE,
      ignore.case = TRUE, recursive = TRUE
    ))
  }
  if (grepl("\\.gz$", f, ignore.case = TRUE)) {
    out <- file.path(tempdir(), sub("\\.gz$", "", basename(f), ignore.case = TRUE))
    if (!file.exists(out)) {
      con <- gzfile(f, "rb")
      on.exit(close(con))
      bin <- readBin(con, "raw", n = 1e9)
      writeBin(bin, out)
    }
    return(out)
  }
  f
}

# Mosaic adjacent tiles into one layer, warning on CRS or resolution
# mismatches (each tile keeps its own grid; the mosaic uses the first).
tmr_mosaic <- function(files) {
  rs <- lapply(files, function(f) terra::rast(f)[[1]])
  if (length(rs) == 1) {
    return(rs[[1]])
  }
  crs <- vapply(
    rs, function(r) terra::crs(r, describe = TRUE)$code %||% terra::crs(r),
    character(1)
  )
  if (length(unique(crs)) > 1) {
    cli::cli_warn("Tiles have different coordinate reference systems; they are \\
      projected to that of the first tile.")
    rs <- lapply(rs, function(r) {
      if (terra::same.crs(r, rs[[1]])) r else terra::project(r, rs[[1]])
    })
  }
  res <- t(vapply(rs, terra::res, numeric(2)))
  if (any(abs(sweep(res, 2, res[1, ])) > 1e-9 * max(res))) {
    cli::cli_warn("Tiles have different resolutions; the mosaic uses \\
      {.val {signif(res[1, 1], 4)}} x {.val {signif(res[1, 2], 4)}}.")
  }
  if (all(abs(sweep(res, 2, res[1, ])) <= 1e-9 * max(res))) {
    return(terra::merge(terra::sprc(rs)))
  }
  terra::mosaic(terra::sprc(lapply(rs, function(r) terra::resample(r, rs[[1]]))), fun = "mean")
}

geo_elevation_bbox <- function(data, lon, lat, bbox, buffer) {
  if (!is.null(bbox)) {
    if (inherits(bbox, "sf") || inherits(bbox, "sfc")) {
      rlang::check_installed("sf")
      b <- sf::st_bbox(sf::st_transform(bbox, 4326))
      return(c(b["xmin"], b["ymin"], b["xmax"], b["ymax"]))
    }
    if (inherits(bbox, c("SpatExtent", "SpatRaster", "SpatVector"))) {
      e <- terra::ext(bbox)
      return(c(e$xmin, e$ymin, e$xmax, e$ymax))
    }
    if (is.numeric(bbox) && length(bbox) == 4) {
      return(as.numeric(bbox))
    }
    cli::cli_abort(
      "{.arg bbox} must be c(xmin, ymin, xmax, ymax), sf, or a terra extent or raster."
    )
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
  out <- tryCatch(geo_srtm_tiles(bb, cache_dir), error = function(e) NULL)
  if (!is.null(out)) {
    return(out)
  }
  if (requireNamespace("geodata", quietly = TRUE)) {
    out <- tryCatch(
      {
        # elevation_3s() serves 5 x 5 degree tiles: fetch every one the box
        # intersects, not only the one at its centre
        lons <- seq(bb[1], bb[3], length.out = max(2, ceiling((bb[3] - bb[1]) / 5) + 1))
        lats <- seq(bb[2], bb[4], length.out = max(2, ceiling((bb[4] - bb[2]) / 5) + 1))
        pts <- unique(expand.grid(lon = lons, lat = lats))
        tiles <- lapply(seq_len(nrow(pts)), function(i) {
          geodata::elevation_3s(
            lon = pts$lon[i], lat = pts$lat[i],
            path = file.path(cache_dir, "geodata")
          )
        })
        keys <- vapply(tiles, function(t) paste(as.vector(terra::ext(t)), collapse = ","), "")
        r <- terra::merge(terra::sprc(tiles[!duplicated(keys)]))
        r <- terra::crop(r, terra::ext(bb[1], bb[3], bb[2], bb[4]))
        names(r) <- "elevation"
        r
      },
      error = function(e) NULL
    )
    if (!is.null(out)) {
      return(out)
    }
  }
  has_elevatr <- requireNamespace("elevatr", quietly = TRUE) &&
    requireNamespace("sf", quietly = TRUE)
  if (has_elevatr) {
    out <- tryCatch(
      {
        poly <- sf::st_as_sf(sf::st_as_sfc(sf::st_bbox(
          c(xmin = bb[1], ymin = bb[2], xmax = bb[3], ymax = bb[4]),
          crs = 4326
        )))
        r <- elevatr::get_elev_raster(poly, z = z, clip = "bbox")
        r <- terra::rast(r)
        names(r) <- "elevation"
        r
      },
      error = function(e) NULL
    )
    if (!is.null(out)) {
      return(out)
    }
  }
  cli::cli_abort(
    c(
      "Could not download elevation data.",
      "i" = "Check the internet connection, or pass {.arg path} to local tiles."
    )
  )
}

#' Names of the 1 x 1 degree SRTM tiles that intersect a bounding box
#'
#' SRTM tiles are named after their south-west corner, for example
#' `S07E146` for the tile from 7 to 6 degrees S and 146 to 147 degrees E.
#'
#' @param bbox `c(xmin, ymin, xmax, ymax)` in degrees.
#' @return Character vector of tile names.
#' @export
#' @examples
#' geo_srtm_tile_names(c(145.4, -7, 147.3, -5.5))
geo_srtm_tile_names <- function(bbox) {
  bbox <- as.numeric(bbox)
  eps <- 1e-9
  lons <- seq(floor(bbox[1]), ceiling(bbox[3] - eps) - 1)
  lats <- seq(floor(bbox[2]), ceiling(bbox[4] - eps) - 1)
  g <- expand.grid(lon = lons, lat = lats)
  sprintf(
    "%s%02d%s%03d",
    ifelse(g$lat < 0, "S", "N"), abs(g$lat),
    ifelse(g$lon < 0, "W", "E"), abs(g$lon)
  )
}

# Download (with caching) every SRTM tile intersecting `bb`, mosaic, crop.
geo_srtm_tiles <- function(bb, cache_dir,
                           base = "https://s3.amazonaws.com/elevation-tiles-prod/skadi") {
  tiles <- geo_srtm_tile_names(bb)
  dir.create(file.path(cache_dir, "srtm"), recursive = TRUE, showWarnings = FALSE)
  files <- vapply(tiles, function(t) {
    dest <- file.path(cache_dir, "srtm", paste0(t, ".hgt.gz"))
    if (!file.exists(dest)) {
      url <- sprintf("%s/%s/%s.hgt.gz", base, substr(t, 1, 3), t)
      tmp <- paste0(dest, ".part")
      status <- utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
      if (status != 0) stop("download failed: ", url)
      file.rename(tmp, dest)
    }
    dest
  }, character(1))
  r <- geo_elevation_from_path(files)
  r <- terra::crop(r, terra::ext(bb[1], bb[3], bb[2], bb[4]))
  names(r) <- "elevation"
  r
}
