#' Terrain hydrology: flow direction, accumulation, watersheds and TWI
#'
#' @description
#' D8 hydrology on a digital elevation model, computed in C++ and returned
#' as `terra::SpatRaster` layers:
#'
#' * `geo_flow_direction()`: the steepest-descent neighbour of each cell,
#'   coded as in ESRI and [terra::terrain()] (1 E, 2 SE, 4 S, 8 SW, 16 W,
#'   32 NW, 64 N, 128 NE; 0 for a pit or flat cell);
#' * `geo_flow_accumulation()`: the number of cells (or the sum of
#'   `weight`) draining through each cell, the cell itself included;
#' * `geo_watershed()`: the catchment above each outlet point, labelled
#'   1, 2, ... in the order of `outlets`;
#' * `geo_twi()`: the topographic wetness index
#'   \eqn{\ln(a / \tan\beta)}, with \eqn{a} the upslope area per unit
#'   contour width and \eqn{\beta} the local slope (Beven and Kirkby 1979).
#'
#' Pits are not filled: flow stops at a cell with no lower neighbour. Fill
#' sinks first (for example with `whitebox::wbt_fill_depressions()`) when
#' you need continuous drainage across a noisy DEM. On longitude/latitude
#' rasters, cell sizes are converted to metres at the raster's mid-latitude.
#'
#' @param dem A `terra::SpatRaster` (first layer used) or a file path.
#' @param direction Optional D8 layer from `geo_flow_direction()`; computed
#'   from `dem` when `NULL`.
#' @param weight Optional `SpatRaster` of per-cell weights (for example
#'   rainfall) with the same geometry as `dem`. Default 1 per cell.
#' @param outlets An `sf` point table (or a two-column matrix of x, y in the
#'   raster's CRS) giving one outlet per watershed.
#' @param snap Search radius in cells: each outlet moves to the cell of
#'   highest flow accumulation within this distance, so that a point a
#'   little off the stream still finds it. `0` (default) keeps it as is.
#' @return A single-layer `SpatRaster` named `"flowdir"`, `"flowacc"`,
#'   `"watershed"` or `"twi"`.
#' @references Beven, K. J. and Kirkby, M. J. (1979). A physically based,
#'   variable contributing area model of basin hydrology. *Hydrological
#'   Sciences Bulletin*, 24, 43-69. \doi{10.1080/02626667909491834}
#'
#'   O'Callaghan, J. F. and Mark, D. M. (1984). The extraction of drainage
#'   networks from digital elevation data. *Computer Vision, Graphics, and
#'   Image Processing*, 28, 323-344. \doi{10.1016/S0734-189X(84)80011-0}
#' @name geo-hydrology
#' @examplesIf requireNamespace("terra", quietly = TRUE)
#' # Real SRTM-derived elevation for Luxembourg, shipped with terra,
#' # projected to metres (LUREF, EPSG:2169)
#' dem <- terra::rast(system.file("ex/elev.tif", package = "terra"))
#' dem <- terra::project(dem, "EPSG:2169")
#' acc <- geo_flow_accumulation(dem)
#' outlet <- terra::xyFromCell(acc, terra::where.max(acc)[1, "cell"])
#' ws <- geo_watershed(dem, outlet)
#' terra::global(ws, "notNA")
#' twi <- geo_twi(dem)
#' terra::plot(twi, col = grDevices::hcl.colors(50, "Blues 3", rev = TRUE))
NULL

#' @rdname geo-hydrology
#' @export
geo_flow_direction <- function(dem) {
  r <- tmr_hydro_dem(dem)
  d <- tmr_cell_size(r)
  v <- geo_d8_cpp(
    as.numeric(terra::values(r, mat = FALSE)),
    terra::nrow(r), terra::ncol(r), d[1], d[2]
  )
  tmr_hydro_out(r, v, "flowdir")
}

#' @rdname geo-hydrology
#' @export
geo_flow_accumulation <- function(dem, direction = NULL, weight = NULL) {
  r <- tmr_hydro_dem(dem)
  dir <- direction %||% geo_flow_direction(r)
  w <- if (is.null(weight)) {
    rep(1, terra::ncell(r))
  } else {
    w <- geo_as_raster(weight)[[1]][[1]]
    if (!terra::compareGeom(r, w, stopOnError = FALSE)) {
      cli::cli_abort("{.arg weight} must have the same geometry as {.arg dem}.")
    }
    wv <- as.numeric(terra::values(w, mat = FALSE))
    wv[is.na(wv)] <- 0
    wv
  }
  v <- geo_flowacc_cpp(
    as.integer(terra::values(dir, mat = FALSE)),
    terra::nrow(r), terra::ncol(r), w
  )
  tmr_hydro_out(r, v, "flowacc")
}

