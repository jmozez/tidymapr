#' Maxent species distribution models, in C++
#'
#' @description
#' `sdm_maxent()` fits Maxent (Phillips, Anderson and Schapire 2006) as an
#' infinitely-weighted logistic regression with a lasso penalty (Fithian and
#' Hastie 2013; Phillips et al. 2017), the formulation of the maxnet package,
#' with the same feature classes and default regularisation. The lasso path
#' is solved by coordinate descent in C++, so no Java and no glmnet are
#' needed. Predictions are on the cloglog scale by default (Phillips et al.
#' 2017), clamped to the training range.
#'
#' @param presence 0/1 vector: 1 for presences, 0 for background points.
#' @param data Data frame of predictors for the same rows; numeric columns
#'   are continuous, factors are categorical.
#' @param features Feature classes, any of `"l"` (linear), `"q"`
#'   (quadratic), `"p"` (product), `"h"` (hinge), `"t"` (threshold) as one
#'   string such as `"lqh"`, or `"default"`, which uses maxnet's rule (`l`
#'   below 10 presences, `lq` below 15, `lqh` below 80, else `lqph`).
#' @param regmult Regularisation multiplier: larger gives smoother models.
#' @param add_samples_to_background Add presences to the background, as
#'   Maxent does?
#' @param standardize Rescale every continuous predictor to 0-1 over the
#'   training data before building features (default `TRUE`), as the
#'   original Java Maxent does. The maxnet package builds linear, quadratic
#'   and product features on the raw scale and fits them unstandardised, so
#'   a predictor in metres (elevation) and one in millimetres (rainfall)
#'   produce squares and products that differ by many orders of magnitude.
#'   The penalties then do not compare across features and the lasso path
#'   can stall. On the 0-1 scale every feature class is comparable, the
#'   default regularisation means the same thing for every predictor, and
#'   the fit is stable. Use `FALSE` to reproduce maxnet exactly.
#' @param object A model from `sdm_maxent()`.
#' @param newdata Data frame or `SpatRaster` of predictors.
#' @param type `"cloglog"` (default), `"logistic"`, `"exponential"` or
#'   `"link"`.
#' @param clamp Clamp predictors and features to the training range?
#' @return `sdm_maxent()`: an object of class `tmr_maxent` with the non-zero
#'   coefficients (`betas`), `alpha`, `entropy` and the feature definitions.
#'   `predict()`: a numeric vector, or a `SpatRaster` for raster input.
#' @references
#' Phillips SJ, Anderson RP, Schapire RE (2006) Maximum entropy modeling of
#' species geographic distributions. Ecological Modelling 190:231-259.
#'
#' Fithian W, Hastie T (2013) Finite-sample equivalence in statistical
#' models for presence-only data. Annals of Applied Statistics 7:1917-1939.
#'
#' Phillips SJ, Anderson RP, Dudik M, Schapire RE, Blair ME (2017) Opening
#' the black box: an open-source release of Maxent. Ecography 40:887-893.
#' @seealso [sdm_ensemble()] to combine Maxent with other algorithms.
#' @examplesIf rlang::is_installed("maxnet")
#' # Brown-throated sloth, Bradypus variegatus (Phillips et al. 2006)
#' data(bradypus, package = "maxnet")
#' fit <- sdm_maxent(bradypus$presence, bradypus[, -1])
#' fit
#' head(predict(fit, bradypus[, -1]))
#' @export
sdm_maxent <- function(presence,
                       data,
                       features = "default",
                       regmult = 1,
                       add_samples_to_background = TRUE,
                       standardize = TRUE) {
  data <- as.data.frame(data)
  if (!is.numeric(presence) || !all(presence %in% c(0, 1)) || length(presence) != nrow(data)) {
    cli::cli_abort("{.arg presence} must be 0/1 with one value per row of {.arg data}.")
  }
  if (anyNA(data)) cli::cli_abort("{.arg data} has missing values; remove those rows first.")
  if (sum(presence) < 2 || sum(presence == 0) < 2) {
    cli::cli_abort("Need at least two presences and two background points.")
  }
  tmr_check_number(regmult, "regmult", 0)
  if (isTRUE(add_samples_to_background)) {
    key <- function(d) do.call(paste, c(lapply(d, as.character), sep = "\r"))
    pk <- key(data[presence == 1, , drop = FALSE])
    nk <- key(data[presence == 0, , drop = FALSE])
    toadd <- !pk %in% nk
    data <- rbind(data, data[presence == 1, , drop = FALSE][toadd, , drop = FALSE])
    presence <- c(presence, rep(0, sum(toadd)))
  }
  np <- sum(presence)
  if (identical(features, "default")) {
    features <- if (np < 10) "l" else if (np < 15) "lq" else if (np < 80) "lqh" else "lqph"
  }
  if (!grepl("^[lqpht]+$", features)) {
    cli::cli_abort("{.arg features} must use the letters l, q, p, h and t, such as {.val lqh}.")
  }
  # Rescale continuous predictors to 0-1 (training range incl. background)
  num <- names(data)[vapply(data, is.numeric, TRUE)]
  scaling <- NULL
  if (isTRUE(standardize) && length(num)) {
    scaling <- lapply(num, function(v) range(data[[v]]))
    names(scaling) <- num
    data <- tmr_maxent_scale(data, scaling)
  }
  spec <- tmr_maxent_spec(data, features)
  mm <- tmr_maxent_features(spec, data)
  reg <- tmr_maxent_regularization(presence, mm, spec$class) * regmult
  w <- presence + (1 - presence) * 100
  lambda <- 10^(seq(4, 0, length.out = 200)) * sum(reg) / length(reg) *
    sum(presence) / sum(w)
  fit <- sdm_lasso_logit_cpp(mm, presence, w, reg, lambda, threads = tmr_threads())
  beta <- fit$beta[, 200]
  names(beta) <- colnames(mm)
  keep <- beta != 0
  obj <- structure(list(
    betas = beta[keep], alpha = 0, entropy = 0, spec = spec,
    feature_class = spec$class[keep], penalty = reg,
    featuremins = apply(mm, 2, min)[keep], featuremaxs = apply(mm, 2, max)[keep],
    varmin = vapply(spec$cont, function(v) min(data[[v]]), 1),
    varmax = vapply(spec$cont, function(v) max(data[[v]]), 1),
    features = features, regmult = regmult, n_presence = np, scaling = scaling,
    n_background = sum(presence == 0), lambda = lambda[200]
  ), class = "tmr_maxent")
  rr <- exp(as.vector(tmr_maxent_link(obj, data[presence == 0, , drop = FALSE], clamp = FALSE)))
  raw <- rr / sum(rr)
  obj$entropy <- -sum(raw * log(raw))
  obj$alpha <- -log(sum(rr))
  obj
}

