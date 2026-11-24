#' Variation partitioning between environment and space
#'
#' @description
#' Separates the variation in species composition explained by measured
#' environmental variables from that explained by spatial structure, as in
#' the spatial variation partitioning of CANOCO and Borcard et al. (2018):
#'
#' 1. Spatial predictors are distance-based Moran's eigenvector maps
#'    ([geo_mem()]) of the site coordinates.
#' 2. MEMs are kept only if they explain composition significantly as a set,
#'    and then chosen by forward selection with the double stopping
#'    criterion (Blanchet et al. 2008), so space is not over-fitted.
#' 3. The variation is partitioned ([vegan::varpart()]) into the fraction
#'    explained by environment alone `[a]`, shared by environment and space
#'    `[b]`, explained by space alone `[c]`, and unexplained, each as an
#'    adjusted \eqn{R^2}. The fractions that can be tested (`[a]`, `[c]` and
#'    the two sets) are tested by permutation in partial redundancy analyses.
#'
#' Read `[a]` as the effect of the measured environment free of spatial
#' structure; `[c]` as spatial structure not explained by the measured
#' environment (unmeasured variables, dispersal or biotic processes);
#' `[b]` as spatially structured environment, which cannot be attributed to
#' either alone. Shared fractions are not tested and can be negative when
#' the two sets suppress each other.
#'
#' @param data Long community data: one row per site and species.
#' @param site,species,abundance Columns of `data`.
#' @param env A data frame with one row per site: the site column, the
#'   coordinates and the environmental variables.
#' @param env_vars Names of the environmental variables in `env`.
#' @param lon,lat Names of the coordinate columns in `env`.
#' @param method Distance for the MEMs: `"euclidean"` for projected or
#'   local coordinates, `"haversine"` for longitude and latitude.
#' @param transform Transformation of the community matrix
#'   (`vegan::decostand()` method); `"hellinger"` by default.
#' @param alpha Significance level for keeping and selecting MEMs.
#' @param permutations Number of permutations.
#' @return A list of class `tmr_geo_varpart`: `fractions` (a tibble of
#'   fraction, meaning, adjusted R2, statistic and p-value), `mems` (the
#'   selected MEMs) and `fit` (the `varpart` object).
#' @references
#' Blanchet, F. G., Legendre, P. and Borcard, D. (2008). Forward selection of
#' explanatory variables. *Ecology*, 89, 2623-2632. \doi{10.1890/07-0986.1}
#'
#' Borcard, D., Gillet, F. and Legendre, P. (2018). *Numerical Ecology with
#' R*, second edition. Springer. Chapter 7.
#'
#' Peres-Neto, P. R., Legendre, P., Dray, S. and Borcard, D. (2006).
#' Variation partitioning of species data matrices: estimation and
#' comparison of fractions. *Ecology*, 87, 2614-2625.
#' @export
#' @examplesIf rlang::is_installed("vegan")
#' data("mite", "mite.env", "mite.xy", package = "vegan")
#' long <- data.frame(
#'   site = rep(rownames(mite), ncol(mite)),
#'   species = rep(colnames(mite), each = nrow(mite)),
#'   n = unlist(mite)
#' )
#' env <- cbind(site = rownames(mite), mite.xy, mite.env)
#' geo_varpart(long, abundance = n, env = env,
#'   env_vars = c("SubsDens", "WatrCont"), lon = "x", lat = "y",
#'   permutations = 199)
geo_varpart <- function(data, site = site, species = species, abundance = NULL, env,
                        env_vars, lon = "lon", lat = "lat",
                        method = c("euclidean", "haversine"), transform = "hellinger",
                        alpha = 0.05, permutations = 999) {
  rlang::check_installed("vegan", "for variation partitioning.")
  method <- rlang::arg_match(method)
  s <- rlang::as_name(rlang::enquo(site))
  sp <- rlang::as_name(rlang::enquo(species))
  ab_q <- rlang::enquo(abundance)
  ab <- if (rlang::quo_is_null(ab_q)) NULL else rlang::as_name(ab_q)
  for (v in c(s, lon, lat, env_vars)) {
    if (!v %in% names(env)) cli::cli_abort("{.arg env} has no column {.field {v}}.")
  }
  if (anyDuplicated(env[[s]])) cli::cli_abort("{.arg env} must have one row per site.")
  val <- if (is.null(ab)) rep(1, nrow(data)) else data[[ab]]
  y <- tapply(val, list(as.character(data[[s]]), as.character(data[[sp]])), sum)
  y[is.na(y)] <- 0
  sites <- intersect(rownames(y), as.character(env[[s]]))
  y <- y[sites, colSums(y[sites, , drop = FALSE]) > 0, drop = FALSE]
  y <- y[rowSums(y) > 0, , drop = FALSE]
  e <- as.data.frame(env)[match(rownames(y), as.character(env[[s]])), , drop = FALSE]
  yt <- if (identical(transform, "none")) y else vegan::decostand(y, transform)
  x_env <- e[env_vars]

  mem <- geo_mem(e, lon = !!rlang::sym(lon), lat = !!rlang::sym(lat), method = method)
  w <- as.data.frame(mem[grepl("^MEM[0-9]+$", names(mem))])
  # Keep space only if the MEMs as a set are significant, then select
  global <- vegan::anova.cca(vegan::rda(yt, w), permutations = permutations)
  selected <- character()
  if (global$`Pr(>F)`[1] <= alpha) {
    full_r2 <- vegan::RsquareAdj(vegan::rda(yt, w))$adj.r.squared
    for (step in seq_len(ncol(w))) {
      cand <- setdiff(names(w), selected)
      if (!length(cand)) break
      gain <- vapply(cand, function(m) {
        vegan::RsquareAdj(vegan::rda(yt, w[c(selected, m)]))$adj.r.squared
      }, 0)
      best <- names(which.max(gain))
      if (gain[[best]] > full_r2) break
      cond <- if (length(selected)) as.matrix(w[selected]) else NULL
      p <- vegan::anova.cca(vegan::rda(yt, w[best], cond), permutations = permutations)$`Pr(>F)`[1]
      if (p > alpha) break
      selected <- c(selected, best)
    }
  }
  if (!length(selected)) {
    cli::cli_abort(c(
      "No spatial structure: the MEMs do not explain composition significantly.",
      i = "Variation partitioning with space is not needed; test the environment alone (an RDA)."
    ))
  }
  ws <- w[selected]
  vp <- vegan::varpart(yt, x_env, ws)
  fr <- vp$part$indfract
  test <- function(x, cond) {
    a <- vegan::anova.cca(vegan::rda(yt, x, cond), permutations = permutations)
    c(a$F[1], a$`Pr(>F)`[1])
  }
  t_a <- test(x_env, as.matrix(ws))
  t_c <- test(ws, stats::model.matrix(~ ., x_env)[, -1, drop = FALSE])
  t_env <- test(x_env, NULL)
  t_sp <- test(ws, NULL)
  tot <- vp$part$fract
  fractions <- tibble::tibble(
    fraction = c("[a+b] environment", "[b+c] space", "[a] environment only",
                 "[b] shared", "[c] space only", "[d] unexplained"),
    meaning = c(
      "all variation the measured environment explains",
      "all variation the selected MEMs explain",
      "environment free of spatial structure",
      "spatially structured environment (not testable)",
      "spatial structure not explained by the measured environment",
      "residual variation"
    ),
    adj_r2 = c(tot$Adj.R.square[1], tot$Adj.R.square[2], fr$Adj.R.square[1],
               fr$Adj.R.square[2], fr$Adj.R.square[3], fr$Adj.R.square[4]),
    statistic = c(t_env[1], t_sp[1], t_a[1], NA, t_c[1], NA),
    p.value = c(t_env[2], t_sp[2], t_a[2], NA, t_c[2], NA)
  )
  structure(list(fractions = fractions, mems = mem[c(if (s %in% names(mem)) s, selected)],
                 selected = selected, fit = vp), class = "tmr_geo_varpart")
}

