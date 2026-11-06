#' Geospatial helpers for tidy biodiversity workflows
#'
#' @description
#' Native tidyverse-style verbs for spatial biodiversity analysis. Sites
#' become [sf][sf::st_as_sf] tables, rasters join as columns, occurrence
#' records are cleaned without calling CoordinateCleaner, distances feed
#' [tidydiversity::beta_decay()], Hill numbers map with ggplot2, and Moran's I diagnoses
#' spatial autocorrelation without requiring spdep at run time.
#'
#' Suggested packages: **sf** (site tables and maps), **terra** (raster
#' extraction). **rgbif** is optional for live downloads; **spdep** and
#' **CoordinateCleaner** are used only in tests when installed.
#'
#' @name geo
#' @keywords internal
NULL

# Internal reference points for occurrence cleaning (capitals, GBIF HQ,
# major biodiversity institutions). Coordinates are WGS84 decimal degrees.
# Sourced from well-known public locations; used for distance-based flags
# that match CoordinateCleaner::cc_cap, cc_cen, cc_inst and cc_gbif.
.geo_ref_points <- function() {
  tibble::tibble(
    name = c(
      "gbif_hq",
      "london", "paris", "berlin", "madrid", "rome", "vienna", "warsaw",
      "moscow", "ankara", "cairo", "nairobi", "lagos", "cape_town",
      "pretoria", "addis_ababa", "new_delhi", "beijing", "tokyo", "seoul",
      "bangkok", "jakarta", "manila", "canberra", "wellington",
      "washington", "ottawa", "mexico_city", "brasilia", "buenos_aires",
      "santiago", "lima", "bogota", "port_moresby",
      "natural_history_london", "mnhn_paris", "smithsonian",
      "amnh_new_york", "field_museum", "naturalis", "museum_fur_naturkunde",
      "rbins_brussels", "australian_museum", "tepapa", "csiro_canberra"
    ),
    type = c(
      "gbif",
      rep("capital", 33),
      rep("institution", 11)
    ),
    lon = c(
      12.58,
      -0.1276, 2.3522, 13.4050, -3.7038, 12.4964, 16.3738, 21.0122,
      37.6173, 32.8597, 31.2357, 36.8219, 3.3792, 18.4241,
      28.1881, 38.7578, 77.2090, 116.4074, 139.6917, 126.9780,
      100.5018, 106.8456, 120.9842, 149.1300, 174.7762,
      -77.0369, -75.6972, -99.1332, -47.9292, -58.3816,
      -70.6693, -77.0428, -74.0721, 147.1803,
      -0.1761, 2.3372, -77.0261,
      -73.9740, -87.6217, 4.4725, 13.3781,
      4.3767, 151.2130, 174.7772, 149.1180
    ),
    lat = c(
      55.67,
      51.5074, 48.8566, 52.5200, 40.4168, 41.9028, 48.2082, 52.2297,
      55.7558, 39.9334, 30.0444, -1.2921, 6.5244, -33.9249,
      -25.7479, 9.0320, 28.6139, 39.9042, 35.6895, 37.5665,
      13.7563, -6.2088, 14.5995, -35.2809, -41.2865,
      38.9072, 45.4215, 19.4326, -15.7801, -34.6037,
      -33.4489, -12.0464, 4.7110, -9.4438,
      51.4964, 48.8421, 38.8910,
      40.7813, 41.8663, 52.1646, 52.5308,
      50.8400, -33.8740, -41.2900, -35.2750
    )
  )
}

#' Convert site coordinates to an sf tibble
#'
#' Builds a consistent [sf][sf::st_sf] tibble from longitude and latitude
#' columns (default CRS EPSG:4326), drops empty coordinates, and keeps the
#' site identifier. Already-sf inputs are validated and returned with the
#' same CRS check.
#'
#' @param data A data frame with coordinates, or an `sf` object.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Longitude
#'   and latitude columns. Ignored when `data` is already `sf`.
#' @param site <[`data-masking`][dplyr::dplyr_data_masking]> Optional site
#'   identifier to keep. Use `NULL` to skip.
#' @param crs Coordinate reference system. Default `4326` (WGS84).
#' @param drop_na Drop rows with missing or non-finite coordinates?
#' @return An `sf` tibble (`tmr_geo_sf`) with a point geometry column.
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' sites <- tibble::tibble(
#'   site = c("a", "b", "c"),
#'   lon = c(147.1, 147.2, NA_real_),
#'   lat = c(-9.4, -9.5, -9.6),
#'   elevation = c(200, 700, 1200)
#' )
#' geo_as_sf(sites, lon, lat, site = site)
geo_as_sf <- function(data,
                      lon = lon,
                      lat = lat,
                      site = NULL,
                      crs = 4326,
                      drop_na = TRUE) {
  rlang::check_installed("sf")
  tmr_check_data(data)
  if (inherits(data, "sf")) {
    geom <- sf::st_geometry(data)
    if (!inherits(geom, "sfc_POINT") && !inherits(geom, "sfc")) {
      cli::cli_abort("{.arg data} must have point geometries.")
    }
    cur <- sf::st_crs(data)
    target <- sf::st_crs(crs)
    if (is.na(cur)) {
      data <- sf::st_set_crs(data, target)
    } else if (!is.na(target) && cur != target) {
      data <- sf::st_transform(data, target)
    }
    if (isTRUE(drop_na)) {
      ok <- sf::st_is_valid(data) & !sf::st_is_empty(data)
      data <- data[ok %in% TRUE, , drop = FALSE]
    }
    class(data) <- unique(c("tmr_geo_sf", class(data)))
    return(data)
  }

  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  site_q <- enquo(site)
  site_col <- if (quo_is_null(site_q)) NULL else tmr_pick(site_q, data, "site")

  lon_v <- data[[lon_col]]
  lat_v <- data[[lat_col]]
  if (!is.numeric(lon_v) || !is.numeric(lat_v)) {
    cli::cli_abort("{.arg lon} and {.arg lat} must be numeric.")
  }
  keep <- rep(TRUE, nrow(data))
  if (isTRUE(drop_na)) {
    keep <- is.finite(lon_v) & is.finite(lat_v)
  }
  out <- tibble::as_tibble(dplyr::ungroup(data)[keep, , drop = FALSE])
  if (nrow(out) == 0) {
    cli::cli_abort("No rows with finite coordinates remain.")
  }
  pts <- sf::st_as_sf(
    out,
    coords = c(lon_col, lat_col),
    crs = crs,
    remove = FALSE,
    sf_column_name = "geometry"
  )
  if (!is.null(site_col) && site_col != "site" && !"site" %in% names(pts)) {
    pts$site <- pts[[site_col]]
  }
  class(pts) <- unique(c("tmr_geo_sf", class(pts)))
  pts
}

