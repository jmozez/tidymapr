#' Basemaps for study-site and diversity maps
#'
#' @description
#' `geo_basemap()` prepares a basemap for [plot_sites()] and [plot_geo()]
#' without sending users to ggmap or other non-tidy tools. The default
#' `"esri"` fetches ESRI World Imagery tiles for the study bbox (cached on
#' disk). Other tile providers: `"osm"`, `"carto"`, `"carto_dark"`,
#' `"esri_topo"`. `"coast"` draws Natural Earth land polygons over an ocean
#' fill (offline). Pass a `SpatRaster` or file path for a custom DEM /
#' hillshade. Online tiles use **maptiles** when installed, otherwise a
#' small XYZ downloader. If tiles cannot be fetched, the function falls
#' back to `"coast"` with a message. Attribution stays with the tile provider.
#'
#' @param x An `sf` object, a bbox numeric vector
#'   `c(xmin, ymin, xmax, ymax)`, or a data frame with lon/lat used only to
#'   set the extent.
#' @param basemap Basemap specification: `"esri"` (default; World Imagery),
#'   `"esri_topo"`, `"osm"`, `"carto"`, `"carto_dark"`, `"coast"` (Natural
#'   Earth land), `"none"`, a `SpatRaster`, or a file path.
#' @param coastline Optional `sf` polygons/lines used when
#'   `basemap = "coast"`.
#' @param lon,lat Coordinate columns when `x` is a plain data frame.
#' @param zoom Optional tile zoom. When `NULL`, chosen from the extent.
#' @param alpha Opacity of raster / tile layers.
#' @param crs Target CRS (default EPSG:4326).
#' @return A list with class `tmr_geo_basemap` containing ggplot2 layers and
#'   metadata (`provider`, `offline`). Add it to a ggplot with `+` via
#'   [ggplot2::ggplot()] helpers, or pass the same `basemap` value to
#'   [plot_sites()] / [plot_geo()].
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE) && requireNamespace("ggplot2", quietly = TRUE)
#' sites <- geo_example_sites("wilhelm")
#' bm <- geo_basemap(sites, basemap = "esri", lon = lon, lat = lat)
#' plot_sites(sites, lon, lat, basemap = "esri", colour = elevation_band)
geo_basemap <- function(x,
                        basemap = "esri",
                        coastline = NULL,
                        lon = lon,
                        lat = lat,
                        zoom = NULL,
                        alpha = 0.9,
                        crs = 4326) {
  rlang::check_installed("sf")
  rlang::check_installed("ggplot2")
  extent <- geo_basemap_extent(x, enquo(lon), enquo(lat), crs = crs)
  layers <- geo_basemap_layers(
    extent$bbox,
    basemap = basemap,
    coastline = coastline,
    zoom = zoom,
    alpha = alpha,
    crs = extent$crs
  )
  structure(
    list(
      layers = layers$layers,
      provider = layers$provider,
      offline = layers$offline,
      bbox = extent$bbox,
      uses_fill = layers$uses_fill
    ),
    class = "tmr_geo_basemap"
  )
}

#' Add a tidymapr basemap to a ggplot
#'
#' S3 method for [ggplot2::ggplot_add()] so that
#' `ggplot2::ggplot() + geo_basemap(...)` works. Not intended to be called
#' directly.
#'
#' @param object A `tmr_geo_basemap` from [geo_basemap()].
#' @param plot A ggplot object.
#' @param object_name Not used.
#' @return `plot` with basemap layers added.
#' @keywords internal
#' @exportS3Method ggplot2::ggplot_add
ggplot_add.tmr_geo_basemap <- function(object, plot, object_name) { # nolint: object_name_linter.
  for (ly in object$layers) {
    plot <- plot + ly
  }
  plot
}