#' @rdname sdm_maxent
#' @param ... Not used.
#' @export
predict.tmr_maxent <- function(object, newdata,
                               type = c("cloglog", "logistic", "exponential", "link"),
                               clamp = TRUE, ...) {
  type <- rlang::arg_match(type)
  if (inherits(newdata, "SpatRaster")) {
    rlang::check_installed("terra")
    df <- terra::as.data.frame(newdata, cells = TRUE, na.rm = TRUE)
    out <- terra::rast(newdata[[1]])
    terra::values(out) <- NA_real_
    out[df$cell] <- stats::predict(object, df[, -1, drop = FALSE], type = type, clamp = clamp)
    names(out) <- type
    return(out)
  }
  newdata <- as.data.frame(newdata)
  if (!is.null(object$scaling)) newdata <- tmr_maxent_scale(newdata, object$scaling)
  link <- as.vector(tmr_maxent_link(object, newdata, clamp = clamp)) + object$alpha
  switch(type,
    link = link,
    exponential = exp(link),
    cloglog = 1 - exp(-exp(object$entropy + link)),
    logistic = 1 / (1 + exp(-object$entropy - link))
  )
}

#' @export
print.tmr_maxent <- function(x, ...) {
  cli::cli_text(
    "{.strong Maxent} ({x$features} features, regmult {x$regmult}): ",
    "{x$n_presence} presences, {x$n_background} background points, ",
    "{if (is.null(x$scaling)) 'raw' else 'standardised'} predictors, ",
    "{length(x$betas)} non-zero features of {length(x$penalty)}."
  )
  kinds <- c("linear", "quadratic", "product", "hinge", "threshold", "categorical")
  cls <- table(factor(x$feature_class, levels = kinds))
  cls <- cls[cls > 0]
  if (length(cls)) {
    kept <- paste(names(cls), cls, sep = " ", collapse = ", ")
    cli::cli_text("Features kept: {kept}.")
  }
  invisible(x)
}

# ---- features ---------------------------------------------------------------

# Feature definitions from the training data (knots from the range, as maxnet)
tmr_maxent_spec <- function(data, features) {
  cont <- names(data)[vapply(data, is.numeric, TRUE)]
  cat <- names(data)[vapply(data, is.factor, TRUE)]
  bad <- setdiff(names(data), c(cont, cat))
  if (length(bad)) {
    cli::cli_abort("Predictor{?s} {.val {bad}} must be numeric or factor.")
  }
  rng <- lapply(cont, function(v) range(data[[v]]))
  names(rng) <- cont
  list(
    cont = cont, cat = cat, range = rng, features = features,
    levels = lapply(data[cat], levels), class = NULL
  ) |> tmr_maxent_spec_class(data)
}

tmr_maxent_spec_class <- function(spec, data) {
  mm <- tmr_maxent_features(spec, data[1, , drop = FALSE])
  spec$class <- attr(mm, "class_of")
  spec
}

