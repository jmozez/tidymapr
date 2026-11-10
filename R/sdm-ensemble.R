#' Ensembles of species distribution models
#'
#' @description
#' `sdm_ensemble()` fits several algorithms to the same presence-background
#' (or presence-absence) data, scores each with spatial block
#' cross-validation, and combines them into one weighted ensemble, in the
#' spirit of biomod2 (Thuiller et al. 2009) but without its dependencies and
#' with fixes for common weaknesses:
#'
#' * **Spatial cross-validation by default.** Random folds put test points
#'   next to training points, so spatially autocorrelated data look better
#'   than they are (Roberts et al. 2017). Folds here are whole spatial
#'   blocks.
#' * **Comparable algorithms.** Presence-background data are fitted with
#'   equal total weight for presences and background (Barbet-Massin et al.
#'   2012) for GLM and GAM, Maxent uses its own infinitely-weighted
#'   formulation, and the random forest grows each tree on a balanced
#'   bootstrap (down-sampling; Valavi et al. 2021), so all four answer the
#'   same question on the same 0-1 scale.
#' * **Weights from transferable skill.** Each algorithm is weighted by its
#'   cross-validated true skill statistic above `min_tss`; algorithms below
#'   it are left out rather than allowed to dilute the ensemble.
#' * **Standardised predictors.** Every algorithm sees predictors rescaled
#'   to 0-1 on the training range, so results do not depend on units or on
#'   where zero lies.
#' * **Agreement as uncertainty.** Predictions give the weighted mean and
#'   the weighted standard deviation across algorithms.
#'
#' The random forest and Maxent are written in C++ and run on several
#' cores.
#'
#' @param presence 0/1 vector: 1 for presences, 0 for background or absence.
#' @param data Data frame of predictors (numeric, or factors for Maxent and
#'   the random forest).
#' @param coords Optional two-column matrix or data frame of x and y
#'   coordinates for spatial blocks. Without it, folds are random.
#' @param algorithms Any of `"maxent"`, `"glm"`, `"gam"`, `"rf"`.
#' @param folds Number of cross-validation folds.
#' @param block_size Side of the square spatial blocks, in the units of
#'   `coords`. By default a tenth of the larger side of the extent.
#' @param min_tss Algorithms with a cross-validated TSS below this get no
#'   weight.
#' @param ntree,mtry Random forest size and variables tried at each split
#'   (default: square root of the number of predictors).
#' @param seed Random seed for the folds and the forest.
#' @param object An ensemble from `sdm_ensemble()`.
#' @param newdata Data frame or `SpatRaster` of predictors.
#' @param what `"mean"` (weighted ensemble), `"sd"` (weighted standard
#'   deviation across algorithms), `"all"` (every algorithm and both
#'   summaries).
#' @param ... Passed on to [sdm_maxent()].
#' @return `sdm_ensemble()`: an object of class `tmr_sdm_ensemble`, with
#'   `scores` (a tibble of AUC, TSS and Boyce index per algorithm and fold),
#'   `summary` (mean scores and the ensemble weight of each algorithm) and
#'   the models fitted on all data. `predict()`: a numeric vector, data
#'   frame or `SpatRaster`.
#' @references
#' Barbet-Massin M, Jiguet F, Albert CH, Thuiller W (2012) Selecting
#' pseudo-absences for species distribution models: how, where and how
#' many? Methods in Ecology and Evolution 3:327-338.
#'
#' Hirzel AH, Le Lay G, Helfer V, Randin C, Guisan A (2006) Evaluating the
#' ability of habitat suitability models to predict species presences.
#' Ecological Modelling 199:142-152.
#'
#' Roberts DR et al. (2017) Cross-validation strategies for data with
#' temporal, spatial, hierarchical, or phylogenetic structure. Ecography
#' 40:913-929.
#'
#' Thuiller W, Lafourcade B, Engler R, Araujo MB (2009) BIOMOD: a platform
#' for ensemble forecasting of species distributions. Ecography 32:369-373.
#'
#' Valavi R, Elith J, Lahoz-Monfort JJ, Guillera-Arroita G (2021) Modelling
#' species presence-only data with random forests. Ecography 44:1731-1742.
#' @seealso [sdm_maxent()].
#' @examplesIf rlang::is_installed("maxnet")
#' # Brown-throated sloth (Phillips et al. 2006)
#' data(bradypus, package = "maxnet")
#' ens <- sdm_ensemble(bradypus$presence, bradypus[, c(2, 3, 5:15)],
#'   algorithms = c("maxent", "glm", "rf"), folds = 4, ntree = 200
#' )
#' ens
#' @export
sdm_ensemble <- function(presence,
                         data,
                         coords = NULL,
                         algorithms = c("maxent", "glm", "gam", "rf"),
                         folds = 5,
                         block_size = NULL,
                         min_tss = 0.3,
                         ntree = 500,
                         mtry = NULL,
                         seed = 1,
                         ...) {
  data <- as.data.frame(data)
  algorithms <- unique(rlang::arg_match(algorithms, c("maxent", "glm", "gam", "rf"),
    multiple = TRUE
  ))
  if (!is.numeric(presence) || !all(presence %in% c(0, 1)) || length(presence) != nrow(data)) {
    cli::cli_abort("{.arg presence} must be 0/1 with one value per row of {.arg data}.")
  }
  ok <- stats::complete.cases(data)
  if (!all(ok)) {
    cli::cli_inform("Dropping {sum(!ok)} row{?s} with missing predictors.")
    data <- data[ok, , drop = FALSE]
    presence <- presence[ok]
    if (!is.null(coords)) coords <- coords[ok, , drop = FALSE]
  }
  if ("gam" %in% algorithms) rlang::check_installed("mgcv")
  tmr_check_number(folds, "folds", 2, 50)
  # Standardise once on the full training range
  num <- names(data)[vapply(data, is.numeric, TRUE)]
  scaling <- lapply(num, function(v) range(data[[v]]))
  names(scaling) <- num
  sdata <- tmr_maxent_scale(data, scaling)

  fold <- tmr_sdm_folds(presence, coords, folds, block_size, seed)
  args <- list(ntree = ntree, mtry = mtry, seed = seed, dots = list(...))
  scores <- list()
  for (k in sort(unique(fold))) {
    train <- fold != k
    if (length(unique(presence[!train])) < 2 || length(unique(presence[train])) < 2) next
    for (a in algorithms) {
      m <- tmr_sdm_fit_one(a, presence[train], sdata[train, , drop = FALSE], args)
      pr <- tmr_sdm_predict_one(m, sdata[!train, , drop = FALSE])
      scores[[length(scores) + 1]] <- tibble::tibble(
        algorithm = a, fold = k,
        auc = sdm_auc(presence[!train], pr),
        tss = tmr_tss(presence[!train], pr),
        boyce = tmr_boyce(pr[presence[!train] == 1], pr)
      )
    }
  }
  if (!length(scores)) cli::cli_abort("No fold has both presences and background; use fewer folds.")
  scores <- dplyr::bind_rows(scores)
  summ <- scores |>
    dplyr::group_by(.data$algorithm) |>
    dplyr::summarise(
      auc = mean(.data$auc, na.rm = TRUE), tss = mean(.data$tss, na.rm = TRUE),
      boyce = mean(.data$boyce, na.rm = TRUE), .groups = "drop"
    )
  w <- pmax(summ$tss - min_tss, 0)
  if (all(w == 0)) {
    cli::cli_warn("No algorithm reached TSS {min_tss}; weighting them equally.")
    w <- rep(1, nrow(summ))
  }
  summ$weight <- w / sum(w)
  summ <- summ[match(algorithms, summ$algorithm), ]
  models <- lapply(algorithms, function(a) tmr_sdm_fit_one(a, presence, sdata, args))
  names(models) <- algorithms
  structure(list(
    models = models, scores = scores, summary = summ, scaling = scaling,
    predictors = names(data), folds = fold, spatial = !is.null(coords),
    n_presence = sum(presence), n_background = sum(presence == 0)
  ), class = "tmr_sdm_ensemble")
}

