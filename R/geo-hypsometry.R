#' Land area by elevation and climate-driven range shifts
#'
#' @description
#' Tools for asking how much land a mountain offers at each elevation, and
#' what warming does to the land available to species with known
#' elevational ranges (Colwell et al. 2008; Elsen and Tingley 2015):
#'
#' * `geo_hypsometry()` gives the land area in each elevation band of a
#'   digital elevation model, optionally inside a region. Areas come from
#'   [terra::cellSize()], so cells on a longitude/latitude grid are measured
#'   on the ellipsoid (`area = "ellipsoid"`), not as equal squares.
#' * `geo_range_shift()` moves each species' range upslope by
#'   `warming / lapse_rate` and reports the land area within the range now
#'   and after warming, the percentage change, whether the shifted range no
#'   longer overlaps the current one (a *gap*, the range-shift gap of
#'   Colwell et al. 2008) and whether it runs past the summit (truncation).
#' * `geo_patches()` labels connected patches of a mask and their areas;
#'   `geo_largest_patch()` keeps the largest, for example the main land mass
#'   of a peninsula once a valley floor has been cut out.
#'
#' @param dem Elevation `SpatRaster` (metres).
#' @param region Optional area to keep: `sf`, `sfc`, `SpatVector`, or a
#'   `SpatRaster` mask (cells that are `NA`, `FALSE` or 0 are dropped).
#' @param band_width Width of elevation bands in metres.
#' @param area `"ellipsoid"` (true cell areas from [terra::cellSize()]) or
#'   `"planar"` (cell areas from the nominal resolution, only meaningful for
#'   projected grids).
#' @param unit Area unit: `"km2"`, `"ha"` or `"m2"`.
#' @param min_elevation Lowest elevation counted; cells below (sea, bathymetry,
#'   voids) are dropped. Default 0.
#' @return `geo_hypsometry()`: a tibble with one row per band: `lower`,
#'   `upper`, `area`, `share` (of the total) and `area_above` (land at or
#'   above `lower`), with attributes `unit` and `summit` (highest elevation).
#' @references
#' Colwell, R. K., Brehm, G., Cardelús, C. L., Gilman, A. C. and Longino,
#' J. T. (2008). Global warming, elevational range shifts, and lowland
#' biotic attrition in the wet tropics. Science, 322, 258-261.
#'
#' Elsen, P. R. and Tingley, M. W. (2015). Global mountain topography and the
#' fate of montane species under climate change. Nature Climate Change, 5,
#' 772-776.
#' @name geo-hypsometry
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   # A synthetic cone-shaped mountain, 0 to 3,000 m
#'   dem <- terra::rast(nrows = 100, ncols = 100, xmin = 145, xmax = 146, ymin = -7, ymax = -6)
#'   xy <- terra::crds(dem)
#'   terra::values(dem) <- pmax(0, 3000 - 6000 * sqrt((xy[, 1] - 145.5)^2 + (xy[, 2] + 6.5)^2))
#'   hyp <- geo_hypsometry(dem, band_width = 500)
#'   hyp
#'   ranges <- data.frame(species = c("a", "b"), lower = c(0, 1800), upper = c(900, 2100))
#'   geo_range_shift(hyp, ranges, warming = c(1.8, 3.7), pad = 250)
#' }
#' }
NULL