#' @rdname geo_as_sf
#' @export
geo_drop_geometry <- function(data) {
  tmr_check_data(data)
  if (inherits(data, "sf")) {
    data <- sf::st_drop_geometry(data)
  } else if ("geometry" %in% names(data)) {
    data$geometry <- NULL
  }
  tibble::as_tibble(data)
}

#' Extract raster values at sites
#'
#' Joins CHELSA, WorldClim or SRTM-style rasters (a `terra::SpatRaster` or
#' a file path) to site coordinates. Layer names become columns. Points that
#' fall on NA cells keep `NA` in those columns.
#'
#' @param data A data frame or `sf` object with site coordinates.
#' @param raster A `terra::SpatRaster`, a file path, or a list of either.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns when `data` is not `sf`.
#' @param method Extraction method passed to [terra::extract()], default
#'   `"simple"`.
#' @param bind Bind extracted columns onto `data`? If `FALSE`, return only
#'   the extracted tibble.
#' @return A tibble (or `sf` tibble) with one column per raster layer.
#' @export
#' @examplesIf requireNamespace("terra", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' r <- terra::rast(ncols = 36, nrows = 18, xmin = -180, xmax = 180,
#'   ymin = -90, ymax = 90, crs = "EPSG:4326")
#' terra::values(r) <- seq_len(terra::ncell(r))
#' names(r) <- "demo"
#' sites <- tibble::tibble(site = "a", lon = 147, lat = -9)
#' geo_extract(sites, r, lon, lat)
geo_extract <- function(data,
                        raster,
                        lon = lon,
                        lat = lat,
                        method = "simple",
                        bind = TRUE) {
  rlang::check_installed("terra")
  tmr_check_data(data)
  rasters <- geo_as_raster(raster)
  if (inherits(data, "sf")) {
    xy <- sf::st_coordinates(sf::st_geometry(data))
    lon_v <- xy[, 1]
    lat_v <- xy[, 2]
  } else {
    lon_col <- tmr_pick(enquo(lon), data, "lon")
    lat_col <- tmr_pick(enquo(lat), data, "lat")
    lon_v <- data[[lon_col]]
    lat_v <- data[[lat_col]]
  }
  pts <- cbind(lon_v, lat_v)
  extracted <- lapply(rasters, function(r) {
    ex <- terra::extract(r, pts, method = method)
    ex <- as.data.frame(ex)
    if ("ID" %in% names(ex)) {
      ex$ID <- NULL
    }
    tibble::as_tibble(ex)
  })
  vals <- dplyr::bind_cols(extracted)
  if (!isTRUE(bind)) {
    return(vals)
  }
  out <- tibble::as_tibble(dplyr::ungroup(data))
  for (nm in names(vals)) {
    out[[nm]] <- vals[[nm]]
  }
  if (inherits(data, "sf")) {
    # Restore geometry from the input sf table
    out <- sf::st_sf(out, geometry = sf::st_geometry(data), crs = sf::st_crs(data))
    class(out) <- unique(c("tmr_geo_sf", class(out)))
  }
  out
}

geo_as_raster <- function(raster, call = caller_env()) {
  if (inherits(raster, "SpatRaster")) {
    return(list(raster))
  }
  if (is.character(raster)) {
    return(lapply(raster, function(p) {
      if (!file.exists(p)) {
        cli::cli_abort("Raster file {.path {p}} does not exist.", call = call)
      }
      terra::rast(p)
    }))
  }
  if (is.list(raster)) {
    return(unlist(lapply(raster, geo_as_raster, call = call), recursive = FALSE))
  }
  cli::cli_abort(
    "{.arg raster} must be a SpatRaster, a file path, or a list of those.",
    call = call
  )
}

