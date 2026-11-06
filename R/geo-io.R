#' Read and write spatial files through GDAL
#'
#' @description
#' Tidy readers and writers so you rarely need `sf::st_read()`,
#' `terra::rast()`, or raw GDAL utilities. [geo_read()] auto-detects raster
#' versus vector from the file extension (and GDAL driver when needed).
#' [geo_write()] picks a writer from the object type and the destination
#' extension. Format-specific twins [geo_vector_read()] / [geo_vector_write()]
#' and [geo_raster_read()] / [geo_raster_write()] are available when you
#' already know the type. All I/O goes through **sf** and **terra** (GDAL /
#' OGR under the hood). Do not use the retired **rgdal** package.
#'
#' Supported formats (read unless noted):
#'
#' | Format | Extensions | Type | Notes |
#' | --- | --- | --- | --- |
#' | GeoTIFF / COG | `.tif`, `.tiff` | raster | write supported |
#' | NetCDF | `.nc`, `.nc4` | raster | write when terra/GDAL allow |
#' | ASCII grid | `.asc`, `.grd` | raster | |
#' | GeoPackage | `.gpkg` | vector (or raster) | preferred vector write |
#' | Shapefile | `.shp` (+ sidecars) | vector | write supported |
#' | GeoJSON | `.geojson`, `.json` | vector | write supported |
#' | KML / KMZ | `.kml`, `.kmz` | vector | KMZ unzipped to KML |
#' | GML | `.gml` | vector | |
#' | FileGDB | `.gdb` | vector | when GDAL has OpenFileGDB/FileGDB |
#' | CSV / text | `.csv`, `.tsv`, `.txt` | vector | needs lon/lat columns |
#' | Occurrence tables | `.csv` etc. | vector | same as CSV via [geo_as_sf()] |
#'
#' Excel (`.xlsx`) is not supported here to avoid a heavy dependency; export
#' CSV first. GADM downloads use these writers for the on-disk cache; see
#' [geo_gadm()] for license notes (do not redistribute the full GADM database).
#'
#' Map figures from [plot_sites()], [plot_geo()], [plot_sdm()] and
#' [plot_topo()] are saved with [geo_save()] (or [tidydiversity::plot_save()]).
#'
#' @param path File path. The extension selects the format unless `driver`
#'   is set.
#' @param x Object to write: `sf`, `SpatRaster`, or a data frame with
#'   lon/lat columns for [geo_write()] / [geo_vector_write()].
#' @param data Vector object or table for [geo_vector_write()] (`sf` or
#'   a data frame with lon/lat columns).
#' @param raster A `terra::SpatRaster` (or coercible) for
#'   [geo_raster_write()].
#' @param type Force `"vector"` or `"raster"` in [geo_read()]; `NULL`
#'   auto-detects.
#' @param driver Optional GDAL/OGR driver name (for example `"GPKG"`,
#'   `"ESRI Shapefile"`, `"GeoJSON"`, `"GTiff"`, `"netCDF"`).
#' @param lon,lat Column names used when reading CSV/text or writing a
#'   non-`sf` table. Defaults try `lon`/`lat`, then `longitude`/`latitude`,
#'   then `x`/`y`.
#' @param layer Layer name for multi-layer containers (GeoPackage, GDB).
#' @param overwrite Overwrite an existing file? Default `FALSE`.
#' @param crs CRS assigned to lon/lat tables (default WGS84).
#' @param ... Passed to `sf::st_read()` / `sf::st_write()` or
#'   `terra::rast()` / `terra::writeRaster()`.
#' @return
#' * Readers: an `sf` tibble (`tmr_geo_sf`) or a `terra::SpatRaster`.
#' * Writers: `path`, invisibly.
#' @name geo-io
#' @seealso [geo_save()], [geo_gadm()], [as_sf()], [as_spat_raster()]
#' @examplesIf requireNamespace("sf", quietly = TRUE) && requireNamespace("terra", quietly = TRUE)
#' sites <- geo_example_sites("wilhelm")
#' gpkg <- tempfile(fileext = ".gpkg")
#' geo_write(sites, gpkg, overwrite = TRUE)
#' geo_read(gpkg)
#'
#' r <- terra::rast(
#'   ncols = 8, nrows = 8, xmin = 144.8, xmax = 145.4,
#'   ymin = -6, ymax = -5.5, crs = "EPSG:4326"
#' )
#' terra::values(r) <- seq_len(terra::ncell(r))
#' tif <- tempfile(fileext = ".tif")
#' geo_raster_write(r, tif, overwrite = TRUE)
#' geo_raster_read(tif)
NULL