#' @rdname sdm_ensemble
#' @export
predict.tmr_sdm_ensemble <- function(object, newdata, what = c("mean", "sd", "all"), ...) {
  what <- rlang::arg_match(what)
  if (inherits(newdata, "SpatRaster")) {
    rlang::check_installed("terra")
    df <- terra::as.data.frame(newdata[[object$predictors]], cells = TRUE, na.rm = TRUE)
    res <- stats::predict(object, df[, -1, drop = FALSE], what = "all")
    layers <- if (what == "all") names(res) else what
    out <- terra::rast(newdata[[1]], nlyrs = length(layers))
    terra::values(out) <- NA_real_
    for (i in seq_along(layers)) out[[i]][df$cell] <- res[[layers[i]]]
    names(out) <- layers
    return(out)
  }
  newdata <- tmr_maxent_scale(as.data.frame(newdata)[object$predictors], object$scaling)
  preds <- lapply(object$models, tmr_sdm_predict_one, newdata = newdata)
  pm <- do.call(cbind, preds)
  w <- object$summary$weight
  mu <- as.vector(pm %*% w)
  sdv <- sqrt(as.vector(((pm - mu)^2) %*% w))
  switch(what,
    mean = mu,
    sd = sdv,
    all = tibble::as_tibble(cbind(as.data.frame(pm), mean = mu, sd = sdv))
  )
}

#' @export
print.tmr_sdm_ensemble <- function(x, ...) {
  cli::cli_text(
    "{.strong SDM ensemble} of {length(x$models)} algorithm{?s}: ",
    "{x$n_presence} presences, {x$n_background} background points, ",
    "{length(unique(x$folds))} {if (x$spatial) 'spatial-block' else 'random'} folds."
  )
  s <- x$summary
  s[c("auc", "tss", "boyce", "weight")] <- lapply(s[c("auc", "tss", "boyce", "weight")], round, 3)
  print(s)
  invisible(x)
}

# ---- internals ------------------------------------------------------------

