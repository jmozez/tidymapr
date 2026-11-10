#' Satellite imagery from STAC catalogues
#'
#' @description
#' Search and read satellite imagery from any STAC API (SpatioTemporal Asset
#' Catalog), such as Element 84 Earth Search, which serves Sentinel-2,
#' Landsat and Copernicus DEM data as cloud-optimised GeoTIFFs:
#'
#' * `geo_stac_collections()` lists the collections a catalogue offers.
#' * `geo_stac_search()` finds the scenes of a collection over an area and a
#'   period, with a cloud cover limit, and returns their footprints as an
#'   `sf` table, clearest first.
#' * `geo_stac_read()` reads chosen bands of those scenes into a
#'   `SpatRaster`. Only the window over your area is downloaded (GDAL reads
#'   cloud-optimised GeoTIFFs over HTTP), the scale and offset stored in the
#'   catalogue are applied, so Sentinel-2 bands come out as surface
#'   reflectance from 0 to about 1 (negative values from the offset are set
#'   to 0), and several scenes are combined into a
#'   per-pixel median, which removes most clouds.
#'
#' The result goes straight into [geo_spectral_index()],
#' [geo_spectral_diversity()] or [map_raster()].
#'
#' @param url Root URL of a STAC API. Default: Element 84 Earth Search.
#' @param collection Collection id, for example `"sentinel-2-l2a"`,
#'   `"landsat-c2-l2"` or `"cop-dem-glo-30"`.
#' @param area Area of interest: an `sf` or terra object, or
#'   `c(xmin, ymin, xmax, ymax)` in degrees.
#' @param datetime Period: two dates (`c("2024-06-01", "2024-08-31")`) or one.
#' @param cloud_cover Largest cloud cover (percent) to accept; `NULL` for
#'   collections without cloud cover.
#' @param limit Largest number of scenes to return.
#' @param items Scenes from `geo_stac_search()`.
#' @param assets Bands to read, by asset name, for example
#'   `c("red", "nir")` for Sentinel-2 on Earth Search.
#' @param n Number of scenes to combine (the clearest first). One scene is
#'   read as is; several are combined into the per-pixel median.
#' @param crs Coordinate reference system of the result; by default that of
#'   the first scene.
#' @param scale Apply the scale and offset stored in the catalogue?
#' @return `geo_stac_collections()`: a tibble of `id`, `title`.
#'   `geo_stac_search()`: an `sf` table with one row per scene (`id`,
#'   `datetime`, `cloud_cover`, `platform`, `assets`). `geo_stac_read()`: a
#'   `SpatRaster` with one layer per asset.
#' @name geo-stac
#' @seealso [geo_spectral_index()], [map_raster()].
#' @examplesIf interactive() && rlang::is_installed(c("httr2", "terra", "sf"))
#' # Sentinel-2 over Luxembourg City, summer 2024
#' lux <- c(6.08, 49.57, 6.18, 49.65)
#' scenes <- geo_stac_search("sentinel-2-l2a", lux,
#'   datetime = c("2024-06-01", "2024-08-31"), cloud_cover = 10
#' )
#' scenes
#' img <- geo_stac_read(scenes, c("red", "nir"), area = lux, n = 3)
#' ndvi <- geo_spectral_index(img, "NDVI")
#' geo_map(title = "NDVI, Luxembourg City, summer 2024") |>
#'   map_raster(ndvi, name = "NDVI", palette = "Greens 3")
NULL

tmr_stac_default <- "https://earth-search.aws.element84.com/v1"

#' @rdname geo-stac
#' @export
geo_stac_collections <- function(url = tmr_stac_default) {
  rlang::check_installed("httr2")
  resp <- tmr_stac_get(paste0(sub("/$", "", url), "/collections"))
  cols <- resp$collections
  tibble::tibble(
    id = vapply(cols, function(x) x$id %||% NA_character_, ""),
    title = vapply(cols, function(x) x$title %||% NA_character_, "")
  )
}

#' @rdname geo-stac
#' @export
geo_stac_search <- function(collection,
                            area,
                            datetime = NULL,
                            cloud_cover = 20,
                            limit = 50,
                            url = tmr_stac_default) {
  rlang::check_installed(c("httr2", "sf"))
  if (!is.character(collection) || length(collection) != 1) {
    cli::cli_abort("{.arg collection} must be one collection id, such as {.val sentinel-2-l2a}.")
  }
  tmr_check_number(limit, "limit", 1, 10000)
  body <- list(
    collections = list(collection),
    bbox = as.numeric(tmr_stac_bbox(area)),
    limit = as.integer(min(limit, 250))
  )
  if (!is.null(datetime)) body$datetime <- tmr_stac_datetime(datetime)
  if (!is.null(cloud_cover)) {
    tmr_check_number(cloud_cover, "cloud_cover", 0, 100)
    body$query <- list(`eo:cloud_cover` = list(lt = cloud_cover))
  }
  feats <- list()
  next_url <- paste0(sub("/$", "", url), "/search")
  next_body <- body
  while (!is.null(next_url) && length(feats) < limit) {
    resp <- tmr_stac_post(next_url, next_body)
    feats <- c(feats, resp$features)
    nxt <- Filter(function(l) identical(l$rel, "next"), resp$links %||% list())
    if (!length(nxt)) break
    next_url <- nxt[[1]]$href
    next_body <- nxt[[1]]$body %||% next_body
  }
  feats <- utils::head(feats, limit)
  if (!length(feats)) {
    cli::cli_inform("No scenes of {.val {collection}} match; widen the period or the cloud limit.")
  }
  tmr_stac_items(feats)
}