#' @rdname geo-hypsometry
#' @export
geo_hypsometry <- function(dem,
                           region = NULL,
                           band_width = 100,
                           area = c("ellipsoid", "planar"),
                           unit = c("km2", "ha", "m2"),
                           min_elevation = 0) {
  rlang::check_installed("terra")
  area <- rlang::arg_match(area)
  unit <- rlang::arg_match(unit)
  if (!is.numeric(band_width) || length(band_width) != 1 || band_width <= 0) {
    cli::cli_abort("{.arg band_width} must be one positive number of metres.")
  }
  r <- geo_as_raster(dem)[[1]]
  r <- tmr_apply_region(r, region)
  r[r < min_elevation] <- NA
  a <- tmr_cell_area(r, area, unit)
  v <- terra::values(r, mat = FALSE)
  w <- terra::values(a, mat = FALSE)
  ok <- !is.na(v) & !is.na(w)
  v <- v[ok]
  w <- w[ok]
  if (!length(v)) {
    cli::cli_abort("No land cells are left in {.arg dem} after applying {.arg region}.")
  }
  start <- floor(min_elevation / band_width) * band_width
  band <- floor((v - start) / band_width)
  nb <- max(band) + 1
  ar <- vapply(split(w, factor(band, levels = 0:(nb - 1))), sum, numeric(1))
  lower <- start + (0:(nb - 1)) * band_width
  out <- tibble::tibble(
    lower = lower, upper = lower + band_width, area = unname(ar),
    share = unname(ar) / sum(ar), area_above = rev(cumsum(rev(unname(ar))))
  )
  attr(out, "unit") <- unit
  attr(out, "summit") <- max(v)
  attr(out, "band_width") <- band_width
  class(out) <- c("tmr_hypsometry", class(out))
  out
}

#' @rdname geo-hypsometry
#' @param hypsometry Result of `geo_hypsometry()`.
#' @param ranges Data frame of species ranges with columns `species`,
#'   `lower` and `upper` (metres).
#' @param warming Warming scenarios in degrees C, for example
#'   `c(1.8, 3.7)` (IPCC AR6 SSP1-2.6 and SSP5-8.5, 2081-2100).
#' @param lapse_rate Temperature lapse rate in degrees C per km. The default,
#'   4.84, is a humid tropical value; give the one measured on your
#'   transect.
#' @param pad Metres added below and above each observed range (an observed
#'   range underestimates the true one); lower limits are not padded below
#'   `floor`.
#' @param summit Highest elevation available; defaults to the summit of the
#'   hypsometry. Shifted ranges are cut at the summit and flagged.
#' @param lowland Species whose (padded) lower limit is at or below this
#'   elevation keep their lower limit (no area is lost at the bottom: there
#'   is no warmer land below them to vacate). `NULL` (default) shifts every
#'   lower limit.
#' @param floor Lowest elevation (default 0, sea level).
#' @return `geo_range_shift()`: a tibble with one row per species and
#'   warming: `species`, `warming`, `shift` (m), `lower`, `upper` (padded
#'   current range), `new_lower`, `new_upper`, `area_now`, `area_future`,
#'   `change` (percent), `gap` (shifted range does not overlap the current
#'   range) and `truncated` (shifted range runs past the summit).
#' @export
geo_range_shift <- function(hypsometry,
                            ranges,
                            warming,
                            lapse_rate = 4.84,
                            pad = 0,
                            summit = NULL,
                            lowland = NULL,
                            floor = 0) {
  if (!inherits(hypsometry, "tmr_hypsometry")) {
    cli::cli_abort("{.arg hypsometry} must come from {.fn geo_hypsometry}.")
  }
  need <- c("species", "lower", "upper")
  if (!is.data.frame(ranges) || !all(need %in% names(ranges))) {
    cli::cli_abort("{.arg ranges} needs columns {.field {need}}.")
  }
  if (any(ranges$upper < ranges$lower, na.rm = TRUE)) {
    cli::cli_abort("Each upper limit in {.arg ranges} must be at least its lower limit.")
  }
  if (!is.numeric(lapse_rate) || length(lapse_rate) != 1 || lapse_rate <= 0) {
    cli::cli_abort("{.arg lapse_rate} must be one positive number (degrees C per km).")
  }
  summit <- summit %||% attr(hypsometry, "summit")
  lo <- pmax(floor, ranges$lower - pad)
  hi <- ranges$upper + pad
  grid <- expand.grid(i = seq_len(nrow(ranges)), warming = warming)
  shift <- grid$warming / lapse_rate * 1000
  l0 <- lo[grid$i]
  h0 <- pmin(hi[grid$i], summit)
  l1 <- l0 + shift
  if (!is.null(lowland)) {
    keep <- l0 <= lowland
    l1[keep] <- l0[keep]
  }
  h1raw <- hi[grid$i] + shift
  h1 <- pmin(h1raw, summit)
  a0 <- tmr_area_between(hypsometry, l0, h0)
  a1 <- ifelse(l1 >= summit, 0, tmr_area_between(hypsometry, pmin(l1, summit), h1))
  tibble::tibble(
    species = ranges$species[grid$i], warming = grid$warming, shift = shift,
    lower = l0, upper = hi[grid$i], new_lower = l1, new_upper = h1raw,
    area_now = a0, area_future = a1, change = 100 * (a1 - a0) / a0,
    gap = l1 > hi[grid$i], truncated = h1raw > summit
  )
}

