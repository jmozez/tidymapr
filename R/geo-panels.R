#' Multi-panel map layouts
#'
#' @description
#' Figures with more than one map, ready for a paper or report:
#'
#' * `geo_panels()` arranges maps (from [geo_map()], [geo_automap()] or any
#'   ggplot) in a grid with panel tags such as `(a)`, `(b)`. Legends that
#'   are the same in every panel are collected into one.
#' * `geo_facet_map()` draws small multiples: one map per group (year,
#'   season, species) with **one** classification shared by all panels, so
#'   a colour means the same value everywhere, one legend, and the scale
#'   bar and north arrow in the first panel only.
#' * `geo_inset()` places a small map (for example a locator of the study
#'   area) inside a corner of a larger one.
#'
#' All three need the patchwork package; the result is a patchwork object
#' that prints as one figure and saves with [geo_save()].
#'
#' @param ... Maps: `tmr_map` objects from [geo_map()] or ggplots.
#' @param ncol,nrow Grid size; by default as square as possible.
#' @param tags Panel tags: `"a"` (default), `"A"`, `"1"`, `"i"`, `"I"`, or
#'   `"none"`.
#' @param tag_prefix,tag_suffix Text around each tag; the default gives
#'   `(a)`, `(b)`, ...
#' @param guides `"collect"` merges legends that are the same in several
#'   panels into one; `"keep"` leaves a legend beside each panel.
#' @param legend_position Where collected legends go: `"right"` or
#'   `"bottom"`. Legends kept per panel stay at the right of their panel.
#' @param title,subtitle,caption Figure title, subtitle and caption.
#' @param widths,heights Relative widths of the columns and heights of the
#'   rows.
#' @param data An `sf` table.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Numeric
#'   column to map.
#' @param by <[`data-masking`][dplyr::dplyr_data_masking]> Column that
#'   splits the data into panels. Alternatively give several value columns
#'   in `value` with `c()`, one panel per column.
#' @param n,style Shared classification, passed to [geo_classify()].
#' @param palette Colour ramp: a name from [grDevices::hcl.pals()] or a
#'   vector of colours.
#' @param legend_title Legend title; defaults to the column name.
#' @param scale_bar,north_arrow Styles of the scale bar and north arrow,
#'   drawn in the first panel; `FALSE` to leave them out.
#' @param main,inset The large map and the small one.
#' @param location Where the inset goes: `"auto"` (default) picks a
#'   corner free of the scale bar, north arrow and any legend inside the
#'   map, and of those the one hiding the least of the mapped features;
#'   `"tr"`, `"tl"`, `"br"` or `"bl"` names a corner; or two numbers give
#'   the inset's lower-left corner anywhere on the map, as fractions of the
#'   map panel (for example `c(0.05, 0.6)`).
#' @param size Width and height of the inset as a fraction of the main map.
#' @return A patchwork object (`geo_panels()`, `geo_inset()`) or a ggplot
#'   (`geo_facet_map()`).
#' @name geo-panels
#' @seealso [geo_map()], [geo_automap()], [geo_save()].
#' @examplesIf rlang::is_installed(c("ggplot2", "patchwork", "sf"))
#' nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
#' nc$`1974-78` <- 1000 * nc$SID74 / nc$BIR74
#' nc$`1979-84` <- 1000 * nc$SID79 / nc$BIR79
#'
#' # Two periods, one classification, one legend
#' geo_facet_map(nc, c(`1974-78`, `1979-84`), n = 5,
#'   legend_title = "SIDS per 1000 births")
#'
#' # Any maps side by side, tagged (a) and (b)
#' a <- geo_automap(nc, `1974-78`)
#' b <- geo_automap(nc, BIR74, legend_title = "Births 1974-78")
#' geo_panels(a, b, ncol = 1, title = "North Carolina")
NULL

