#' Spectral indices from satellite bands
#'
#' @description
#' `geo_spectral_index()` computes common normalised-difference indices
#' from a multi-band image (Sentinel-2, Landsat, drone imagery), as in
#' GeoSpaX's Forestry plug-in. Each index is `(a - b) / (a + b)`:
#'
#' | `index` | Bands (a, b) | Measures |
#' |---|---|---|
#' | `"NDVI"` | NIR, red | green vegetation |
#' | `"GNDVI"` | NIR, green | chlorophyll |
#' | `"NDRE"` | NIR, red edge | canopy chlorophyll (Sentinel-2 B05) |
#' | `"NDWI"` | green, NIR | open water (McFeeters) |
#' | `"MNDWI"` | green, SWIR1 | open water in built-up areas |
#' | `"NDMI"` | NIR, SWIR1 | vegetation moisture |
#' | `"NBR"` | NIR, SWIR2 | burned areas |
#' | `"NDBI"` | SWIR1, NIR | built-up land |
#'
#' Name the band layers with `bands`, for example
#' `bands = c(red = "B04", nir = "B08")`. Sentinel-2 names (`B03`, `B04`,
#' `B05`, `B08`, `B11`, `B12`) are recognised automatically.
#'
#' With `threshold = "otsu"`, the index is also split into two classes by
#' Otsu's method (the cut that best separates the two peaks of the histogram),
#' and the area above the cut is reported, for example vegetated or water
#' area.
#'
#' @param x A multi-band `SpatRaster` or file path.
#' @param index Index name (see table).
#' @param bands Named character vector mapping `red`, `green`, `nir`,
#'   `rededge`, `swir1`, `swir2` to layer names of `x`.
#' @param threshold `NULL` (no classes), `"otsu"`, or a number.
#' @return A `SpatRaster` with the index; with a threshold, a second layer
#'   `above` (1/0), and attribute `"threshold"` with the cut value, the area
#'   above it (km^2) and its share of valid cells.
#' @references Otsu, N. (1979). A threshold selection method from
#'   gray-level histograms. *IEEE Transactions on Systems, Man, and
#'   Cybernetics*, 9, 62-66. \doi{10.1109/TSMC.1979.4310076}
#' @export
#' @examplesIf rlang::is_installed("terra")
#' # Sentinel-2 Level-2A bands over Luxembourg, 24 August 2024 (terra)
#' s2 <- terra::rast(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
#' ndvi <- geo_spectral_index(s2, "NDVI", threshold = "otsu")
#' ndvi
#' attr(ndvi, "threshold")
geo_spectral_index <- function(x,
                               index = c(
                                 "NDVI", "GNDVI", "NDRE", "NDWI", "MNDWI", "NDMI",
                                 "NBR", "NDBI"
                               ),
                               bands = NULL,
                               threshold = NULL) {
  rlang::check_installed("terra")
  index <- rlang::arg_match(index)
  r <- geo_as_raster(x)[[1]]
  map <- tmr_band_map(names(r), bands)
  pair <- switch(index,
    NDVI = c("nir", "red"),
    GNDVI = c("nir", "green"),
    NDRE = c("nir", "rededge"),
    NDWI = c("green", "nir"),
    MNDWI = c("green", "swir1"),
    NDMI = c("nir", "swir1"),
    NBR = c("nir", "swir2"),
    NDBI = c("swir1", "nir")
  )
  miss <- pair[!pair %in% names(map)]
  if (length(miss)) {
    cli::cli_abort(c(
      "{index} needs the {.val {miss}} band{?s}.",
      "i" = "Name them with {.arg bands}, for example {.code bands = c({miss[1]} = \"B08\")}."
    ))
  }
  a <- r[[map[[pair[1]]]]]
  b <- r[[map[[pair[2]]]]]
  out <- (a - b) / (a + b)
  # A zero or negative denominator (no signal) gives no index
  out <- terra::ifel(abs(a + b) < 1e-6 | out < -1 | out > 1, NA, out)
  names(out) <- index
  if (is.null(threshold)) return(out)
  v <- terra::values(out, mat = FALSE)
  cut <- if (identical(threshold, "otsu")) tmr_otsu(v) else as.numeric(threshold)
  above <- out >= cut
  names(above) <- "above"
  res <- c(out, above)
  ok <- is.finite(v)
  cell_km2 <- terra::values(terra::cellSize(out, unit = "km"), mat = FALSE)
  attr(res, "threshold") <- list(
    index = index, method = if (identical(threshold, "otsu")) "Otsu" else "fixed",
    cut = cut,
    area_above_km2 = sum(cell_km2[ok & v >= cut]),
    share_above = mean(v[ok] >= cut)
  )
  res
}

