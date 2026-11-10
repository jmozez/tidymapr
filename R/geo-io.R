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
# nolint start: line_length_linter.
#' Supported formats (read unless noted; anything else GDAL reads also
#' works, with `type` set):
#'
#' | Format | Extensions | Type | Notes |
#' | --- | --- | --- | --- |
#' | GeoTIFF / COG | `.tif`, `.tiff` | raster | write supported |
#' | netCDF | `.nc`, `.nc4`, `.cdf` | raster | climate and ocean data; pick variables with `var`, time kept in `terra::time()` |
#' | HDF4 / HDF5 | `.hdf`, `.h4`, `.he4`, `.h5`, `.hdf5`, `.he5` | raster | MODIS, VIIRS, GEDI; pick subdatasets with `var` |
#' | GRIB | `.grib`, `.grb`, `.grib2`, `.grb2` | raster | weather model output |
#' | Sentinel-2 | `.SAFE` folder, `.zip`, `MTD_*.xml` | raster | Level-1C and Level-2A products |
#' | JPEG 2000 | `.jp2` | raster | Sentinel-2 band files |
#' | ENVI | `.dat`/`.bin` with `.hdr`, `.envi` | raster | hyperspectral cubes |
#' | ERDAS Imagine | `.img` | raster | |
#' | Zarr | `.zarr` | raster | cloud-native arrays |
#' | Other rasters | `.asc`, `.grd`, `.vrt`, `.rst`, `.sdat`, `.ers`, `.bil`, `.bip`, `.bsq` | raster | ASCII grid, VRT, IDRISI, SAGA, ER Mapper |
#' | Band files | several paths | raster | stacked into one multi-band raster |
#' | GeoPackage | `.gpkg` | vector (or raster) | preferred vector write |
#' | Shapefile | `.shp` (+ sidecars) | vector | write supported |
#' | GeoJSON / TopoJSON | `.geojson`, `.json`, `.topojson` | vector | write supported |
#' | FlatGeobuf | `.fgb` | vector | write supported |
#' | KML / KMZ | `.kml`, `.kmz` | vector | KMZ unzipped to KML |
#' | GPS exchange | `.gpx` | vector | waypoints, tracks, routes (`layer`) |
#' | AutoCAD | `.dxf`, `.dwg` | vector | pick CAD layers with `cad_layer`; DWG needs GDAL's CAD driver |
#' | MicroStation | `.dgn` | vector | `cad_layer` filters by level |
#' | MapInfo | `.tab`, `.mif` | vector | |
#' | GML, SQLite / SpatiaLite | `.gml`, `.sqlite` | vector | |
#' | OpenStreetMap | `.osm`, `.pbf` | vector | `layer` = `"points"`, `"lines"`, `"multipolygons"` |
#' | Nautical charts (S-57) | `.000` | vector | |
#' | FileGDB | `.gdb` | vector | when GDAL has OpenFileGDB/FileGDB |
#' | Spreadsheets | `.xlsx`, `.xls`, `.ods` | vector | through GDAL; needs lon/lat columns |
#' | CSV / text | `.csv`, `.tsv`, `.txt` | vector | needs lon/lat columns |
#'
# nolint end
#' Use [geo_layers()] to see what a file holds (vector layers, netCDF/HDF
#' variables and subdatasets, or AutoCAD layers) before reading it. GADM
#' downloads use these writers for the on-disk cache; see [geo_gadm()] for
#' license notes (do not redistribute the full GADM database).
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
#' @param layer Layer name for multi-layer containers (GeoPackage, GDB,
#'   GPX, OSM).
#' @param var For netCDF, HDF and GRIB rasters: variable or subdataset
#'   names (or numbers) to read, as listed by [geo_layers()]. `NULL` reads
#'   them all.
#' @param cad_layer For AutoCAD (`.dxf`, `.dwg`) and MicroStation (`.dgn`)
#'   files: CAD layers (or DGN levels) to keep. `NULL` keeps all.
#' @param overwrite Overwrite an existing file? Default `FALSE`.
#' @param crs CRS assigned to lon/lat tables (default WGS84) and to CAD
#'   drawings, which store none (for example `32755` for UTM zone 55S).
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
    "gpkg", "shp", "geojson", "json", "topojson", "fgb", "kml", "kmz",
    "gml", "gdb", "gpx", "dxf", "dwg", "dgn", "tab", "mif", "sqlite",
    "osm", "pbf", "000", "xlsx", "xls", "ods", "csv", "tsv", "txt"
  )
}

geo_io_raster_ext <- function() {
  c(
    "tif", "tiff", "nc", "nc4", "cdf", "hdf", "h4", "he4", "hdf4", "h5",
    "hdf5", "he5", "grib", "grb", "grib2", "grb2", "jp2", "envi", "zarr",
    "safe", "asc", "grd", "img", "bil", "bip", "bsq", "vrt", "rst",
    "sdat", "ers"
  )
}

