#' Tidy species distribution models (presence-background / presence-absence)
#'
#' Fits presence-only (presence-background) or presence-absence models with
#' a tidy interface. Engines: `"glm"` (logistic or cloglog), `"gam"` (mgcv
#' when installed), and `"maxnet"` (native Maxent-like linear + quadratic
#' features with ridge-penalised logistic regression; no Java Maxent, no
#' biomod2 or dismo). Predictors may be columns or a SpatRaster stack from
#' [geo_bioclim()] / [geo_extract()].
#'
#' @param data Occurrence table with coordinates and optional absence rows
#'   (`present` column 1/0). When absences are missing, background points
#'   are sampled from `predictors` or from the bounding box.
#' @param predictors Character vector of predictor columns in `data`, or a
#'   `SpatRaster` of predictors.
#' @param lon,lat Coordinate columns.
#' @param present Optional presence/absence column (1/0). When `NULL`, every
#'   row is treated as a presence and background points are added.
#' @param engine `"glm"`, `"gam"`, or `"maxnet"`.
#' @param link `"logit"` or `"cloglog"`.
#' @param n_background Number of background points for presence-only data.
#' @param features Feature types for `"maxnet"`: any of `"linear"`,
#'   `"quadratic"`.
#' @param lambda Ridge penalty for `"maxnet"` (larger = more shrinkage).
#' @param seed Optional RNG seed for background sampling.
#' @return An object of class `tmr_sdm` with elements `engine`, `model`,
#'   `predictors`, `coefficients` (tibble), `training` (tibble), `link`,
#'   and `formula`.
#' @name sdm
#' @examplesIf requireNamespace("terra", quietly = TRUE)
#' set.seed(1)
#' # Species present only at high bio1
#' grid <- expand.grid(lon = seq(145, 145.5, length.out = 12),
#'                     lat = seq(-5.9, -5.5, length.out = 10))
#' grid$bio1 <- 15 + 10 * (grid$lat - min(grid$lat)) /
#'   diff(range(grid$lat))
#' occ <- dplyr::filter(grid, bio1 > 22) |>
#'   dplyr::slice_sample(n = 25)
#' fit <- sdm_fit(occ, predictors = "bio1", engine = "glm")
#' sdm_evaluate(fit)
NULL

