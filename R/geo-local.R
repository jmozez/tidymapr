#' Local spatial statistics: hotspots and LISA clusters
#'
#' @description
#' Per-site statistics that say *where* values cluster, adding columns to
#' `data`:
#'
#' * `geo_hotspot()`: the Getis-Ord \eqn{G_i^*} statistic (Getis and Ord
#'   1992; Ord and Getis 1995) as a z-score, its two-sided p-value and a
#'   class (`"hot"`, `"cold"` or `"not significant"`). The site itself is in
#'   its own neighbourhood, with binary weights.
#' * `geo_lisa()`: local Moran's \eqn{I_i} (Anselin 1995) with row-
#'   standardised weights, its expectation, variance, z-score and p-value
#'   under conditional randomisation (Sokal, Oden and Thomson 1998), and
#'   the cluster type (`"High-High"`,
#'   `"Low-Low"`, `"High-Low"`, `"Low-High"` or `"not significant"`).
#'   With `nperm > 0` the p-value comes from conditional permutation
#'   instead.
#'
#' Neighbours are the `k` nearest sites (default) or all sites within
#' `dist` metres (great-circle). Values equal `spdep::localG()` and
#' `spdep::localmoran()` for the same neighbours.
#'
#' Many sites are tested at once, so consider adjusting `p_value` (for
#' example `p.adjust(p_value, "fdr")`) before reading individual sites.
#'
#' @inheritParams geo_moran
#' @param k Number of nearest neighbours (used when `dist` is `NULL`).
#' @param dist Distance band in metres; overrides `k`.
#' @param alpha Significance level for the class columns.
#' @param nperm `geo_lisa()` only: number of conditional permutations for
#'   the p-value; `0` (default) uses the analytical randomisation variance.
#' @return `data` with columns `gi_star`, `p_value` and `hotspot`
#'   (`geo_hotspot()`), or `lisa`, `lisa_expected`, `lisa_variance`,
#'   `lisa_z`, `p_value` and `cluster` (`geo_lisa()`). Rows with a missing
#'   value or coordinate get `NA`. The neighbour definition is in attribute
#'   `"neighbours"`.
#' @references Anselin, L. (1995). Local indicators of spatial association
#'   -- LISA. *Geographical Analysis*, 27, 93-115.
#'   \doi{10.1111/j.1538-4632.1995.tb00338.x}
#'
#'   Getis, A. and Ord, J. K. (1992). The analysis of spatial association by
#'   use of distance statistics. *Geographical Analysis*, 24, 189-206.
#'   \doi{10.1111/j.1538-4632.1992.tb00261.x}
#'
#'   Sokal, R. R., Oden, N. L. and Thomson, B. A. (1998). Local spatial
#'   autocorrelation in a biological model. *Geographical Analysis*, 30,
#'   331-354. \doi{10.1111/j.1538-4632.1998.tb00406.x}
#'
#'   Ord, J. K. and Getis, A. (1995). Local spatial autocorrelation
#'   statistics: distributional issues and an application. *Geographical
#'   Analysis*, 27, 286-306. \doi{10.1111/j.1538-4632.1995.tb00912.x}
#' @name geo-local
#' @examples
#' # The 16 real Mt Wilhelm ant transects (Mottl, Moses and Klimes 2023)
#' geo_hotspot(png_ants_sites, elevation, k = 3)
#' geo_lisa(png_ants_sites, elevation, k = 3)
NULL

#' @rdname geo-local
#' @export
geo_hotspot <- function(data,
                        value,
                        lon = lon,
                        lat = lat,
                        k = 5,
                        dist = NULL,
                        alpha = 0.05) {
  prep <- tmr_local_prep(data, enquo(value), enquo(lon), enquo(lat), k, dist)
  x <- prep$x
  n <- length(x)
  w <- prep$nb
  diag(w) <- 1 # G*: the site belongs to its own neighbourhood
  xbar <- mean(x)
  s <- sqrt(sum(x^2) / n - xbar^2)
  wi <- rowSums(w)
  s1i <- rowSums(w^2)
  num <- as.vector(w %*% x) - xbar * wi
  den <- s * sqrt((n * s1i - wi^2) / (n - 1))
  g <- num / den
  p <- 2 * stats::pnorm(-abs(g))
  cls <- ifelse(p < alpha, ifelse(g > 0, "hot", "cold"), "not significant")
  out <- tmr_local_fill(data, prep$ok, list(
    gi_star = g, p_value = p,
    hotspot = factor(cls, levels = c("hot", "cold", "not significant"))
  ))
  attr(out, "neighbours") <- prep$desc
  out
}

