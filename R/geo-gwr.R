#' Geographically weighted regression
#'
#' @description
#' Fits a linear regression separately at each location, weighting the
#' other observations by their distance (Fotheringham et al. 2002), so the
#' coefficients can vary in space. The bandwidth (a distance, or a number
#' of nearest neighbours when `adaptive = TRUE`) is chosen by minimising
#' the corrected Akaike information criterion (AICc) or the leave-one-out
#' cross-validation score, with a golden-section search, as in the GWmodel
#' package (Gollini et al. 2015). Distances are great-circle kilometres on
#' longitude and latitude, or Euclidean on projected coordinates with
#' `lonlat = FALSE`.
#'
#' Map the local coefficients with [geo_map()] or [plot_bubble()]. A
#' coefficient that varies little across space suggests the global model
#' is adequate; compare `aicc` with that of [stats::lm()] (`aicc_global`).
#'
#' @param data A data frame with one row per location.
#' @param formula A model formula, such as `y ~ x1 + x2`.
#' @param lon,lat Coordinate columns.
#' @param bandwidth Bandwidth: a number of neighbours when `adaptive =
#'   TRUE`, else a distance (kilometres for longitude and latitude). `NULL`
#'   (default) selects it.
#' @param kernel `"bisquare"` (default) or `"gaussian"`.
#' @param adaptive Use an adaptive bandwidth (a fixed number of nearest
#'   neighbours)?
#' @param criterion Bandwidth selection criterion: `"aicc"` or `"cv"`.
#' @param lonlat Are the coordinates longitude and latitude in degrees?
#' @return A `tmr_gwr` tibble: `data` with, for each term, the local
#'   coefficient (named after the term, with `(Intercept)` as
#'   `intercept`), its standard error (`se_<term>`) and t value
#'   (`t_<term>`), plus `.fitted`, `.resid` and `.local_r2` (the
#'   geographically weighted R-squared around the weighted local mean). The attribute
#'   `"gwr"` holds `bandwidth`, `kernel`, `adaptive`, `aicc`,
#'   `aicc_global`, `r_squared`, `enp` (effective number of parameters,
#'   2 tr(S) - tr(S'S), as reported by GWmodel)
#'   and `sigma`; `print()` shows them.
#' @references Fotheringham, A. S., Brunsdon, C. and Charlton, M. (2002).
#'   Geographically Weighted Regression: The Analysis of Spatially Varying
#'   Relationships. Wiley, Chichester. ISBN 978-0-471-49616-8.
#'
#'   Gollini, I., Lu, B., Charlton, M., Brunsdon, C. and Harris, P. (2015).
#'   GWmodel: an R package for exploring spatial heterogeneity using
#'   geographically weighted models. Journal of Statistical Software, 63(17),
#'   1-50. \doi{10.18637/jss.v063.i17}
#' @export
#' @examplesIf requireNamespace("spData", quietly = TRUE)
#' # Boston housing, corrected coordinates (Gilley and Pace 1996)
#' boston <- spData::boston.c
#' fit <- geo_gwr(boston, log(CMEDV) ~ RM + LSTAT, lon = LON, lat = LAT)
#' fit
#' summary(fit$LSTAT)
geo_gwr <- function(data,
                    formula,
                    lon = lon,
                    lat = lat,
                    bandwidth = NULL,
                    kernel = c("bisquare", "gaussian"),
                    adaptive = TRUE,
                    criterion = c("aicc", "cv"),
                    lonlat = TRUE) {
  kernel <- rlang::arg_match(kernel)
  criterion <- rlang::arg_match(criterion)
  tmr_check_data(data)
  if (!inherits(formula, "formula")) {
    cli::cli_abort("{.arg formula} must be a formula, such as {.code y ~ x}.")
  }
  lon_col <- tmr_pick(enquo(lon), data, "lon", lonlat = lonlat)
  lat_col <- tmr_pick(enquo(lat), data, "lat", lonlat = lonlat)
  mf <- stats::model.frame(formula, as.data.frame(data), na.action = stats::na.fail)
  y <- stats::model.response(mf)
  x <- stats::model.matrix(formula, mf)
  n <- nrow(x)
  if (n < ncol(x) + 3) {
    cli::cli_abort("Too few observations ({n}) for {ncol(x)} coefficients.")
  }
  lo <- data[[lon_col]]
  la <- data[[lat_col]]
  if (anyNA(lo) || anyNA(la)) cli::cli_abort("Coordinates must not be missing.")
  d <- if (lonlat) {
    geo_haversine_matrix_cpp(lo, la) / 1000
  } else {
    as.matrix(stats::dist(cbind(lo, la)))
  }
  if (is.null(bandwidth)) {
    bandwidth <- gwr_select(x, y, d, kernel, adaptive, criterion)
  } else if (adaptive) {
    tmr_check_number(bandwidth, "bandwidth", ncol(x) + 1, n, whole = TRUE)
  } else {
    tmr_check_number(bandwidth, "bandwidth", 0)
  }
  fit <- gwr_fit(x, y, d, bandwidth, kernel, adaptive, full = TRUE)
  terms <- colnames(x)
  nm <- ifelse(terms == "(Intercept)", "intercept", make.names(terms))
  out <- tibble::as_tibble(data)
  for (j in seq_along(terms)) {
    out[[nm[j]]] <- fit$beta[, j]
    out[[paste0("se_", nm[j])]] <- fit$se[, j]
    out[[paste0("t_", nm[j])]] <- fit$beta[, j] / fit$se[, j]
  }
  out$.fitted <- fit$fitted
  out$.resid <- y - fit$fitted
  out$.local_r2 <- fit$local_r2
  glob <- stats::lm.fit(x, y)
  rss_g <- sum(glob$residuals^2)
  p <- ncol(x)
  aicc_g <- n * log(rss_g / n) + n * log(2 * pi) + n * (n + p) / (n - 2 - p)
  info <- list(
    bandwidth = bandwidth, kernel = kernel, adaptive = adaptive,
    criterion = criterion, aicc = fit$aicc, aicc_global = aicc_g,
    r_squared = 1 - fit$rss / sum((y - mean(y))^2), enp = fit$enp,
    sigma = fit$sigma, n = n, terms = nm
  )
  attr(out, "gwr") <- info
  class(out) <- c("tmr_gwr", class(out))
  out
}

