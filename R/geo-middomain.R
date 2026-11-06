#' Geometric mid-domain null for elevational richness
#'
#' Randomises species elevational ranges within a hard domain while keeping
#' each range size fixed (Colwell and Lees 2000), then recomputes richness
#' per elevation band. Compare the observed band richness to the null
#' envelope when testing mid-domain effects on tropical mountains.
#'
#' @param data A data frame with species occurrences and elevation.
#' @param species,elevation Column selections.
#' @param bands Number of elevation bands, or a numeric vector of breaks.
#' @param nperm Number of null permutations.
#' @param seed Optional RNG seed.
#' @return A tibble (`tmr_geo_middomain`) with band midpoints, observed
#'   richness, null mean, and 2.5% / 97.5% null quantiles. Attribute
#'   `ranges` holds the observed species range table.
#' @references
#' Colwell, R. K. and Lees, D. C. (2000). The mid-domain effect: geometric
#' constraints on the geography of species richness. *Trends in Ecology and
#' Evolution*, 15, 70-76. \doi{10.1016/s0169-5347(99)01767-x}
#' @export
#' @examples
#' set.seed(1)
#' occ <- expand.grid(
#'   species = paste0("sp", 1:20),
#'   elevation = seq(200, 3200, by = 200),
#'   stringsAsFactors = FALSE
#' )
#' # Each species occupies a contiguous elevational range
#' occ <- dplyr::filter(
#'   occ,
#'   elevation >= 200 + (as.integer(factor(species)) - 1) * 50,
#'   elevation <= 1200 + (as.integer(factor(species)) - 1) * 80
#' )
#' geo_middomain(occ, nperm = 49)
geo_middomain <- function(data,
                          species = species,
                          elevation = elevation,
                          bands = 10,
                          nperm = 999,
                          seed = NULL) {
  tmr_check_data(data)
  tmr_check_number(nperm, "nperm", 0, whole = TRUE)
  sp_col <- tmr_pick(enquo(species), data, "species")
  elev_col <- tmr_pick(enquo(elevation), data, "elevation")
  elev <- as.numeric(data[[elev_col]])
  spp <- as.character(data[[sp_col]])
  ok <- is.finite(elev) & !is.na(spp)
  elev <- elev[ok]
  spp <- spp[ok]
  if (length(elev) == 0) cli::cli_abort("No finite elevations.")

  domain_min <- min(elev)
  domain_max <- max(elev)
  ranges <- tapply(elev, spp, function(v) c(min = min(v), max = max(v)))
  range_tab <- tibble::tibble(
    species = names(ranges),
    elev_min = vapply(ranges, `[[`, numeric(1), "min"),
    elev_max = vapply(ranges, `[[`, numeric(1), "max")
  )
  range_tab$range_size <- range_tab$elev_max - range_tab$elev_min

  if (length(bands) == 1) {
    breaks <- seq(domain_min, domain_max, length.out = as.integer(bands) + 1L)
  } else {
    breaks <- sort(as.numeric(bands))
  }
  mids <- (breaks[-1] + breaks[-length(breaks)]) / 2
  obs <- geo_middomain_richness(range_tab$elev_min, range_tab$elev_max, breaks)

  if (!is.null(seed)) set.seed(seed)
  null_mat <- matrix(NA_real_, nperm, length(mids))
  if (nperm > 0) {
    for (b in seq_len(nperm)) {
      sim <- geo_middomain_randomise(range_tab$range_size, domain_min, domain_max)
      null_mat[b, ] <- geo_middomain_richness(sim$lo, sim$hi, breaks)
    }
  }
  out <- tibble::tibble(
    band = seq_along(mids),
    elevation = mids,
    elev_min = breaks[-length(breaks)],
    elev_max = breaks[-1],
    richness = obs,
    null_mean = if (nperm > 0) colMeans(null_mat) else NA_real_,
    null_lower = if (nperm > 0) apply(null_mat, 2, stats::quantile, 0.025) else NA_real_,
    null_upper = if (nperm > 0) apply(null_mat, 2, stats::quantile, 0.975) else NA_real_
  )
  attr(out, "ranges") <- range_tab
  attr(out, "domain") <- c(min = domain_min, max = domain_max)
  tmr_new(out, "tmr_geo_middomain")
}

geo_middomain_richness <- function(lo, hi, breaks) {
  mids <- (breaks[-1] + breaks[-length(breaks)]) / 2
  vapply(mids, function(m) sum(lo <= m & hi >= m), numeric(1))
}

geo_middomain_randomise <- function(range_size, domain_min, domain_max) {
  domain <- domain_max - domain_min
  lo <- numeric(length(range_size))
  hi <- numeric(length(range_size))
  for (i in seq_along(range_size)) {
    rs <- min(range_size[i], domain)
    # Midpoint uniform in [domain_min + rs/2, domain_max - rs/2]
    half <- rs / 2
    mid <- stats::runif(1, domain_min + half, domain_max - half)
    lo[i] <- mid - half
    hi[i] <- mid + half
  }
  list(lo = lo, hi = hi)
}