#' @rdname geo-panels
#' @export
geo_panels <- function(...,
                       ncol = NULL,
                       nrow = NULL,
                       tags = c("a", "A", "1", "i", "I", "none"),
                       tag_prefix = "(",
                       tag_suffix = ")",
                       guides = c("collect", "keep"),
                       legend_position = c("right", "bottom"),
                       title = NULL,
                       subtitle = NULL,
                       caption = NULL,
                       widths = NULL,
                       heights = NULL) {
  rlang::check_installed(c("ggplot2", "patchwork"))
  tags <- rlang::arg_match(tags)
  guides <- rlang::arg_match(guides)
  legend_position <- rlang::arg_match(legend_position)
  plots <- rlang::list2(...)
  if (length(plots) == 1 && is.list(plots[[1]]) && !inherits(plots[[1]], c("gg", "tmr_map"))) {
    plots <- plots[[1]]
  }
  if (!length(plots)) cli::cli_abort("Give at least one map.")
  plots <- lapply(seq_along(plots), function(i) tmr_as_ggplot(plots[[i]], i))
  out <- patchwork::wrap_plots(plots,
    ncol = ncol, nrow = nrow,
    widths = widths, heights = heights, guides = guides
  )
  out <- out + patchwork::plot_annotation(
    title = title, subtitle = subtitle, caption = caption,
    tag_levels = if (tags == "none") NULL else tags,
    tag_prefix = tag_prefix, tag_suffix = tag_suffix,
    theme = ggplot2::theme(
      plot.title = ggplot2::element_text(size = 15, face = "bold"),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
  )
  out <- out & ggplot2::theme(
    plot.tag = ggplot2::element_text(size = 12, face = "bold"),
    plot.background = ggplot2::element_rect(fill = "white", colour = NA)
  )
  # Collected legends go where asked; kept legends keep each map's own
  # setting (beside the panel, inside it, or none)
  if (guides == "collect") out <- out & ggplot2::theme(legend.position = legend_position)
  out
}

#' @rdname geo-panels
#' @export
geo_facet_map <- function(data,
                          value,
                          by = NULL,
                          ncol = NULL,
                          n = 5,
                          style = c("quantile", "jenks", "equal", "pretty", "sd"),
                          palette = "YlOrRd",
                          legend_title = NULL,
                          title = NULL,
                          scale_bar = "pill",
                          north_arrow = "needle") {
  rlang::check_installed(c("ggplot2", "sf"))
  style <- rlang::arg_match(style)
  if (!inherits(data, "sf")) cli::cli_abort("{.arg data} must be an {.cls sf} table.")
  vcols <- names(tidyselect::eval_select(rlang::enquo(value), sf::st_drop_geometry(data)))
  by_quo <- rlang::enquo(by)
  if (!length(vcols)) cli::cli_abort("{.arg value} must select at least one column.")
  if (rlang::quo_is_null(by_quo)) {
    if (length(vcols) < 2) {
      cli::cli_abort("Give {.arg by}, or several columns in {.arg value}.")
    }
    long <- do.call(rbind, lapply(vcols, function(v) {
      d <- data[, v]
      names(d)[1] <- ".value"
      d$.panel <- v
      d
    }))
    long$.panel <- factor(long$.panel, levels = vcols)
    vname <- legend_title %||% "value"
  } else {
    if (length(vcols) != 1) cli::cli_abort("With {.arg by}, {.arg value} must be one column.")
    bcol <- tmr_pick(by_quo, data, "by")
    long <- data[, c(vcols, bcol)]
    names(long)[1:2] <- c(".value", ".panel")
    long$.panel <- factor(long$.panel)
    vname <- legend_title %||% vcols
  }
  if (!is.numeric(long$.value)) cli::cli_abort("{.arg value} must be numeric.")
  # One classification over all panels, so colours compare across panels
  cls <- geo_classify(long, !!rlang::sym(".value"), n = n, style = style, name = ".class")
  levs <- levels(cls$.class)
  fills <- stats::setNames(tmr_ramp(palette, NULL, length(levs)), levs)
  first <- data.frame(.panel = factor(levels(long$.panel)[1], levels = levels(long$.panel)))
  p <- ggplot2::ggplot(cls) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data$.class), colour = "grey35", linewidth = 0.15) +
    ggplot2::scale_fill_manual(
      values = fills, drop = FALSE, na.value = "grey85", name = vname
    ) +
    ggplot2::facet_wrap(ggplot2::vars(.data$.panel), ncol = ncol) +
    ggplot2::labs(title = title, x = NULL, y = NULL) +
    theme_tidymapr(grid = "none", legend_position = "bottom") +
    ggplot2::theme(
      strip.text = ggplot2::element_text(face = "bold", size = 11, hjust = 0),
      strip.background = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey40", linewidth = 0.3)
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 1, title.position = "top"))
  sb <- tmr_furniture_style(scale_bar, "scale")
  na <- tmr_furniture_style(north_arrow, "north")
  if (!is.null(sb)) p <- p + annotation_scale_bar(style = sb, location = "bl", data = first)
  if (!is.null(na)) p <- p + annotation_north_arrow(style = na, location = "tr", data = first)
  attr(p, "classification") <- attr(cls, "classification")
  p
}