# ---- format tables --------------------------------------------------------

geo_io_vector_ext <- function() {
  c(
    "gpkg", "shp", "geojson", "json", "kml", "kmz", "gml", "gdb",
    "csv", "tsv", "txt"
  )
}

geo_io_raster_ext <- function() {
  c("tif", "tiff", "nc", "nc4", "asc", "grd", "img", "bil", "bip", "bsq")
}

geo_io_ext <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (identical(ext, "gz")) {
    # e.g. file.tif.gz — peel once
    ext <- tolower(tools::file_ext(sub("\\.[Gg][Zz]$", "", path)))
  }
  ext
}

geo_io_guess_type <- function(path, type = NULL) {
  if (!is.null(type)) {
    type <- rlang::arg_match(type, c("vector", "raster"))
    return(type)
  }
  ext <- geo_io_ext(path)
  if (ext %in% geo_io_raster_ext()) return("raster")
  if (ext %in% geo_io_vector_ext()) return("vector")
  # GeoPackage can hold both; prefer vector unless driver says raster
  if (identical(ext, "gpkg") || identical(ext, "gdb")) {
    return("vector")
  }
  # Probe with sf first, then terra
  if (requireNamespace("sf", quietly = TRUE) && file.exists(path)) {
    ok <- tryCatch({
      sf::st_read(path, quiet = TRUE, query = "SELECT 1")
      TRUE
    }, error = function(e) FALSE)
    if (isTRUE(ok)) return("vector")
  }
  if (requireNamespace("terra", quietly = TRUE) && file.exists(path)) {
    ok <- tryCatch({
      r <- terra::rast(path)
      terra::nlyr(r) >= 1
    }, error = function(e) FALSE)
    if (isTRUE(ok)) return("raster")
  }
  cli::cli_abort(
    c(
      "Cannot detect whether {.path {path}} is vector or raster.",
      "i" = paste(
        "Pass {.arg type} = {.val vector} or {.val raster},",
        "or use {.fn geo_vector_read} / {.fn geo_raster_read}."
      )
    )
  )
}

geo_io_lonlat_cols <- function(data, lon = NULL, lat = NULL) {
  nms <- names(data)
  if (!is.null(lon) && !is.null(lat)) {
    return(c(lon, lat))
  }
  candidates <- list(
    c("lon", "lat"),
    c("longitude", "latitude"),
    c("lng", "lat"),
    c("long", "lat"),
    c("x", "y"),
    c("X", "Y"),
    c("decimalLongitude", "decimalLatitude")
  )
  for (pair in candidates) {
    if (all(pair %in% nms)) return(pair)
  }
  cli::cli_abort(
    c(
      "No lon/lat columns found.",
      "i" = "Pass {.arg lon} and {.arg lat}, or rename columns to lon/lat."
    )
  )
}

# ---- readers --------------------------------------------------------------

#' @rdname geo-io
#' @export
geo_read <- function(path,
                     type = NULL,
                     driver = NULL,
                     lon = NULL,
                     lat = NULL,
                     layer = NULL,
                     crs = 4326,
                     ...) {
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (!file.exists(path) && !geo_io_ext(path) %in% c("gdb")) {
    # .gdb is a directory data source
    if (!(dir.exists(path) && geo_io_ext(path) == "gdb")) {
      cli::cli_abort("File {.path {path}} does not exist.")
    }
  }
  kind <- geo_io_guess_type(path, type = type)
  if (identical(kind, "raster")) {
    geo_raster_read(path, driver = driver, ...)
  } else {
    geo_vector_read(
      path, driver = driver, lon = lon, lat = lat,
      layer = layer, crs = crs, ...
    )
  }
}

