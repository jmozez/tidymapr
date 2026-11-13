#' Integrated species distribution model with physiological limits
#'
#' @description
#' `sdm_integrated()` fits one niche model to two kinds of data at once
#' (Fithian et al. 2015; Isaac et al. 2020):
#'
#' * **presence-only** records (for example GBIF), modelled as an
#'   inhomogeneous Poisson point process with background (quadrature)
#'   points, with its own intercept and optional **bias** covariates that
#'   describe where people look (distance to roads, towns, field stations);
#' * **presence-absence** surveys (for example standardised elevational
#'   transects), modelled with a complementary log-log link, so that the
#'   probability of presence at a site of area \eqn{A} is
#'   \eqn{1 - \exp(-A \lambda(x))}.
#'
#' Both share the same environmental response \eqn{\lambda(x)}, so the
#' many but biased presence-only records and the few but unbiased surveys
#' inform one niche: the surveys correct the sampling bias of the records
#' and the records fill in where no surveys were made.
#'
#' Two constraints keep projections to future climates biologically
#' plausible:
#'
#' * `unimodal`: the response to these covariates is forced to be a
#'   hump (negative quadratic term), so suitability falls beyond the
#'   optimum instead of rising without limit in novel climates;
#' * `limits`: physiological limits, such as a critical thermal maximum
#'   (CTmax) for maximum temperature. Suitability is multiplied by a
#'   smooth step that falls from 0.9 to 0.1 over the `limit_width` just
#'   inside the limit, and towards 0 beyond it.
#'
#' Covariates are standardised before fitting, and a small ridge penalty
#' (`lambda`) stabilises the fit; the coefficients are reported on the
#' standardised scale.
#'
#' @param presence Data frame of covariates at presence-only records.
#' @param background Data frame of covariates at background points spread
#'   over the study area (for example 10,000 random cells).
#' @param area Total area of the study region (any unit; it scales the
#'   intensity of the presence-only process).
#' @param survey Optional data frame of presence-absence surveys: covariates
#'   and a 0/1 column `present` (and optionally `site_area`, in the same
#'   units as `area`; default 1).
#' @param covariates Environmental covariates (column names).
#' @param quadratic Covariates that also get a squared term; default all.
#' @param unimodal Quadratic covariates whose response must be a hump.
#' @param bias Bias covariates, used only for the presence-only data. Set
#'   them to a common value (for example their minimum, meaning "well
#'   surveyed") when predicting.
#' @param limits Named list of physiological limits, each `c(lower, upper)`
#'   on the original scale of the covariate (use `NA` for no limit), for
#'   example `list(bio5 = c(NA, 33))` for a CTmax of 33 degrees C.
#' @param limit_width Width of the smooth fall to zero at a limit, in the
#'   units of the covariate.
#' @param lambda Ridge penalty on the environmental coefficients.
#' @return `sdm_integrated()`: an object of class `tmr_sdm_integrated` with
#'   the coefficients (`coef`), their standard errors (`se`, from the
#'   inverse Hessian), the log-likelihood and the standardisation used.
#'   `predict()` gives, for a data frame or a `SpatRaster` of covariates,
#'   the probability of presence in an area of `site_area`
#'   (`type = "probability"`), the intensity (`"intensity"`) or the linear
#'   predictor (`"link"`).
#' @param se_fit For a data frame `newdata`, also return the standard error
#'   of the linear predictor (`se_link`, by the delta method from the
#'   covariance of the fitted parameters) and a confidence interval formed
#'   on the link scale and back-transformed to `type` (`lower`, `upper`).
#' @param level Confidence level of the interval.
#' @references
#' Fithian, W., Elith, J., Hastie, T. and Keith, D. A. (2015). Bias
#' correction in species distribution models: pooling survey and
#' collection data for multiple species. Methods in Ecology and Evolution,
#' 6, 424-438.
#'
#' Isaac, N. J. B. et al. (2020). Data integration for large-scale models of
#' species distributions. Trends in Ecology & Evolution, 35, 56-67.
#'
#' Sunday, J. M., Bates, A. E. and Dulvy, N. K. (2012). Thermal tolerance and
#' the global redistribution of animals. Nature Climate Change, 2, 686-690.
#' @seealso [geo_shift_simulate()] to add dispersal to the projections.
#' @export
#' @examples
#' set.seed(1)
#' # Virtual species with an optimum at 20 C, records biased towards roads
#' bg <- data.frame(temp = runif(5000, 5, 30), road = runif(5000))
#' lam <- function(d) exp(2 - 0.08 * (d$temp - 20)^2)
#' keep <- runif(5000) < lam(bg) / max(lam(bg)) * exp(-3 * bg$road)
#' po <- bg[keep, ][1:300, ]
#' sv <- data.frame(temp = runif(80, 5, 30), road = runif(80))
#' sv$present <- rbinom(80, 1, 1 - exp(-0.02 * lam(sv)))
#' fit <- sdm_integrated(po, bg,
#'   area = 1000, survey = sv,
#'   covariates = "temp", unimodal = "temp", bias = "road",
#'   limits = list(temp = c(NA, 28))
#' )
#' fit
#' predict(fit, data.frame(temp = c(10, 20, 27, 29), road = 0))
sdm_integrated <- function(presence,
                           background,
                           area,
                           survey = NULL,
                           covariates,
                           quadratic = covariates,
                           unimodal = character(),
                           bias = character(),
                           limits = list(),
                           limit_width = 1,
                           lambda = 0.01) {
  for (nm in c("presence", "background")) {
    if (!is.data.frame(get(nm))) cli::cli_abort("{.arg {nm}} must be a data frame.")
  }
  need <- unique(c(covariates, bias))
  miss <- setdiff(need, intersect(names(presence), names(background)))
  if (length(miss)) {
    cli::cli_abort("Covariates missing from {.arg presence} or {.arg background}: {.val {miss}}.")
  }
  if (!all(quadratic %in% covariates) || !all(unimodal %in% quadratic)) {
    cli::cli_abort(
      "{.arg unimodal} must be in {.arg quadratic}, and {.arg quadratic} in {.arg covariates}."
    )
  }
  if (!is.null(survey)) {
    if (!all(c(covariates, "present") %in% names(survey))) {
      cli::cli_abort("{.arg survey} needs the covariates and a 0/1 column {.field present}.")
    }
    if (!all(survey$present %in% c(0, 1))) {
      cli::cli_abort("{.field present} in {.arg survey} must be 0 or 1.")
    }
  }
  if (!is.numeric(area) || length(area) != 1 || area <= 0) {
    cli::cli_abort("{.arg area} must be one positive number.")
  }
  # Standardisation from presence + background
  pool <- rbind(presence[need], background[need])
  centre <- vapply(pool, mean, numeric(1), na.rm = TRUE)
  scale <- vapply(pool, stats::sd, numeric(1), na.rm = TRUE)
  scale[!is.finite(scale) | scale == 0] <- 1
  spec <- list(
    covariates = covariates, quadratic = quadratic, unimodal = unimodal,
    bias = bias, centre = centre, scale = scale
  )
  x_po <- tmr_isdm_design(presence, spec)
  x_bg <- tmr_isdm_design(background, spec)
  b_po <- tmr_isdm_bias(presence, spec)
  b_bg <- tmr_isdm_bias(background, spec)
  ok_po <- stats::complete.cases(x_po, b_po)
  ok_bg <- stats::complete.cases(x_bg, b_bg)
  x_po <- x_po[ok_po, , drop = FALSE]
  b_po <- b_po[ok_po, , drop = FALSE]
  x_bg <- x_bg[ok_bg, , drop = FALSE]
  b_bg <- b_bg[ok_bg, , drop = FALSE]
  w_bg <- area / nrow(x_bg)
  has_sv <- !is.null(survey)
  if (has_sv) {
    x_sv <- tmr_isdm_design(survey, spec)
    ok_sv <- stats::complete.cases(x_sv)
    x_sv <- x_sv[ok_sv, , drop = FALSE]
    y_sv <- survey$present[ok_sv]
    a_sv <- if ("site_area" %in% names(survey)) survey$site_area[ok_sv] else rep(1, sum(ok_sv))
  }
  p_env <- ncol(x_po)
  p_bias <- ncol(b_po)
  uni_idx <- match(paste0(unimodal, "^2"), colnames(x_po))
  uni_idx <- uni_idx[!is.na(uni_idx)]
  # Parameters: env (unimodal squared terms as log(-b)), po intercept,
  # bias, survey intercept
  unpack <- function(theta) {
    b <- theta[seq_len(p_env)]
    b[uni_idx] <- -exp(b[uni_idx])
    list(
      b = b, a_po = theta[p_env + 1],
      g = theta[p_env + 1 + seq_len(p_bias)],
      a_sv = if (has_sv) theta[p_env + p_bias + 2] else NA_real_
    )
  }
  negll <- function(theta) {
    q <- unpack(theta)
    e_po <- q$a_po + drop(x_po %*% q$b) + drop(b_po %*% q$g)
    e_bg <- q$a_po + drop(x_bg %*% q$b) + drop(b_bg %*% q$g)
    ll <- if (has_po) sum(e_po) - w_bg * sum(exp(e_bg)) else 0
    if (has_sv) {
      mu <- a_sv * exp(q$a_sv + drop(x_sv %*% q$b))
      ll <- ll + sum(ifelse(y_sv == 1, log(-expm1(-mu)), -mu))
    }
    -ll + lambda * sum(q$b^2) / 2
  }
  grad <- function(theta) {
    q <- unpack(theta)
    e_po <- q$a_po + drop(x_po %*% q$b) + drop(b_po %*% q$g)
    e_bg <- q$a_po + drop(x_bg %*% q$b) + drop(b_bg %*% q$g)
    r_bg <- if (has_po) w_bg * exp(e_bg) else 0 * e_bg
    gb <- colSums(x_po) - colSums(x_bg * r_bg)
    ga <- nrow(x_po) - sum(r_bg)
    gg <- colSums(b_po) - colSums(b_bg * r_bg)
    gs <- numeric(0)
    if (has_sv) {
      mu <- a_sv * exp(q$a_sv + drop(x_sv %*% q$b))
      d <- ifelse(y_sv == 1, mu * exp(-mu) / (-expm1(-mu)), -mu)
      gb <- gb + colSums(x_sv * d)
      gs <- sum(d)
    }
    gb <- gb - lambda * q$b
    gb[uni_idx] <- gb[uni_idx] * q$b[uni_idx]
    -c(gb, ga, gg, gs)
  }
  has_po <- nrow(x_po) > 0
  if (!has_po && !has_sv) {
    cli::cli_abort("Give at least one presence record or a {.arg survey}.")
  }
  start <- c(rep(0, p_env), log(max(nrow(x_po), 1) / area), rep(0, p_bias), if (has_sv) -2)
  start[uni_idx] <- log(0.1)
  opt <- stats::optim(start, negll, grad,
    method = "BFGS", hessian = TRUE,
    control = list(maxit = 2000, reltol = 1e-12)
  )
  if (opt$convergence != 0) {
    cli::cli_warn("The optimiser did not fully converge (code {opt$convergence}).")
  }
  q <- unpack(opt$par)
  # Without presence records the presence-only intercept is not estimable
  est <- if (has_po) seq_along(opt$par) else setdiff(seq_along(opt$par), p_env + 1)
  se_theta <- rep(NA_real_, length(opt$par))
  se_theta[est] <- tryCatch(sqrt(pmax(diag(solve(opt$hessian[est, est, drop = FALSE])), 0)),
    error = function(e) rep(NA_real_, length(est))
  )
  vcov_theta <- matrix(NA_real_, length(opt$par), length(opt$par))
  vcov_theta[est, est] <- tryCatch(solve(opt$hessian[est, est, drop = FALSE]),
    error = function(e) matrix(NA_real_, length(est), length(est))
  )
  se_b <- se_theta[seq_len(p_env)]
  se_b[uni_idx] <- se_b[uni_idx] * abs(q$b[uni_idx]) # delta method
  coef <- c(q$b,
    po_intercept = q$a_po, stats::setNames(q$g, colnames(b_po)),
    if (has_sv) c(survey_intercept = q$a_sv)
  )
  names(coef)[seq_len(p_env)] <- colnames(x_po)
  se <- c(se_b, se_theta[-seq_len(p_env)])
  names(se) <- names(coef)
  structure(list(
    coef = coef, se = se, loglik = -opt$value, spec = spec,
    limits = limits, limit_width = limit_width, has_survey = has_sv,
    n = c(
      presence = nrow(x_po), background = nrow(x_bg),
      survey = if (has_sv) length(y_sv) else 0L
    ),
    lambda = lambda, convergence = opt$convergence,
    vcov_theta = vcov_theta, uni_idx = uni_idx, p_env = p_env, p_bias = p_bias
  ), class = "tmr_sdm_integrated")
}