tmr_maxent_features <- function(spec, data) {
  f <- spec$features
  acc <- new.env(parent = emptyenv())
  acc$cols <- list()
  acc$cls <- character()
  add <- function(name, val, k) {
    # maxnet builds the outermost forward and reverse hinges of every
    # predictor as the same column twice, (x - min) / (max - min); keep one
    if (!is.null(acc$cols[[name]])) return(invisible())
    acc$cols[[name]] <- val
    acc$cls <- c(acc$cls, k)
  }
  has <- function(ch) grepl(ch, f, fixed = TRUE)
  ramp <- function(x, lo, hi) pmin(1, pmax(0, (x - lo) / (hi - lo)))
  if (has("l")) for (v in spec$cont) add(v, data[[v]], "linear")
  if (has("q")) for (v in spec$cont) add(paste0("I(", v, "^2)"), data[[v]]^2, "quadratic")
  if (has("h")) {
    for (v in spec$cont) {
      r <- spec$range[[v]]
      k <- seq(r[1], r[2], length.out = 50)
      x <- data[[v]]
      for (h in utils::head(k, -1)) {
        add(paste0("hinge(", v, "):", h, ":", r[2]), ramp(x, h, r[2]), "hinge")
      }
      for (h in k[-1]) {
        add(paste0("hinge(", v, "):", r[1], ":", h), ramp(x, r[1], h), "hinge")
      }
    }
  }
  if (has("t")) {
    for (v in spec$cont) {
      r <- spec$range[[v]]
      k <- seq(r[1], r[2], length.out = 52)[2:51]
      for (t in k) add(paste0("thresholds(", v, "):", t), as.numeric(data[[v]] >= t), "threshold")
    }
  }
  if (has("p") && length(spec$cont) > 1) {
    cc <- spec$cont
    for (j in seq_len(length(cc) - 1)) {
      for (i in (j + 1):length(cc)) {
        add(paste0(cc[i], ":", cc[j]), data[[cc[i]]] * data[[cc[j]]], "product")
      }
    }
  }
  for (v in spec$cat) {
    for (lv in spec$levels[[v]]) {
      val <- as.numeric(as.character(data[[v]]) == lv)
      add(paste0("categorical(", v, "):", lv), val, "categorical")
    }
  }
  cols <- acc$cols
  m <- do.call(cbind, cols)
  if (is.null(dim(m))) m <- matrix(m, nrow = 1, dimnames = list(NULL, names(cols)))
  colnames(m) <- names(cols)
  attr(m, "class_of") <- acc$cls
  m
}

# maxnet's default regularisation (Phillips and Dudik 2008 tables)
tmr_maxent_regularization <- function(presence, m, cls) {
  mm <- m[presence == 1, , drop = FALSE]
  np <- nrow(mm)
  lq <- list(c(0, 10, 30, 100), c(1, 1, 0.2, 0.05))
  if (any(cls == "quadratic")) lq <- list(c(0, 10, 17, 30, 100), c(1.3, 0.8, 0.5, 0.25, 0.05))
  if (any(cls == "product")) lq <- list(c(0, 10, 17, 30, 100), c(2.6, 1.6, 0.9, 0.55, 0.05))
  tab <- function(k) {
    switch(k,
      hinge = list(c(0, 1), c(0.5, 0.5)),
      categorical = list(c(0, 10, 17), c(0.65, 0.5, 0.25)),
      threshold = list(c(0, 100), c(2, 1)),
      lq
    )
  }
  creg <- vapply(cls, function(k) {
    t <- tab(k)
    stats::approx(t[[1]], t[[2]], np, rule = 2)$y
  }, 1) / sqrt(np)
  sds <- apply(mm, 2, stats::sd)
  hmindev <- ifelse(cls == "hinge", pmax(sds, 1 / sqrt(np)) * 0.5 / sqrt(np), 0)
  tmindev <- ifelse(cls == "threshold" & (colSums(mm) == 0 | colSums(mm) == np), 1, 0)
  pmax(0.001 * (apply(m, 2, max) - apply(m, 2, min)), hmindev, tmindev, sds * creg)
}

# Linear predictor without alpha, from the kept features only
tmr_maxent_link <- function(object, data, clamp = TRUE) {
  if (clamp) {
    for (v in intersect(names(object$varmax), names(data))) {
      data[[v]] <- pmin(pmax(data[[v]], object$varmin[[v]]), object$varmax[[v]])
    }
  }
  mm <- tmr_maxent_features(object$spec, data)[, names(object$betas), drop = FALSE]
  if (clamp) {
    mm <- t(pmin(pmax(t(mm), object$featuremins), object$featuremaxs))
  }
  mm %*% object$betas
}

# (x - min) / (max - min) per continuous predictor; constant ones become 0
tmr_maxent_scale <- function(data, scaling) {
  for (v in intersect(names(scaling), names(data))) {
    r <- scaling[[v]]
    d <- r[2] - r[1]
    data[[v]] <- if (d > 0) (data[[v]] - r[1]) / d else data[[v]] * 0
  }
  data
}