#' @rdname geo-io
#' @export
geo_vector_read <- function(path,
                            driver = NULL,
                            lon = NULL,
                            lat = NULL,
                            layer = NULL,
                            crs = 4326,
                            ...) {
  rlang::check_installed("sf")
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  ext <- geo_io_ext(path)

  # KMZ: unzip and read inner KML
  if (identical(ext, "kmz")) {
    return(geo_vector_read_kmz(path, layer = layer, crs = crs, ...))
  }

  # CSV / text occurrence tables
  if (ext %in% c("csv", "tsv", "txt")) {
    return(geo_vector_read_table(path, lon = lon, lat = lat, crs = crs, ...))
  }

  if (!file.exists(path) && !(dir.exists(path) && ext == "gdb")) {
    cli::cli_abort("Vector file {.path {path}} does not exist.")
  }

  # FileGDB: require driver
  if (identical(ext, "gdb")) {
    geo_io_require_driver(c("OpenFileGDB", "FileGDB"))
  }

  args <- list(dsn = path, quiet = TRUE, ...)
  if (!is.null(layer)) args$layer <- layer
  if (!is.null(driver)) args$driver <- driver
  out <- tryCatch(
    do.call(sf::st_read, args),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not read vector file {.path {path}}.",
          "x" = conditionMessage(e),
          "i" = "Check the path, layer name, and that GDAL has the right driver."
        )
      )
    }
  )
  if (!inherits(out, "sf")) {
    # Some drivers return data.frame without geometry — try lon/lat
    if (is.data.frame(out)) {
      out <- geo_vector_table_as_sf(out, lon = lon, lat = lat, crs = crs)
    } else {
      cli::cli_abort("GDAL did not return an sf table from {.path {path}}.")
    }
  }
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}

geo_vector_read_kmz <- function(path, layer = NULL, crs = 4326, ...) {
  tmp <- tempfile("tmr_kmz")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(path, exdir = tmp)
  kml <- list.files(tmp, pattern = "\\.kml$", full.names = TRUE, recursive = TRUE)
  if (length(kml) == 0) {
    cli::cli_abort("No KML found inside {.path {path}}.")
  }
  geo_vector_read(kml[[1]], layer = layer, crs = crs, ...)
}

geo_vector_read_table <- function(path, lon = NULL, lat = NULL, crs = 4326, ...) {
  ext <- geo_io_ext(path)
  sep <- if (identical(ext, "tsv")) "\t" else ","
  dots <- list(...)
  dots$path <- NULL
  args <- utils::modifyList(
    list(file = path, sep = sep, header = TRUE, stringsAsFactors = FALSE, check.names = FALSE),
    dots
  )
  # read.csv uses 'file'; read.table too
  tbl <- do.call(utils::read.table, args)
  tbl <- tibble::as_tibble(tbl)
  geo_vector_table_as_sf(tbl, lon = lon, lat = lat, crs = crs)
}

geo_vector_table_as_sf <- function(data, lon = NULL, lat = NULL, crs = 4326) {
  pair <- geo_io_lonlat_cols(data, lon = lon, lat = lat)
  geo_as_sf(
    data,
    lon = !!rlang::sym(pair[[1]]),
    lat = !!rlang::sym(pair[[2]]),
    crs = crs,
    drop_na = TRUE
  )
}

#' @rdname geo-io
#' @export
geo_raster_read <- function(path, driver = NULL, ...) {
  rlang::check_installed("terra")
  if (inherits(path, "SpatRaster")) {
    return(path)
  }
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path or a SpatRaster.")
  }
  if (!file.exists(path)) {
    cli::cli_abort("Raster file {.path {path}} does not exist.")
  }
  args <- list(x = path, ...)
  # terra::rast has no driver=; GDAL finds it. Accept driver for API symmetry.
  if (!is.null(driver)) {
    cli::cli_inform(
      "{.arg driver} is ignored for rasters; terra/GDAL detect it from {.path {path}}."
    )
  }
  tryCatch(
    terra::rast(path, ...),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not read raster {.path {path}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )
}

# ---- writers --------------------------------------------------------------

#' @rdname geo-io
#' @export
geo_write <- function(x,
                      path,
                      driver = NULL,
                      lon = NULL,
                      lat = NULL,
                      layer = NULL,
                      overwrite = FALSE,
                      crs = 4326,
                      ...) {
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (inherits(x, "SpatRaster") || inherits(x, "Raster")) {
    return(geo_raster_write(x, path, driver = driver, overwrite = overwrite, ...))
  }
  geo_vector_write(
    x, path, driver = driver, lon = lon, lat = lat,
    layer = layer, overwrite = overwrite, crs = crs, ...
  )
}