#' @rdname geo-local
#' @export
geo_lisa <- function(data,
                     value,
                     lon = lon,
                     lat = lat,
                     k = 5,
                     dist = NULL,
                     alpha = 0.05,
                     nperm = 0,
                     seed = NULL) {
  tmr_check_number(nperm, "nperm", 0, whole = TRUE)
  prep <- tmr_local_prep(data, enquo(value), enquo(lon), enquo(lat), k, dist)
  x <- prep$x
  n <- length(x)
  w <- prep$nb
  rs <- rowSums(w)
  rs[rs == 0] <- 1
  w <- w / rs
  z <- x - mean(x)
  m2 <- sum(z^2) / n
  lag <- as.vector(w %*% z)
  ii <- z / m2 * lag
  # Moments under conditional randomisation (Sokal, Oden and Thomson
  # 1998), the spdep::localmoran() default
  wi <- rowSums(w)
  wi2 <- rowSums(w^2)
  ei <- -(z^2 * wi) / ((n - 1) * m2)
  vi <- (z / m2)^2 * (n / (n - 2)) * (wi2 - wi^2 / (n - 1)) *
    (m2 - z^2 / (n - 1))
  zi <- (ii - ei) / sqrt(vi)
  p <- if (nperm > 0) {
    if (!is.null(seed)) set.seed(seed)
    vapply(seq_len(n), function(i) {
      others <- z[-i]
      nb <- which(w[i, ] > 0)
      wv <- w[i, nb]
      sims <- replicate(nperm, sum(wv * sample(others, length(nb))))
      obs <- lag[i]
      (1 + min(sum(sims >= obs), sum(sims <= obs))) * 2 / (nperm + 1)
    }, numeric(1))
  } else {
    2 * stats::pnorm(-abs(zi))
  }
  p <- pmin(p, 1)
  quad <- ifelse(z > 0,
    ifelse(lag > 0, "High-High", "High-Low"),
    ifelse(lag > 0, "Low-High", "Low-Low")
  )
  cls <- ifelse(p < alpha, quad, "not significant")
  out <- tmr_local_fill(data, prep$ok, list(
    lisa = ii, lisa_expected = ei, lisa_variance = vi, lisa_z = zi,
    p_value = p,
    cluster = factor(cls, levels = c(
      "High-High", "Low-Low", "High-Low", "Low-High", "not significant"
    ))
  ))
  attr(out, "neighbours") <- prep$desc
  out
}

tmr_local_prep <- function(data, value, lon, lat, k, dist,
                           call = caller_env()) {
  tmr_check_data(data, call = call)
  val_col <- tmr_pick(value, data, "value", call = call)
  lon_col <- tmr_pick(lon, data, "lon", call = call)
  lat_col <- tmr_pick(lat, data, "lat", call = call)
  x <- data[[val_col]]
  if (!is.numeric(x)) {
    cli::cli_abort("{.arg value} must be a numeric column.", call = call)
  }
  lo <- as.numeric(data[[lon_col]])
  la <- as.numeric(data[[lat_col]])
  ok <- is.finite(x) & is.finite(lo) & is.finite(la)
  n <- sum(ok)
  if (n < 3) {
    cli::cli_abort("Local statistics need at least three complete sites.", call = call)
  }
  d <- geo_haversine_matrix_cpp(lo[ok], la[ok])
  diag(d) <- Inf
  if (is.null(dist)) {
    tmr_check_number(k, "k", 1, n - 1, whole = TRUE, call = call)
    nb <- t(apply(d, 1, function(r) {
      v <- numeric(n)
      v[order(r)[seq_len(k)]] <- 1
      v
    }))
    desc <- paste(k, "nearest neighbours")
  } else {
    tmr_check_number(dist, "dist", 0, call = call)
    nb <- (d <= dist) * 1
    lonely <- sum(rowSums(nb) == 0)
    if (lonely > 0) {
      cli::cli_warn(
        "{lonely} site{?s} {?has/have} no neighbour within {dist} m.",
        call = call
      )
    }
    desc <- paste("neighbours within", dist, "m")
  }
  list(x = as.numeric(x[ok]), ok = ok, nb = nb, desc = desc)
}

tmr_local_fill <- function(data, ok, cols) {
  for (nm in names(cols)) {
    v <- cols[[nm]]
    full <- if (is.factor(v)) {
      factor(rep(NA_character_, length(ok)), levels = levels(v))
    } else {
      rep(NA_real_, length(ok))
    }
    full[ok] <- v
    data[[nm]] <- full
  }
  data
}
