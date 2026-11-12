#' Map diversity as a continuous surface, with its uncertainty
#'
#' @description
#' `geo_diversity_surface()` turns a community table (sites x species
#' counts) into continuous maps of Hill-number diversity:
#'
#' 1. For every site it estimates diversity of order `q` (0 = richness,
#'    1 = exponential Shannon, 2 = inverse Simpson) at a **common sample
#'    coverage** with [tidydiversity::div_standardise()] (Chao and Jost
#'    2012), so sites sampled with different effort are compared fairly. The
#'    bootstrap standard error of each estimate is kept.
#' 2. It interpolates each `q` by **ordinary kriging with measurement
#'    error** (Cressie 1993): each site's estimation variance is added to
#'    the kriging system, so poorly sampled, uncertain sites count for less
#'    and the map shows the underlying diversity surface rather than
#'    sampling noise. The variogram nugget is filtered the same way, so the
#'    surface is smooth through the sites. Kriging runs on the log scale (diversity is positive
#'    and right-skewed) in C++ on several cores.
#' 3. It returns, for each `q`, the predicted diversity and a 95% interval,
#'    whose width combines spatial uncertainty (distance from sampled
#'    sites) and estimation uncertainty (how well each site was sampled).
#'
#' The variogram of each `q` is fitted with **gstat** unless you give one.
#' Coverage-based standardisation, Hill numbers and kriging with known
#' measurement error each exist on their own; this function links them so a
#' diversity map carries an honest uncertainty map.
#'
#' @param data Long community table: one row per species per site.
#' @param site,species,abundance <[`data-masking`][dplyr::dplyr_data_masking]>
#'   Columns for site, species and counts (`abundance = NULL` counts rows).
#' @param sites Site locations: an `sf` point table, or a data frame with
#'   longitude/latitude (or x/y) columns, with a column named like `site`
#'   in `data`.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns when `sites` is not `sf`.
#' @param crs CRS of `lon`/`lat` when `sites` is not `sf` (default WGS 84).
#' @param q Orders of diversity.
#' @param coverage Sample coverage to standardise to. `NULL` uses the
#'   tidydiversity default (the highest coverage reachable by all sites
#'   without extrapolating beyond twice the smallest sample).
#' @param grid Where to predict: a `terra::SpatRaster` template, or the
#'   number of cells along the longer side of the sites' extent (default
#'   100).
#' @param model Variogram model: `"Exp"`, `"Sph"` or `"Gau"`.
#' @param measurement_error Use each site's estimation variance in the
#'   kriging (recommended)? `FALSE` gives ordinary kriging.
#' @param nboot Bootstrap replicates for the site standard errors.
#' @param level Width of the prediction interval.
#' @return A `SpatRaster` with three layers per `q`: `q0` (predicted
#'   diversity, the back-transformed log-scale prediction), `q0_lower` and
#'   `q0_upper` (interval bounds), and so on. Attribute `"sites"` holds the
#'   per-site estimates, standard errors and coordinates; `"variograms"`
#'   holds the fitted variogram of each `q`.
#' @references Chao, A. and Jost, L. (2012). Coverage-based rarefaction and
#'   extrapolation. *Ecology*, 93, 2533-2547. \doi{10.1890/11-1952.1}
#'
#'   Cressie, N. (1993). *Statistics for Spatial Data*, revised edition.
#'   Wiley. \doi{10.1002/9781119115151}
#' @seealso [plot_diversity_surface()], [geo_interpolate()]
#' @export
#' @examplesIf rlang::is_installed(c("tidydiversity", "vegan", "gstat", "terra", "sf"))
#' # Trees in 50 one-hectare plots of the Barro Colorado Island forest
#' # dynamics plot, Panama (Condit et al. 2002; shipped with vegan)
#' e <- new.env()
#' utils::data(BCI, BCI.env, package = "vegan", envir = e)
#' trees <- tibble::tibble(
#'   plot = rep(sprintf("P%02d", 1:50), ncol(e$BCI)),
#'   species = rep(colnames(e$BCI), each = 50),
#'   n = as.vector(as.matrix(e$BCI))
#' )
#' trees <- trees[trees$n > 0, ]
#' plots <- tibble::tibble(
#'   plot = sprintf("P%02d", 1:50),
#'   x = e$BCI.env$UTM.EW, y = e$BCI.env$UTM.NS
#' )
#' set.seed(1)
#' surf <- geo_diversity_surface(trees, plot, species, n,
#'   sites = plots, lon = x, lat = y, crs = 32617, grid = 40, nboot = 20
#' )
#' surf
#' attr(surf, "sites")
geo_diversity_surface <- function(data,
                                  site = site,
                                  species = species,
                                  abundance = NULL,
                                  sites,
                                  lon = lon,
                                  lat = lat,
                                  crs = 4326,
                                  q = c(0, 1, 2),
                                  coverage = NULL,
                                  grid = 100,
                                  model = c("Exp", "Sph", "Gau"),
                                  measurement_error = TRUE,
                                  nboot = 50,
                                  level = 0.95) {
  rlang::check_installed(c("tidydiversity", "sf", "terra", "gstat"))
  model <- rlang::arg_match(model)
  tmr_check_data(data)
  tmr_check_number(level, "level", 0, 1)
  site_col <- tmr_pick(enquo(site), data, "site")

  # 1. Coverage-standardised Hill numbers per site ---------------------------
  est <- tidydiversity::div_standardise(
    data, {{ site }}, {{ species }}, {{ abundance }},
    q = q, coverage = coverage, nboot = nboot
  )
  names(est)[names(est) == "site"] <- site_col

  # 2. Site locations ------------------------------------------------------
  pts <- if (inherits(sites, "sf")) {
    sites
  } else {
    tmr_check_data(sites)
    geo_as_sf(sites, {{ lon }}, {{ lat }}, crs = crs)
  }
  if (!site_col %in% names(pts)) {
    cli::cli_abort("{.arg sites} needs a {.field {site_col}} column matching {.arg data}.")
  }
  if (isTRUE(sf::st_is_longlat(pts))) {
    # Work in metres: the local UTM zone
    ctr <- sf::st_coordinates(sf::st_centroid(sf::st_union(pts)))
    pts <- sf::st_transform(pts, geo_local_utm_crs(ctr[1], ctr[2]))
  }
  xy <- sf::st_coordinates(pts)[, 1:2, drop = FALSE]
  loc <- tibble::tibble(!!site_col := as.character(pts[[site_col]]), x = xy[, 1], y = xy[, 2])
  est[[site_col]] <- as.character(est[[site_col]])
  est <- dplyr::inner_join(est, loc, by = site_col)
  missing <- setdiff(unique(as.character(data[[site_col]])), loc[[site_col]])
  if (length(missing)) {
    cli::cli_warn("{length(missing)} site{?s} without a location {?was/were} left out.")
  }

  # 3. Prediction grid -----------------------------------------------------
  tmpl <- if (inherits(grid, "SpatRaster")) {
    terra::project(terra::rast(grid), sf::st_crs(pts)$wkt)
  } else {
    tmr_check_number(grid, "grid", 2, whole = TRUE)
    bb <- sf::st_bbox(pts)
    w <- bb["xmax"] - bb["xmin"]
    h <- bb["ymax"] - bb["ymin"]
    res <- max(w, h) / grid
    terra::rast(
      xmin = bb["xmin"] - res / 2, xmax = bb["xmax"] + res / 2,
      ymin = bb["ymin"] - res / 2, ymax = bb["ymax"] + res / 2,
      resolution = res, crs = sf::st_crs(pts)$wkt
    )
  }
  gxy <- terra::xyFromCell(tmpl, seq_len(terra::ncell(tmpl)))
  zcrit <- stats::qnorm(1 - (1 - level) / 2)

  # 4. Krige each q on the log scale with measurement error ------------------
  layers <- list()
  vgms <- list()
  for (qq in sort(unique(est$q))) {
    d <- est[est$q == qq & is.finite(est$diversity) & est$diversity > 0, ]
    if (nrow(d) < 4) {
      cli::cli_warn("Too few sites with diversity estimates for q = {qq}; skipped.")
      next
    }
    y <- log(d$diversity)
    # Delta method: var(log D) ~ (se / D)^2
    ev <- if (isTRUE(measurement_error)) (d$se / d$diversity)^2 else rep(0, nrow(d))
    ev[!is.finite(ev)] <- 0
    dsf <- sf::st_as_sf(tibble::tibble(y = y, x = d$x, yy = d$y),
      coords = c("x", "yy"), crs = sf::st_crs(pts)
    )
    vg <- tmr_variogram_error(dsf, "y", model, mean(ev))
    vgms[[paste0("q", qq)]] <- vg
    # Filtered kriging: the nugget (micro-scale variation) is treated as
    # noise along with the estimation error, so the surface is smooth and
    # does not jump to the raw value at each site
    k <- geo_krige_cpp(
      d$x, d$y, y, gxy[, 1], gxy[, 2],
      match(model, c("Exp", "Sph", "Gau")), 0, vg$psill, vg$range,
      FALSE,
      variance = TRUE, threads = tmr_threads(), err_var = ev + vg$nugget
    )
    sdv <- sqrt(pmax(k$variance, 0))
    nm <- paste0("q", qq)
    layers[[nm]] <- exp(k$prediction)
    layers[[paste0(nm, "_lower")]] <- exp(k$prediction - zcrit * sdv)
    layers[[paste0(nm, "_upper")]] <- exp(k$prediction + zcrit * sdv)
  }
  out <- terra::rast(lapply(names(layers), function(nm) {
    r <- terra::rast(tmpl)
    terra::values(r) <- layers[[nm]]
    names(r) <- nm
    r
  }))
  attr(out, "sites") <- est
  attr(out, "variograms") <- vgms
  out
}