#' @rdname geo-panels
#' @export
geo_inset <- function(main,
                      inset,
                      location = "auto",
                      size = 0.3) {
  rlang::check_installed(c("ggplot2", "patchwork"))
  tmr_check_number(size, "size", 0.05, 0.8)
  main <- tmr_as_ggplot(main, 1)
  pad <- 0.02
  if (is.numeric(location)) {
    if (length(location) != 2 || any(location < 0 | location > 1 - size)) {
      cli::cli_abort(
        paste(
          "A numeric {.arg location} is the inset's lower-left corner,",
          "two numbers between 0 and {1 - size}."
        )
      )
    }
    x0 <- location[1]
    y0 <- location[2]
  } else {
    location <- rlang::arg_match(location, c("auto", "tr", "tl", "br", "bl"))
    if (location == "auto") location <- tmr_inset_corner(main, size, pad)
    x0 <- if (location %in% c("tr", "br")) 1 - size - pad else pad
    y0 <- if (location %in% c("tr", "tl")) 1 - size - pad else pad
  }
  inset <- tmr_as_ggplot(inset, 2) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = "grey30", linewidth = 0.5),
      axis.text = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(fill = NA, colour = NA),
      axis.ticks = ggplot2::element_blank(),
      legend.position = "none",
      plot.margin = ggplot2::margin(2, 2, 2, 2)
    )
  main + patchwork::inset_element(inset,
    left = x0, bottom = y0, right = x0 + size, top = y0 + size,
    align_to = "panel"
  )
}

# The best corner for an inset: not one holding the scale bar, north arrow
# or an inside legend, and of the rest the one covering the least of the
# mapped features
tmr_inset_corner <- function(p, size, pad) {
  corners <- c("bl", "br", "tl", "tr")
  taken <- tmr_taken_corners(p)
  free <- setdiff(corners, taken)
  if (!length(free)) {
    cli::cli_warn("Every corner holds map furniture; the inset goes bottom right.")
    return("br")
  }
  if (length(free) == 1) return(free)
  scores <- vapply(free, function(cn) tmr_corner_cover(p, cn, size, pad), numeric(1))
  free[which.min(scores)]
}

tmr_taken_corners <- function(p) {
  out <- character()
  for (l in p$layers) {
    loc <- l$geom_params$location %||% l$aes_params$location
    if (inherits(l$geom, c("GeomTmrScaleBar", "GeomTmrNorthArrow")) && !is.null(loc)) {
      out <- c(out, loc)
    }
  }
  th <- ggplot2::theme_get() + p$theme
  if (identical(th$legend.position, "inside")) {
    j <- th$legend.position.inside %||% th$legend.justification.inside %||% th$legend.justification
    if (is.numeric(j) && length(j) == 2) {
      out <- c(out, paste0(if (j[2] > 0.5) "t" else "b", if (j[1] > 0.5) "r" else "l"))
    }
  }
  unique(out)
}

# Share of the corner box covered by the plotted features (0 to 1)
tmr_corner_cover <- function(p, corner, size, pad) {
  b <- tryCatch(ggplot2::ggplot_build(p), error = function(e) NULL)
  if (is.null(b)) return(0)
  pp <- b$layout$panel_params[[1]]
  xr <- pp$x_range %||% pp$x.range
  yr <- pp$y_range %||% pp$y.range
  if (is.null(xr) || is.null(yr)) return(0)
  fx <- if (grepl("r", corner)) c(1 - size - pad, 1 - pad) else c(pad, pad + size)
  fy <- if (grepl("t", corner)) c(1 - size - pad, 1 - pad) else c(pad, pad + size)
  bx <- xr[1] + fx * diff(xr)
  by <- yr[1] + fy * diff(yr)
  box_area <- diff(bx) * diff(by)
  cover <- 0
  for (d in b$data) {
    if ("geometry" %in% names(d) && inherits(d$geometry, "sfc")) {
      g <- d$geometry
      box <- sf::st_as_sfc(sf::st_bbox(
        c(xmin = bx[1], ymin = by[1], xmax = bx[2], ymax = by[2]),
        crs = sf::st_crs(g)
      ))
      hit <- suppressWarnings(suppressMessages(
        sf::st_intersection(sf::st_make_valid(g), box)
      ))
      if (!length(hit)) next
      a <- suppressWarnings(sum(as.numeric(sf::st_area(hit[sf::st_dimension(hit) == 2]))))
      n_other <- sum(sf::st_dimension(hit) < 2, na.rm = TRUE)
      cover <- cover + a / box_area + 0.02 * n_other
    } else if (all(c("x", "y") %in% names(d)) && is.numeric(d$x) && nrow(d) > 0) {
      inb <- d$x >= bx[1] & d$x <= bx[2] & d$y >= by[1] & d$y <= by[2]
      cover <- cover + mean(inb) * 4
    }
  }
  cover
}

tmr_as_ggplot <- function(x, i, call = caller_env()) {
  if (inherits(x, "tmr_map")) return(map_build(x))
  if (inherits(x, "gg")) return(x)
  cli::cli_abort("Map {i} must be a ggplot or a map from {.fn geo_map}.", call = call)
}