#' Clean occurrence coordinates
#'
#' Flags and optionally filters occurrence records using tests rebuilt
#' inside tidymapr, so callers never need CoordinateCleaner. Flags
#' cover equal longitude and latitude, zero coordinates, country capitals,
#' the GBIF headquarters, biodiversity institutions, points at sea (when a
#' land mask is supplied), geographic outliers, invalid coordinates and
#' duplicates.
#'
#' @param data A data frame of occurrence records.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns.
#' @param species <[`data-masking`][dplyr::dplyr_data_masking]> Optional
#'   species column for duplicate and outlier tests.
#' @param tests Character vector of tests to run. See Details.
#' @param capitals_rad,institutions_rad,gbif_rad Buffer radius in metres
#'   around reference points (defaults match CoordinateCleaner).
#' @param outliers_method `"quantile"` or `"mad"`.
#' @param outliers_mtp Multiplier for the outlier threshold (quantile IQR
#'   or MAD).
#' @param land_mask Optional `sf`/`SpatVector` polygons of land, or a
#'   SpatRaster land mask. When `NULL`, the `"seas"` test is skipped.
#' @param value `"clean"` (filtered data), `"flagged"` (logical matrix of
#'   flags plus coordinates), or `"both"` (a list).
#' @return Depending on `value`: a tibble, a flagged tibble, or a list with
#'   `clean` and `flagged`.
#' @details
#' Available tests: `"equal"`, `"zeros"`, `"capitals"`, `"centroids"`
#' (treated as capitals for the bundled reference set), `"gbif"`,
#' `"institutions"`, `"seas"`, `"outliers"`, `"validity"`, `"duplicates"`.
#' @references Zizka, A. et al. (2019). CoordinateCleaner: standardized
#'   cleaning of occurrence records from biological collection databases.
#'   *Methods in Ecology and Evolution*, 10, 744-751.
#'   \doi{10.1111/2041-210X.13152}
#' @export
#' @examples
#' occ <- tibble::tibble(
#'   species = c("a", "a", "b", "b", "c"),
#'   lon = c(147.1, 147.1, 0, 12.58, 151),
#'   lat = c(-9.4, -9.4, 0, 55.67, -33.9)
#' )
#' geo_clean(occ, lon, lat, species = species, value = "flagged")
geo_clean <- function(data,
                      lon = lon,
                      lat = lat,
                      species = NULL,
                      tests = c(
                        "equal", "zeros", "capitals", "gbif",
                        "institutions", "validity", "duplicates", "outliers"
                      ),
                      capitals_rad = 10000,
                      institutions_rad = 100,
                      gbif_rad = 1000,
                      outliers_method = c("quantile", "mad"),
                      outliers_mtp = 5,
                      land_mask = NULL,
                      value = c("clean", "flagged", "both")) {
  tmr_check_data(data)
  value <- rlang::arg_match(value)
  outliers_method <- rlang::arg_match(outliers_method)
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  spp_q <- enquo(species)
  spp_col <- if (quo_is_null(spp_q)) NULL else tmr_pick(spp_q, data, "species")

  lon_v <- as.numeric(data[[lon_col]])
  lat_v <- as.numeric(data[[lat_col]])
  n <- length(lon_v)
  tests <- unique(tests)
  known <- c(
    "equal", "zeros", "capitals", "centroids", "gbif", "institutions",
    "seas", "outliers", "validity", "duplicates"
  )
  bad <- setdiff(tests, known)
  if (length(bad) > 0) {
    cli::cli_abort("Unknown test{?s}: {.val {bad}}.")
  }

  flags <- tibble::tibble(.rows = n)
  if ("validity" %in% tests) {
    flags$.val <- !(is.finite(lon_v) & is.finite(lat_v) &
                      lon_v >= -180 & lon_v <= 180 &
                      lat_v >= -90 & lat_v <= 90)
  }
  if ("equal" %in% tests) {
    flags$.equ <- is.finite(lon_v) & is.finite(lat_v) & lon_v == lat_v
  }
  if ("zeros" %in% tests) {
    flags$.zer <- is.finite(lon_v) & is.finite(lat_v) & lon_v == 0 & lat_v == 0
  }
  ref <- .geo_ref_points()
  if ("capitals" %in% tests || "centroids" %in% tests) {
    caps <- ref[ref$type == "capital", ]
    flags$.cap <- geo_near_points(lon_v, lat_v, caps$lon, caps$lat, capitals_rad)
  }
  if ("gbif" %in% tests) {
    gb <- ref[ref$type == "gbif", ]
    flags$.gbf <- geo_near_points(lon_v, lat_v, gb$lon, gb$lat, gbif_rad)
  }
  if ("institutions" %in% tests) {
    inst <- ref[ref$type == "institution", ]
    flags$.inst <- geo_near_points(
      lon_v, lat_v, inst$lon, inst$lat, institutions_rad
    )
  }
  if ("seas" %in% tests) {
    if (is.null(land_mask)) {
      cli::cli_warn(
        "Skipping {.val seas}: supply {.arg land_mask} for a land/sea test."
      )
    } else {
      flags$.sea <- geo_flag_seas(lon_v, lat_v, land_mask)
    }
  }
  if ("duplicates" %in% tests) {
    key <- data.frame(lon = lon_v, lat = lat_v)
    if (!is.null(spp_col)) key$species <- as.character(data[[spp_col]])
    flags$.dpl <- duplicated(key) | duplicated(key, fromLast = TRUE)
    # CoordinateCleaner marks all but the first as duplicates; keep that
    # convention for the clean filter while exposing both-sided flags above
    # for inspection. Use first-occurrence rule for filtering:
    flags$.dpl_filter <- duplicated(key)
  }
  if ("outliers" %in% tests) {
    flags$.otl <- geo_flag_outliers(
      lon_v, lat_v,
      species = if (is.null(spp_col)) NULL else as.character(data[[spp_col]]),
      method = outliers_method,
      mtp = outliers_mtp
    )
  }

  # Columns that mark a record as dirty for filtering
  filter_cols <- setdiff(names(flags), ".dpl")
  if (".dpl_filter" %in% names(flags)) {
    filter_cols <- setdiff(filter_cols, ".dpl")
  } else {
    filter_cols <- names(flags)
  }
  dirty <- Reduce(`|`, lapply(filter_cols, function(cl) flags[[cl]] %in% TRUE))
  dirty[is.na(dirty)] <- FALSE

  flagged <- tibble::as_tibble(dplyr::ungroup(data))
  for (cl in names(flags)) {
    if (cl == ".dpl_filter") next
    flagged[[cl]] <- flags[[cl]]
  }
  flagged$.summary <- dirty
  clean <- tibble::as_tibble(dplyr::ungroup(data)[!dirty, , drop = FALSE])

  switch(
    value,
    clean = clean,
    flagged = flagged,
    both = list(clean = clean, flagged = flagged)
  )
}

geo_near_points <- function(lon, lat, ref_lon, ref_lat, rad_m) {
  n <- length(lon)
  out <- rep(FALSE, n)
  ok <- is.finite(lon) & is.finite(lat)
  if (!any(ok) || length(ref_lon) == 0) {
    return(out)
  }
  # Approximate degrees for a first cull, then exact haversine
  deg <- rad_m / 111320
  for (i in which(ok)) {
    near <- abs(ref_lon - lon[i]) <= deg / max(cos(lat[i] * pi / 180), 0.2) &
      abs(ref_lat - lat[i]) <= deg
    if (!any(near)) next
    d <- geo_haversine_m(lon[i], lat[i], ref_lon[near], ref_lat[near])
    if (any(d <= rad_m, na.rm = TRUE)) out[i] <- TRUE
  }
  out
}

geo_haversine_m <- function(lon1, lat1, lon2, lat2) {
  # Prefer the compiled pairwise kernel when lengths match; fall back to
  # vectorised R (including length-1 recycling against a reference set).
  n1 <- length(lon1)
  n2 <- length(lon2)
  if (n1 == n2 && length(lat1) == n1 && length(lat2) == n2 &&
        exists("geo_haversine_pair_cpp", mode = "function")) {
    return(geo_haversine_pair_cpp(lon1, lat1, lon2, lat2))
  }
  if (n1 == 1L && n2 > 1L) {
    lon1 <- rep(lon1, n2)
    lat1 <- rep(lat1, n2)
    if (exists("geo_haversine_pair_cpp", mode = "function")) {
      return(geo_haversine_pair_cpp(lon1, lat1, lon2, lat2))
    }
  }
  to_rad <- pi / 180
  dlon <- (lon2 - lon1) * to_rad
  dlat <- (lat2 - lat1) * to_rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  6371000 * 2 * atan2(sqrt(a), sqrt(pmax(0, 1 - a)))
}

