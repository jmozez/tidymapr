#' Export a site-by-feature matrix for conservation planning
#'
#' Builds a wide site-by-feature table (coverage-standardised diversity or
#' species abundances) suitable for **prioritizr**. Does not call prioritizr
#' or embed a solver; hand the matrix to that package yourself.
#'
#' Spectral diversity / Google Earth Engine workflows remain deferred (link
#' only; no rgee dependency).
#'
#' @param data Community table or a diversity table with a site column.
#' @param site,species,abundance,value Column selections. For diversity
#'   tables, pass `value` (for example `diversity`) and omit `species`.
#' @param features Optional feature name when exporting a single diversity
#'   metric (defaults to `"feature"`).
#' @return A tibble with `site` and one column per feature.
#' @export
#' @examplesIf requireNamespace("tidydiversity", quietly = TRUE)
#' geo_as_features(tidydiversity::png_ants) |> dim()
geo_as_features <- function(data,
                            site = site,
                            species = species,
                            abundance = NULL,
                            value = NULL,
                            features = "feature") {
  tmr_check_data(data)
  site_col <- tmr_pick(enquo(site), data, "site")
  value_q <- enquo(value)
  if (!quo_is_null(value_q)) {
    val_col <- tmr_pick(value_q, data, "value")
    out <- tibble::tibble(
      !!site_col := data[[site_col]],
      !!features := as.numeric(data[[val_col]])
    )
    return(out)
  }
  sp_col <- tmr_pick(enquo(species), data, "species")
  abu_q <- enquo(abundance)
  sites <- as.character(data[[site_col]])
  spp <- as.character(data[[sp_col]])
  if (quo_is_null(abu_q)) {
    abu <- rep(1, length(sites))
  } else {
    abu_col <- tmr_pick(abu_q, data, "abundance")
    abu <- as.numeric(data[[abu_col]])
  }
  u_sites <- unique(sites)
  u_spp <- sort(unique(spp))
  mat <- matrix(0, length(u_sites), length(u_spp),
                dimnames = list(u_sites, u_spp))
  for (i in seq_along(sites)) {
    if (!is.finite(abu[i])) next
    mat[sites[i], spp[i]] <- mat[sites[i], spp[i]] + abu[i]
  }
  out <- tibble::as_tibble(mat, rownames = "site")
  names(out)[1] <- site_col
  out
}
