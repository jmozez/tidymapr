#' Aggregate sites or rasters across grains (MAUP helpers)
#'
#' Rebins point sites into square cells of one or more grain sizes and
#' recomputes Hill numbers per cell, so users can see how richness patterns
#' change with grain (Dungan et al. 2002; Wagner and Fortin 2005). Also
#' aggregates SpatRaster layers with [terra::aggregate()] when `raster` is
#' supplied. Recomputing Hill numbers needs the **tidydiversity** package.
#'
#' @param data Long community table with coordinates.
#' @param grains Numeric vector of cell sizes in the same units as the
#'   coordinates (degrees for lon/lat, metres for local plots).
#' @param lon,lat,site,species,abundance Column selections.
#' @param q Hill-number orders passed to [tidydiversity::div_hill()].
#' @param raster Optional `SpatRaster` to aggregate instead of (or as well
#'   as) the community table.
#' @param fun Raster aggregation function (`"mean"`, `"sum"`, `"modal"`, ...).
#' @param .by Optional grouping columns preserved inside each grain.
#' @return When `data` is supplied, a tibble (`tmr_geo_grain`) with columns
#'   `grain`, `cell`, coordinates of cell centres, and Hill estimates. When
#'   only `raster` is supplied, a named list of SpatRasters.
#' @export
#' @examplesIf requireNamespace("tidydiversity", quietly = TRUE)
#' set.seed(1)
#' pts <- expand.grid(lon = seq(145, 145.4, by = 0.1),
#'                    lat = seq(-5.9, -5.5, by = 0.1))
#' pts$site <- paste0("s", seq_len(nrow(pts)))
#' com <- expand.grid(site = pts$site, species = paste0("sp", 1:8),
#'                    stringsAsFactors = FALSE)
#' com$abundance <- rpois(nrow(com), 2)
#' com <- dplyr::left_join(com, pts, by = "site")
#' geo_grain(com, grains = c(0.15, 0.3), q = 0)
geo_grain <- function(data = NULL,
                      grains,
                      lon = lon,
                      lat = lat,
                      site = site,
                      species = species,
                      abundance = NULL,
                      q = 0,
                      raster = NULL,
                      fun = "mean",
                      .by = NULL) {
  if (missing(grains) || length(grains) == 0) {
    cli::cli_abort("{.arg grains} must be a positive numeric vector.")
  }
  grains <- as.numeric(grains)
  if (any(!is.finite(grains) | grains <= 0)) {
    cli::cli_abort("{.arg grains} must be finite and positive.")
  }
  raster_out <- NULL
  if (!is.null(raster)) {
    rlang::check_installed("terra")
    if (!inherits(raster, "SpatRaster")) {
      cli::cli_abort("{.arg raster} must be a terra SpatRaster.")
    }
    raster_out <- lapply(grains, function(g) {
      # factor relative to current resolution
      res <- terra::res(raster)
      fact <- pmax(1L, as.integer(round(g / res)))
      terra::aggregate(raster, fact = fact, fun = fun)
    })
    names(raster_out) <- paste0("grain_", grains)
  }
  if (is.null(data)) {
    if (is.null(raster_out)) {
      cli::cli_abort("Provide {.arg data} and/or {.arg raster}.")
    }
    return(raster_out)
  }
  tmr_check_data(data)
  rlang::check_installed("tidydiversity", reason = "to compute Hill numbers.")
  site_col <- tmr_pick(enquo(site), data, "site")
  sp_col <- tmr_pick(enquo(species), data, "species")
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  abu_q <- enquo(abundance)
  by_cols <- tmr_group_cols(data, enquo(.by))

  rows <- lapply(grains, function(g) {
    d <- dplyr::ungroup(data)
    d$.gx <- floor(as.numeric(d[[lon_col]]) / g) * g + g / 2
    d$.gy <- floor(as.numeric(d[[lat_col]]) / g) * g + g / 2
    d$.cell <- paste(d$.gx, d$.gy, sep = "_")
    # Hill numbers by cell
    # Attach grouping columns to cell id when needed
    if (length(by_cols) > 0) {
      d$.cell <- paste(d$.cell, do.call(paste, c(d[by_cols], sep = "|")), sep = "|")
    }
    hill <- if (quo_is_null(abu_q)) {
      tidydiversity::div_hill(
        d, site = ".cell", species = !!rlang::sym(sp_col), q = q
      )
    } else {
      abu_col <- tmr_pick(abu_q, data, "abundance")
      tidydiversity::div_hill(
        d, site = ".cell", species = !!rlang::sym(sp_col),
        abundance = !!rlang::sym(abu_col), q = q
      )
    }
    # div_hill uses the site column name from the data (".cell")
    cell_col <- if (".cell" %in% names(hill)) ".cell" else "site"
    hill$grain <- g
    parts <- strsplit(as.character(hill[[cell_col]]), "|", fixed = TRUE)
    # First token is "gx_gy" (may be followed by grouping keys)
    xy_tok <- vapply(parts, function(p) p[[1]], character(1))
    xy_parts <- strsplit(xy_tok, "_", fixed = TRUE)
    hill$lon <- as.numeric(vapply(xy_parts, function(p) p[[1]], character(1)))
    hill$lat <- as.numeric(vapply(xy_parts, function(p) {
      if (length(p) >= 2) p[[2]] else NA_character_
    }, character(1)))
    hill$cell <- hill[[cell_col]]
    if (cell_col != "cell") hill[[cell_col]] <- NULL
    hill
  })
  out <- tibble::as_tibble(vctrs::vec_rbind(!!!rows))
  if (!is.null(raster_out)) {
    attr(out, "rasters") <- raster_out
  }
  tmr_new(out, "tmr_geo_grain")
}
