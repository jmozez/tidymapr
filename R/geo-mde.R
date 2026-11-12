#' Two-dimensional mid-domain null model of species richness
#'
#' @description
#' `geo_mde()` asks whether a map of species richness could arise from the
#' shape of the land alone. In a bounded domain (an island, a country, a
#' mountain range), ranges placed at random overlap most in the interior,
#' so richness peaks there with no environmental cause: the mid-domain
#' effect in two dimensions (Colwell and Lees 2000; Jetz and Rahbek 2001).
#'
#' Each species keeps its observed range size (in grid cells) and its range
#' is placed at random in the domain `nsim` times with the spreading-dye
#' algorithm: a random seed cell, then growth into randomly chosen
#' neighbouring cells, so ranges stay contiguous and follow the real
#' coastline. Unlike RangeModel and rangemodelR, which work along one
#' dimension or on regular grids, the domain here is any polygon, on an
#' equal-area grid.
#'
#' Ranges are built from occurrence points: `range = "hull"` (default)
#' takes the cells inside the convex hull of each species' records within
#' the domain, a common proxy for the extent of occurrence; `range =
#' "cells"` uses the occupied cells only.
#'
#' @param data Occurrence records: an `sf` object of points, or a data
#'   frame with longitude and latitude columns.
#' @param domain An `sf` polygon (or multipolygon) of the bounded domain.
#' @param res Grid cell size in metres.
#' @param species Column with species names.
#' @param range `"hull"` or `"cells"`; see Description.
#' @param nsim Number of randomisations.
#' @param conf Width of the simulation interval.
#' @param lon,lat Coordinate columns when `data` is not `sf`.
#' @return A `SpatRaster` with layers `observed` (richness of the observed
#'   ranges), `expected` (mean of the null model), `sd`, `lower`, `upper`
#'   (simulation interval) and `ses` (standardised effect size,
#'   (observed - expected) / sd: positive where there are more species than
#'   geometry predicts). Attribute `fit` holds `n_species`, `n_cells`, `r2`
#'   (variance in observed richness explained by the null model) and
#'   `truncated` (ranges that could not grow to full size because the
#'   piece of domain they started in was too small).
#' @references
#' Colwell, R. K. and Lees, D. C. (2000). The mid-domain effect: geometric
#' constraints on the geography of species richness. Trends in Ecology &
#' Evolution, 15, 70-76. \doi{10.1016/S0169-5347(99)01767-X}
#'
#' Jetz, W. and Rahbek, C. (2001). Geometric constraints explain much of
#' the species richness pattern in African birds. Proceedings of the
#' National Academy of Sciences, 98, 5661-5666. \doi{10.1073/pnas.091100998}
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   lux <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#'   set.seed(1)
#'   pts <- sf::st_sample(sf::st_union(lux), 300)
#'   occ <- sf::st_sf(species = sample(paste0("sp", 1:20), 300, TRUE), geometry = pts)
#'   m <- geo_mde(occ, lux, res = 5000, nsim = 49)
#'   attr(m, "fit")
#' }
#' }
geo_mde <- function(data,
                    domain,
                    res,
                    species = species,
                    range = c("hull", "cells"),
                    nsim = 199,
                    conf = 0.95,
                    lon = lon,
                    lat = lat) {
  rlang::check_installed(c("sf", "terra"))
  range <- rlang::arg_match(range)
  tmr_check_number(res, "res", 0)
  tmr_check_number(nsim, "nsim", 1, whole = TRUE)
  tmr_check_number(conf, "conf", 0, 1)
  if (!inherits(domain, c("sf", "sfc"))) {
    cli::cli_abort("{.arg domain} must be an {.cls sf} polygon.")
  }
  if (!inherits(data, "sf")) {
    tmr_check_data(data)
    lon_col <- tmr_pick(rlang::enquo(lon), data, "lon")
    lat_col <- tmr_pick(rlang::enquo(lat), data, "lat")
    data <- sf::st_as_sf(data, coords = c(lon_col, lat_col), crs = 4326, remove = FALSE)
  }
  sp_col <- tmr_pick(rlang::enquo(species), data, "species", lonlat = FALSE)
  dom <- sf::st_union(sf::st_geometry(domain))
  crs <- if (isTRUE(sf::st_is_longlat(dom))) geo_crs("laea", data = dom) else sf::st_crs(dom)
  dom <- sf::st_transform(dom, crs)
  pts <- sf::st_transform(data, crs)
  grid <- terra::rast(terra::ext(terra::vect(dom)), resolution = res, crs = crs$wkt)
  if (terra::ncell(grid) < 4) {
    cli::cli_abort("The domain has fewer than 4 cells at {.arg res} = {res}.")
  }
  mask <- terra::rasterize(terra::vect(dom), grid, touches = FALSE)
  dmask <- !is.na(terra::values(mask)[, 1])
  if (sum(dmask) < 4) cli::cli_abort("The domain has fewer than 4 cells at {.arg res} = {res}.")
  xy <- sf::st_coordinates(pts)
  cell <- terra::cellFromXY(grid, xy)
  keep <- !is.na(cell) & dmask[cell]
  if (!any(keep)) cli::cli_abort("No occurrence falls inside {.arg domain}.")
  spp <- split(seq_len(nrow(pts))[keep], as.character(pts[[sp_col]])[keep])
  occ <- matrix(FALSE, terra::ncell(grid), length(spp))
  for (j in seq_along(spp)) {
    idx <- spp[[j]]
    cells_j <- unique(cell[idx])
    if (range == "hull" && length(unique(cell[idx])) >= 3) {
      hull <- sf::st_convex_hull(sf::st_union(sf::st_geometry(pts)[idx]))
      h <- terra::rasterize(terra::vect(hull), grid, touches = TRUE)
      cells_j <- union(cells_j, which(!is.na(terra::values(h)[, 1]) & dmask))
    }
    occ[cells_j, j] <- TRUE
  }
  size <- colSums(occ)
  observed <- rowSums(occ)
  sim <- geo_mde_cpp(
    as.integer(dmask), terra::nrow(grid), terra::ncol(grid),
    as.integer(size), as.integer(nsim)
  )
  rich <- sim$richness
  dc <- sim$cells + 1
  a <- (1 - conf) / 2
  expected <- rowMeans(rich)
  sdv <- apply(rich, 1, stats::sd)
  lay <- function(v) {
    out <- rep(NA_real_, terra::ncell(grid))
    out[dc] <- v
    r <- terra::rast(grid)
    terra::values(r) <- out
    r
  }
  ses <- ifelse(sdv > 0, (observed[dc] - expected) / sdv, 0)
  out <- c(
    lay(observed[dc]), lay(expected), lay(sdv),
    lay(apply(rich, 1, stats::quantile, probs = a, names = FALSE)),
    lay(apply(rich, 1, stats::quantile, probs = 1 - a, names = FALSE)),
    lay(ses)
  )
  names(out) <- c("observed", "expected", "sd", "lower", "upper", "ses")
  obs <- observed[dc]
  ss <- sum((obs - mean(obs))^2)
  attr(out, "fit") <- tibble::tibble(
    n_species = length(size), n_cells = length(dc),
    r2 = if (ss > 0) 1 - sum((obs - expected)^2) / ss else NA_real_,
    truncated = sim$truncated
  )
  out
}