#' Spectral diversity in Hill numbers
#'
#' @description
#' `geo_spectral_diversity()` maps diversity from satellite or drone
#' imagery with the same Hill numbers used for species (Jost 2006), so
#' spectral and field diversity are on one scale. Following the spectral
#' species approach (Féret and Asner 2014):
#'
#' 1. the bands are standardised and reduced with principal components
#'    (keeping the components that explain `pca_var` of the variance);
#' 2. pixels are grouped into `k` **spectral species** by k-means;
#' 3. in a moving window around each pixel, the spectral species are
#'    counted and their Hill numbers of order `q` computed (q = 0: number of
#'    spectral species; 1: exponential Shannon; 2: inverse Simpson).
#'
#' The window step runs in C++ on several cores.
#'
#' @param x A multi-band `SpatRaster` or file path.
#' @param window Window size in cells (odd; 5 means 5 x 5).
#' @param k Number of spectral species.
#' @param q Orders of diversity.
#' @param pca_var Share of variance the principal components must keep.
#' @param min_cells Minimum valid cells in a window; fewer gives `NA`.
#' @param sample Number of pixels used to fit the PCA and k-means (all
#'   pixels are then classified).
#' @return A `SpatRaster` with layers `q0`, `q1`, `q2` (one per `q`) and
#'   `spectral_species`; attribute `"spectral"` holds the PCA variance kept,
#'   number of components and the k-means centres.
#' @references Féret, J.-B. and Asner, G. P. (2014). Mapping tropical
#'   forest canopy diversity using high-fidelity imaging spectroscopy.
#'   *Ecological Applications*, 24, 1289-1296. \doi{10.1890/13-1824.1}
#'
#'   Jost, L. (2006). Entropy and diversity. *Oikos*, 113, 363-375.
#'   \doi{10.1111/j.2006.0030-1299.14714.x}
#' @export
#' @examplesIf rlang::is_installed("terra")
#' s2 <- terra::rast(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
#' set.seed(1)
#' sd <- geo_spectral_diversity(s2, window = 5, k = 15)
#' sd
#' attr(sd, "spectral")$components
geo_spectral_diversity <- function(x,
                                   window = 5,
                                   k = 20,
                                   q = c(0, 1, 2),
                                   pca_var = 0.95,
                                   min_cells = NULL,
                                   sample = 20000) {
  rlang::check_installed("terra")
  tmr_check_number(window, "window", 3, whole = TRUE)
  if (window %% 2 == 0) cli::cli_abort("{.arg window} must be odd (3, 5, 7, ...).")
  tmr_check_number(k, "k", 2, whole = TRUE)
  tmr_check_number(pca_var, "pca_var", 0, 1)
  r <- geo_as_raster(x)[[1]]
  if (terra::nlyr(r) < 2) cli::cli_abort("{.arg x} needs at least two bands.")
  m <- terra::values(r, mat = TRUE)
  ok <- stats::complete.cases(m)
  if (sum(ok) < k * 5) cli::cli_abort("Too few valid pixels for {k} spectral species.")
  mv <- m[ok, , drop = FALSE]
  fit_rows <- if (nrow(mv) > sample) sample.int(nrow(mv), sample) else seq_len(nrow(mv))
  pc <- stats::prcomp(mv[fit_rows, , drop = FALSE], center = TRUE, scale. = TRUE)
  cumv <- cumsum(pc$sdev^2) / sum(pc$sdev^2)
  ncomp <- max(2L, which(cumv >= pca_var)[1])
  ncomp <- min(ncomp, ncol(mv))
  scores_fit <- pc$x[, seq_len(ncomp), drop = FALSE]
  km <- stats::kmeans(scores_fit, centers = k, nstart = 5, iter.max = 50)
  scores <- stats::predict(pc, mv)[, seq_len(ncomp), drop = FALSE]
  # Nearest k-means centre for every valid pixel
  d2 <- vapply(seq_len(k), function(j) {
    rowSums((scores - matrix(km$centers[j, ], nrow(scores), ncomp, byrow = TRUE))^2)
  }, numeric(nrow(scores)))
  cls <- rep(NA_integer_, nrow(m))
  cls[ok] <- max.col(-d2, ties.method = "first")
  h <- (window - 1) %/% 2
  min_cells <- min_cells %||% ceiling(window^2 / 2)
  hill <- geo_window_hill_cpp(
    cls, terra::nrow(r), terra::ncol(r), as.integer(h), as.integer(k),
    as.numeric(q), as.integer(min_cells), tmr_threads()
  )
  layers <- lapply(seq_along(q), function(j) {
    o <- terra::rast(r[[1]])
    terra::values(o) <- hill[, j]
    names(o) <- paste0("q", q[j])
    o
  })
  sp <- terra::rast(r[[1]])
  terra::values(sp) <- cls
  names(sp) <- "spectral_species"
  out <- terra::rast(c(layers, list(sp)))
  attr(out, "spectral") <- list(
    components = ncomp, variance_kept = cumv[ncomp], k = k, window = window,
    centres = km$centers
  )
  out
}