geo_basemap_extent <- function(x, lon, lat, crs = 4326) {
  if (inherits(x, "sf")) {
    x <- sf::st_transform(x, crs)
    return(list(bbox = sf::st_bbox(x), crs = sf::st_crs(x)))
  }
  if (is.numeric(x) && length(x) == 4 && !is.null(names(x))) {
    bb <- sf::st_bbox(c(
      xmin = x[["xmin"]], ymin = x[["ymin"]],
      xmax = x[["xmax"]], ymax = x[["ymax"]]
    ), crs = sf::st_crs(crs))
    return(list(bbox = bb, crs = sf::st_crs(crs)))
  }
  if (is.numeric(x) && length(x) == 4) {
    bb <- sf::st_bbox(c(
      xmin = x[1], ymin = x[2], xmax = x[3], ymax = x[4]
    ), crs = sf::st_crs(crs))
    return(list(bbox = bb, crs = sf::st_crs(crs)))
  }
  tmr_check_data(x)
  lon_col <- tmr_pick(lon, x, "lon")
  lat_col <- tmr_pick(lat, x, "lat")
  ok <- is.finite(x[[lon_col]]) & is.finite(x[[lat_col]])
  if (!any(ok)) {
    cli::cli_abort("No finite coordinates to set the basemap extent.")
  }
  bb <- sf::st_bbox(c(
    xmin = min(x[[lon_col]][ok]),
    ymin = min(x[[lat_col]][ok]),
    xmax = max(x[[lon_col]][ok]),
    ymax = max(x[[lat_col]][ok])
  ), crs = sf::st_crs(crs))
  # Expand slightly so points are not on the edge
  dx <- max((bb["xmax"] - bb["xmin"]) * 0.15, 0.05)
  dy <- max((bb["ymax"] - bb["ymin"]) * 0.15, 0.05)
  bb["xmin"] <- bb["xmin"] - dx
  bb["xmax"] <- bb["xmax"] + dx
  bb["ymin"] <- bb["ymin"] - dy
  bb["ymax"] <- bb["ymax"] + dy
  list(bbox = bb, crs = sf::st_crs(crs))
}

geo_basemap_layers <- function(bbox,
                               basemap = "esri",
                               coastline = NULL,
                               zoom = NULL,
                               alpha = 0.9,
                               crs = 4326) {
  # User raster / path
  if (inherits(basemap, "SpatRaster") ||
    (is.character(basemap) && length(basemap) == 1 &&
      !basemap %in% c(
        "none", "coast", "osm", "carto", "carto_dark", "esri", "esri_topo"
      ) &&
      (file.exists(basemap) || grepl("\\.(tif|tiff|nc|grd)$", basemap, ignore.case = TRUE)))) {
    rlang::check_installed("terra")
    r <- geo_as_raster(basemap)[[1]]
    rdf <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)
    zname <- setdiff(names(rdf), c("x", "y"))[1]
    return(list(
      layers = list(
        ggplot2::geom_raster(
          data = rdf,
          ggplot2::aes(.data$x, .data$y, fill = .data[[zname]]),
          alpha = alpha
        ),
        ggplot2::scale_fill_viridis_c(
          name = zname, option = "C",
          guide = ggplot2::guide_colourbar(order = 1)
        )
      ),
      provider = "raster",
      offline = TRUE,
      uses_fill = TRUE
    ))
  }

  if (!is.character(basemap) || length(basemap) != 1) {
    cli::cli_abort(
      "{.arg basemap} must be {.val none}, {.val coast}, a tile name,
      a SpatRaster, or a file path."
    )
  }
  basemap <- tolower(basemap)

  if (identical(basemap, "none")) {
    return(list(layers = list(), provider = "none", offline = TRUE, uses_fill = FALSE))
  }

  if (identical(basemap, "coast")) {
    return(list(
      layers = geo_coast_layers(bbox, coastline = coastline, crs = crs),
      provider = "coast",
      offline = TRUE,
      uses_fill = FALSE
    ))
  }

  tile_providers <- c(
    osm = "OpenStreetMap",
    carto = "CartoDB.Positron",
    carto_dark = "CartoDB.DarkMatter",
    esri = "Esri.WorldImagery",
    esri_topo = "Esri.WorldTopoMap"
  )
  if (!basemap %in% names(tile_providers)) {
    cli::cli_abort(
      "Unknown basemap {.val {basemap}}. Use {.val none}, {.val coast},
      {.val osm}, {.val carto}, {.val carto_dark}, {.val esri},
      {.val esri_topo}, a raster, or a file path."
    )
  }

  tiles <- geo_fetch_tiles(
    bbox,
    provider = tile_providers[[basemap]],
    zoom = zoom,
    crs = crs
  )
  if (is.null(tiles)) {
    cli::cli_inform(
      "Could not fetch {.val {basemap}} tiles; falling back to {.val coast}."
    )
    return(list(
      layers = geo_coast_layers(bbox, coastline = coastline, crs = crs),
      provider = "coast",
      offline = TRUE,
      uses_fill = FALSE
    ))
  }
  list(
    layers = geo_tile_layers(tiles, alpha = alpha),
    provider = basemap,
    offline = FALSE,
    uses_fill = FALSE
  )
}