#' @rdname sdm
#' @export
sdm_fit <- function(data,
                    predictors,
                    lon = lon,
                    lat = lat,
                    present = NULL,
                    engine = c("glm", "gam", "maxnet"),
                    link = c("logit", "cloglog"),
                    n_background = 500,
                    features = c("linear", "quadratic"),
                    lambda = 1e-4,
                    seed = NULL) {
  engine <- rlang::arg_match(engine)
  link <- rlang::arg_match(link)
  tmr_check_data(data)
  lon_col <- tmr_pick(enquo(lon), data, "lon")
  lat_col <- tmr_pick(enquo(lat), data, "lat")
  present_q <- enquo(present)

  pred_rast <- NULL
  if (inherits(predictors, "SpatRaster")) {
    rlang::check_installed("terra")
    pred_rast <- predictors
    data <- geo_extract(data, predictors, lon = {{ lon }}, lat = {{ lat }})
    predictors <- names(pred_rast)
  }
  if (is.character(predictors)) {
    missing <- setdiff(predictors, names(data))
    if (length(missing) > 0) {
      cli::cli_abort("Predictor column{?s} missing: {.val {missing}}.")
    }
  } else {
    cli::cli_abort("{.arg predictors} must be a character vector or SpatRaster.")
  }

  if (quo_is_null(present_q)) {
    data$.present <- 1L
    present_col <- ".present"
    if (!is.null(seed)) set.seed(seed)
    bg <- sdm_sample_background(
      data, lon_col, lat_col, predictors, pred_rast, n_background
    )
    train <- dplyr::bind_rows(
      tibble::as_tibble(data[c(lon_col, lat_col, predictors, present_col)]),
      bg
    )
  } else {
    present_col <- tmr_pick(present_q, data, "present")
    train <- tibble::as_tibble(data[c(lon_col, lat_col, predictors, present_col)])
    names(train)[names(train) == present_col] <- ".present"
    present_col <- ".present"
  }
  train <- stats::na.omit(train)
  if (length(unique(train$.present)) < 2) {
    cli::cli_abort("Training data need both presence and absence/background rows.")
  }

  if (engine == "glm") {
    fml <- stats::as.formula(paste(
      ".present ~", paste(predictors, collapse = " + ")
    ))
    fam <- if (identical(link, "cloglog")) {
      stats::binomial(link = "cloglog")
    } else {
      stats::binomial(link = "logit")
    }
    model <- suppressWarnings(stats::glm(fml, data = train, family = fam))
    coefs <- broom_tidy_glm(model)
  } else if (engine == "gam") {
    rlang::check_installed("mgcv")
    terms <- vapply(predictors, function(p) sprintf("s(%s, k = 5)", p), character(1))
    fml <- stats::as.formula(paste(".present ~", paste(terms, collapse = " + ")))
    fam <- if (identical(link, "cloglog")) {
      stats::binomial(link = "cloglog")
    } else {
      stats::binomial(link = "logit")
    }
    model <- mgcv::gam(fml, data = train, family = fam, method = "REML")
    coefs <- broom_tidy_glm(model)
  } else {
    # Native maxnet-like: linear (+ quadratic) features, ridge logistic
    design <- sdm_maxnet_design(train[predictors], features = features)
    y <- as.numeric(train$.present)
    model <- sdm_ridge_logit(design$x, y, lambda = lambda, link = link)
    model$feature_names <- design$names
    model$base_predictors <- predictors
    model$features <- features
    model$means <- design$means
    model$sds <- design$sds
    coefs <- tibble::tibble(
      term = c("(Intercept)", design$names),
      estimate = c(model$intercept, model$beta)
    )
    fml <- paste(".present ~ maxnet(", paste(predictors, collapse = ", "), ")")
  }

  out <- list(
    engine = engine,
    model = model,
    predictors = predictors,
    predictor_raster = pred_rast,
    coefficients = coefs,
    training = train,
    link = link,
    formula = fml,
    lon = lon_col,
    lat = lat_col
  )
  class(out) <- c("tmr_sdm", "list")
  out
}

#' @rdname sdm
#' @param object A `tmr_sdm` from [sdm_fit()].
#' @param newdata Optional data frame of prediction locations. When `NULL`
#'   and a predictor raster was supplied at fit time, predicts on that raster.
#' @param type `"response"` (probability) or `"link"`.
#' @export
sdm_predict <- function(object, newdata = NULL, type = c("response", "link")) {
  if (!inherits(object, "tmr_sdm")) {
    cli::cli_abort("{.arg object} must be a {.cls tmr_sdm} from {.fn sdm_fit}.")
  }
  type <- rlang::arg_match(type)
  if (is.null(newdata) && !is.null(object$predictor_raster)) {
    rlang::check_installed("terra")
    r <- object$predictor_raster
    # Predict on raster cells
    vals <- terra::values(r)
    colnames(vals) <- names(r)
    eta <- sdm_eta(object, as.data.frame(vals))
    prob <- sdm_link_inv(eta, object$link)
    out <- r[[1]]
    terra::values(out) <- if (identical(type, "link")) eta else prob
    names(out) <- "suitability"
    if (is.null(terra::crs(out)) || !nzchar(terra::crs(out))) {
      terra::crs(out) <- terra::crs(r)
    }
    return(out)
  }
  if (is.null(newdata)) {
    newdata <- object$training
  }
  tmr_check_data(newdata)
  eta <- sdm_eta(object, newdata)
  tibble::tibble(
    !!!newdata[intersect(c(object$lon, object$lat, object$predictors), names(newdata))],
    suitability = if (identical(type, "link")) eta else sdm_link_inv(eta, object$link)
  )
}

