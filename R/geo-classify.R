#' Classify a numeric column into map classes
#'
#' @description
#' `geo_breaks()` returns class breaks for a numeric vector, and
#' `geo_classify()` adds the class of every row to a data frame, ready for a
#' choropleth or a bubble map. The styles follow tmap and classInt:
#'
#' * `"quantile"`: equal numbers of observations per class;
#' * `"equal"`: equal-width classes over the range;
#' * `"jenks"`: Fisher-Jenks natural breaks, which minimise the
#'   within-class sum of squares exactly (Fisher 1958; computed in C++).
#'   The breaks equal classInt's `"jenks"` style; classInt's `"fisher"`
#'   style gives the same classes with breaks halfway between neighbouring
#'   values;
#' * `"pretty"`: rounded breaks from [base::pretty()];
#' * `"sd"`: breaks at the mean plus or minus whole standard deviations;
#' * `"fixed"`: the `breaks` you give.
#'
#' Like GeoSpaX's AutoMap, `geo_classify()` explains its choice: the result
#' carries the breaks, the number of rows in each class and the goodness of
#' variance fit (GVF, 1 = classes explain all variance) in attribute
#' `"classification"`.
#'
#' @param x A numeric vector.
#' @param data A data frame or `sf` table.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Numeric
#'   column to classify.
#' @param n Number of classes.
#' @param style Classification style (see Description).
#' @param breaks For `style = "fixed"`, the full vector of breaks,
#'   including the minimum and maximum.
#' @param digits Significant digits used in class labels.
#' @param name Name of the new class column (default `"<value>_class"`).
#' @return `geo_breaks()` returns the sorted breaks (`n + 1` values,
#'   minimum to maximum). `geo_classify()` returns `data` with an ordered
#'   factor column of class labels such as `"10 - 20"`.
#' @references Fisher, W. D. (1958). On grouping for maximum homogeneity.
#'   *Journal of the American Statistical Association*, 53, 789-798.
#'   \doi{10.1080/01621459.1958.10501479}
#'
#'   Jenks, G. F. (1977). *Optimal data classification for choropleth
#'   maps*. Occasional paper 2, Department of Geography, University of
#'   Kansas.
#' @export
#' @examples
#' set.seed(1)
#' x <- c(rnorm(20, 10), rnorm(20, 30), rnorm(20, 60))
#' geo_breaks(x, n = 3, style = "jenks")
#'
#' sites <- geo_example_sites()
#' geo_classify(sites, elevation, n = 3, style = "equal")
geo_breaks <- function(x,
                       n = 5,
                       style = c("quantile", "equal", "jenks", "pretty",
                                 "sd", "fixed"),
                       breaks = NULL) {
  style <- rlang::arg_match(style)
  if (!is.numeric(x)) {
    cli::cli_abort("{.arg x} must be numeric.")
  }
  x <- x[is.finite(x)]
  if (length(x) == 0) {
    cli::cli_abort("{.arg x} has no finite values.")
  }
  tmr_check_number(n, "n", 1, whole = TRUE)
  rng <- range(x)
  out <- switch(style,
    quantile = unique(stats::quantile(x, seq(0, 1, length.out = n + 1),
      names = FALSE, type = 7
    )),
    equal = seq(rng[1], rng[2], length.out = n + 1),
    jenks = {
      ux <- sort(x)
      if (length(unique(ux)) <= n) {
        sort(unique(ux))
      } else {
        c(rng[1], geo_jenks_cpp(ux, as.integer(n)), rng[2])
      }
    },
    pretty = pretty(x, n = n),
    sd = {
      m <- mean(x)
      s <- stats::sd(x)
      k <- ceiling(max(abs(rng - m)) / s)
      b <- m + s * seq(-k, k)
      b[b >= rng[1] - s & b <= rng[2] + s]
    },
    fixed = {
      if (is.null(breaks) || !is.numeric(breaks) || length(breaks) < 2) {
        cli::cli_abort(
          "{.arg breaks} must give at least two numbers for {.code style = \"fixed\"}."
        )
      }
      sort(unique(breaks))
    }
  )
  if (style %in% c("pretty", "sd")) {
    out[1] <- min(out[1], rng[1])
    out[length(out)] <- max(out[length(out)], rng[2])
  }
  sort(unique(out))
}

#' @rdname geo_breaks
#' @export
geo_classify <- function(data,
                         value,
                         n = 5,
                         style = c("quantile", "equal", "jenks", "pretty",
                                   "sd", "fixed"),
                         breaks = NULL,
                         digits = 3,
                         name = NULL) {
  style <- rlang::arg_match(style)
  tmr_check_data(data)
  col <- tmr_pick(enquo(value), data, "value")
  x <- data[[col]]
  if (!is.numeric(x)) {
    cli::cli_abort("{.arg value} must be a numeric column.")
  }
  brk <- geo_breaks(x, n = n, style = style, breaks = breaks)
  lab <- geo_class_labels(brk, digits)
  cls <- cut(x, brk, labels = lab, include.lowest = TRUE, ordered_result = TRUE)
  name <- name %||% paste0(col, "_class")
  data[[name]] <- cls
  # Goodness of variance fit: 1 - SDCM / SDAM (Jenks 1977)
  ok <- !is.na(cls)
  sdam <- sum((x[ok] - mean(x[ok]))^2)
  sdcm <- sum(tapply(x[ok], cls[ok], function(v) sum((v - mean(v))^2)),
    na.rm = TRUE
  )
  attr(data, "classification") <- list(
    value = col, style = style, breaks = brk,
    counts = as.vector(table(cls)),
    gvf = if (sdam > 0) 1 - sdcm / sdam else 1
  )
  data
}

geo_class_labels <- function(brk, digits = 3) {
  f <- format(signif(brk, digits), trim = TRUE, scientific = FALSE,
    drop0trailing = TRUE
  )
  paste(utils::head(f, -1), "-", utils::tail(f, -1))
}
