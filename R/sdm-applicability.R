#' Where can a model be trusted? Area of applicability and MESS
#'
#' @description
#' Models fitted to environmental predictors, such as species distribution
#' models ([sdm_fit()]), are unreliable where new locations have predictor
#' values unlike any in the training data.
#'
#' `sdm_aoa()` computes the dissimilarity index (DI) and the area of
#' applicability (AOA) of Meyer and Pebesma (2021), as in the CAST package:
#' predictors are standardised by the training data and optionally weighted
#' by their importance; DI is the distance from each new location to its
#' nearest training point, divided by the mean distance between training
#' points. The threshold is the upper whisker (third quartile plus 1.5
#' times the interquartile range) of the DI of the training points, each
#' measured to the nearest training point outside its own cross-validation
#' fold (or to the nearest other point without folds), capped at the
#' largest training DI. Locations with DI
#' above the threshold are outside the AOA.
#'
#' `sdm_mess()` computes the multivariate environmental similarity surface
#' (MESS) of Elith et al. (2010), as in `dismo::mess()` and
#' `predicts::mess()`: negative values show extrapolation beyond the
#' training range of at least one predictor, and `mod` names the most
#' dissimilar predictor.
#'
#' @param train A data frame of training data with the predictor columns,
#'   or a `tmr_sdm` from [sdm_fit()] (its training data are used).
#' @param newdata A data frame of new locations with the same predictors.
#' @param predictors Character vector of predictor columns. Defaults to the
#'   predictors of a `tmr_sdm`, else is required.
#' @param weights Optional named numeric vector of predictor importance
#'   (such as absolute standardised coefficients); all 1 when `NULL`.
#' @param folds Optional vector of cross-validation fold labels for the
#'   rows of `train`, such as spatial blocks, so the threshold reflects the
#'   cross-validation used to assess the model.
#' @return `sdm_aoa()` returns `newdata` as a tibble with `di` and `aoa`
#'   (`TRUE` inside the area of applicability), and the threshold in the
#'   attribute `"threshold"`. `sdm_mess()` returns `newdata` with `mess`
#'   and `mod`.
#' @references Meyer, H. and Pebesma, E. (2021). Predicting into unknown
#'   space? Estimating the area of applicability of spatial prediction
#'   models. Methods in Ecology and Evolution, 12, 1620-1633.
#'   \doi{10.1111/2041-210X.13650}
#'
#'   Elith, J., Kearney, M. and Phillips, S. (2010). The art of modelling
#'   range-shifting species. Methods in Ecology and Evolution, 1, 330-342.
#'   \doi{10.1111/j.2041-210X.2010.00036.x}
#' @export
#' @examples
#' set.seed(1)
#' train <- data.frame(temp = runif(60, 18, 24), rain = runif(60, 2000, 3000))
#' new <- data.frame(
#'   temp = c(20, 23, 28, 15),
#'   rain = c(2500, 2900, 2500, 4000)
#' )
#' sdm_aoa(train, new, predictors = c("temp", "rain"))
#' sdm_mess(train, new, predictors = c("temp", "rain"))
sdm_aoa <- function(train, newdata, predictors = NULL, weights = NULL, folds = NULL) {
  ref <- aoa_inputs(train, newdata, predictors)
  p <- ref$predictors
  w <- rep(1, length(p))
  names(w) <- p
  if (!is.null(weights)) {
    ok <- is.numeric(weights) && !is.null(names(weights)) &&
      all(p %in% names(weights)) && all(weights[p] >= 0)
    if (!ok) {
      cli::cli_abort(
        "{.arg weights} must be a named non-negative vector covering {.val {p}}."
      )
    }
    w <- weights[p]
  }
  tr <- as.matrix(ref$train[p])
  nw <- as.matrix(ref$newdata[p])
  if (anyNA(tr)) cli::cli_abort("Training predictors must not be missing.")
  mu <- colMeans(tr)
  sdv <- apply(tr, 2, stats::sd)
  sdv[sdv == 0] <- 1
  scale_w <- function(m) sweep(sweep(m, 2, mu), 2, sdv, "/") %*% diag(w, length(w))
  ts <- scale_w(tr)
  ns <- scale_w(nw)
  n <- nrow(ts)
  if (n < 3) cli::cli_abort("{.arg train} needs at least three rows.")
  dtr <- as.matrix(stats::dist(ts))
  mean_d <- mean(dtr[upper.tri(dtr)])
  if (!is.null(folds)) {
    if (length(folds) != n) {
      cli::cli_abort("{.arg folds} must have one value per row of {.arg train}.")
    }
    same <- outer(folds, folds, "==")
    dtr[same] <- Inf
  } else {
    diag(dtr) <- Inf
  }
  di_train <- apply(dtr, 1, min) / mean_d
  di_train <- di_train[is.finite(di_train)]
  q <- stats::quantile(di_train, c(0.25, 0.75), names = FALSE)
  thr <- q[2] + 1.5 * (q[2] - q[1])
  thr <- min(thr, max(di_train))
  di <- apply(ns, 1, function(z) {
    if (anyNA(z)) return(NA_real_)
    sqrt(min(colSums((t(ts) - z)^2)))
  }) / mean_d
  out <- tibble::as_tibble(ref$newdata)
  out$di <- di
  out$aoa <- di <= thr
  attr(out, "threshold") <- thr
  out
}

#' @rdname sdm_aoa
#' @export
sdm_mess <- function(train, newdata, predictors = NULL) {
  ref <- aoa_inputs(train, newdata, predictors)
  p <- ref$predictors
  sim <- vapply(p, function(v) {
    r <- ref$train[[v]]
    r <- r[!is.na(r)]
    mess_one(ref$newdata[[v]], r)
  }, numeric(nrow(ref$newdata)))
  sim <- matrix(sim, nrow = nrow(ref$newdata))
  out <- tibble::as_tibble(ref$newdata)
  out$mess <- apply(sim, 1, function(z) if (all(is.na(z))) NA_real_ else min(z, na.rm = TRUE))
  out$mod <- apply(sim, 1, function(z) if (all(is.na(z))) NA_character_ else p[which.min(z)])
  out
}

mess_one <- function(x, r) {
  mn <- min(r)
  mx <- max(r)
  rng <- mx - mn
  f <- vapply(x, function(z) 100 * mean(r < z), 1)
  out <- ifelse(f == 0, (x - mn) / rng * 100,
    ifelse(f <= 50, 2 * f,
      ifelse(f < 100, 2 * (100 - f), (mx - x) / rng * 100)
    )
  )
  out[is.na(x)] <- NA_real_
  out
}

aoa_inputs <- function(train, newdata, predictors, call = caller_env()) {
  if (inherits(train, "tmr_sdm")) {
    predictors <- predictors %||% train$predictors
    train <- train$training
  }
  tmr_check_data(train, call = call)
  tmr_check_data(newdata, call = call)
  if (is.null(predictors) || !is.character(predictors)) {
    cli::cli_abort("{.arg predictors} must name the predictor columns.", call = call)
  }
  miss <- union(setdiff(predictors, names(train)), setdiff(predictors, names(newdata)))
  if (length(miss)) {
    cli::cli_abort("Predictor column{?s} missing: {.val {miss}}.", call = call)
  }
  ok <- vapply(predictors, function(v) is.numeric(train[[v]]) && is.numeric(newdata[[v]]), TRUE)
  if (!all(ok)) cli::cli_abort("Predictors must be numeric.", call = call)
  list(train = train, newdata = newdata, predictors = predictors)
}