geo_flag_seas <- function(lon, lat, land_mask) {
  rlang::check_installed("sf")
  n <- length(lon)
  out <- rep(FALSE, n)
  ok <- is.finite(lon) & is.finite(lat)
  if (!any(ok)) {
    return(out)
  }
  pts <- sf::st_as_sf(
    data.frame(lon = lon[ok], lat = lat[ok]),
    coords = c("lon", "lat"),
    crs = 4326
  )
  if (inherits(land_mask, "SpatRaster")) {
    rlang::check_installed("terra")
    vals <- terra::extract(land_mask, cbind(lon[ok], lat[ok]), ID = FALSE)[[1]]
    out[ok] <- is.na(vals) | vals == 0
    return(out)
  }
  if (inherits(land_mask, "SpatVector")) {
    rlang::check_installed("terra")
    land_mask <- sf::st_as_sf(land_mask)
  }
  land <- sf::st_transform(sf::st_make_valid(land_mask), 4326)
  hit <- lengths(sf::st_intersects(pts, land)) > 0
  out[ok] <- !hit
  out
}

geo_flag_outliers <- function(lon, lat, species, method, mtp) {
  n <- length(lon)
  out <- rep(FALSE, n)
  ok <- is.finite(lon) & is.finite(lat)
  groups <- if (is.null(species)) rep("_all_", n) else species
  groups[!ok] <- NA_character_
  for (g in unique(stats::na.omit(groups))) {
    idx <- which(groups == g)
    if (length(idx) < 3) next
    # Mean pairwise distance to other points of the same species
    dmean <- vapply(idx, function(i) {
      mean(geo_haversine_m(lon[i], lat[i], lon[idx], lat[idx]))
    }, numeric(1))
    if (method == "quantile") {
      lim <- stats::quantile(dmean, 0.75, names = FALSE, na.rm = TRUE) +
        mtp * stats::IQR(dmean, na.rm = TRUE)
    } else {
      lim <- stats::median(dmean, na.rm = TRUE) +
        mtp * stats::mad(dmean, na.rm = TRUE)
    }
    out[idx] <- dmean > lim
  }
  out
}

#' Import GBIF-style occurrence records
#'
#' Accepts a pre-downloaded GBIF (or rgbif-like) data frame, or downloads
#' records with **rgbif** when it is installed. The result is standardised
#' to `species`, `lon`, `lat` and optional extras, then optionally passed
#' through [geo_clean()] and [geo_as_sf()].
#'
#' @param data Optional data frame already holding GBIF columns such as
#'   `decimalLongitude`, `decimalLatitude` and `species` /
#'   `scientificName`.
#' @param scientificName,country,limit Arguments forwarded to
#'   `rgbif::occ_search()` when `data` is `NULL`.
#' @param clean Run [geo_clean()]?
#' @param as_sf Convert cleaned points with [geo_as_sf()]?
#' @param ... Passed to [geo_clean()] when `clean = TRUE`.
#' @return A tibble, or an `sf` tibble when `as_sf = TRUE`.
#' @export
#' @examples
#' gbif_like <- tibble::tibble(
#'   scientificName = "Camponotus",
#'   decimalLongitude = 147.1,
#'   decimalLatitude = -9.4,
#'   countryCode = "PG"
#' )
#' geo_gbif(gbif_like, clean = FALSE, as_sf = FALSE)
geo_gbif <- function(data = NULL,
                     scientificName = NULL, # nolint: object_name_linter.
                     country = NULL,
                     limit = 500,
                     clean = TRUE,
                     as_sf = FALSE,
                     ...) {
  if (is.null(data)) {
    rlang::check_installed(
      "rgbif",
      reason = "to download occurrences; or pass a pre-downloaded data frame"
    )
    args <- list(limit = limit)
    if (!is.null(scientificName)) args$scientificName <- scientificName
    if (!is.null(country)) args$country <- country
    res <- do.call(rgbif::occ_search, args)
    data <- res$data
    if (is.null(data) || nrow(data) == 0) {
      cli::cli_abort("No GBIF records returned for this query.")
    }
  }
  tmr_check_data(data)
  data <- tibble::as_tibble(data)
  # Standardise common GBIF column names
  rename_map <- c(
    decimalLongitude = "lon",
    decimalLatitude = "lat",
    scientificName = "species",
    species = "species",
    longitude = "lon",
    latitude = "lat"
  )
  for (src in names(rename_map)) {
    if (src %in% names(data) && !rename_map[[src]] %in% names(data)) {
      names(data)[names(data) == src] <- rename_map[[src]]
    }
  }
  if (!all(c("lon", "lat") %in% names(data))) {
    cli::cli_abort(
      "{.arg data} needs longitude/latitude columns (lon/lat or GBIF names)."
    )
  }
  if (!"species" %in% names(data) && "scientificName" %in% names(data)) {
    data$species <- data$scientificName
  }
  if (isTRUE(clean)) {
    if ("species" %in% names(data)) {
      data <- geo_clean(data, lon = "lon", lat = "lat", species = "species", ...)
    } else {
      data <- geo_clean(data, lon = "lon", lat = "lat", ...)
    }
  }
  if (isTRUE(as_sf)) {
    data <- geo_as_sf(data, lon = "lon", lat = "lat", site = NULL)
  }
  data
}