#' @rdname sdm
#' @param threshold Suitability threshold for TSS / sensitivity. When `NULL`,
#'   the threshold that maximises TSS on the training data is used.
#' @export
sdm_evaluate <- function(object, newdata = NULL, threshold = NULL) {
  if (!inherits(object, "tmr_sdm")) {
    cli::cli_abort("{.arg object} must be a {.cls tmr_sdm}.")
  }
  dat <- newdata %||% object$training
  if (!".present" %in% names(dat)) {
    cli::cli_abort("{.arg newdata} needs a {.val .present} column (0/1).")
  }
  pred <- sdm_predict(object, newdata = dat, type = "response")
  y <- as.numeric(dat$.present)
  p <- pred$suitability
  auc <- sdm_auc(y, p)
  thr <- threshold %||% sdm_best_threshold(y, p)
  cls <- as.integer(p >= thr)
  sens <- sum(cls == 1 & y == 1) / max(1, sum(y == 1))
  spec <- sum(cls == 0 & y == 0) / max(1, sum(y == 0))
  tss <- sens + spec - 1
  tibble::tibble(
    auc = auc,
    tss = tss,
    threshold = thr,
    sensitivity = sens,
    specificity = spec,
    n = length(y),
    n_presence = sum(y == 1),
    n_absence = sum(y == 0)
  )
}

#' @rdname sdm
#' @param x A `tmr_sdm`, a prediction tibble from [sdm_predict()], or a
#'   suitability SpatRaster.
#' @param basemap Basemap for ggplot maps. See [geo_basemap()].
#' @param ... Passed through to the surface / [plot_geo()] helpers (for
#'   example `legend_position`, `scale_bar`, `north_arrow`, `subtitle`).
#'   Regular prediction grids are drawn as a continuous raster surface;
#'   sparse tables stay as points.
#' @export
plot_sdm <- function(x, basemap = "esri", ...) {
  rlang::check_installed("ggplot2")
  dots <- list(...)
  if (inherits(x, "tmr_sdm")) {
    pred <- sdm_predict(x)
    return(plot_sdm(pred, basemap = basemap, ...))
  }
  if (inherits(x, "SpatRaster")) {
    return(plot_sdm_raster(x, basemap = basemap, ...))
  }
  tmr_check_data(x)
  if (!"suitability" %in% names(x)) {
    cli::cli_abort("{.arg x} must contain a {.val suitability} column.")
  }
  lon_col <- intersect(c("lon", "x"), names(x))[1]
  lat_col <- intersect(c("lat", "y"), names(x))[1]
  if (is.na(lon_col) || is.na(lat_col)) {
    cli::cli_abort("Prediction table needs lon/lat columns.")
  }
  # Regular prediction grids become a continuous raster surface (not a point lattice)
  if (geo_is_regular_grid(x[[lon_col]], x[[lat_col]])) {
    r <- geo_grid_to_raster(x, lon_col, lat_col, value = "suitability")
    return(plot_sdm_raster(r, basemap = basemap, ...))
  }
  # Sparse presence/background predictions stay as points via plot_geo
  dots$legend_position <- dots$legend_position %||% "outside"
  dots$legend_title <- dots$legend_title %||% "Suitability"
  dots$scale_bar <- dots$scale_bar %||% TRUE
  rlang::inject(plot_geo(
    x, value = "suitability",
    lon = !!rlang::sym(lon_col), lat = !!rlang::sym(lat_col),
    basemap = basemap, !!!dots
  ))
}