geo_io_cad_ext <- function() c("dxf", "dwg", "dgn")

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
  # ENVI cubes: a binary file next to a .hdr header
  if (file.exists(sub("\\.[^.]*$", ".hdr", path))) return("raster")
  # Sentinel-2 product: zipped SAFE or its metadata XML
  b <- basename(path)
  if (grepl("^S2[ABC]_MSIL(1C|2A)_", b) || grepl("^MTD_MSIL", b)) {
    return("raster")
  }
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
                     var = NULL,
                     cad_layer = NULL,
                     ...) {
  if (!is.character(path) || length(path) < 1) {
    cli::cli_abort("{.arg path} must be a file path.")
  }
  if (length(path) > 1) {
    # Several band files: one multi-band raster
    return(geo_raster_read(path, var = var, ...))
  }
  if (!file.exists(path) && !dir.exists(path)) {
    cli::cli_abort("File {.path {path}} does not exist.")
  }
  kind <- geo_io_guess_type(path, type = type)
  if (identical(kind, "raster")) {
    geo_raster_read(path, driver = driver, var = var, ...)
  } else {
    geo_vector_read(
      path, driver = driver, lon = lon, lat = lat,
      layer = layer, crs = if (missing(crs)) NULL else crs,
      cad_layer = cad_layer, ...
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
                            crs = NULL,
                            cad_layer = NULL,
                            ...) {
  rlang::check_installed("sf")
  crs_given <- !is.null(crs)
  crs <- crs %||% 4326
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
  if (ext %in% geo_io_cad_ext()) {
    out <- geo_io_cad_filter(out, cad_layer, path)
    # CAD drawings store no coordinate system
    if (is.na(sf::st_crs(out))) {
      if (crs_given) {
        out <- sf::st_set_crs(out, crs)
      } else {
        cli::cli_inform(c(
          "i" = paste(
            "{.path {basename(path)}} has no coordinate system",
            "(CAD drawings do not store one)."
          ),
          " " = "Set it with {.arg crs}, for example {.code crs = 32755} for UTM zone 55S."
        ))
      }
    }
  }
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

# CAD drawings: GDAL puts the AutoCAD layer in "Layer" (DGN: "Level")
geo_io_cad_layer_col <- function(data) {
  hit <- intersect(c("Layer", "layer", "Level", "level"), names(data))
  if (length(hit)) hit[[1]] else NULL
}

geo_io_cad_filter <- function(out, cad_layer, path, call = caller_env()) {
  if (is.null(cad_layer)) return(out)
  col <- geo_io_cad_layer_col(out)
  if (is.null(col)) {
    cli::cli_abort("No CAD layer column found in {.path {path}}.", call = call)
  }
  have <- unique(as.character(out[[col]]))
  miss <- setdiff(as.character(cad_layer), have)
  if (length(miss)) {
    cli::cli_abort(c(
      "CAD layer(s) not found in the drawing: {.val {miss}}.",
      "i" = "Layers in the drawing: {.val {have}}."
    ), call = call)
  }
  out[as.character(out[[col]]) %in% as.character(cad_layer), ]
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
geo_raster_read <- function(path, driver = NULL, var = NULL, ...) {
  rlang::check_installed("terra")
  if (inherits(path, "SpatRaster")) {
    return(path)
  }
  if (!is.character(path) || length(path) < 1) {
    cli::cli_abort("{.arg path} must be file path(s) or a SpatRaster.")
  }
  gone <- path[!file.exists(path) & !dir.exists(path)]
  if (length(gone)) {
    cli::cli_abort("Raster file{?s} {.path {gone}} {?does/do} not exist.")
  }
  # terra::rast has no driver=; GDAL finds it. Accept driver for API symmetry.
  if (!is.null(driver)) {
    cli::cli_inform(
      "{.arg driver} is ignored for rasters; terra/GDAL detect it from the file."
    )
  }
  if (length(path) > 1) {
    # Separate band files (for example Landsat or Sentinel-2 .jp2/.tif)
    out <- tryCatch(terra::rast(path, ...), error = function(e) {
      cli::cli_abort(c(
        "Could not stack the band files into one raster.",
        "x" = conditionMessage(e),
        "i" = "Band files must share extent, resolution and CRS."
      ))
    })
    names(out) <- make.unique(tools::file_path_sans_ext(basename(path)))
    return(out)
  }
  src <- geo_io_sentinel2_source(path)
  read_one <- function(v) {
    args <- list(x = src, ...)
    if (!is.null(v)) args$subds <- v
    do.call(terra::rast, args)
  }
  tryCatch(
    if (length(var) > 1) terra::rast(lapply(var, read_one)) else read_one(var),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not read raster {.path {path}}.",
          "x" = conditionMessage(e),
          "i" = "See the variables and subdatasets with {.fn geo_layers}."
        )
      )
    }
  )
}

# A Sentinel-2 .SAFE folder or zip is read through its product metadata
geo_io_sentinel2_source <- function(path) {
  b <- basename(path)
  if (dir.exists(path) && grepl("\\.SAFE$", b, ignore.case = TRUE)) {
    mtd <- list.files(path, pattern = "^MTD_MSIL(1C|2A)\\.xml$", full.names = TRUE)
    if (length(mtd)) return(mtd[[1]])
  }
  if (grepl("\\.zip$", b, ignore.case = TRUE) && grepl("^S2[ABC]_MSIL", b)) {
    inner <- utils::unzip(path, list = TRUE)$Name
    mtd <- inner[grepl("MTD_MSIL(1C|2A)\\.xml$", inner)]
    if (length(mtd)) return(paste0("/vsizip/", normalizePath(path), "/", mtd[[1]]))
  }
  path
}

#' List what a spatial file contains
#'
#' @description
#' `geo_layers()` looks inside a file before you read it and returns a tidy
#' table of its contents:
#'
#' * vector files (GeoPackage, GDB, GPX, OSM, KML, ...): one row per layer,
#'   with geometry type, number of features and fields;
#' * netCDF, HDF and GRIB files: one row per variable or subdataset, with
#'   its description, grid size and number of layers (time steps, depths
#'   or bands); pass the `var` value to [geo_read()];
#' * AutoCAD (`.dxf`, `.dwg`) and MicroStation (`.dgn`) drawings: one row
#'   per CAD layer or level, with its number of entities; pass the
#'   `cad_layer` value to [geo_read()];
#' * other rasters: one row per band.
#'
#' @param path Path to a spatial file (or a `.SAFE` folder / `.gdb`).
#' @return A tibble.
#' @seealso [geo_read()]
#' @export
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' # ERA5 monthly climate at the Nouragues station, French Guiana (netCDF)
#' nc <- system.file("ex/nouragues.nc", package = "terra")
#' geo_layers(nc)
#' t2m <- geo_read(nc, var = "t2m")
#' t2m
#'
#' # Sentinel-2 Level-2A bands over Luxembourg
#' geo_layers(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
#'
#' # Luxembourg cantons written to AutoCAD DXF, then one CAD layer read back
#' lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#' lux <- sf::st_cast(lux[, "NAME_1"], "MULTILINESTRING")
#' names(lux)[1] <- "Layer"
#' dxf <- tempfile(fileext = ".dxf")
#' sf::st_write(lux, dxf, driver = "DXF", quiet = TRUE)
#' geo_layers(dxf)
#' geo_read(dxf, cad_layer = "Diekirch", crs = 4326)
geo_layers <- function(path) {
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (!file.exists(path) && !dir.exists(path)) {
    cli::cli_abort("File {.path {path}} does not exist.")
  }
  ext <- geo_io_ext(path)
  if (ext %in% geo_io_cad_ext()) {
    rlang::check_installed("sf")
    d <- suppressWarnings(sf::st_read(path, quiet = TRUE))
    col <- geo_io_cad_layer_col(d)
    if (is.null(col)) {
      return(tibble::tibble(cad_layer = character(), entities = integer()))
    }
    tab <- table(as.character(d[[col]]))
    return(tibble::tibble(
      cad_layer = names(tab),
      entities = as.integer(tab),
      geometry = vapply(names(tab), function(l) {
        paste(unique(as.character(sf::st_geometry_type(d[d[[col]] == l, ]))), collapse = ", ")
      }, character(1), USE.NAMES = FALSE)
    ))
  }
  kind <- geo_io_guess_type(path)
  if (identical(kind, "vector")) {
    rlang::check_installed("sf")
    l <- sf::st_layers(path)
    return(tibble::tibble(
      layer = l$name,
      geometry = vapply(l$geomtype, function(g) paste(g, collapse = ", "), character(1)),
      features = as.integer(l$features),
      fields = as.integer(l$fields)
    ))
  }
  rlang::check_installed("terra")
  src <- geo_io_sentinel2_source(path)
  sds <- tryCatch(terra::describe(src, sds = TRUE), error = function(e) NULL)
  if (!is.null(sds) && nrow(sds) > 0) {
    return(tibble::tibble(
      var = sds$var,
      description = trimws(sub("^\\[[^]]*\\]\\s*", "", sds$desc)),
      nrow = as.integer(sds$nrow),
      ncol = as.integer(sds$ncol),
      layers = as.integer(sds$nlyr),
      source = sds$name
    ))
  }
  r <- terra::rast(src)
  tibble::tibble(
    band = seq_len(terra::nlyr(r)),
    name = names(r),
    nrow = terra::nrow(r),
    ncol = terra::ncol(r),
    crs = terra::crs(r, describe = TRUE)$name %||% NA_character_
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