#' Pairwise geographic or elevational distances
#'
#' Great-circle (haversine) or elevational distances between sites, as a
#' long tibble ready to join with [tidydiversity::beta_pair()] or to build
#' a [geo_decay()] distance-decay table. Elevational distance is the absolute
#' difference in metres.
#'
#' @param data A data frame of unique sites (or records constant within
#'   site) with coordinates and optional elevation.
#' @param lon,lat,elevation,site <[`data-masking`][dplyr::dplyr_data_masking]>
#'   Column selections.
#' @param method `"haversine"` (metres), `"elevation"` (metres),
#'   `"euclidean"` on lon/lat in degrees, or `"environmental"` for Euclidean
#'   or Gower distance on numeric covariate columns (for example bioclim
#'   layers from [geo_extract()] / [geo_bioclim()]).
#' @param vars Character vector of covariate columns for
#'   `method = "environmental"`. When `NULL`, every numeric column except
#'   coordinates, elevation and the site id is used.
#' @param scale Standardise environmental columns to mean 0 and sd 1 before
#'   Euclidean distance? Ignored for Gower.
#' @param metric `"euclidean"` or `"gower"` for environmental distances.
#' @param .by Optional grouping columns.
#' @return A tibble with `site_1`, `site_2`, `distance` and grouping columns.
#' @export
#' @examples
#' sites <- tibble::tibble(
#'   site = c("a", "b", "c"),
#'   lon = c(147.0, 147.1, 147.2),
#'   lat = c(-9.4, -9.5, -9.6),
#'   elevation = c(200, 700, 1200)
#' )
#' geo_distance(sites, lon, lat, method = "haversine")
#' geo_distance(sites, elevation = elevation, method = "elevation")
geo_distance <- function(data,
                         lon = lon,
                         lat = lat,
                         elevation = NULL,
                         site = site,
                         method = c("haversine", "elevation", "euclidean",
                                    "environmental"),
                         vars = NULL,
                         scale = TRUE,
                         metric = c("euclidean", "gower"),
                         .by = NULL) {
  method <- rlang::arg_match(method)
  metric <- rlang::arg_match(metric)
  tmr_check_data(data)
  site_col <- tmr_pick(enquo(site), data, "site")
  by_cols <- tmr_group_cols(data, enquo(.by))
  elev_q <- enquo(elevation)

  cols <- c(by_cols, site_col)
  lon_col <- lat_col <- elev_col <- NULL
  env_cols <- character()
  if (method %in% c("haversine", "euclidean")) {
    lon_col <- tmr_pick(enquo(lon), data, "lon")
    lat_col <- tmr_pick(enquo(lat), data, "lat")
    cols <- c(cols, lon_col, lat_col)
  }
  if (method == "elevation") {
    if (quo_is_null(elev_q)) {
      cli::cli_abort("{.arg elevation} is required when {.arg method} is {.val elevation}.")
    }
    elev_col <- tmr_pick(elev_q, data, "elevation")
    cols <- c(cols, elev_col)
  } else if (!quo_is_null(elev_q)) {
    elev_col <- tmr_pick(elev_q, data, "elevation")
    cols <- c(cols, elev_col)
  }
  if (method == "environmental") {
    # Prefer lon/lat when present so sites stay unique; not used in distance
    lon_try <- tryCatch(tmr_pick(enquo(lon), data, "lon"), error = function(e) NULL)
    lat_try <- tryCatch(tmr_pick(enquo(lat), data, "lat"), error = function(e) NULL)
    if (!is.null(lon_try) && !is.null(lat_try)) {
      lon_col <- lon_try
      lat_col <- lat_try
      cols <- c(cols, lon_col, lat_col)
    }
    env_cols <- geo_distance_env_cols(data, vars, site_col, by_cols,
                                      lon_col, lat_col, elev_col)
    cols <- c(cols, env_cols)
  }

  sites <- tibble::as_tibble(dplyr::ungroup(data)[unique(cols)])
  sites <- vctrs::vec_unique(sites)
  if (vctrs::vec_duplicate_any(sites[c(by_cols, site_col)])) {
    cli::cli_abort("Coordinates must be constant within each site.")
  }
  names(sites)[names(sites) == site_col] <- ".site"
  if (!is.null(elev_col) && elev_col %in% names(sites)) {
    names(sites)[names(sites) == elev_col] <- ".elev"
  }
  if (!is.null(lon_col) && lon_col %in% names(sites)) {
    names(sites)[names(sites) == lon_col] <- ".lon"
  }
  if (!is.null(lat_col) && lat_col %in% names(sites)) {
    names(sites)[names(sites) == lat_col] <- ".lat"
  }

  split <- if (length(by_cols) == 0) {
    list(key = tibble::tibble(.rows = 1), val = list(sites))
  } else {
    vctrs::vec_split(sites, sites[by_cols])
  }

  rows <- lapply(seq_along(split$val), function(i) {
    s <- split$val[[i]]
    k <- nrow(s)
    if (k < 2) {
      return(NULL)
    }
    ij <- utils::combn(k, 2)
    d <- switch(
      method,
      haversine = geo_haversine_m(
        s$.lon[ij[1, ]], s$.lat[ij[1, ]],
        s$.lon[ij[2, ]], s$.lat[ij[2, ]]
      ),
      elevation = abs(s$.elev[ij[1, ]] - s$.elev[ij[2, ]]),
      euclidean = sqrt(
        (s$.lon[ij[1, ]] - s$.lon[ij[2, ]])^2 +
          (s$.lat[ij[1, ]] - s$.lat[ij[2, ]])^2
      ),
      environmental = geo_env_pairwise(
        s[env_cols], ij, scale = scale, metric = metric
      )
    )
    out <- tibble::tibble(
      site_1 = s$.site[ij[1, ]],
      site_2 = s$.site[ij[2, ]],
      distance = d
    )
    if (length(by_cols) > 0) {
      key <- vctrs::vec_slice(split$key, rep(i, nrow(out)))
      out <- vctrs::vec_cbind(key, out)
    }
    out
  })
  out <- tibble::as_tibble(vctrs::vec_rbind(!!!rows))
  tmr_new(out, "tmr_geo_distance")
}

geo_distance_env_cols <- function(data, vars, site_col, by_cols,
                                  lon_col, lat_col, elev_col) {
  if (!is.null(vars)) {
    missing <- setdiff(vars, names(data))
    if (length(missing) > 0) {
      cli::cli_abort("Unknown environmental column{?s}: {.val {missing}}.")
    }
    return(vars)
  }
  skip <- unique(c(site_col, by_cols, lon_col, lat_col, elev_col,
                   "site_1", "site_2", "distance"))
  skip <- skip[!is.null(skip) & nzchar(skip)]
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  env <- setdiff(num, skip)
  if (length(env) == 0) {
    cli::cli_abort(
      c(
        "No environmental columns found for {.arg method} = {.val environmental}.",
        "i" = "Pass {.arg vars} or join bioclim columns with {.fn geo_extract}."
      )
    )
  }
  env
}

geo_env_pairwise <- function(mat, ij, scale = TRUE, metric = "euclidean") {
  x <- as.matrix(mat)
  storage.mode(x) <- "double"
  if (identical(metric, "gower")) {
    # Simple Gower on numeric columns: |xi-xj| / range
    rng <- apply(x, 2, function(v) {
      r <- diff(range(v, na.rm = TRUE))
      if (!is.finite(r) || r == 0) 1 else r
    })
    d <- numeric(ncol(ij))
    for (k in seq_len(ncol(ij))) {
      a <- x[ij[1, k], ]
      b <- x[ij[2, k], ]
      d[k] <- mean(abs(a - b) / rng, na.rm = TRUE)
    }
    return(d)
  }
  if (isTRUE(scale)) {
    for (j in seq_len(ncol(x))) {
      s <- stats::sd(x[, j], na.rm = TRUE)
      m <- mean(x[, j], na.rm = TRUE)
      if (is.finite(s) && s > 0) {
        x[, j] <- (x[, j] - m) / s
      } else {
        x[, j] <- x[, j] - m
      }
    }
  }
  if (exists("geo_euclidean_pair_cpp", mode = "function")) {
    return(geo_euclidean_pair_cpp(x[ij[1, ], , drop = FALSE],
                                  x[ij[2, ], , drop = FALSE]))
  }
  sqrt(rowSums((x[ij[1, ], , drop = FALSE] - x[ij[2, ], , drop = FALSE])^2))
}