# Continuous suitability surface from a SpatRaster
plot_sdm_raster <- function(r, basemap = "esri", ...) {
  rlang::check_installed("terra")
  rlang::check_installed("sf")
  dots <- list(...)
  # Use first layer as suitability
  if (terra::nlyr(r) > 1) r <- r[[1]]
  names(r) <- "suitability"
  df <- terra::as.data.frame(r, xy = TRUE, na.rm = FALSE)
  names(df)[1:3] <- c("lon", "lat", "suitability")
  bb <- sf::st_bbox(
    c(
      xmin = min(df$lon, na.rm = TRUE), ymin = min(df$lat, na.rm = TRUE),
      xmax = max(df$lon, na.rm = TRUE), ymax = max(df$lat, na.rm = TRUE)
    ),
    crs = sf::st_crs(terra::crs(r))
  )
  # Expand slightly for basemap context
  dx <- max((bb["xmax"] - bb["xmin"]) * 0.05, 1e-4)
  dy <- max((bb["ymax"] - bb["ymin"]) * 0.05, 1e-4)
  bb["xmin"] <- bb["xmin"] - dx
  bb["xmax"] <- bb["xmax"] + dx
  bb["ymin"] <- bb["ymin"] - dy
  bb["ymax"] <- bb["ymax"] + dy

  p <- ggplot2::ggplot()
  bm <- geo_basemap_layers(bb, basemap = basemap, crs = sf::st_crs(bb))
  for (ly in bm$layers) p <- p + ly
  p <- p +
    ggplot2::geom_raster(
      data = df,
      ggplot2::aes(.data$lon, .data$lat, fill = .data$suitability),
      interpolate = TRUE,
      alpha = if (isTRUE(bm$uses_fill) || identical(basemap, "none")) 1 else 0.85
    ) +
    ggplot2::scale_fill_viridis_c(
      name = "Suitability", option = "C", na.value = "transparent",
      guide = ggplot2::guide_colourbar(order = 1)
    )

  scale_bar <- dots$scale_bar %||% TRUE
  north_arrow <- dots$north_arrow %||% TRUE
  # Dummy points at corners so decoration picker has coordinates
  corners <- tibble::tibble(
    lon = c(bb["xmin"], bb["xmax"], bb["xmin"], bb["xmax"]),
    lat = c(bb["ymin"], bb["ymin"], bb["ymax"], bb["ymax"])
  )
  decor <- geo_pick_decoration_corner(
    corners, bb,
    scale_bar = isTRUE(scale_bar),
    north_arrow = isTRUE(north_arrow),
    inset = FALSE,
    legend_inside = FALSE
  )
  if (isTRUE(scale_bar) && !is.null(decor$scale_box)) {
    for (ly in geo_annotation_scale_bar(
      bb, crs = sf::st_crs(bb), corner = decor$scale_corner, box = decor$scale_box
    )) p <- p + ly
  }
  if (isTRUE(north_arrow) && !is.null(decor$north_box)) {
    for (ly in geo_annotation_north_arrow(
      bb, corner = decor$north_corner, box = decor$north_box
    )) p <- p + ly
  }
  p <- p +
    ggplot2::coord_sf(
      xlim = c(bb["xmin"], bb["xmax"]),
      ylim = c(bb["ymin"], bb["ymax"]),
      expand = FALSE, crs = sf::st_crs(bb)
    ) +
    theme_tidymapr(grid = "none") +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey20", linewidth = 0.4),
      legend.position = dots$legend_position %||% "right"
    ) +
    ggplot2::labs(
      x = NULL, y = NULL,
      subtitle = dots$subtitle
    )
  attr(p, "tmr_decoration") <- decor
  p
}

geo_is_regular_grid <- function(x, y, tol = 1e-8) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  ux <- sort(unique(x[is.finite(x)]))
  uy <- sort(unique(y[is.finite(y)]))
  if (length(ux) < 3 || length(uy) < 3) return(FALSE)
  # Nearly complete rectangular lattice
  expected <- length(ux) * length(uy)
  if (length(x) < expected * 0.85) return(FALSE)
  dx <- diff(ux)
  dy <- diff(uy)
  isTRUE(diff(range(dx)) < max(tol, mean(dx) * 1e-3)) &&
    isTRUE(diff(range(dy)) < max(tol, mean(dy) * 1e-3))
}

geo_grid_to_raster <- function(data, lon_col, lat_col, value = "suitability") {
  rlang::check_installed("terra")
  xs <- sort(unique(data[[lon_col]]))
  ys <- sort(unique(data[[lat_col]]))
  r <- terra::rast(
    nrows = length(ys), ncols = length(xs),
    xmin = min(xs) - diff(xs)[1] / 2,
    xmax = max(xs) + diff(xs)[1] / 2,
    ymin = min(ys) - diff(ys)[1] / 2,
    ymax = max(ys) + diff(ys)[1] / 2,
    crs = "EPSG:4326"
  )
  # terra rasterize from points
  pts <- data.frame(
    x = data[[lon_col]], y = data[[lat_col]], z = data[[value]]
  )
  v <- terra::vect(pts, geom = c("x", "y"), crs = "EPSG:4326")
  out <- terra::rasterize(v, r, field = "z")
  names(out) <- value
  out
}