#' @export
print.tmr_gwr <- function(x, ...) {
  g <- attr(x, "gwr")
  unit <- if (g$adaptive) "nearest neighbours" else "distance units"
  crit <- if (g$criterion == "aicc") "AICc" else "cross-validation"
  cli::cli_text(
    "Geographically weighted regression ({g$kernel} kernel), bandwidth \\
    {signif(g$bandwidth, 4)} {unit} (by {crit})."
  )
  cli::cli_text(
    "AICc {round(g$aicc, 2)} (global model {round(g$aicc_global, 2)}); \\
    R-squared {round(g$r_squared, 3)}; effective parameters \\
    {round(g$enp, 1)}; n = {g$n}."
  )
  print(tibble::as_tibble(structure(x, gwr = NULL, class = class(x)[-1])), ...)
  invisible(x)
}

gwr_weights <- function(dist_i, bw, kernel, adaptive) {
  b <- if (adaptive) sort(dist_i)[bw] else bw
  b <- max(b, 1e-12)
  if (kernel == "bisquare") {
    ifelse(dist_i < b, (1 - (dist_i / b)^2)^2, 0)
  } else {
    exp(-0.5 * (dist_i / b)^2)
  }
}

gwr_fit <- function(x, y, d, bw, kernel, adaptive, full = FALSE, loo = FALSE) {
  n <- nrow(x)
  p <- ncol(x)
  beta <- matrix(NA_real_, n, p)
  hat_diag <- numeric(n)
  cmat <- if (full) vector("list", n) else NULL
  s_rows <- if (full) matrix(0, n, n) else NULL
  fitted <- numeric(n)
  ok <- TRUE
  for (i in seq_len(n)) {
    w <- gwr_weights(d[i, ], bw, kernel, adaptive)
    if (loo) w[i] <- 0
    xw <- x * w
    xtwx <- crossprod(xw, x)
    inv <- tryCatch(solve(xtwx), error = function(e) NULL)
    if (is.null(inv)) {
      ok <- FALSE
      break
    }
    ci <- inv %*% t(xw)
    beta[i, ] <- ci %*% y
    si <- drop(x[i, , drop = FALSE] %*% ci)
    hat_diag[i] <- si[i]
    fitted[i] <- sum(x[i, ] * beta[i, ])
    if (full) {
      cmat[[i]] <- ci
      s_rows[i, ] <- si
    }
  }
  if (!ok) return(list(aicc = Inf, cv = Inf))
  rss <- sum((y - fitted)^2)
  tr_s <- sum(hat_diag)
  sigma <- sqrt(rss / n)
  aicc <- if (n - 2 - tr_s > 0) {
    2 * n * log(sigma) + n * log(2 * pi) + n * (n + tr_s) / (n - 2 - tr_s)
  } else {
    Inf
  }
  out <- list(
    beta = beta, fitted = fitted, rss = rss, tr_s = tr_s, aicc = aicc, cv = rss
  )
  if (full) {
    tr_sts <- sum(s_rows^2)
    sigma2 <- rss / (n - 2 * tr_s + tr_sts)
    out$sigma <- sqrt(sigma2)
    out$enp <- 2 * tr_s - tr_sts
    out$se <- t(vapply(cmat, function(ci) sqrt(rowSums(ci^2) * sigma2), numeric(ncol(x))))
    if (ncol(x) == 1) out$se <- t(out$se)
    out$local_r2 <- vapply(seq_len(n), function(i) {
      w <- gwr_weights(d[i, ], bw, kernel, adaptive)
      ybar <- sum(w * y) / sum(w)
      1 - sum(w * (y - fitted)^2) / sum(w * (y - ybar)^2)
    }, 1)
  }
  out
}