tmr_isdm_design <- function(d, spec) {
  z <- lapply(spec$covariates, function(v) (d[[v]] - spec$centre[[v]]) / spec$scale[[v]])
  names(z) <- spec$covariates
  xm <- do.call(cbind, z)
  colnames(xm) <- spec$covariates
  if (length(spec$quadratic)) {
    qm <- do.call(cbind, z[spec$quadratic])^2
    colnames(qm) <- paste0(spec$quadratic, "^2")
    xm <- cbind(xm, qm)
  }
  xm
}

tmr_isdm_bias <- function(d, spec) {
  if (!length(spec$bias)) {
    return(matrix(numeric(0), nrow(d), 0))
  }
  bm <- do.call(cbind, lapply(spec$bias, function(v) (d[[v]] - spec$centre[[v]]) / spec$scale[[v]]))
  colnames(bm) <- spec$bias
  bm
}

#' @rdname sdm_integrated
#' @param object A fitted `sdm_integrated()` model.
#' @param newdata Data frame or `SpatRaster` of covariates. Bias covariates
#'   are ignored (prediction is for unbiased sampling).
#' @param type `"probability"`, `"intensity"` or `"link"`.
#' @param site_area Area for `type = "probability"`; default 1 (one survey
#'   site).
#' @param ... Unused.
#' @export
predict.tmr_sdm_integrated <- function(object, newdata,
                                       type = c("probability", "intensity", "link"),
                                       site_area = 1, se_fit = FALSE,
                                       level = 0.95, ...) {
  type <- rlang::arg_match(type)
  if (se_fit && inherits(newdata, "SpatRaster")) {
    cli::cli_abort("{.arg se_fit} needs a data frame {.arg newdata}.")
  }
  if (inherits(newdata, "SpatRaster")) {
    rlang::check_installed("terra")
    vars <- unique(c(object$spec$covariates, names(object$limits)))
    df <- as.data.frame(newdata[[vars]], na.rm = FALSE)
    p <- predict.tmr_sdm_integrated(object, df, type = type, site_area = site_area)
    out <- terra::rast(newdata[[1]])
    terra::values(out) <- p
    names(out) <- type
    return(out)
  }
  spec <- object$spec
  xm <- tmr_isdm_design(newdata, spec)
  b <- object$coef[colnames(xm)]
  a <- if (object$has_survey) object$coef[["survey_intercept"]] else object$coef[["po_intercept"]]
  eta <- a + drop(xm %*% b)
  lim <- rep(1, nrow(newdata))
  for (v in names(object$limits)) {
    l <- object$limits[[v]]
    x <- newdata[[v]]
    w <- object$limit_width
    if (!is.na(l[1])) lim <- lim * stats::plogis((x - l[1]) / (w / 4.4) - 2.2)
    if (length(l) > 1 && !is.na(l[2])) lim <- lim * stats::plogis((l[2] - x) / (w / 4.4) - 2.2)
  }
  inv <- function(e) {
    switch(type,
      link = e + log(lim),
      intensity = exp(e) * lim,
      probability = -expm1(-site_area * exp(e) * lim)
    )
  }
  if (!se_fit) {
    return(inv(eta))
  }
  # Standard error of the linear predictor by the delta method, from the
  # covariance of the fitted parameters; the interval is formed on the link
  # scale and back-transformed, so it respects the bounds of the response.
  pe <- object$p_env
  jac <- matrix(0, nrow(xm), nrow(object$vcov_theta))
  jac[, seq_len(pe)] <- xm
  if (length(object$uni_idx)) {
    jac[, object$uni_idx] <- xm[, object$uni_idx, drop = FALSE] *
      rep(b[object$uni_idx], each = nrow(xm))
  }
  int_idx <- if (object$has_survey) pe + object$p_bias + 2 else pe + 1
  jac[, int_idx] <- 1
  # Parameters not estimated (the presence-only intercept without records)
  # do not enter the linear predictor
  keep <- which(colSums(abs(jac)) > 0)
  vc <- object$vcov_theta[keep, keep, drop = FALSE]
  jk <- jac[, keep, drop = FALSE]
  se <- sqrt(pmax(rowSums((jk %*% vc) * jk), 0))
  z <- stats::qnorm(1 - (1 - level) / 2)
  tibble::tibble(
    fit = inv(eta), se_link = se,
    lower = inv(eta - z * se), upper = inv(eta + z * se)
  )
}

#' @export
print.tmr_sdm_integrated <- function(x, ...) {
  cli::cli_text("Integrated species distribution model")
  cli::cli_text(
    "{x$n[['presence']]} presence-only records, {x$n[['background']]} background points, \\
    {x$n[['survey']]} survey sites"
  )
  if (length(x$limits)) {
    cli::cli_text("Physiological limits: {.val {names(x$limits)}}")
  }
  tab <- data.frame(estimate = x$coef, se = x$se)
  print(round(tab, 4))
  invisible(x)
}