#' @rdname geo-io
#' @export
geo_vector_write <- function(data,
                             path,
                             driver = NULL,
                             lon = NULL,
                             lat = NULL,
                             layer = NULL,
                             overwrite = FALSE,
                             crs = 4326,
                             ...) {
  rlang::check_installed("sf")
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  ext <- geo_io_ext(path)
  if (file.exists(path) || (dir.exists(path) && ext == "shp")) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(
        c(
          "File {.path {path}} already exists and {.arg overwrite} is FALSE.",
          "i" = "Pass {.arg overwrite} = TRUE to replace it."
        )
      )
    }
  }

  # Promote tibbles with coordinates
  if (!inherits(data, "sf")) {
    if (ext %in% c("csv", "tsv", "txt")) {
      return(geo_vector_write_table(data, path, lon = lon, lat = lat, overwrite = overwrite, ...))
    }
    pair <- geo_io_lonlat_cols(data, lon = lon, lat = lat)
    data <- geo_as_sf(
      data,
      lon = !!rlang::sym(pair[[1]]),
      lat = !!rlang::sym(pair[[2]]),
      crs = crs,
      drop_na = TRUE
    )
  }

  if (ext %in% c("csv", "tsv", "txt")) {
    return(geo_vector_write_table(data, path, lon = lon, lat = lat, overwrite = overwrite, ...))
  }

  x <- data
  class(x) <- setdiff(class(x), "tmr_geo_sf")

  # Driver from extension when not set
  if (is.null(driver)) {
    driver <- geo_io_vector_driver(ext)
  }
  if (identical(ext, "gdb")) {
    geo_io_require_driver(c("OpenFileGDB", "FileGDB"))
  }

  # Shapefile sidecars: delete when overwriting
  if (isTRUE(overwrite) && identical(ext, "shp")) {
    geo_io_unlink_shapefile(path)
  }

  exists_already <- file.exists(path) || (identical(ext, "shp") && file.exists(path))
  args <- list(
    obj = x, dsn = path, quiet = TRUE,
    delete_dsn = isTRUE(overwrite) && exists_already,
    ...
  )
  if (!is.null(layer)) args$layer <- layer
  if (!is.null(driver)) args$driver <- driver
  tryCatch(
    do.call(sf::st_write, args),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not write vector file {.path {path}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )
  invisible(path)
}

geo_vector_write_table <- function(data, path, lon = NULL, lat = NULL,
                                   overwrite = FALSE, ...) {
  if (file.exists(path) && !isTRUE(overwrite)) {
    cli::cli_abort("File {.path {path}} already exists and {.arg overwrite} is FALSE.")
  }
  if (inherits(data, "sf")) {
    xy <- sf::st_coordinates(data)
    attrs <- geo_drop_geometry(data)
    # Prefer existing lon/lat names; else add lon/lat
    if (!all(c("lon", "lat") %in% names(attrs))) {
      attrs$lon <- xy[, 1]
      attrs$lat <- xy[, 2]
    }
    data <- attrs
  }
  ext <- geo_io_ext(path)
  sep <- if (identical(ext, "tsv")) "\t" else ","
  utils::write.table(
    data, file = path, sep = sep, row.names = FALSE, ...
  )
  invisible(path)
}

geo_io_vector_driver <- function(ext) {
  switch(
    ext,
    gpkg = "GPKG",
    shp = "ESRI Shapefile",
    geojson = "GeoJSON",
    json = "GeoJSON",
    kml = "KML",
    gml = "GML",
    gdb = "OpenFileGDB",
    NULL
  )
}

geo_io_unlink_shapefile <- function(path) {
  base <- sub("\\.shp$", "", path, ignore.case = TRUE)
  extras <- paste0(base, c(".shp", ".shx", ".dbf", ".prj", ".cpg", ".qpj", ".sbn", ".sbx"))
  unlink(extras)
}

geo_io_require_driver <- function(candidates) {
  rlang::check_installed("sf")
  have <- sf::st_drivers()$name
  if (!any(candidates %in% have)) {
    cli::cli_abort(
      c(
        "GDAL has no FileGDB driver in this build.",
        "i" = "Install a GDAL with OpenFileGDB, or export to GeoPackage instead."
      )
    )
  }
}