geo_coast_layers <- function(bbox, coastline = NULL, crs = 4326) {
  # Expand the ocean panel slightly so the neatline is not flush with land
  bb <- bbox
  dx <- max((unname(bb["xmax"]) - unname(bb["xmin"])) * 0.05, 0.02)
  dy <- max((unname(bb["ymax"]) - unname(bb["ymin"])) * 0.05, 0.02)
  bb["xmin"] <- unname(bb["xmin"]) - dx
  bb["xmax"] <- unname(bb["xmax"]) + dx
  bb["ymin"] <- unname(bb["ymin"]) - dy
  bb["ymax"] <- unname(bb["ymax"]) + dy
  ocean <- sf::st_as_sf(sf::st_as_sfc(bb, crs = crs))
  layers <- list(
    ggplot2::geom_sf(
      data = ocean,
      fill = "#b7d2e8",
      colour = NA,
      inherit.aes = FALSE
    )
  )
  if (is.null(coastline)) {
    coastline <- geo_default_land_poly(bbox, crs = crs)
  } else if (!inherits(coastline, "sf")) {
    cli::cli_abort("{.arg coastline} must be an sf object.")
  } else {
    coastline <- sf::st_transform(coastline, crs)
  }
  # Crop land to a padded bbox so large country polygons do not dominate
  land_bb <- sf::st_as_sfc(bb, crs = crs)
  coastline <- tryCatch(
    suppressWarnings(sf::st_crop(sf::st_make_valid(coastline), land_bb)),
    error = function(e) coastline
  )
  layers <- c(layers, list(
    ggplot2::geom_sf(
      data = coastline,
      fill = "#e8e0d0",
      colour = "#5a5248",
      linewidth = 0.35,
      inherit.aes = FALSE
    )
  ))
  layers
}

# Real land polygons for the study extent (Natural Earth when available).
# Never return a plain rectangle pretending to be coast.
geo_default_land_poly <- function(bbox, crs = 4326) {
  land <- NULL
  if (requireNamespace("rnaturalearth", quietly = TRUE)) {
    land <- tryCatch(
      rnaturalearth::ne_countries(scale = "medium", returnclass = "sf"),
      error = function(e) NULL
    )
    if (is.null(land)) {
      land <- tryCatch(
        rnaturalearth::ne_coastline(scale = "medium", returnclass = "sf"),
        error = function(e) NULL
      )
    }
  }
  if (is.null(land) && requireNamespace("rnaturalearthdata", quietly = TRUE)) {
    land <- tryCatch(
      sf::st_as_sf(rnaturalearthdata::countries50),
      error = function(e) NULL
    )
  }
  if (is.null(land)) {
    cli::cli_warn(
      c(
        "No Natural Earth land data available; install {.pkg rnaturalearth}.",
        "i" = "Returning an empty land layer. Pass {.arg coastline} or use a tile basemap."
      )
    )
    return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  }
  land <- sf::st_transform(sf::st_make_valid(land), crs)
  # Expand crop window so coastline context is visible around sites
  bb <- bbox
  dx <- max((unname(bb["xmax"]) - unname(bb["xmin"])) * 0.6, 0.4)
  dy <- max((unname(bb["ymax"]) - unname(bb["ymin"])) * 0.6, 0.4)
  bb["xmin"] <- unname(bb["xmin"]) - dx
  bb["xmax"] <- unname(bb["xmax"]) + dx
  bb["ymin"] <- unname(bb["ymin"]) - dy
  bb["ymax"] <- unname(bb["ymax"]) + dy
  crop_win <- sf::st_as_sfc(bb, crs = crs)
  out <- tryCatch(
    suppressWarnings(sf::st_crop(land, crop_win)),
    error = function(e) land
  )
  if (nrow(out) == 0) {
    # Site bbox may be inland; keep intersecting countries by bbox filter
    hit <- sf::st_intersects(land, crop_win, sparse = FALSE)[, 1]
    out <- land[hit, , drop = FALSE]
  }
  out
}

