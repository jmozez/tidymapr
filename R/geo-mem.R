#' Distance-based Moran's eigenvector maps (dbMEM)
#'
#' Builds spatial eigenvectors from a truncated geographic distance matrix
#' (Dray, Legendre and Peres-Neto 2006). Implemented natively so callers stay
#' in tidymapr; when **adespatial** is installed, tests compare the
#' leading eigenvalues.
#'
#' @param data A data frame of sites with coordinates.
#' @param lon,lat Coordinate columns (degrees for haversine).
#' @param site Optional site id column retained in the output.
#' @param thresh Truncation threshold in metres (haversine) or coordinate
#'   units (euclidean). When `NULL`, the longest edge of the minimum
#'   spanning tree is used.
#' @param method `"haversine"` or `"euclidean"` for the distance matrix.
#' @param positive_only Keep only eigenvectors with positive eigenvalues
#'   (the usual dbMEM set)?
#' @return A tibble (`tmr_geo_mem`) with site columns and `MEM1`, `MEM2`, ...
#'   Eigenvalues are stored in attribute `eigenvalues`.
#' @references
#' Dray, S., Legendre, P. and Peres-Neto, P. R. (2006). Spatial modelling: a
#' comprehensive framework for principal coordinate analysis of neighbour
#' matrices (PCNM). *Ecological Modelling*, 196, 483-493.
#' \doi{10.1016/j.ecolmodel.2006.02.015}
#' @export
#' @examples
#' set.seed(1)
#' g <- expand.grid(lon = 1:5, lat = 1:4)
#' g$site <- paste0("s", seq_len(nrow(g)))
#' mem <- geo_mem(g, lon, lat, site = site, method = "euclidean")
#' names(mem)[1:5]
geo_mem <- function(data,
                    lon = lon,
                    lat = lat,
                    site = NULL,
                    thresh = NULL,
                    method = c("haversine", "euclidean"),
                    positive_only = TRUE) {
  method <- rlang::arg_match(method)
  tmr_check_data(data)
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  site_q <- enquo(site)
  site_col <- if (quo_is_null(site_q)) NULL else tmr_pick(site_q, data, "site")

  lon_v <- as.numeric(data[[lon_col]])
  lat_v <- as.numeric(data[[lat_col]])
  n <- length(lon_v)
  if (n < 3) {
    cli::cli_abort("{.fn geo_mem} needs at least 3 sites.")
  }
  if (method == "haversine") {
    if (exists("geo_haversine_matrix_cpp", mode = "function")) {
      d <- geo_haversine_matrix_cpp(lon_v, lat_v)
    } else {
      d <- as.matrix(stats::dist(cbind(lon_v, lat_v)))
    }
  } else {
    xy <- cbind(lon_v, lat_v)
    if (exists("geo_euclidean_matrix_cpp", mode = "function")) {
      d <- geo_euclidean_matrix_cpp(xy)
    } else {
      d <- as.matrix(stats::dist(xy))
    }
  }
  if (is.null(thresh)) {
    thresh <- geo_mem_mst_thresh(d)
  }
  tmr_check_number(thresh, "thresh", 0)
  # Classic PCNM: truncate, replace larger distances with 4 * thresh
  dt <- d
  dt[d > thresh] <- 4 * thresh
  diag(dt) <- 0
  # Principal coordinates of the truncated matrix
  pc <- suppressWarnings(stats::cmdscale(stats::as.dist(dt), k = n - 1, eig = TRUE))
  values <- as.numeric(pc$eig)
  vectors <- pc$points
  if (is.null(dim(vectors))) {
    vectors <- matrix(vectors, ncol = 1)
  }
  keep <- if (isTRUE(positive_only)) {
    which(values > 1e-8)
  } else {
    which(is.finite(values) & abs(values) > 1e-8)
  }
  # cmdscale may return fewer columns than eigenvalues
  keep <- keep[keep <= ncol(vectors)]
  if (length(keep) == 0) {
    cli::cli_abort("No positive spatial eigenvectors; try a larger {.arg thresh}.")
  }
  mem <- vectors[, keep, drop = FALSE]
  colnames(mem) <- paste0("MEM", seq_len(ncol(mem)))
  out <- tibble::as_tibble(mem)
  if (!is.null(site_col)) {
    out <- tibble::add_column(out, !!site_col := data[[site_col]], .before = 1)
  }
  out[[lon_col]] <- lon_v
  out[[lat_col]] <- lat_v
  # Reorder: site, lon, lat, MEMs
  mem_names <- grep("^MEM", names(out), value = TRUE)
  front <- c(site_col, lon_col, lat_col)
  front <- front[!vapply(front, is.null, logical(1))]
  out <- out[c(front, mem_names)]
  attr(out, "eigenvalues") <- values[keep]
  attr(out, "thresh") <- thresh
  tmr_new(out, "tmr_geo_mem")
}

# Truncation distance: the longest edge of the minimum spanning tree (C++)
geo_mem_mst_thresh <- function(d) {
  geo_mst_max_edge_cpp(d)
}