# Variogram for log diversity. The fitted nugget includes the average
# measurement error, which the kriging handles separately, so it is removed
# from the nugget to avoid counting it twice.
tmr_variogram_error <- function(dsf, col, model, mean_err) {
  rlang::check_installed("gstat", "to fit a variogram for kriging.")
  f <- stats::as.formula(paste(col, "~ 1"))
  ev <- gstat::variogram(f, dsf)
  v <- stats::var(dsf[[col]])
  init <- gstat::vgm(psill = v / 2, model = model, range = max(ev$dist) / 3, nugget = v / 2)
  fit <- suppressWarnings(gstat::fit.variogram(ev, init))
  part <- fit[fit$model == model, ]
  nug <- fit[fit$model == "Nug", "psill"]
  nug <- if (length(nug)) nug else 0
  if (anyNA(part$psill) || part$psill <= 0 || part$range <= 0) {
    # Fit failed: fall back to the sample variance and a third of the extent
    part <- data.frame(psill = v, range = max(ev$dist) / 3)
    nug <- 0
  }
  list(
    model = model,
    nugget = max(nug - mean_err, 0),
    psill = part$psill,
    range = part$range
  )
}

#' Plot diversity surfaces and their uncertainty
#'
#' Draws the result of [geo_diversity_surface()]: one panel per order `q`
#' (predicted diversity) and, with `uncertainty = TRUE`, a second row with
#' the relative width of the prediction interval (upper / lower), so you can
#' see where the map is well supported by data. Sampled sites are overlaid.
#'
#' @param x Output of [geo_diversity_surface()].
#' @param uncertainty Add the uncertainty row?
#' @param palette Sequential palette name from [grDevices::hcl.pals()].
#' @param sites Overlay the sampled sites?
#' @return A ggplot (or a patchwork of two when `uncertainty = TRUE` and
#'   **patchwork** is installed).
#' @export
#' @examplesIf rlang::is_installed(c("tidydiversity", "vegan", "gstat", "terra", "sf", "ggplot2"))
#' e <- new.env()
#' utils::data(BCI, BCI.env, package = "vegan", envir = e)
#' trees <- tibble::tibble(
#'   plot = rep(sprintf("P%02d", 1:50), ncol(e$BCI)),
#'   species = rep(colnames(e$BCI), each = 50),
#'   n = as.vector(as.matrix(e$BCI))
#' )
#' trees <- trees[trees$n > 0, ]
#' plots <- tibble::tibble(
#'   plot = sprintf("P%02d", 1:50),
#'   x = e$BCI.env$UTM.EW, y = e$BCI.env$UTM.NS
#' )
#' set.seed(1)
#' surf <- geo_diversity_surface(trees, plot, species, n,
#'   sites = plots, lon = x, lat = y, crs = 32617, grid = 40, nboot = 20
#' )
#' plot_diversity_surface(surf)
plot_diversity_surface <- function(x, uncertainty = TRUE, palette = "YlGnBu",
                                   sites = TRUE) {
  rlang::check_installed(c("ggplot2", "terra"))
  if (!inherits(x, "SpatRaster") || is.null(attr(x, "sites"))) {
    cli::cli_abort("{.arg x} must come from {.fn geo_diversity_surface}.")
  }
  qs <- grep("^q[0-9.]+$", names(x), value = TRUE)
  df <- terra::as.data.frame(x, xy = TRUE, na.rm = TRUE)
  long <- function(cols, fun) {
    do.call(rbind, lapply(cols, function(nm) {
      data.frame(x = df$x, y = df$y, value = fun(nm), q = paste("q =", sub("^q", "", nm)))
    }))
  }
  pred <- long(qs, function(nm) df[[nm]])
  st <- attr(x, "sites")
  st <- unique(data.frame(x = st$x, y = st$y))
  base <- function(d, title, lab) {
    p <- ggplot2::ggplot(d, ggplot2::aes(.data$x, .data$y, fill = .data$value)) +
      ggplot2::geom_raster() +
      ggplot2::facet_wrap(ggplot2::vars(.data$q), nrow = 1) +
      ggplot2::scale_fill_gradientn(
        colours = grDevices::hcl.colors(9, palette, rev = TRUE), name = lab
      ) +
      ggplot2::coord_equal(expand = FALSE) +
      ggplot2::scale_x_continuous(n.breaks = 3) +
      ggplot2::scale_y_continuous(n.breaks = 3) +
      ggplot2::labs(title = title, x = NULL, y = NULL) +
      theme_tidymapr(grid = "none", legend_position = "right")
    if (isTRUE(sites)) {
      p <- p + ggplot2::geom_point(
        data = st, ggplot2::aes(.data$x, .data$y), inherit.aes = FALSE,
        shape = 21, fill = "white", colour = "grey20", size = 1.2
      )
    }
    p
  }
  p1 <- base(pred, "Predicted diversity (effective number of species)", "Diversity")
  if (!isTRUE(uncertainty)) return(p1)
  unc <- long(qs, function(nm) df[[paste0(nm, "_upper")]] / df[[paste0(nm, "_lower")]])
  p2 <- base(unc, "Uncertainty: upper / lower bound of the interval", "Ratio")
  if (rlang::is_installed("patchwork")) {
    patchwork::wrap_plots(p1, p2, ncol = 1)
  } else {
    list(prediction = p1, uncertainty = p2)
  }
}