#' Distance decay with geographic, elevational or environmental distance
#'
#' Computes pairwise beta diversity with [tidydiversity::beta_pair()] and
#' joins distances from [geo_distance()] (great-circle, elevational or
#' environmental), returning a `td_beta_decay` object (see
#' [tidydiversity::beta_decay()]) for [tidydiversity::beta_decay_model()] and
#' [ggplot2::autoplot()].
#'
#' Needs the **tidydiversity** package.
#'
#' @param data A long community table with coordinate columns.
#' @param site,species,abundance <[`tidy-select`][dplyr::dplyr_tidy_select]>
#'   Site, species and (optional) abundance columns of `data`.
#' @param index Dissimilarity family passed to [tidydiversity::beta_pair()]:
#'   `"sorensen"`, `"jaccard"` or `"bray"`.
#' @param .by <[`tidy-select`][dplyr::dplyr_tidy_select]> Optional grouping
#'   columns.
#' @param lon,lat,elevation Coordinate and elevation columns of `data`.
#' @param method,vars,scale,metric Passed to [geo_distance()].
#' @return A `td_beta_decay` tibble.
#' @export
#' @examplesIf requireNamespace("tidydiversity", quietly = TRUE)
#' png_ants <- tidydiversity::png_ants
#' sites <- unique(png_ants[c("site", "elevation", "season")])
#' # Illustrative lon/lat near Mt Wilhelm for the example
#' sites$lon <- 145.0 + sites$elevation / 1e5
#' sites$lat <- -5.8 - sites$elevation / 2e5
#' com <- dplyr::left_join(png_ants, sites[c("site", "season", "lon", "lat")],
#'   by = c("site", "season")
#' )
#' decay <- geo_decay(com, lon, lat, .by = season, method = "haversine")
#' head(decay)
geo_decay <- function(data,
                      lon = lon,
                      lat = lat,
                      elevation = NULL,
                      site = site,
                      species = species,
                      abundance = NULL,
                      index = c("sorensen", "jaccard", "bray"),
                      method = c("haversine", "elevation", "euclidean",
                                 "environmental"),
                      vars = NULL,
                      scale = TRUE,
                      metric = c("euclidean", "gower"),
                      .by = NULL) {
  index <- rlang::arg_match(index)
  method <- rlang::arg_match(method)
  metric <- rlang::arg_match(metric)
  rlang::check_installed("tidydiversity", reason = "to compute beta diversity.")
  pairs <- tidydiversity::beta_pair(
    data,
    site = {{ site }},
    species = {{ species }},
    abundance = {{ abundance }},
    index = index,
    .by = {{ .by }}
  )
  dist <- geo_distance(
    data,
    lon = {{ lon }},
    lat = {{ lat }},
    elevation = {{ elevation }},
    site = {{ site }},
    method = method,
    vars = vars,
    scale = scale,
    metric = metric,
    .by = {{ .by }}
  )
  keys <- intersect(names(pairs), names(dist))
  out <- dplyr::left_join(tibble::as_tibble(pairs), tibble::as_tibble(dist),
    by = keys
  )
  tmr_new(out, "td_beta_decay")
}