# Land area between elevations lo and hi, interpolating linearly in bands
tmr_area_between <- function(h, lo, hi) {
  cum_at <- function(z) {
    # Area below elevation z
    below <- c(0, cumsum(h$area))
    edges <- c(h$lower, utils::tail(h$upper, 1))
    stats::approx(edges, below, xout = z, rule = 2)$y
  }
  pmax(0, cum_at(hi) - cum_at(lo))
}

#' @rdname geo-hypsometry
#' @param x A mask `SpatRaster` (cells that are `NA`, `FALSE` or 0 are
#'   background) or an elevation raster with `NA` outside the land.
#' @param min_area Patches smaller than this (in `unit`) are dropped.
#' @param directions 8 (default, queen) or 4 (rook) neighbour cells.
#' @return `geo_patches()`: a list with `patches` (a `SpatRaster` of patch
#'   ids, largest first) and `areas` (a tibble of `patch` and `area`).
#'   `geo_largest_patch()`: `x` with every cell outside the largest patch set
#'   to `NA`.
#' @export
geo_patches <- function(x, min_area = 0, directions = 8,
                        area = c("ellipsoid", "planar"), unit = c("km2", "ha", "m2")) {
  rlang::check_installed("terra")
  area <- rlang::arg_match(area)
  unit <- rlang::arg_match(unit)
  r <- geo_as_raster(x)[[1]]
  m <- terra::ifel(is.na(r) | r == 0, NA, 1)
  p <- terra::patches(m, directions = directions, zeroAsNA = TRUE)
  a <- tmr_cell_area(r, area, unit)
  z <- terra::zonal(a, p, fun = "sum", na.rm = TRUE)
  names(z) <- c("id", "area")
  z <- z[order(-z$area), , drop = FALSE]
  z <- z[z$area >= min_area, , drop = FALSE]
  z$patch <- seq_len(nrow(z))
  p <- terra::classify(p, cbind(z$id, z$patch), others = NA)
  names(p) <- "patch"
  list(patches = p, areas = tibble::tibble(patch = z$patch, area = z$area))
}

#' @rdname geo-hypsometry
#' @export
geo_largest_patch <- function(x, directions = 8) {
  r <- geo_as_raster(x)[[1]]
  p <- geo_patches(r, directions = directions)$patches
  terra::mask(r, terra::ifel(p == 1, 1, NA))
}

tmr_cell_area <- function(r, area, unit) {
  if (area == "ellipsoid") {
    u <- switch(unit,
      km2 = "km",
      ha = "ha",
      m2 = "m"
    )
    a <- terra::cellSize(r, unit = u, mask = FALSE)
  } else {
    if (terra::is.lonlat(r)) {
      cli::cli_warn(c(
        "Planar areas of a longitude/latitude grid are in square degrees.",
        "i" = 'Use {.code area = "ellipsoid"} for true areas.'
      ))
    }
    f <- switch(unit,
      km2 = 1e-6,
      ha = 1e-4,
      m2 = 1
    )
    a <- terra::init(r, prod(terra::res(r)) * f)
  }
  a
}

tmr_apply_region <- function(r, region, call = caller_env()) {
  if (is.null(region)) {
    return(r)
  }
  if (inherits(region, "SpatRaster")) {
    m <- region[[1]]
    if (!terra::compareGeom(r, m, stopOnError = FALSE)) {
      m <- terra::resample(m, r, method = "near")
    }
    return(terra::mask(r, m, maskvalues = c(NA, 0)))
  }
  v <- geo_raster_vect(region, r, call = call)
  if (inherits(v, "SpatExtent")) {
    return(terra::crop(r, v))
  }
  terra::mask(terra::crop(r, v), v)
}