#' @rdname geo-hydrology
#' @export
geo_watershed <- function(dem, outlets, direction = NULL, snap = 0) {
  r <- tmr_hydro_dem(dem)
  tmr_check_number(snap, "snap", 0, whole = TRUE)
  xy <- tmr_outlet_xy(outlets, r)
  cells <- terra::cellFromXY(r, xy)
  if (anyNA(cells)) {
    cli::cli_abort("{sum(is.na(cells))} outlet{?s} fall{?s/} outside {.arg dem}.")
  }
  dir <- direction %||% geo_flow_direction(r)
  if (snap > 0) {
    acc <- geo_flow_accumulation(r, direction = dir)
    cells <- vapply(cells, tmr_snap_cell, numeric(1), acc = acc, k = snap)
  }
  v <- geo_watershed_cpp(
    as.integer(terra::values(dir, mat = FALSE)),
    terra::nrow(r), terra::ncol(r), as.integer(cells - 1)
  )
  tmr_hydro_out(r, v, "watershed")
}

#' @rdname geo-hydrology
#' @export
geo_twi <- function(dem, direction = NULL) {
  r <- tmr_hydro_dem(dem)
  d <- tmr_cell_size(r)
  acc <- geo_flow_accumulation(r, direction = direction)
  # Specific catchment area: upslope area per unit contour width (m)
  a <- acc * (d[1] * d[2]) / sqrt(d[1] * d[2])
  slope <- tmr_hydro_out(r, tmr_slope_rad(r, d), "slope")
  tanb <- terra::app(tan(slope), function(x) pmax(x, 0.001))
  out <- log(a / tanb)
  names(out) <- "twi"
  out
}

tmr_hydro_dem <- function(dem, call = caller_env()) {
  rlang::check_installed("terra")
  r <- geo_as_raster(dem, call = call)[[1]][[1]]
  if (terra::ncell(r) < 4) {
    cli::cli_abort("{.arg dem} needs at least 2 x 2 cells.", call = call)
  }
  r
}

tmr_hydro_out <- function(r, v, name) {
  out <- terra::rast(r)
  terra::values(out) <- v
  names(out) <- name
  out
}

# Cell width and height in metres (degrees converted at mid-latitude)
tmr_cell_size <- function(r) {
  res <- terra::res(r)
  if (isTRUE(terra::is.lonlat(r))) {
    lat <- mean(terra::ext(r)[3:4]) * pi / 180
    res <- res * c(111320 * cos(lat), 110574)
  }
  res
}

# Horn (1981) slope in radians, matching terra::terrain() on projected data
tmr_slope_rad <- function(r, d) {
  m <- terra::as.matrix(r, wide = TRUE)
  nr <- nrow(m)
  nc <- ncol(m)
  p <- matrix(NA_real_, nr + 2, nc + 2)
  p[2:(nr + 1), 2:(nc + 1)] <- m
  # Replicate edges so border cells get a slope too
  p[1, ] <- p[2, ]
  p[nr + 2, ] <- p[nr + 1, ]
  p[, 1] <- p[, 2]
  p[, nc + 2] <- p[, nc + 1]
  # Missing neighbours (DEM edges, coastlines) take the centre value
  z <- function(i, j) {
    v <- p[(2 + i):(nr + 1 + i), (2 + j):(nc + 1 + j)]
    v[is.na(v)] <- m[is.na(v)]
    v
  }
  east <- z(-1, 1) + 2 * z(0, 1) + z(1, 1)
  west <- z(-1, -1) + 2 * z(0, -1) + z(1, -1)
  south <- z(1, -1) + 2 * z(1, 0) + z(1, 1)
  north <- z(-1, -1) + 2 * z(-1, 0) + z(-1, 1)
  dzdx <- (east - west) / (8 * d[1])
  dzdy <- (south - north) / (8 * d[2])
  as.vector(t(atan(sqrt(dzdx^2 + dzdy^2))))
}

tmr_outlet_xy <- function(outlets, r, call = caller_env()) {
  if (inherits(outlets, c("sf", "sfc"))) {
    rlang::check_installed("sf")
    crs <- terra::crs(r)
    if (nzchar(crs)) outlets <- sf::st_transform(outlets, crs)
    return(sf::st_coordinates(sf::st_geometry(outlets))[, 1:2, drop = FALSE])
  }
  if (is.numeric(outlets) && (is.matrix(outlets) || length(outlets) == 2)) {
    return(matrix(outlets, ncol = 2))
  }
  cli::cli_abort(
    "{.arg outlets} must be an {.cls sf} point table or a two-column matrix.",
    call = call
  )
}

tmr_snap_cell <- function(cell, acc, k) {
  rc <- terra::rowColFromCell(acc, cell)
  rows <- max(1, rc[1] - k):min(terra::nrow(acc), rc[1] + k)
  cols <- max(1, rc[2] - k):min(terra::ncol(acc), rc[2] + k)
  cand <- terra::cellFromRowColCombine(acc, rows, cols)
  v <- terra::values(acc, mat = FALSE)[cand]
  if (all(is.na(v))) cell else cand[which.max(v)]
}