geo_fetch_tiles <- function(bbox, provider, zoom = NULL, crs = 4326) {
  # Prefer maptiles when available; otherwise try a minimal XYZ fetch.
  if (requireNamespace("maptiles", quietly = TRUE) &&
        requireNamespace("terra", quietly = TRUE)) {
    cache <- file.path(
      tools::R_user_dir("tidymapr", "cache"), "maptiles"
    )
    dir.create(cache, recursive = TRUE, showWarnings = FALSE)
    out <- tryCatch(
      {
        x <- sf::st_as_sfc(bbox, crs = crs)
        # Expand slightly so tiles cover labels / scale bar margins
        x <- sf::st_buffer(sf::st_as_sf(x), dist = 0) # no-op; keep sfc
        maptiles::get_tiles(
          x = x,
          provider = provider,
          zoom = zoom,
          crop = TRUE,
          project = FALSE,
          cachedir = cache,
          verbose = FALSE
        )
      },
      error = function(e) NULL
    )
    if (!is.null(out)) {
      return(out)
    }
  }
  geo_fetch_tiles_xyz(bbox, provider = provider, zoom = zoom, crs = crs)
}

geo_fetch_tiles_xyz <- function(bbox, provider, zoom = NULL, crs = 4326) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    return(NULL)
  }
  # Tiny XYZ templates (raster tiles). Attribution remains with the provider.
  templates <- c(
    OpenStreetMap = "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    `CartoDB.Positron` =
      "https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
    `CartoDB.DarkMatter` =
      "https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png",
    `Esri.WorldImagery` = paste0(
      "https://server.arcgisonline.com/ArcGIS/rest/services/",
      "World_Imagery/MapServer/tile/{z}/{y}/{x}"
    ),
    `Esri.WorldTopoMap` = paste0(
      "https://server.arcgisonline.com/ArcGIS/rest/services/",
      "World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
    )
  )
  if (!provider %in% names(templates)) {
    return(NULL)
  }
  template <- templates[[provider]]
  xmin <- unname(bbox["xmin"])
  xmax <- unname(bbox["xmax"])
  ymin <- unname(bbox["ymin"])
  ymax <- unname(bbox["ymax"])
  if (is.null(zoom)) {
    span <- max(xmax - xmin, ymax - ymin)
    zoom <- if (span > 40) {
      3
    } else if (span > 10) {
      5
    } else if (span > 2) {
      7
    } else if (span > 0.5) {
      9
    } else {
      11
    }
  }
  # Limit tile count for safety
  tiles <- geo_xyz_tile_index(xmin, ymin, xmax, ymax, zoom)
  if (nrow(tiles) > 64) {
    cli::cli_inform("Basemap extent needs too many tiles; use a smaller area or set {.arg zoom}.")
    return(NULL)
  }
  tmp <- tempfile("tmr_tiles")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  files <- character(0)
  for (i in seq_len(nrow(tiles))) {
    url <- template
    url <- gsub("{z}", zoom, url, fixed = TRUE)
    url <- gsub("{x}", tiles$x[i], url, fixed = TRUE)
    url <- gsub("{y}", tiles$y[i], url, fixed = TRUE)
    dest <- file.path(tmp, sprintf("%s_%s.png", tiles$x[i], tiles$y[i]))
    ok <- tryCatch(
      {
        utils::download.file(url, dest, quiet = TRUE, mode = "wb")
        file.exists(dest) && file.info(dest)$size > 0
      },
      error = function(e) FALSE,
      warning = function(w) FALSE
    )
    if (!isTRUE(ok)) {
      return(NULL)
    }
    files <- c(files, dest)
  }
  # Build a SpatRaster mosaic in Web Mercator then project if needed
  rasters <- lapply(seq_along(files), function(i) {
    r <- suppressWarnings(terra::rast(files[i]))
    # Approximate geographic extent of the XYZ tile
    e <- geo_xyz_tile_extent(tiles$x[i], tiles$y[i], zoom)
    terra::ext(r) <- terra::ext(e[1], e[2], e[3], e[4])
    terra::crs(r) <- "EPSG:4326"
    r
  })
  tryCatch(
    suppressWarnings(terra::merge(terra::sprc(rasters))),
    error = function(e) NULL
  )
}