# ---- internals ----------------------------------------------------------

sdm_sample_background <- function(data, lon_col, lat_col, predictors,
                                  pred_rast, n_background) {
  n_background <- as.integer(n_background)
  if (!is.null(pred_rast)) {
    pts <- terra::spatSample(pred_rast, size = n_background, method = "random",
                             xy = TRUE, values = TRUE, na.rm = TRUE)
    pts <- tibble::as_tibble(pts)
    names(pts)[1:2] <- c(lon_col, lat_col)
    pts$.present <- 0L
    return(pts[c(lon_col, lat_col, predictors, ".present")])
  }
  xr <- range(data[[lon_col]], na.rm = TRUE)
  yr <- range(data[[lat_col]], na.rm = TRUE)
  # Expand bbox so background covers a wider environmental space
  dx <- diff(xr)
  dy <- diff(yr)
  if (!is.finite(dx) || dx == 0) dx <- 1
  if (!is.finite(dy) || dy == 0) dy <- 1
  bg <- tibble::tibble(
    !!lon_col := stats::runif(n_background, xr[1] - 0.5 * dx, xr[2] + 0.5 * dx),
    !!lat_col := stats::runif(n_background, yr[1] - 0.5 * dy, yr[2] + 0.5 * dy)
  )
  # Sample predictors from an expanded range around presence values
  for (p in predictors) {
    pr <- range(data[[p]], na.rm = TRUE)
    span <- diff(pr)
    if (!is.finite(span) || span == 0) span <- 1
    bg[[p]] <- stats::runif(n_background, pr[1] - 0.5 * span, pr[2] + 0.5 * span)
  }
  bg$.present <- 0L
  bg
}

sdm_maxnet_design <- function(df, features = c("linear", "quadratic")) {
  x <- as.matrix(df)
  storage.mode(x) <- "double"
  means <- colMeans(x, na.rm = TRUE)
  sds <- apply(x, 2, stats::sd, na.rm = TRUE)
  sds[!is.finite(sds) | sds == 0] <- 1
  z <- sweep(sweep(x, 2, means, "-"), 2, sds, "/")
  cols <- list()
  nms <- character()
  if ("linear" %in% features) {
    cols <- c(cols, list(z))
    nms <- c(nms, colnames(z))
  }
  if ("quadratic" %in% features) {
    q <- z^2
    colnames(q) <- paste0(colnames(z), "^2")
    cols <- c(cols, list(q))
    nms <- c(nms, colnames(q))
  }
  mat <- do.call(cbind, cols)
  list(x = mat, names = nms, means = means, sds = sds)
}

sdm_ridge_logit <- function(x, y, lambda = 1e-4, link = "logit",
                            maxit = 50, tol = 1e-6) {
  n <- nrow(x)
  p <- ncol(x)
  beta <- rep(0, p)
  intercept <- stats::qlogis(mean(y))
  for (iter in seq_len(maxit)) {
    eta <- as.numeric(intercept + x %*% beta)
    if (identical(link, "cloglog")) {
      mu <- 1 - exp(-exp(pmin(eta, 20)))
      mu <- pmin(pmax(mu, 1e-6), 1 - 1e-6)
      # Working weights for cloglog binomial
      dmu <- exp(pmin(eta, 20) - exp(pmin(eta, 20)))
      w <- as.numeric(dmu^2 / (mu * (1 - mu) + 1e-8))
      z <- eta + (y - mu) / (dmu + 1e-8)
    } else {
      mu <- if (exists("sdm_logistic_cpp", mode = "function")) {
        sdm_logistic_cpp(eta)
      } else {
        1 / (1 + exp(-eta))
      }
      mu <- pmin(pmax(mu, 1e-6), 1 - 1e-6)
      w <- as.numeric(mu * (1 - mu))
      z <- eta + (y - mu) / w
    }
    # Weighted ridge regression with intercept
    sqrtw <- sqrt(pmax(w, 1e-8))
    design <- cbind(1, x)
    design_w <- design * sqrtw
    z_w <- z * sqrtw
    xtx <- crossprod(design_w)
    diag(xtx) <- diag(xtx) + c(0, rep(lambda, p))
    coef <- tryCatch(
      solve(xtx, crossprod(design_w, z_w)),
      error = function(e) {
        qr.coef(qr(xtx), as.numeric(crossprod(design_w, z_w)))
      }
    )
    intercept_new <- coef[1]
    beta_new <- coef[-1]
    if (max(abs(c(intercept_new - intercept, beta_new - beta))) < tol) {
      intercept <- intercept_new
      beta <- beta_new
      break
    }
    intercept <- intercept_new
    beta <- beta_new
  }
  list(intercept = as.numeric(intercept), beta = as.numeric(beta),
       lambda = lambda, link = link)
}