#' @rdname geo-stac
#' @export
geo_stac_read <- function(items,
                          assets,
                          area = NULL,
                          n = 1,
                          crs = NULL,
                          scale = TRUE) {
  rlang::check_installed(c("terra", "sf"))
  if (!inherits(items, "sf") || !"assets" %in% names(items)) {
    cli::cli_abort("{.arg items} must come from {.fn geo_stac_search}.")
  }
  if (!nrow(items)) cli::cli_abort("{.arg items} has no scenes.")
  tmr_check_number(n, "n", 1, 100)
  missing <- setdiff(assets, names(items$assets[[1]]))
  if (length(missing)) {
    cli::cli_abort(c(
      "Asset{?s} {.val {missing}} not found.",
      i = "Available: {.val {names(items$assets[[1]])}}."
    ))
  }
  use <- utils::head(items, n)
  # Read every band of every scene (only the window over the area)
  scenes <- lapply(seq_len(nrow(use)), function(i) {
    lapply(assets, function(a) {
      tmr_stac_band(use$assets[[i]][[a]], area, NULL, scale,
        skip_offset = isTRUE(use$offset_applied[i])
      )
    })
  })
  # One grid for all: the first scene's projection at the finest
  # resolution, covering the whole area (or the union of the scenes)
  first <- scenes[[1]][[which.min(vapply(scenes[[1]], function(b) terra::res(b)[1], 1))]]
  target_crs <- if (is.null(crs)) terra::crs(first) else sf::st_crs(crs)$wkt
  res <- terra::res(first)[1]
  if (!is.null(crs)) res <- terra::res(terra::project(first, target_crs))[1]
  if (!is.null(area)) {
    bb <- tmr_stac_bbox(area)
    ext <- terra::ext(terra::project(
      terra::as.polygons(terra::ext(bb[c(1, 3, 2, 4)]), crs = "EPSG:4326"),
      target_crs
    ))
  } else {
    exts <- lapply(scenes, function(s) terra::ext(terra::project(s[[1]], target_crs)))
    ext <- Reduce(terra::union, exts)
  }
  template <- terra::rast(ext, resolution = res, crs = target_crs)
  on_grid <- function(b) {
    if (!terra::same.crs(b, template)) b <- terra::project(b, template, method = "bilinear")
    terra::resample(b, template, method = "bilinear")
  }
  out <- lapply(seq_along(assets), function(k) {
    layers <- lapply(scenes, function(s) on_grid(s[[k]]))
    if (length(layers) == 1) return(layers[[1]])
    # Several scenes (other tiles or dates): per-pixel median, so tile
    # edges fill in and clouds drop out
    terra::app(do.call(c, layers), stats::median, na.rm = TRUE)
  })
  out <- do.call(c, out)
  names(out) <- assets
  out
}

# ---- internals ------------------------------------------------------------

tmr_stac_get <- function(url) {
  req <- httr2::request(url) |>
    httr2::req_user_agent("tidymapr (R package)") |>
    httr2::req_retry(max_tries = 3)
  httr2::resp_body_json(httr2::req_perform(req), simplifyVector = FALSE)
}

tmr_stac_post <- function(url, body) {
  req <- httr2::request(url) |>
    httr2::req_user_agent("tidymapr (R package)") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_retry(max_tries = 3)
  httr2::resp_body_json(httr2::req_perform(req), simplifyVector = FALSE)
}