#' @export
print.tmr_geo_varpart <- function(x, ...) {
  n <- length(x$selected)
  cli::cli_text("{.strong Variation partitioning}: environment and space")
  cli::cli_text("{n} MEM{?s} selected: {x$selected}")
  print(x$fractions)
  invisible(x)
}

# nolint start: line_length_linter. Sentences read better unbroken.

#' @export
tmr_interpret.tmr_geo_varpart <- function(x, ...) {
  f <- x$fractions
  pct <- function(i) sprintf("%.1f%%", 100 * f$adj_r2[i])
  pv <- function(i) if (is.na(f$p.value[i])) "not testable" else paste0("p = ", tmr_fp(f$p.value[i]))
  s <- list(
    Overview = sprintf("Variation in composition partitioned between the measured environment and space (%d Moran's eigenvector map%s selected: %s).",
                       length(x$selected), if (length(x$selected) == 1) "" else "s", paste(x$selected, collapse = ", ")),
    Fractions = c(
      sprintf("Environment alone [a]: %s of the variation (adjusted R2), %s.", pct(3), pv(3)),
      sprintf("Shared [b]: %s; spatially structured environment, which cannot be attributed to either set.", pct(4)),
      sprintf("Space alone [c]: %s, %s; spatial structure the measured variables do not explain, pointing to unmeasured variables, dispersal or biotic processes.", pct(5), pv(5)),
      sprintf("Unexplained [d]: %s.", pct(6))
    ),
    Reading = "Adjusted R2 values are unbiased and can be slightly negative for fractions near zero; a negative shared fraction means the two sets suppress each other. Show the fractions as a Venn diagram (tidydiversity::plot_venn())."
  )
  tmr_interp(s, list(fractions = f))
}

# nolint end