#' Map Hill numbers (and coverage) in geographic space
#'
#' Plots site-level diversity estimates as points on an sf map, with an
#' optional raster backdrop. Uses [theme_tidymapr()] and the
#' colour-blind-safe Okabe-Ito / viridis scales.
#'
#' @param data An `sf` object or a data frame with `lon`/`lat` and an
#'   estimate column (for example the output of
#'   [tidydiversity::div_estimate()] joined to coordinates with
#'   [tidydiversity::add_site_data()] / [geo_as_sf()]).
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Column to map
#'   (fill / size).
#' @param lon,lat Coordinate columns when `data` is not `sf`.
#' @param basemap Basemap: `"none"`, `"coast"`, tile name, SpatRaster or
#'   path. See [geo_basemap()].
#' @param raster Optional `SpatRaster` backdrop (used when `basemap` is
#'   `"none"`).
#' @param coastline Optional coastline `sf` for a coast basemap.
#' @param size Point size when not mapping size to `value`.
#' @param label Optional column of site labels.
#' @param scale_bar,north_arrow Draw a scale bar and north arrow?
#' @param scale_bar_km Length of the scale bar in kilometres.
#' @param legend_title Optional legend title (defaults to the value column).
#' @param legend_position `"auto"` (collision-aware inside corner),
#'   `"outside"`, or a corner `"bl"` / `"br"` / `"tl"` / `"tr"`.
#' @param legend_frame Draw a frame around an inside legend?
#' @param size Point size, or a bare column mapped to point size (combined
#'   with `value` like tmap size + col, e.g. Hill number and elevation).
#' @param inset Overview map: `FALSE`, `TRUE`/`"auto"`, `"png"`, or a
#'   length-4 bbox. Uses the same collision reservation as the scale bar
#'   and north arrow. PNG insets prefer GADM provinces when cached.
#' @param admin Optional administrative boundaries (`sf` or ISO3 code);
#'   see [plot_sites()].
#' @param admin_level GADM level when `admin` is a country code.
#' @param admin_fill Fill admin polygons instead of outlines only.
#' @return A ggplot object with attribute `tmr_decoration`.
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' est <- tibble::tibble(
#'   site = c("a", "b", "c"),
#'   lon = c(147.0, 147.2, 147.4),
#'   lat = c(-9.4, -9.5, -9.6),
#'   diversity = c(12, 18, 9)
#' )
#' plot_geo(est, diversity, lon, lat, basemap = "coast", label = site)
plot_geo <- function(data,
                     value = NULL,
                     lon = lon,
                     lat = lat,
                     basemap = "esri",
                     raster = NULL,
                     coastline = NULL,
                     size = 3,
                     label = NULL,
                     scale_bar = TRUE,
                     north_arrow = TRUE,
                     scale_bar_km = NULL,
                     legend_title = NULL,
                     legend_position = "auto",
                     legend_frame = TRUE,
                     inset = FALSE,
                     admin = NULL,
                     admin_level = 1,
                     admin_fill = FALSE) {
  rlang::check_installed("ggplot2")
  rlang::check_installed("sf")
  tmr_check_data(data)
  val_q <- enquo(value)
  if (rlang::quo_is_null(val_q)) {
    # Auto-pick common Hill / coverage columns when value is omitted
    candidates <- c("diversity", "estimate", "coverage", "qD", "obs")
    hit <- candidates[candidates %in% names(data)]
    if (length(hit) == 0) {
      cli::cli_abort(
        "{.arg value} is required unless {.arg data} has a diversity/estimate column."
      )
    }
    val_col <- hit[[1]]
  } else {
    val_col <- tmr_pick(val_q, data, "value")
  }
  lab_q <- enquo(label)
  lab_col <- if (quo_is_null(lab_q)) NULL else tmr_pick(lab_q, data, "label")
  leg <- legend_title %||% geo_pretty_label(val_col)

  if (!inherits(data, "sf")) {
    data <- geo_as_sf(data, lon = {{ lon }}, lat = {{ lat }}, drop_na = TRUE)
  } else {
    data <- geo_as_sf(data)
  }

  p <- ggplot2::ggplot()
  bm <- basemap
  if (identical(bm, "none") && !is.null(raster)) {
    bm <- raster
  }
  bb <- sf::st_bbox(data)
  dx <- max((bb["xmax"] - bb["xmin"]) * 0.35, 0.15)
  dy <- max((bb["ymax"] - bb["ymin"]) * 0.45, 0.12)
  bb["xmin"] <- bb["xmin"] - dx
  bb["xmax"] <- bb["xmax"] + dx
  bb["ymin"] <- bb["ymin"] - dy
  bb["ymax"] <- bb["ymax"] + dy
  bm_layers <- geo_basemap_layers(
    bb, basemap = bm, coastline = coastline, crs = sf::st_crs(data)
  )
  for (ly in bm_layers$layers) {
    p <- p + ly
  }

  admin_sf <- geo_resolve_admin(admin, level = admin_level, crs = sf::st_crs(data))
  if (!is.null(admin_sf)) {
    for (ly in geo_admin_layers(admin_sf, fill = isTRUE(admin_fill))) {
      p <- p + ly
    }
  }

  # size may be a constant or a second column (e.g. elevation) combined with value
  size_q <- enquo(size)
  size_expr <- rlang::quo_get_expr(size_q)
  size_aes <- NULL
  size_const <- 3
  if (is.symbol(size_expr) && as.character(size_expr) %in% names(data)) {
    size_aes <- as.character(size_expr)
  } else {
    sv <- rlang::eval_tidy(size_q, data = data)
    if (is.numeric(sv) && length(sv) == 1L) size_const <- sv
  }
  # Keep labelled maps readable: large size aesthetics crowd geom_label_repel
  size_max <- if (!is.null(lab_col)) 6.5 else 10

  # Map value to fill (or colour when basemap uses fill); optional size_aes
  use_fill <- !isTRUE(bm_layers$uses_fill)
  if (use_fill && is.null(size_aes)) {
    p <- p +
      ggplot2::geom_sf(
        data = data,
        ggplot2::aes(fill = .data[[val_col]]),
        shape = 21, colour = "grey20", size = size_const, stroke = 0.3
      ) +
      ggplot2::scale_fill_viridis_c(
        name = leg, option = "C",
        guide = ggplot2::guide_colourbar(order = 1)
      )
  } else if (use_fill && !is.null(size_aes)) {
    p <- p +
      ggplot2::geom_sf(
        data = data,
        ggplot2::aes(fill = .data[[val_col]], size = .data[[size_aes]]),
        shape = 21, colour = "grey20", stroke = 0.3
      ) +
      ggplot2::scale_fill_viridis_c(
        name = leg, option = "C",
        guide = ggplot2::guide_colourbar(order = 1)
      ) +
      ggplot2::scale_size_area(
        name = geo_pretty_label(size_aes), max_size = size_max,
        guide = ggplot2::guide_legend(order = 2)
      )
  } else if (!is.null(size_aes)) {
    p <- p +
      ggplot2::geom_sf(
        data = data,
        ggplot2::aes(colour = .data[[val_col]], size = .data[[size_aes]]),
        shape = 16, stroke = 0.3
      ) +
      ggplot2::scale_colour_viridis_c(
        name = leg, option = "C",
        guide = ggplot2::guide_colourbar(order = 1)
      ) +
      ggplot2::scale_size_area(
        name = geo_pretty_label(size_aes), max_size = size_max,
        guide = ggplot2::guide_legend(order = 2)
      )
  } else {
    p <- p +
      ggplot2::geom_sf(
        data = data,
        ggplot2::aes(size = .data[[val_col]]),
        shape = 21, fill = tmr_palette(1), colour = "grey10", stroke = 0.4
      ) +
      ggplot2::scale_size_area(name = leg, max_size = size_max)
  }
  if (!is.null(lab_col)) {
    rlang::check_installed("ggrepel")
    xy <- sf::st_coordinates(data)
    labs <- tibble::tibble(
      x = xy[, 1], y = xy[, 2],
      .lab = as.character(data[[lab_col]])
    )
    p <- p + geo_label_repel_layer(labs)
  }
  legend_inside <- !identical(legend_position, "outside") &&
    (identical(legend_position, "auto") ||
       legend_position %in% c("bl", "br", "tl", "tr"))
  want_inset <- !isFALSE(inset) && !is.null(inset)
  decor <- geo_pick_decoration_corner(
    data, bb,
    scale_bar = isTRUE(scale_bar),
    north_arrow = isTRUE(north_arrow),
    inset = want_inset,
    legend_inside = legend_inside
  )
  if (legend_position %in% c("bl", "br", "tl", "tr")) {
    lj <- geo_legend_npc(legend_position)
    decor$legend_corner <- legend_position
    decor$legend_position <- lj$position
    decor$legend_justification <- lj$justification
    decor$legend_box <- geo_decoration_box(bb, legend_position)
  }
  if (isTRUE(scale_bar) && !is.null(decor$scale_box)) {
    for (ly in geo_annotation_scale_bar(
      bb, length_km = scale_bar_km, crs = sf::st_crs(data),
      corner = decor$scale_corner, box = decor$scale_box
    )) {
      p <- p + ly
    }
  }
  if (isTRUE(north_arrow) && !is.null(decor$north_box)) {
    for (ly in geo_annotation_north_arrow(
      bb, corner = decor$north_corner, box = decor$north_box
    )) {
      p <- p + ly
    }
  }
  if (want_inset && !is.null(decor$inset_box)) {
    for (ly in geo_annotation_inset(
      bb, decor$inset_box, inset = inset, crs = sf::st_crs(data)
    )) {
      p <- p + ly
    }
  }
  p <- p +
    ggplot2::coord_sf(expand = FALSE) +
    theme_tidymapr(grid = "none") +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey20", linewidth = 0.4)
    ) +
    geo_legend_theme(
      position = legend_position, frame = legend_frame, decor = decor
    ) +
    ggplot2::labs(x = NULL, y = NULL)
  attr(p, "tmr_decoration") <- decor
  p
}

