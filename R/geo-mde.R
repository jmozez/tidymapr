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
#' @param range How each species' range is built from its records:
#'   `"hull"` (the convex hull), `"buffer"` (all cells within `buffer`
#'   metres of a record) or `"cells"` (occupied cells only). Hulls suit
#'   continuous ranges on land; buffers suit species tied to patchy
#'   habitat such as reefs, coasts or mountain tops, where a hull would
#'   span unsuitable ground between distant records.
#' @param buffer Buffer distance in metres for `range = "buffer"`; by
#'   default twice the cell size.
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
                    range = c("hull", "buffer", "cells"),
                    buffer = NULL,
                    nsim = 199,
                    conf = 0.95,
                    lon = lon,
                    lat = lat) {
  rlang::check_installed(c("sf", "terra"))
  range <- rlang::arg_match(range)
  tmr_check_number(res, "res", 0)
  if (!is.null(buffer)) tmr_check_number(buffer, "buffer", 0)
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
    cells_j <- mde_range_cells(grid, sf::st_geometry(pts)[idx], cell[idx], range, buffer)
    occ[cells_j[dmask[cells_j]], j] <- TRUE
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

#' Three-dimensional mid-domain null model for marine and other volumes
#'
#' @description
#' `geo_mde_3d()` extends [geo_mde()] to volumes: the sea, lakes, caves or a
#' forest canopy, where species occupy a range in depth as well as on the
#' map. The domain is the water column defined by a bathymetry raster,
#' divided into depth bands; a band exists in a cell if the sea floor there
#' is deeper than the top of the band. Each species keeps its observed
#' range size in grid cells x depth bands (voxels) and is placed at random
#' `nsim` times with the spreading-dye algorithm, growing into the six
#' face-neighbouring voxels (north, south, east, west, up and down), so
#' ranges stay contiguous and follow the coastline and the sea floor.
#'
#' A species' observed range (`range = "hull"`) is the convex hull of its
#' records on the map, in every depth band between its shallowest and
#' deepest record (range-through interpolation in depth), restricted to
#' the domain; `range = "cells"` uses the occupied voxels only. With one
#' depth band the model equals [geo_mde()]; on a single water column it
#' equals the one-dimensional model along depth.
#'
#' @inheritParams geo_mde
#' @param data Occurrence records with a depth column: an `sf` object of
#'   points or a data frame with longitude and latitude.
#' @param bathymetry A `SpatRaster` of sea-floor depth in metres, positive
#'   downwards (cells that are land or `NA` are outside the domain). Its
#'   grid is the grid of the model.
#' @param depth Column with the depth of each record (metres, positive).
#' @param breaks Depth band limits in metres, increasing from 0.
#' @return A list with `observed`, `expected`, `sd`, `lower`, `upper` and
#'   `ses`, each a `SpatRaster` with one layer per depth band; `profile`, a
#'   tibble with the mean observed and expected richness per water voxel,
#'   and its interval, for every depth band (the vertical richness
#'   profile); and `fit`, as in [geo_mde()].
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   bathy <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 10, ymin = 0, ymax = 10,
#'     crs = "EPSG:3857", vals = rep(seq(10, 300, length.out = 10), 10))
#'   set.seed(1)
#'   recs <- data.frame(x = runif(200, 0, 10), y = runif(200, 0, 10),
#'     depth = runif(200, 0, 250), species = sample(letters, 200, TRUE))
#'   recs <- sf::st_as_sf(recs, coords = c("x", "y"), crs = 3857)
#'   m <- geo_mde_3d(recs, bathy, breaks = c(0, 50, 100, 200, 300), nsim = 19)
#'   m$profile
#' }
#' }
geo_mde_3d <- function(data,
                       bathymetry,
                       breaks,
                       depth = depth,
                       species = species,
                       range = c("hull", "buffer", "cells"),
                       buffer = NULL,
                       nsim = 199,
                       conf = 0.95,
                       lon = lon,
                       lat = lat) {
  rlang::check_installed(c("sf", "terra"))
  range <- rlang::arg_match(range)
  tmr_check_number(nsim, "nsim", 1, whole = TRUE)
  tmr_check_number(conf, "conf", 0, 1)
  if (!is.null(buffer)) tmr_check_number(buffer, "buffer", 0)
  if (!inherits(bathymetry, "SpatRaster")) {
    cli::cli_abort("{.arg bathymetry} must be a {.cls SpatRaster} of depth in metres.")
  }
  if (!is.numeric(breaks) || length(breaks) < 2 || is.unsorted(breaks, strictly = TRUE) ||
        breaks[1] < 0) {
    cli::cli_abort("{.arg breaks} must be increasing depths from 0 or more.")
  }
  if (!inherits(data, "sf")) {
    tmr_check_data(data)
    lon_col <- tmr_pick(rlang::enquo(lon), data, "lon")
    lat_col <- tmr_pick(rlang::enquo(lat), data, "lat")
    data <- sf::st_as_sf(data, coords = c(lon_col, lat_col), crs = 4326, remove = FALSE)
  }
  sp_col <- tmr_pick(rlang::enquo(species), data, "species", lonlat = FALSE)
  dp_col <- tmr_pick(rlang::enquo(depth), data, "depth", lonlat = FALSE)
  grid <- bathymetry[[1]]
  floor_depth <- terra::values(grid)[, 1]
  nb <- length(breaks) - 1
  nc <- terra::ncell(grid)
  # Water voxel (cell, band) if the sea floor is deeper than the band top
  dom <- vapply(seq_len(nb), function(k) {
    !is.na(floor_depth) & floor_depth > breaks[k]
  }, logical(nc))
  if (sum(dom) < 4) cli::cli_abort("The domain has fewer than 4 water voxels.")
  pts <- sf::st_transform(data, terra::crs(grid))
  cell <- terra::cellFromXY(grid, sf::st_coordinates(pts))
  band <- findInterval(pts[[dp_col]], breaks, rightmost.closed = TRUE)
  ok <- !is.na(cell) & !is.na(pts[[dp_col]]) & band >= 1 & band <= nb
  ok[ok] <- dom[cbind(cell[ok], band[ok])]
  if (!any(ok)) cli::cli_abort("No record falls in a water voxel of the domain.")
  vox <- (band - 1) * nc + cell
  spp <- split(seq_len(nrow(pts))[ok], as.character(pts[[sp_col]])[ok])
  domv <- as.vector(dom)
  occ <- matrix(FALSE, nc * nb, length(spp))
  for (j in seq_along(spp)) {
    idx <- spp[[j]]
    v <- unique(vox[idx])
    if (range != "cells") {
      bands <- seq(min(band[idx]), max(band[idx]))
      cells <- mde_range_cells(grid, sf::st_geometry(pts)[idx], cell[idx], range, buffer)
      v <- union(v, as.vector(outer(cells, (bands - 1) * nc, `+`)))
      v <- v[domv[v]]
    }
    occ[v, j] <- TRUE
  }
  size <- colSums(occ)
  observed <- rowSums(occ)
  sim <- geo_mde_cpp(
    as.integer(domv), terra::nrow(grid), terra::ncol(grid),
    as.integer(size), as.integer(nsim), as.integer(nb)
  )
  rich <- sim$richness
  dc <- sim$cells + 1
  a <- (1 - conf) / 2
  expected <- rowMeans(rich)
  sdv <- apply(rich, 1, stats::sd)
  lo <- apply(rich, 1, stats::quantile, probs = a, names = FALSE)
  hi <- apply(rich, 1, stats::quantile, probs = 1 - a, names = FALSE)
  ses <- ifelse(sdv > 0, (observed[dc] - expected) / sdv, 0)
  band_names <- paste0(breaks[-length(breaks)], "-", breaks[-1], " m")
  stack <- function(vals) {
    full <- rep(NA_real_, nc * nb)
    full[dc] <- vals
    r <- terra::rast(grid, nlyrs = nb)
    terra::values(r) <- matrix(full, nc, nb)
    names(r) <- band_names
    r
  }
  vband <- (dc - 1) %/% nc + 1
  profile <- tibble::tibble(
    band = factor(band_names, levels = band_names),
    top = breaks[-length(breaks)], bottom = breaks[-1],
    n_voxels = tabulate(vband, nb),
    observed = as.vector(tapply(observed[dc], factor(vband, seq_len(nb)), mean)),
    expected = as.vector(tapply(expected, factor(vband, seq_len(nb)), mean)),
    lower = as.vector(tapply(lo, factor(vband, seq_len(nb)), mean)),
    upper = as.vector(tapply(hi, factor(vband, seq_len(nb)), mean))
  )
  obs <- observed[dc]
  ss <- sum((obs - mean(obs))^2)
  list(
    observed = stack(obs), expected = stack(expected), sd = stack(sdv),
    lower = stack(lo), upper = stack(hi), ses = stack(ses), profile = profile,
    fit = tibble::tibble(
      n_species = length(size), n_voxels = length(dc),
      r2 = if (ss > 0) 1 - sum((obs - expected)^2) / ss else NA_real_,
      truncated = sim$truncated
    )
  )
}

# Cells of one species' range on `grid`: the occupied cells plus the cells
# of its convex hull or of buffers around its records.
mde_range_cells <- function(grid, geom, cells, range, buffer) {
  cells <- unique(cells[!is.na(cells)])
  if (range == "cells") return(cells)
  if (range == "hull") {
    if (length(cells) < 3) return(cells)
    poly <- sf::st_convex_hull(sf::st_union(geom))
  } else {
    if (is.null(buffer)) {
      r <- terra::res(grid)[1]
      buffer <- 2 * if (terra::is.lonlat(grid)) r * 111320 else r
    }
    poly <- sf::st_union(sf::st_buffer(geom, buffer))
  }
  # Unions on the sphere can return collections or stray lines; keep the
  # polygon parts only
  if (any(sf::st_is(poly, "GEOMETRYCOLLECTION"))) {
    poly <- sf::st_collection_extract(poly, "POLYGON")
  }
  poly <- poly[sf::st_is(poly, c("POLYGON", "MULTIPOLYGON"))]
  if (length(poly) == 0) return(cells)
  h <- terra::rasterize(terra::vect(poly), grid, touches = TRUE)
  union(cells, which(!is.na(terra::values(h)[, 1])))
}
