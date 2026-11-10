#' Point clusters with DBSCAN
#'
#' @description
#' `geo_dbscan()` finds clusters of points with DBSCAN (Ester et al. 1996),
#' the clustering tool of the GeoSpaX plug-ins: points with at least
#' `min_pts` neighbours within `eps` form cluster cores, points near a core
#' join its cluster, and the rest are noise. Distances are in metres for
#' geographic data (points are projected to an equal-area projection
#' centred on them), so `eps` means the same thing anywhere on Earth. The
#' search uses a grid index in C++. Each cluster also gets its outline as a
#' convex hull.
#'
#' @param data An `sf` point table, or a data frame with coordinate columns.
#' @param eps Neighbourhood radius, in metres (or in the units of a
#'   projected CRS).
#' @param min_pts Smallest number of points within `eps` (the point itself
#'   included) for a core point.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns when `data` is not `sf`.
#' @param crs Coordinate reference system of `lon`/`lat` (default WGS 84).
#' @return The points as `sf` with `cluster` (integer; `0` for noise) and
#'   `core` (logical). Attribute `"hulls"` holds an `sf` table of cluster
#'   outlines with the number of points in each.
#' @references Ester M, Kriegel H-P, Sander J, Xu X (1996) A density-based
#'   algorithm for discovering clusters in large spatial databases with
#'   noise. Proceedings of KDD-96: 226-231.
#' @seealso [geo_hotspot()] for hot spots of values, [geo_landscape()] for
#'   fragmentation.
#' @examplesIf rlang::is_installed("sf")
#' # Earthquakes near Fiji since 1964 (datasets::quakes)
#' cl <- geo_dbscan(datasets::quakes, eps = 50000, min_pts = 15,
#'   lon = long, lat = lat)
#' table(cl$cluster)
#' attr(cl, "hulls")
#' @export
geo_dbscan <- function(data,
                       eps,
                       min_pts = 5,
                       lon = lon,
                       lat = lat,
                       crs = 4326) {
  rlang::check_installed("sf")
  tmr_check_number(eps, "eps", 0)
  tmr_check_number(min_pts, "min_pts", 1)
  if (!inherits(data, "sf")) {
    tmr_check_data(data)
    lon_col <- tmr_pick(rlang::enquo(lon), data, "lon")
    lat_col <- tmr_pick(rlang::enquo(lat), data, "lat")
    data <- sf::st_as_sf(data, coords = c(lon_col, lat_col), crs = crs, remove = FALSE)
  }
  g <- unique(as.character(sf::st_geometry_type(data)))
  if (!all(g == "POINT")) cli::cli_abort("{.arg data} must contain single points.")
  if (nrow(data) == 0) cli::cli_abort("{.arg data} has no points.")
  pts <- data
  if (isTRUE(sf::st_is_longlat(pts))) pts <- sf::st_transform(pts, geo_crs("laea", data = pts))
  xy <- sf::st_coordinates(pts)
  res <- dbscan_cpp(xy[, 1], xy[, 2], eps, as.integer(min_pts))
  data$cluster <- res$cluster
  data$core <- res$core
  ids <- sort(setdiff(unique(res$cluster), 0))
  hulls <- lapply(ids, function(k) {
    sf::st_convex_hull(sf::st_union(sf::st_geometry(pts)[res$cluster == k]))
  })
  hull_sf <- sf::st_sf(
    cluster = ids,
    n = vapply(ids, function(k) sum(res$cluster == k), 1L),
    geometry = if (length(hulls)) do.call(c, hulls) else sf::st_sfc(crs = sf::st_crs(pts))
  )
  attr(data, "hulls") <- sf::st_transform(hull_sf, sf::st_crs(data))
  data
}