sdm_eta <- function(object, newdata) {
  if (identical(object$engine, "maxnet")) {
    base <- as.matrix(newdata[object$predictors])
    means <- object$model$means
    sds <- object$model$sds
    z <- sweep(sweep(base, 2, means, "-"), 2, sds, "/")
    cols <- list()
    if ("linear" %in% object$model$features) cols <- c(cols, list(z))
    if ("quadratic" %in% object$model$features) {
      q <- z^2
      cols <- c(cols, list(q))
    }
    design <- do.call(cbind, cols)
    if (exists("sdm_linear_predict_cpp", mode = "function")) {
      return(object$model$intercept +
               sdm_linear_predict_cpp(design, object$model$beta))
    }
    return(as.numeric(object$model$intercept + design %*% object$model$beta))
  }
  if (identical(object$engine, "gam")) {
    return(as.numeric(stats::predict(object$model, newdata = newdata, type = "link")))
  }
  as.numeric(stats::predict(object$model, newdata = newdata, type = "link"))
}

sdm_link_inv <- function(eta, link) {
  if (identical(link, "cloglog")) {
    if (exists("sdm_cloglog_cpp", mode = "function")) return(sdm_cloglog_cpp(eta))
    return(1 - exp(-exp(pmin(eta, 20))))
  }
  if (exists("sdm_logistic_cpp", mode = "function")) return(sdm_logistic_cpp(eta))
  1 / (1 + exp(-eta))
}

sdm_auc <- function(y, p) {
  y <- as.integer(y)
  pos <- p[y == 1]
  neg <- p[y == 0]
  if (length(pos) == 0 || length(neg) == 0) return(NA_real_)
  # Mann-Whitney U / AUC
  sum(vapply(pos, function(a) mean(a > neg) + 0.5 * mean(a == neg), numeric(1))) /
    length(pos)
}

sdm_best_threshold <- function(y, p) {
  ths <- sort(unique(p))
  if (length(ths) > 200) {
    ths <- stats::quantile(p, probs = seq(0, 1, length.out = 201), names = FALSE)
  }
  best <- ths[1]
  best_tss <- -Inf
  for (t in ths) {
    cls <- as.integer(p >= t)
    sens <- sum(cls == 1 & y == 1) / max(1, sum(y == 1))
    spec <- sum(cls == 0 & y == 0) / max(1, sum(y == 0))
    tss <- sens + spec - 1
    if (tss > best_tss) {
      best_tss <- tss
      best <- t
    }
  }
  best
}

broom_tidy_glm <- function(model) {
  sm <- summary(model)$coefficients
  tibble::tibble(
    term = rownames(sm),
    estimate = sm[, 1],
    std.error = if (ncol(sm) >= 2) sm[, 2] else NA_real_,
    statistic = if (ncol(sm) >= 3) sm[, 3] else NA_real_,
    p.value = if (ncol(sm) >= 4) sm[, 4] else NA_real_
  )
}

#' @export
print.tmr_sdm <- function(x, ...) {
  cli::cli_text("Species distribution model ({.val {x$engine}}, link = {.val {x$link}})")
  cli::cli_text("Predictors: {.val {x$predictors}}")
  cli::cli_text("Training rows: {nrow(x$training)} ({sum(x$training$.present)} presences)")
  print(x$coefficients, ...)
  invisible(x)
}
