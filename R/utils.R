# Column handling ---------------------------------------------------------

tmr_check_data <- function(data, call = caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame, not {.obj_type_friendly {data}}.",
      call = call
    )
  }
  if (nrow(data) == 0) {
    cli::cli_abort("{.arg data} must have at least one row.", call = call)
  }
  invisible(data)
}

tmr_pick <- function(quo, data, arg, call = caller_env(), lonlat = TRUE) {
  loc <- tidyselect::eval_select(
    quo,
    data,
    allow_rename = FALSE,
    error_call = call
  )
  if (length(loc) != 1) {
    cli::cli_abort(
      "{.arg {arg}} must select exactly one column, not {length(loc)}.",
      call = call
    )
  }
  col <- names(loc)
  if (isTRUE(lonlat) && arg %in% c("lon", "lat")) {
    tmr_check_lonlat(data[[col]], arg, col, call = call)
  }
  col
}

# Coordinate columns of a plain data frame are read as longitude/latitude
# in degrees (WGS84). Values outside that range are projected coordinates
# (metres, feet): stop instead of computing distances from them as if they
# were degrees. Projected data go in as an sf table with its CRS, which
# every function handles correctly.
tmr_check_lonlat <- function(v, arg, col, call = caller_env()) {
  if (!is.numeric(v)) {
    cli::cli_abort("{.arg {arg}} column {.field {col}} must be numeric.", call = call)
  }
  lim <- if (arg == "lon") 360 else 90
  bad <- is.finite(v) & abs(v) > lim
  if (any(bad)) {
    unit <- if (arg == "lon") "longitude (-180 to 360)" else "latitude (-90 to 90)"
    cli::cli_abort(c(
      paste(
        "{.arg {arg}} column {.field {col}} is not a {unit} in degrees:",
        "{sum(bad)} value{?s} out of range (e.g. {format(v[bad][1], big.mark = ',')})."
      ),
      "i" = paste(
        "These look like projected coordinates (for example metres in UTM).",
        "Convert them to an {.cls sf} table with their CRS, which tidymapr measures correctly:"
      ),
      " " = "{.code sf::st_as_sf(data, coords = c(\"x\", \"y\"), crs = <EPSG code>)}"
    ), call = call)
  }
  invisible(TRUE)
}

tmr_group_cols <- function(data, by, call = caller_env()) {
  by_cols <- names(tidyselect::eval_select(by, data, error_call = call))
  if (length(by_cols) > 0 && dplyr::is_grouped_df(data)) {
    cli::cli_abort(
      "Can't supply {.arg .by} when {.arg data} is a grouped data frame.",
      call = call
    )
  }
  if (length(by_cols) == 0) {
    by_cols <- dplyr::group_vars(data)
  }
  by_cols
}

tmr_check_number <- function(x, arg, min = 0, max = Inf, whole = FALSE,
                             call = caller_env()) {
  ok <- is.numeric(x) && length(x) == 1 && !is.na(x) && x >= min && x <= max
  if (ok && whole) ok <- abs(x - round(x)) < 1e-8
  if (!ok) {
    what <- if (whole) "a whole number" else "a number"
    cli::cli_abort(
      "{.arg {arg}} must be {what} between {min} and {max}.",
      call = call
    )
  }
  invisible(x)
}

tmr_new <- function(x, class) {
  tibble::new_tibble(x, class = class)
}

# Cores for tidymapr's C++ kernels: options(tidymapr.threads = n) wins;
# otherwise all cores but one, and at most 2 under R CMD check (CRAN policy)
tmr_threads <- function() {
  opt <- getOption("tidymapr.threads")
  if (!is.null(opt)) return(max(1L, as.integer(opt)))
  if (nzchar(Sys.getenv("_R_CHECK_LIMIT_CORES_"))) return(2L)
  cores <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) NA)
  if (is.na(cores)) 1L else max(1L, as.integer(cores) - 1L)
}

# Is a CRS (EPSG code, string or crs object) longitude/latitude?
tmr_crs_is_lonlat <- function(crs) {
  if (is.null(crs)) {
    return(TRUE)
  }
  if (requireNamespace("sf", quietly = TRUE)) {
    return(isTRUE(sf::st_is_longlat(sf::st_crs(crs))))
  }
  grepl("4326|longlat|lonlat|WGS ?84$", as.character(crs)[1], ignore.case = TRUE)
}

# sf input for functions that work on coordinate columns: add .lon/.lat
# columns (degrees for great-circle distances, the CRS units otherwise) and
# drop the geometry.
tmr_sf_coords <- function(data, planar = FALSE) {
  g <- sf::st_geometry(data)
  if (!all(sf::st_geometry_type(g) == "POINT")) {
    g <- suppressWarnings(sf::st_point_on_surface(g))
  }
  if (!planar) {
    g <- sf::st_transform(g, 4326)
  } else if (isTRUE(sf::st_is_longlat(g))) {
    cli::cli_abort(paste(
      "{.code method = \"euclidean\"} needs projected coordinates;",
      "this {.cls sf} table is in longitude/latitude."
    ), call = rlang::caller_env())
  }
  xy <- sf::st_coordinates(g)
  out <- sf::st_drop_geometry(data)
  out$.lon <- xy[, 1]
  out$.lat <- xy[, 2]
  out
}

# Colours for categories. A named palette maps each category to the colour
# with its name, whatever the order of the categories; names that do not
# cover every category are an error, never a silent reassignment. An
# unnamed palette is used in order through `fallback(n)`.
tmr_category_colours <- function(palette, levs, fallback, call = caller_env()) {
  if (!is.null(names(palette)) && any(nzchar(names(palette)))) {
    missing <- setdiff(levs, names(palette))
    if (length(missing) > 0) {
      cli::cli_abort(c(
        paste(
          "{.arg palette} is named but has no colour for",
          "{length(missing)} categor{?y/ies}: {.val {missing}}."
        ),
        "i" = "Name a colour for every category, or pass an unnamed palette."
      ), call = call)
    }
    return(stats::setNames(unname(palette[levs]), levs))
  }
  stats::setNames(fallback(length(levs)), levs)
}

# Category order: factor levels (those present), otherwise sorted values
tmr_levels <- function(v) {
  if (is.factor(v)) {
    intersect(levels(v), unique(as.character(v)))
  } else {
    sort(unique(as.character(v)))
  }
}