# Band roles from user names or Sentinel-2 band codes
tmr_band_map <- function(layers, bands = NULL) {
  s2 <- c(green = "B03", red = "B04", rededge = "B05", nir = "B08", swir1 = "B11", swir2 = "B12")
  map <- as.list(s2[s2 %in% layers])
  # STAC asset names (Earth Search Sentinel-2 and Landsat)
  stac <- c(
    green = "green", red = "red", rededge = "rededge1", nir = "nir",
    swir1 = "swir16", swir2 = "swir22"
  )
  for (k in names(stac)) {
    if (is.null(map[[k]]) && stac[[k]] %in% layers) map[[k]] <- stac[[k]]
  }
  if (is.null(map$nir) && "nir08" %in% layers) map$nir <- "nir08"
  if (!is.null(bands)) {
    bad <- setdiff(unname(bands), layers)
    if (length(bad)) cli::cli_abort("Band{?s} {.val {bad}} not found in the raster.")
    map[names(bands)] <- as.list(unname(bands))
  }
  map
}

# Otsu's threshold: maximise between-class variance over a 256-bin histogram
tmr_otsu <- function(v, bins = 256) {
  v <- v[is.finite(v)]
  h <- graphics::hist(v, breaks = seq(min(v), max(v), length.out = bins + 1), plot = FALSE)
  p <- h$counts / sum(h$counts)
  mids <- h$mids
  w0 <- cumsum(p)
  mu0 <- cumsum(p * mids)
  mut <- sum(p * mids)
  between <- (mut * w0 - mu0)^2 / (w0 * (1 - w0))
  between[!is.finite(between)] <- 0
  # Between two well-separated modes every cut in the gap is equally good:
  # take the middle of that plateau
  best <- which(between >= max(between) * (1 - 1e-9))
  mean(mids[range(best)])
}