geo_xyz_tile_index <- function(xmin, ymin, xmax, ymax, zoom) {
  n <- 2^zoom
  lon_to_x <- function(lon) floor((lon + 180) / 360 * n)
  lat_to_y <- function(lat) {
    lat <- pmax(pmin(lat, 85.0511), -85.0511)
    rad <- lat * pi / 180
    floor((1 - log(tan(rad) + 1 / cos(rad)) / pi) / 2 * n)
  }
  x0 <- max(0, lon_to_x(xmin))
  x1 <- min(n - 1, lon_to_x(xmax))
  y0 <- max(0, lat_to_y(ymax))
  y1 <- min(n - 1, lat_to_y(ymin))
  expand.grid(x = x0:x1, y = y0:y1)
}

geo_xyz_tile_extent <- function(x, y, zoom) {
  n <- 2^zoom
  lon_min <- x / n * 360 - 180
  lon_max <- (x + 1) / n * 360 - 180
  lat_rad_max <- atan(sinh(pi * (1 - 2 * y / n)))
  lat_rad_min <- atan(sinh(pi * (1 - 2 * (y + 1) / n)))
  # terra::ext(numeric) is xmin, xmax, ymin, ymax
  c(lon_min, lon_max, lat_rad_min * 180 / pi, lat_rad_max * 180 / pi)
}

geo_tile_layers <- function(tiles, alpha = 0.9) {
  # RGB SpatRaster from maptiles / XYZ: plot with annotation_raster
  if (!inherits(tiles, "SpatRaster")) {
    return(list())
  }
  e <- terra::ext(tiles)
  # Convert to a raster array for ggplot
  if (terra::nlyr(tiles) >= 3) {
    arr <- terra::as.array(tiles[[1:3]])
    # Values may be 0-1 or 0-255
    mx <- max(arr, na.rm = TRUE)
    if (is.finite(mx) && mx > 1.5) {
      arr <- arr / 255
    }
    arr[is.na(arr)] <- 1
    arr <- pmin(pmax(arr, 0), 1)
    # Soften with alpha against white
    if (is.finite(alpha) && alpha < 1) {
      arr <- alpha * arr + (1 - alpha) * 1
    }
    img <- grDevices::rgb(arr[, , 1], arr[, , 2], arr[, , 3])
    dim(img) <- dim(arr)[1:2]
    img <- t(img)[, rev(seq_len(nrow(img))), drop = FALSE] # annotation_raster
    list(ggplot2::annotation_raster(
      img,
      xmin = e$xmin, xmax = e$xmax,
      ymin = e$ymin, ymax = e$ymax,
      interpolate = TRUE
    ))
  } else {
    rdf <- terra::as.data.frame(tiles, xy = TRUE, na.rm = TRUE)
    zname <- setdiff(names(rdf), c("x", "y"))[1]
    list(ggplot2::geom_raster(
      data = rdf,
      ggplot2::aes(.data$x, .data$y, fill = .data[[zname]]),
      alpha = alpha
    ))
  }
}