#' Landscape fragmentation metrics
#'
#' @description
#' `geo_landscape()` measures how fragmented each class of a categorical
#' raster (land cover, habitat, forest/non-forest) is, with the standard
#' FRAGSTATS metrics (McGarigal and Marks 1995) as in the GeoSpaX
#' fragmentation plug-in. Patches are built with 8-neighbour rules; areas
#' are in hectares and edges in metres, measured on the ground for both
#' projected and geographic rasters.
#'
#' Class-level metrics: `np` (number of patches), `ca` (class area, ha),
#' `pland` (share of the landscape, %), `lpi` (largest patch index, %),
#' `area_mn` (mean patch area, ha), `ed` (edge density, m/ha), `ai`
#' (aggregation index, %; He et al. 2000) and `mesh` (effective mesh size,
#' ha; Jaeger 2000), the expected size of the patch a randomly placed
#' animal finds itself in. Landscape-level metrics add Shannon's (`shdi`)
#' and Simpson's (`sidi`) diversity of classes.
#'
#' @param x A categorical `SpatRaster` (integer classes; `NA` is outside the
#'   landscape).
#' @param level `"class"` or `"landscape"`.
#' @return A tibble: one row per class (`level = "class"`) or one row.
#' @references
#' He HS, DeZonia BE, Mladenoff DJ (2000) An aggregation index (AI) to
#' quantify spatial patterns of landscapes. Landscape Ecology 15:591-601.
#'
#' Jaeger JAG (2000) Landscape division, splitting index, and effective mesh
#' size. Landscape Ecology 15:115-130.
#'
#' McGarigal K, Marks BJ (1995) FRAGSTATS: spatial pattern analysis program
#' for quantifying landscape structure. USDA Forest Service General
#' Technical Report PNW-351.
#' @seealso [geo_dbscan()].
#' @examplesIf rlang::is_installed("terra")
#' r <- terra::rast(nrows = 30, ncols = 30, xmin = 0, xmax = 3000,
#'   ymin = 0, ymax = 3000, crs = "EPSG:32631")
#' terra::values(r) <- rep(c(1, 2), length.out = 900)
#' geo_landscape(r)
#' @export
geo_landscape <- function(x, level = c("class", "landscape")) {
  rlang::check_installed("terra")
  level <- rlang::arg_match(level)
  if (!inherits(x, "SpatRaster")) cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
  x <- x[[1]]
  v <- terra::values(x, mat = FALSE)
  if (all(is.na(v))) cli::cli_abort("{.arg x} has no values.")
  if (any(v != round(v), na.rm = TRUE)) cli::cli_abort("{.arg x} must hold integer classes.")
  # Cell area and side lengths on the ground
  if (terra::is.lonlat(x)) {
    cell_area <- terra::values(terra::cellSize(x, unit = "m"), mat = FALSE)
    lat <- terra::yFromRow(x, seq_len(terra::nrow(x)))
    rs <- terra::res(x)
    ew <- rs[1] * 111320 * cos(lat * pi / 180)  # width of a cell, by row
    ns <- rs[2] * 110574                         # height of a cell
    side_h <- rep(ew, each = terra::ncol(x))     # horizontal edges
    side_v <- rep(ns, length(v))                 # vertical edges
  } else {
    rs <- terra::res(x)
    cell_area <- rep(prod(rs), length(v))
    side_h <- rep(rs[1], length(v))
    side_v <- rep(rs[2], length(v))
  }
  total <- sum(cell_area[!is.na(v)])
  m <- matrix(v, nrow = terra::nrow(x), byrow = TRUE)
  ah <- matrix(side_h, nrow = terra::nrow(x), byrow = TRUE)
  av <- matrix(side_v, nrow = terra::nrow(x), byrow = TRUE)
  classes <- sort(unique(v[!is.na(v)]))
  # Shared edges between neighbouring cells (4-neighbour), within the landscape
  right <- cbind(m[, -1, drop = FALSE], NA)
  down <- rbind(m[-1, , drop = FALSE], NA)
  out <- lapply(classes, function(k) {
    is_k <- !is.na(m) & m == k
    pr <- terra::patches(terra::classify(x, cbind(k, 1), others = NA), directions = 8)
    pid <- terra::values(pr, mat = FALSE)
    areas <- tapply(cell_area[!is.na(pid)], pid[!is.na(pid)], sum)
    # Edges with other classes (not with NA): vertical edges between
    # horizontal neighbours have the cell height; horizontal ones the width
    e_r <- is_k & !is.na(right) & right != k | !is_k & !is.na(m) & !is.na(right) & right == k
    e_d <- is_k & !is.na(down) & down != k | !is_k & !is.na(m) & !is.na(down) & down == k
    edge <- sum(av[e_r], na.rm = TRUE) + sum(ah[e_d], na.rm = TRUE)
    # Like adjacencies for the aggregation index (single count)
    gii <- sum(is_k & !is.na(right) & right == k) + sum(is_k & !is.na(down) & down == k)
    a <- sum(is_k)
    nn <- floor(sqrt(a))
    mm <- a - nn^2
    # Largest possible number of like adjacencies for a cells (He et al. 2000)
    gmax <- 2 * nn * (nn - 1) + if (mm == 0) 0 else if (mm <= nn) 2 * mm - 1 else 2 * mm - 2
    tibble::tibble(
      class = k,
      np = length(areas),
      ca = sum(areas) / 1e4,
      pland = 100 * sum(areas) / total,
      lpi = 100 * max(areas) / total,
      area_mn = mean(areas) / 1e4,
      ed = edge / (total / 1e4),
      ai = if (gmax > 0) 100 * gii / gmax else NA_real_,
      mesh = sum(areas^2) / total / 1e4
    )
  })
  cls <- dplyr::bind_rows(out)
  if (level == "class") return(cls)
  p <- cls$pland / 100
  # Every shared edge is counted once for each of its two classes
  tibble::tibble(
    np = sum(cls$np), ta = total / 1e4, ed = sum(cls$ed) / 2,
    shdi = -sum(p * log(p)), sidi = 1 - sum(p^2), mesh = sum(cls$mesh)
  )
}