# Area of interest as a lon/lat bbox
tmr_stac_bbox <- function(area, call = caller_env()) {
  if (is.numeric(area) && length(area) == 4) {
    bb <- stats::setNames(as.numeric(area), c("xmin", "ymin", "xmax", "ymax"))
    bad <- bb[["xmin"]] >= bb[["xmax"]] || bb[["ymin"]] >= bb[["ymax"]] ||
      any(abs(bb[c(1, 3)]) > 180) || any(abs(bb[c(2, 4)]) > 90)
    if (bad) {
      cli::cli_abort(
        "{.arg area} must be {.code c(xmin, ymin, xmax, ymax)} in degrees.",
        call = call
      )
    }
    return(bb)
  }
  if (inherits(area, c("SpatRaster", "SpatVector"))) {
    e <- terra::project(terra::as.polygons(terra::ext(area), crs = terra::crs(area)), "EPSG:4326")
    v <- as.vector(terra::ext(e))[c(1, 3, 2, 4)]
    return(stats::setNames(v, c("xmin", "ymin", "xmax", "ymax")))
  }
  if (inherits(area, c("sf", "sfc", "bbox"))) {
    g <- if (inherits(area, "bbox")) sf::st_as_sfc(area) else sf::st_geometry(area)
    bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(g)), 4326))
    return(stats::setNames(as.numeric(bb), c("xmin", "ymin", "xmax", "ymax")))
  }
  cli::cli_abort(
    "{.arg area} must be an sf or terra object, or {.code c(xmin, ymin, xmax, ymax)} in degrees.",
    call = call
  )
}

tmr_stac_datetime <- function(x, call = caller_env()) {
  d <- tryCatch(as.Date(x), error = function(e) NULL)
  if (is.null(d) || anyNA(d) || !length(d) %in% 1:2) {
    cli::cli_abort(
      "{.arg datetime} must be one or two dates, such as {.val 2024-06-01}.",
      call = call
    )
  }
  if (length(d) == 1) d <- c(d, d)
  sprintf("%sT00:00:00Z/%sT23:59:59Z", format(min(d)), format(max(d)))
}

# STAC features as an sf table of footprints, clearest first
tmr_stac_items <- function(feats) {
  empty <- sf::st_sf(
    id = character(), datetime = as.POSIXct(character(), tz = "UTC"),
    cloud_cover = numeric(), platform = character(), offset_applied = logical(),
    assets = list(),
    geometry = sf::st_sfc(crs = 4326)
  )
  if (!length(feats)) return(empty)
  geoms <- lapply(feats, function(f) {
    g <- f$geometry
    to_ring <- function(r) do.call(rbind, lapply(r, function(p) as.numeric(unlist(p))[1:2]))
    if (identical(g$type, "Polygon")) {
      sf::st_polygon(lapply(g$coordinates, to_ring))
    } else {
      sf::st_multipolygon(lapply(g$coordinates, function(pl) lapply(pl, to_ring)))
    }
  })
  out <- sf::st_sf(
    id = vapply(feats, function(f) f$id, ""),
    datetime = as.POSIXct(
      vapply(feats, function(f) f$properties$datetime %||% NA_character_, ""),
      format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"
    ),
    cloud_cover = vapply(feats, function(f) as.numeric(f$properties$`eo:cloud_cover` %||% NA), 1),
    platform = vapply(feats, function(f) f$properties$platform %||% NA_character_, ""),
    # Earth Search marks Sentinel-2 files whose values already have the
    # bottom-of-atmosphere offset applied; the offset must then be skipped
    offset_applied = vapply(feats, function(f) {
      isTRUE(f$properties$`earthsearch:boa_offset_applied`)
    }, TRUE),
    assets = I(lapply(feats, function(f) f$assets)),
    geometry = sf::st_sfc(geoms, crs = 4326)
  )
  out <- out[order(out$cloud_cover, -as.numeric(out$datetime), na.last = TRUE), ]
  rownames(out) <- NULL
  tibble::as_tibble(out) |> sf::st_as_sf()
}

# One band of one scene: a windowed read of a cloud-optimised GeoTIFF
tmr_stac_band <- function(asset, area, crs, scale, skip_offset = FALSE) {
  href <- asset$href
  if (grepl("^s3://", href)) {
    href <- sub("^s3://([^/]+)/", "https://\\1.s3.amazonaws.com/", href)
  }
  r <- terra::rast(paste0("/vsicurl/", href))
  if (!is.null(area)) {
    bb <- tmr_stac_bbox(area)
    box <- terra::project(
      terra::as.polygons(terra::ext(bb[c(1, 3, 2, 4)]), crs = "EPSG:4326"),
      terra::crs(r)
    )
    r <- terra::crop(r, box, snap = "out")
  }
  r <- r * 1
  if (isTRUE(scale)) {
    rb <- asset$`raster:bands`
    if (length(rb)) {
      sc <- as.numeric(rb[[1]]$scale %||% 1)
      of <- if (skip_offset) 0 else as.numeric(rb[[1]]$offset %||% 0)
      nd <- rb[[1]]$nodata
      if (!is.null(nd)) r[r == as.numeric(nd)] <- NA
      if (sc != 1 || of != 0) {
        r <- r * sc + of
        # The offset can push the darkest pixels below zero: clamp, since
        # reflectance cannot be negative
        r <- terra::clamp(r, lower = 0, values = TRUE)
      }
    }
  }
  if (!is.null(crs)) r <- terra::project(r, sf::st_crs(crs)$wkt)
  r
}