tmr_sdm_folds <- function(presence, coords, k, block_size, seed) {
  set.seed(seed)
  if (is.null(coords)) {
    # Random folds, stratified by presence
    f <- integer(length(presence))
    for (v in c(0, 1)) {
      idx <- which(presence == v)
      f[idx] <- sample(rep_len(seq_len(k), length(idx)))
    }
    return(f)
  }
  xy <- as.matrix(coords)[, 1:2]
  if (is.null(block_size)) block_size <- max(diff(range(xy[, 1])), diff(range(xy[, 2]))) / 10
  bx <- floor((xy[, 1] - min(xy[, 1])) / block_size)
  by <- floor((xy[, 2] - min(xy[, 2])) / block_size)
  block <- paste(bx, by)
  ub <- unique(block)
  # Spread blocks over folds so that every fold gets a similar share of the
  # presences and of the background: each block adds its share of both
  pres_in <- tapply(presence, block, sum)[ub]
  back_in <- tapply(1 - presence, block, sum)[ub]
  share <- pres_in / max(sum(pres_in), 1) + back_in / max(sum(back_in), 1)
  ord <- order(-share, stats::runif(length(ub)))
  load <- numeric(k)
  assign <- integer(length(ub))
  for (i in ord) {
    j <- which.min(load)
    assign[i] <- j
    load[j] <- load[j] + share[[i]]
  }
  assign[match(block, ub)]
}

tmr_sdm_fit_one <- function(a, y, d, args) {
  num <- vapply(d, is.numeric, TRUE)
  switch(a,
    maxent = do.call(sdm_maxent, c(list(y, d, standardize = FALSE), args$dots)),
    glm = {
      dn <- d[num]
      w <- ifelse(y == 1, 1, sum(y == 1) / sum(y == 0))
      f <- stats::as.formula(paste(
        "y ~", paste(c(names(dn), paste0("I(", names(dn), "^2)")), collapse = " + ")
      ))
      fit <- suppressWarnings(stats::glm(f,
        data = cbind(y = y, dn), family = stats::binomial(), weights = w
      ))
      structure(list(fit = fit), class = "tmr_sdm_glm")
    },
    gam = {
      dn <- d[num]
      w <- ifelse(y == 1, 1, sum(y == 1) / sum(y == 0))
      f <- stats::as.formula(paste("y ~", paste0("s(", names(dn), ", k = 4)", collapse = " + ")))
      fit <- suppressWarnings(mgcv::gam(f,
        data = cbind(y = y, dn), family = stats::binomial(), weights = w,
        method = "REML"
      ))
      structure(list(fit = fit), class = "tmr_sdm_glm")
    },
    rf = {
      x <- as.matrix(data.frame(lapply(d, as.numeric)))
      mtry <- args$mtry %||% max(1, floor(sqrt(ncol(x))))
      structure(list(
        forest = sdm_rf_fit_cpp(x, y,
          ntree = args$ntree, mtry = mtry, min_node = 1,
          balanced = TRUE, seed = args$seed, threads = tmr_threads()
        ),
        cols = colnames(x)
      ), class = "tmr_sdm_rf")
    }
  )
}

tmr_sdm_predict_one <- function(m, newdata) {
  if (inherits(m, "tmr_maxent")) {
    return(stats::predict(m, newdata, clamp = TRUE))
  }
  if (inherits(m, "tmr_sdm_glm")) {
    return(as.vector(stats::predict(m$fit, newdata, type = "response")))
  }
  x <- as.matrix(data.frame(lapply(newdata[m$cols], as.numeric)))
  sdm_rf_predict_cpp(m$forest, x, threads = tmr_threads())
}

# Largest true skill statistic over thresholds
tmr_tss <- function(y, p) {
  if (length(unique(y)) < 2) {
    return(NA_real_)
  }
  th <- sort(unique(p))
  if (length(th) > 400) th <- stats::quantile(p, seq(0, 1, length.out = 400), names = FALSE)
  np <- sum(y == 1)
  na <- sum(y == 0)
  best <- -1
  for (t in th) {
    sens <- sum(p[y == 1] >= t) / np
    spec <- sum(p[y == 0] < t) / na
    best <- max(best, sens + spec - 1)
  }
  best
}

# Continuous Boyce index (Hirzel et al. 2006): Spearman correlation of the
# predicted-to-expected ratio over moving windows of suitability
tmr_boyce <- function(pres, all, nclass = 0, window = NULL) {
  pres <- pres[is.finite(pres)]
  all <- all[is.finite(all)]
  if (length(pres) < 3) {
    return(NA_real_)
  }
  lo <- min(all)
  hi <- max(all)
  if (hi <= lo) {
    return(NA_real_)
  }
  window <- window %||% ((hi - lo) / 10)
  starts <- seq(lo, hi - window, length.out = 100)
  f <- vapply(starts, function(s) {
    pi <- mean(pres >= s & pres <= s + window)
    ei <- mean(all >= s & all <= s + window)
    if (ei == 0) NA_real_ else pi / ei
  }, 1)
  ok <- is.finite(f)
  if (sum(ok) < 3) {
    return(NA_real_)
  }
  suppressWarnings(stats::cor(f[ok], starts[ok], method = "spearman"))
}