gwr_select <- function(x, y, d, kernel, adaptive, criterion) {
  n <- nrow(x)
  score <- function(bw) {
    if (adaptive) bw <- round(bw)
    f <- gwr_fit(x, y, d, bw, kernel, adaptive, loo = criterion == "cv")
    if (criterion == "cv") f$cv else f$aicc
  }
  if (adaptive) {
    lower <- ncol(x) + 2
    upper <- n
  } else {
    dd <- d[upper.tri(d)]
    lower <- max(stats::quantile(dd, 0.05), 1e-6)
    upper <- max(dd)
  }
  gr <- (sqrt(5) - 1) / 2
  a <- lower
  b <- upper
  c1 <- b - gr * (b - a)
  c2 <- a + gr * (b - a)
  f1 <- score(c1)
  f2 <- score(c2)
  tol <- if (adaptive) 1 else 1e-4 * (upper - lower)
  while (abs(b - a) > tol) {
    if (f1 < f2) {
      b <- c2
      c2 <- c1
      f2 <- f1
      c1 <- b - gr * (b - a)
      f1 <- score(c1)
    } else {
      a <- c1
      c1 <- c2
      f1 <- f2
      c2 <- a + gr * (b - a)
      f2 <- score(c2)
    }
  }
  if (adaptive) {
    cand <- unique(pmin(pmax(as.vector(outer(round(c(a, b, c1, c2)), -1:1, `+`)), lower), upper))
    sc <- vapply(cand, score, 1)
    cand[which.min(sc)]
  } else {
    (a + b) / 2
  }
}