#' @rdname geo-io
#' @export
geo_raster_write <- function(raster,
                             path,
                             driver = NULL,
                             overwrite = FALSE,
                             ...) {
  rlang::check_installed("terra")
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path (for example a GeoTIFF).")
  }
  if (file.exists(path) && !isTRUE(overwrite)) {
    cli::cli_abort(
      c(
        "File {.path {path}} already exists and {.arg overwrite} is FALSE.",
        "i" = "Pass {.arg overwrite} = TRUE to replace it."
      )
    )
  }
  r <- geo_as_raster(raster)[[1]]
  ext <- geo_io_ext(path)
  if (is.null(driver)) {
    driver <- switch(
      ext,
      tif = "GTiff",
      tiff = "GTiff",
      nc = "netCDF",
      nc4 = "netCDF",
      asc = "AAIGrid",
      grd = "RRASTER",
      gpkg = "GPKG",
      NULL
    )
  }
  args <- list(x = r, filename = path, overwrite = isTRUE(overwrite), ...)
  # terra::writeRaster uses filetype= for GDAL driver in recent versions
  if (!is.null(driver)) {
    if ("filetype" %in% names(formals(terra::writeRaster))) {
      args$filetype <- driver
    } else {
      args$gdal <- c(args$gdal, paste0("COMPRESS=LZW"))
    }
  }
  tryCatch(
    do.call(terra::writeRaster, args),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not write raster {.path {path}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )
  invisible(path)
}

# ---- map figure save ------------------------------------------------------

#' Save a map figure (PNG, PDF, SVG, TIFF, JPEG)
#'
#' Writes ggplot maps from [plot_sites()], [plot_geo()], [plot_sdm()],
#' [plot_topo()] (or any ggplot / patchwork object) to disk. Format is taken
#' from the file extension. [geo_save()] is the geospatial-oriented name;
#' [tidydiversity::plot_save()] is the general journal-size helper (also used outside maps).
#'
#' @param plot A ggplot or patchwork map object.
#' @param path Output path. The extension selects the device
#'   (`.png`, `.pdf`, `.svg`, `.tiff`/`.tif`, `.jpg`/`.jpeg`).
#' @param width,height Size in `units`. For [geo_save()], defaults are
#'   180 mm wide and 140 mm tall (a comfortable single map panel).
#' @param units `"mm"`, `"cm"`, `"in"`, or `"px"`.
#' @param dpi Resolution for raster formats (default 300 for print).
#' @param bg Background colour (default `"white"`).
#' @param ... Passed to [ggplot2::ggsave()] (device-specific extras such as
#'   `compression`, `family`, or `useDingbats`).
#' @return `path`, invisibly.
#' @seealso [tidydiversity::plot_save()], [geo_write()], [plot_sites()]
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' p <- plot_sites(
#'   geo_example_sites("wilhelm"), lon, lat,
#'   colour = elevation_band, basemap = "none",
#'   scale_bar = FALSE, north_arrow = FALSE
#' )
#' f <- tempfile(fileext = ".png")
#' geo_save(p, f, width = 80, height = 60, units = "mm")
geo_save <- function(plot,
                     path,
                     width = 180,
                     height = 140,
                     units = c("mm", "cm", "in", "px"),
                     dpi = 300,
                     bg = "white",
                     ...) {
  rlang::check_installed("ggplot2", reason = "to save map figures.")
  units <- rlang::arg_match(units)
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  ext <- geo_io_ext(path)
  if (!ext %in% c("png", "pdf", "svg", "tiff", "tif", "jpg", "jpeg")) {
    cli::cli_abort(
      c(
        "Unsupported map format .{ext}.",
        "i" = "Use png, pdf, svg, tiff/tif, or jpg/jpeg."
      )
    )
  }
  # ggsave has no units = "px"; convert to inches
  if (identical(units, "px")) {
    if (!is.finite(dpi) || dpi <= 0) {
      cli::cli_abort("{.arg dpi} must be positive when {.arg units} is {.val px}.")
    }
    width <- width / dpi
    height <- height / dpi
    units <- "in"
  }
  ggplot2::ggsave(
    filename = path,
    plot = plot,
    width = width,
    height = height,
    units = units,
    dpi = dpi,
    bg = bg,
    ...
  )
  invisible(path)
}