#' Moran's I for spatial autocorrelation of diversity
#'
#' Computes Moran's I for a numeric site attribute (for example a Hill
#' number or a model residual) using inverse-distance weights among sites.
#' A permutation p-value is returned. Implemented natively so callers do
#' not need spdep; when spdep is installed, tests compare the two.
#'
#' @param data A data frame of sites with coordinates and a value column.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Numeric column
#'   to test.
#' @param lon,lat Coordinate columns.
#' @param site Optional site column for labels in the correlogram.
#' @param nperm Number of permutations for the p-value.
#' @param correlogram If `TRUE`, also return a simple distance-bin
#'   correlogram.
#' @param bins Number of distance bins for the correlogram.
#' @param seed Optional RNG seed for permutations.
#' @return A tibble (`tmr_geo_moran`) with Moran's I, the expected value under
#'   randomness, the variance under normality, a two-sided permutation
#'   p-value, and optional correlogram rows in attribute `correlogram`.
#' @references Moran, P. A. P. (1950). Notes on continuous stochastic
#'   phenomena. *Biometrika*, 37, 17-23. \doi{10.2307/2332142}
#' @export
#' @examples
#' set.seed(1)
#' # Positive spatial autocorrelation along a gradient
#' g <- expand.grid(x = 1:6, y = 1:6)
#' g$val <- g$x + 0.3 * rnorm(nrow(g))
#' geo_moran(g, val, lon = x, lat = y, nperm = 199)
geo_moran <- function(data,
                      value,
                      lon = lon,
                      lat = lat,
                      site = NULL,
                      nperm = 999,
                      correlogram = FALSE,
                      bins = 5,
                      seed = NULL) {
  tmr_check_data(data)
  tmr_check_number(nperm, "nperm", 0, whole = TRUE)
  val_col <- tmr_pick(enquo(value), data, "value")
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  x <- as.numeric(data[[val_col]])
  lon_v <- as.numeric(data[[lon_col]])
  lat_v <- as.numeric(data[[lat_col]])
  ok <- is.finite(x) & is.finite(lon_v) & is.finite(lat_v)
  x <- x[ok]
  lon_v <- lon_v[ok]
  lat_v <- lat_v[ok]
  n <- length(x)
  if (n < 3) {
    cli::cli_abort("Moran's I needs at least three finite sites.")
  }

  if (exists("geo_haversine_matrix_cpp", mode = "function")) {
    d <- geo_haversine_matrix_cpp(lon_v, lat_v)
  } else {
    d <- outer(seq_len(n), seq_len(n), function(i, j) {
      geo_haversine_m(lon_v[i], lat_v[i], lon_v[j], lat_v[j])
    })
  }
  # Inverse distance, zero diagonal
  w <- 1 / d
  diag(w) <- 0
  w[!is.finite(w)] <- 0
  # Row-standardise
  rs <- rowSums(w)
  rs[rs == 0] <- 1
  w <- w / rs

  mi <- geo_moran_i(x, w)
  if (!is.null(seed)) {
    set.seed(seed)
  }
  null <- numeric(nperm)
  for (p in seq_len(nperm)) {
    null[p] <- geo_moran_i(sample(x), w)
  }
  # Two-sided permutation p-value, never zero
  p_value <- (1 + sum(abs(null - mean(null)) >= abs(mi - mean(null)))) /
    (1 + nperm)

  # Analytical expectation / variance under normality (Cliff and Ord)
  ei <- -1 / (n - 1)
  s0 <- sum(w)
  s1 <- 0.5 * sum((w + t(w))^2)
  s2 <- sum((rowSums(w) + colSums(w))^2)
  b2 <- (sum((x - mean(x))^4) / n) / (sum((x - mean(x))^2) / n)^2
  vi <- (n * ((n^2 - 3 * n + 3) * s1 - n * s2 + 3 * s0^2) -
           b2 * ((n^2 - n) * s1 - 2 * n * s2 + 6 * s0^2)) /
    ((n - 1) * (n - 2) * (n - 3) * s0^2) - ei^2

  out <- tibble::tibble(
    statistic = mi,
    expectation = ei,
    variance = vi,
    p.value = p_value,
    n = n,
    nperm = nperm,
    method = "Moran's I (inverse-distance, row-standardised)"
  )
  out <- tmr_new(out, "tmr_geo_moran")
  if (isTRUE(correlogram)) {
    attr(out, "correlogram") <- geo_correlogram(x, d, bins = bins)
  }
  out
}

geo_moran_i <- function(x, w) {
  z <- x - mean(x)
  n <- length(z)
  num <- as.numeric(t(z) %*% w %*% z)
  den <- sum(z^2)
  (n / sum(w)) * (num / den)
}

geo_correlogram <- function(x, d, bins = 5) {
  n <- length(x)
  ut <- upper.tri(d)
  dist <- as.numeric(d[ut])
  # Pairwise z_i * z_j
  z <- x - mean(x)
  zz <- outer(z, z)
  prod <- as.numeric(zz[ut])
  ok <- is.finite(dist) & dist > 0 & is.finite(prod)
  dist <- dist[ok]
  prod <- prod[ok]
  if (length(dist) < 2L) {
    return(tibble::tibble(
      bin = 1L, distance = NA_real_, moran = NA_real_, n = 0L
    ))
  }
  brks <- unique(as.numeric(stats::quantile(
    dist, probs = seq(0, 1, length.out = bins + 1L), names = FALSE
  )))
  if (length(brks) < 3L) {
    return(tibble::tibble(
      bin = 1L, distance = mean(dist), moran = NA_real_, n = length(dist)
    ))
  }
  # Integer labels avoid empty-factor length mismatches in tibble()
  grp <- cut(dist, breaks = brks, include.lowest = TRUE, labels = FALSE)
  keep <- !is.na(grp)
  dist <- dist[keep]
  prod <- prod[keep]
  grp <- grp[keep]
  ids <- sort(unique(grp))
  scale <- sum(z^2) / n
  # Precompute outside tibble() so column name `bin` cannot mask `grp`
  out_distance <- vapply(ids, function(i) mean(dist[grp == i]), numeric(1))
  out_moran <- vapply(ids, function(i) mean(prod[grp == i]) / scale, numeric(1))
  out_n <- vapply(ids, function(i) sum(grp == i), integer(1))
  tibble::tibble(
    bin = as.integer(ids),
    distance = out_distance,
    moran = out_moran,
    n = out_n
  )
}
