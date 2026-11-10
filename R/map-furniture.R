#' Scale bars, north arrows and legends in GeoSpaX styles
#'
#' @description
#' Map furniture you can add to any ggplot map drawn with
#' [ggplot2::coord_sf()] (every tidymapr map uses it), in the same styles as
#' the GeoSpaX desktop app:
#'
#' * `annotation_scale_bar()`: a scale bar whose length is measured on the
#'   ground (great-circle metres across the panel) when the map is drawn, so
#'   it is right for longitude/latitude and projected maps and in every
#'   facet. Styles: `"pill"` (default; rounded bar, half dark), `"checker"`
#'   (alternating blocks), `"line"` (a bracket with the distance above) and
#'   `"ruler"` (ticks at 0, 1/4, 1/2, 3/4 and 1). Units: `"metric"`,
#'   `"imperial"` or `"both"` (a second bar in miles).
#' * `annotation_north_arrow()`: styles `"needle"` (default; two-tone needle
#'   in a ring), `"compass"`, `"rose"` (eight-point compass rose) and
#'   `"minimal"`.
#' * `map_legend()`: puts the legend `"right"` (default), `"bottom"`,
#'   `"inside"` a corner of the map, or removes it (`"none"`), and
#'   customises it as in GeoSpaX: title, renamed entries (`labels`), hidden
#'   legends (`hide`), frame, text, title and key sizes, columns, direction
#'   and reversed order.
#'
#' [plot_sites()], [plot_geo()], [plot_choropleth()] and [plot_bubble()]
#' take the same style names through their `scale_bar`, `north_arrow` and
#' legend arguments.
#'
#' @param style Furniture style (see Description).
#' @param location Corner: `"bl"` (bottom left), `"br"`, `"tl"` or `"tr"`.
#' @param units Scale bar units: `"metric"`, `"imperial"` or `"both"`.
#' @param length Optional fixed bar length, in metres (or miles when
#'   `units = "imperial"`). When `NULL`, a round length of about a fifth of
#'   the map width.
#' @param size North arrow size in millimetres.
#' @param pad Distance from the panel edge, in millimetres.
#' @param text_size Text size in points: scale bar labels, or legend
#'   entries in `map_legend()`.
#' @param data Optional one-row data frame holding facet columns, to draw
#'   the furniture in one facet only.
#' @return A ggplot2 layer (`annotation_*()`) or legend settings
#'   (`map_legend()`) to add to a plot with `+`.
#' @name map-furniture
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' library(ggplot2)
#' # North Carolina counties (real data shipped with sf)
#' nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
#' base <- ggplot(nc) + geom_sf(aes(fill = AREA)) + theme_tidymapr(grid = "none")
#' base +
#'   annotation_scale_bar(style = "checker", location = "bl") +
#'   annotation_north_arrow(style = "rose", location = "tr") +
#'   map_legend("bottom", title = "Area")
#'
#' # Customised legend: renamed entries, two columns, larger keys
#' nc$size_class <- cut(nc$AREA, c(0, 0.08, 0.15, 0.25),
#'   labels = c("small", "medium", "large")
#' )
#' ggplot(nc) +
#'   geom_sf(aes(fill = size_class)) +
#'   theme_tidymapr(grid = "none") +
#'   map_legend("inside",
#'     corner = "bl", title = "County size",
#'     labels = c(small = "Small (< 0.08)", large = "Large (> 0.15)"),
#'     ncol = 1, key_size = 6, text_size = 9
#'   )
#'
#' # Every style at once
#' base +
#'   annotation_scale_bar(style = "pill", location = "bl", units = "both") +
#'   annotation_scale_bar(style = "ruler", location = "br") +
#'   annotation_north_arrow(style = "needle", location = "tl") +
#'   annotation_north_arrow(style = "compass", location = "tr") +
#'   map_legend("none")
NULL

tmr_ink <- "#2f3b46"

#' @rdname map-furniture
#' @export
annotation_scale_bar <- function(style = c("pill", "checker", "line", "ruler"),
                                 location = c("bl", "br", "tl", "tr"),
                                 units = c("metric", "imperial", "both"),
                                 length = NULL,
                                 pad = 3,
                                 text_size = 8,
                                 data = NULL) {
  rlang::check_installed(c("ggplot2", "sf"))
  style <- rlang::arg_match(style)
  location <- rlang::arg_match(location)
  units <- rlang::arg_match(units)
  if (!is.null(length)) tmr_check_number(length, "length", 0)
  ggplot2::layer(
    geom = GeomTmrScaleBar, stat = "identity", position = "identity",
    data = data %||% data.frame(.tmr = 1), mapping = NULL,
    inherit.aes = FALSE, show.legend = FALSE,
    params = list(
      style = style, location = location, units = units,
      bar_length = length, pad = pad, text_size = text_size
    )
  )
}

#' @rdname map-furniture
#' @export
annotation_north_arrow <- function(style = c("needle", "compass", "rose", "minimal"),
                                   location = c("tr", "tl", "br", "bl"),
                                   size = 16,
                                   pad = 3,
                                   data = NULL) {
  rlang::check_installed("ggplot2")
  style <- rlang::arg_match(style)
  location <- rlang::arg_match(location)
  tmr_check_number(size, "size", 0)
  ggplot2::layer(
    geom = GeomTmrNorthArrow, stat = "identity", position = "identity",
    data = data %||% data.frame(.tmr = 1), mapping = NULL,
    inherit.aes = FALSE, show.legend = FALSE,
    params = list(style = style, location = location, size = size, pad = pad)
  )
}

#' @rdname map-furniture
#' @param position Legend position: `"right"`, `"bottom"`, `"inside"` or
#'   `"none"`.
#' @param corner For `position = "inside"`, the corner (`"tr"`, `"tl"`,
#'   `"br"` or `"bl"`).
#' @param title Legend title. `NULL` keeps the titles the plot already has.
#' @param labels Rename legend entries: a named character vector,
#'   `c(old = "new")`, applied to every discrete legend (colour, fill,
#'   shape) that shows those entries.
#' @param hide Aesthetics whose legend to hide, for example `"size"`.
#' @param frame Draw a white box with a thin border around the legend?
#' @param title_size Legend title size in points.
#' @param key_size Size of the legend keys in millimetres.
#' @param ncol Number of columns of legend entries.
#' @param direction `"vertical"` or `"horizontal"`; by default horizontal at
#'   the bottom and vertical elsewhere.
#' @param reverse Reverse the order of legend entries?
#' @export
map_legend <- function(position = c("right", "bottom", "inside", "none"),
                       corner = c("tr", "tl", "br", "bl"),
                       title = NULL,
                       labels = NULL,
                       hide = NULL,
                       frame = TRUE,
                       text_size = NULL,
                       title_size = NULL,
                       key_size = NULL,
                       ncol = NULL,
                       direction = NULL,
                       reverse = FALSE) {
  rlang::check_installed("ggplot2")
  position <- rlang::arg_match(position)
  corner <- rlang::arg_match(corner)
  if (!is.null(labels) && (!is.character(labels) || is.null(names(labels)))) {
    cli::cli_abort("{.arg labels} must be a named character vector, {.code c(old = \"new\")}.")
  }
  if (!is.null(direction)) direction <- rlang::arg_match(direction, c("vertical", "horizontal"))
  box <- if (isTRUE(frame)) {
    ggplot2::element_rect(fill = "white", colour = "grey30", linewidth = 0.3)
  } else {
    ggplot2::element_blank()
  }
  th <- switch(position,
    none = ggplot2::theme(legend.position = "none"),
    right = ggplot2::theme(legend.position = "right", legend.background = box),
    bottom = ggplot2::theme(
      legend.position = "bottom",
      legend.direction = direction %||% "horizontal",
      legend.background = box
    ),
    inside = {
      xy <- c(
        if (substr(corner, 2, 2) == "l") 0.02 else 0.98,
        if (substr(corner, 1, 1) == "b") 0.02 else 0.98
      )
      ggplot2::theme(
        legend.position = "inside", legend.position.inside = xy,
        legend.justification = xy, legend.background = box
      )
    }
  )
  extra <- list()
  if (!is.null(direction) && position != "bottom") extra$legend.direction <- direction
  if (!is.null(text_size)) extra$legend.text <- ggplot2::element_text(size = text_size)
  if (!is.null(title_size)) {
    extra$legend.title <- ggplot2::element_text(size = title_size, face = "bold")
  }
  if (!is.null(key_size)) extra$legend.key.size <- grid::unit(key_size, "mm")
  if (length(extra)) th <- th + do.call(ggplot2::theme, extra)
  structure(
    list(
      theme = th, title = title, labels = labels, hide = hide,
      ncol = ncol, reverse = isTRUE(reverse)
    ),
    class = "tmr_map_legend"
  )
}

#' @exportS3Method ggplot2::ggplot_add
ggplot_add.tmr_map_legend <- function(object, plot, object_name) { # nolint: object_name_linter.
  plot <- plot + object$theme
  aes_all <- c("colour", "fill", "shape", "size", "linetype", "alpha")
  if (!is.null(object$title)) {
    # Only retitle aesthetics the plot actually maps
    mapped <- unique(c(
      names(plot$mapping),
      unlist(lapply(plot$layers, function(l) names(l$mapping)))
    ))
    use <- intersect(aes_all, mapped)
    if (length(use)) {
      plot <- plot + do.call(ggplot2::labs, stats::setNames(
        rep(list(object$title), length(use)), use
      ))
    }
  }
  if (!is.null(object$labels)) {
    recode <- object$labels
    for (sc in plot$scales$scales) {
      if (inherits(sc, "ScaleDiscrete")) {
        old <- sc$labels
        sc$labels <- function(breaks) {
          base <- if (is.function(old)) {
            old(breaks)
          } else if (inherits(old, "waiver")) {
            breaks
          } else {
            old
          }
          base <- as.character(base)
          hit <- breaks %in% names(recode)
          base[hit] <- recode[as.character(breaks[hit])]
          base
        }
      }
    }
    # Aesthetics without a scale yet get a default discrete one with labels
    present <- unlist(lapply(plot$scales$scales, function(sc) sc$aesthetics))
    lab_fun <- function(breaks) {
      out <- as.character(breaks)
      hit <- out %in% names(recode)
      out[hit] <- recode[out[hit]]
      out
    }
    for (a in c("colour", "fill", "shape")) {
      mapped <- a %in% names(plot$mapping) ||
        any(vapply(plot$layers, function(l) a %in% names(l$mapping), logical(1)))
      if (mapped && !a %in% present) {
        f <- switch(a,
          colour = ggplot2::scale_colour_discrete,
          fill = ggplot2::scale_fill_discrete,
          shape = ggplot2::scale_shape_discrete
        )
        plot <- plot + f(labels = lab_fun)
      }
    }
  }
  if (!is.null(object$ncol) || isTRUE(object$reverse)) {
    for (a in c("colour", "fill", "shape")) {
      plot <- plot + do.call(ggplot2::guides, stats::setNames(list(
        ggplot2::guide_legend(ncol = object$ncol, reverse = object$reverse)
      ), a))
    }
  }
  if (length(object$hide)) {
    plot <- plot + do.call(ggplot2::guides, stats::setNames(
      rep(list("none"), length(object$hide)), object$hide
    ))
  }
  plot
}

# ------------------------------------------------------------------ scale bar

# nolint next: object_name_linter.
GeomTmrScaleBar <- ggplot2::ggproto("GeomTmrScaleBar", ggplot2::Geom,
  required_aes = character(),
  default_aes = ggplot2::aes(),
  draw_key = ggplot2::draw_key_blank,
  draw_panel = function(data, panel_params, coord, style = "pill",
                        location = "bl", units = "metric", bar_length = NULL,
                        pad = 3, text_size = 8) {
    m_npc <- tmr_metres_per_npc(panel_params, location)
    if (!is.finite(m_npc) || m_npc <= 0) {
      return(ggplot2::zeroGrob())
    }
    tmr_scale_bar_grob(
      m_npc, style = style, location = location, units = units,
      bar_length = bar_length, pad = pad, text_size = text_size
    )
  }
)

# Ground distance (metres) spanned by the full panel width, measured along
# the row where the bar sits
tmr_metres_per_npc <- function(panel_params, location) {
  xr <- panel_params$x_range %||% panel_params$x.range
  yr <- panel_params$y_range %||% panel_params$y.range
  if (is.null(xr) || is.null(yr)) {
    return(NA_real_)
  }
  y <- if (substr(location, 1, 1) == "b") yr[1] + 0.08 * diff(yr) else yr[2] - 0.08 * diff(yr)
  crs <- panel_params$crs
  pts <- sf::st_sfc(sf::st_point(c(xr[1], y)), sf::st_point(c(xr[2], y)),
    crs = if (is.null(crs)) 4326 else crs
  )
  ll <- tryCatch(sf::st_coordinates(sf::st_transform(pts, 4326)),
    error = function(e) NULL
  )
  if (is.null(ll)) {
    return(NA_real_)
  }
  geo_haversine_pair_cpp(ll[1, 1], ll[1, 2], ll[2, 1], ll[2, 2])
}

tmr_nice_floor <- function(x) {
  p <- 10^floor(log10(x))
  m <- x / p
  p * if (m >= 5) 5 else if (m >= 2) 2 else 1
}

tmr_fmt_metric <- function(m) {
  num <- function(v) format(v, trim = TRUE, drop0trailing = TRUE, big.mark = ",")
  if (m >= 1000) paste(num(m / 1000), "km") else paste(num(m), "m")
}

tmr_fmt_imperial <- function(m) {
  mi <- m / 1609.344
  if (mi >= 1) {
    paste(format(round(mi, 2), trim = TRUE, drop0trailing = TRUE), "mi")
  } else {
    paste(format(round(m / 0.3048), trim = TRUE, big.mark = ","), "ft")
  }
}

tmr_nice_imperial <- function(target_m) {
  mi <- target_m / 1609.344
  if (mi >= 1) {
    tmr_nice_floor(mi) * 1609.344
  } else {
    tmr_nice_floor(target_m / 0.3048) * 0.3048
  }
}

tmr_scale_bar_grob <- function(m_npc, style, location, units, bar_length,
                               pad, text_size) {
  imperial <- units == "imperial"
  target <- 0.2 * m_npc
  d <- if (!is.null(bar_length)) {
    if (imperial) bar_length * 1609.344 else bar_length
  } else if (imperial) {
    tmr_nice_imperial(target)
  } else {
    tmr_nice_floor(target)
  }
  fmt <- if (imperial) tmr_fmt_imperial else tmr_fmt_metric
  len <- d / m_npc # bar length in npc
  left <- substr(location, 2, 2) == "l"
  bottom <- substr(location, 1, 1) == "b"
  u <- function(x) grid::unit(x, "mm")
  # Box layout (mm): bar 2.5 mm high with labels above; extra row for "both"
  box_h <- if (units == "both") 15 else 10
  side <- 6
  gp_txt <- grid::gpar(fontsize = text_size, col = tmr_ink)
  x0 <- if (left) {
    grid::unit(0, "npc") + u(pad + side)
  } else {
    grid::unit(1 - len, "npc") - u(pad + side)
  }
  y_base <- if (bottom) {
    u(pad + if (units == "both") 8 else 3)
  } else {
    grid::unit(1, "npc") - u(pad + 7)
  }
  bar_h <- u(2.5)
  xs <- function(f) x0 + grid::unit(len * f, "npc")
  box <- grid::roundrectGrob(
    x = x0 - u(side), y = y_base - u(if (units == "both") 8 else 3),
    width = grid::unit(len, "npc") + u(2 * side), height = u(box_h),
    just = c("left", "bottom"),
    r = if (style == "pill") grid::unit(0.5, "snpc") else u(1),
    gp = grid::gpar(fill = "white", alpha = 0.88, col = NA)
  )
  # On a short bar the middle label would collide with its neighbours
  short <- len < 0.22
  lab <- function(f, txt, bold = FALSE) {
    if (short && isTRUE(all.equal(f, 0.5))) return(grid::nullGrob())
    grid::textGrob(txt,
      x = xs(f), y = y_base + bar_h + u(1.2), just = c("centre", "bottom"),
      gp = grid::gpar(
        fontsize = text_size, col = tmr_ink,
        fontface = if (bold) "bold" else "plain"
      )
    )
  }
  rect <- function(f0, f1, fill) {
    grid::rectGrob(
      x = xs(f0), y = y_base, width = grid::unit(len * (f1 - f0), "npc"),
      height = bar_h, just = c("left", "bottom"),
      gp = grid::gpar(fill = fill, col = tmr_ink, lwd = 0.8)
    )
  }
  parts <- switch(style,
    line = list(
      grid::polylineGrob(
        x = grid::unit.c(xs(0), xs(0), xs(1), xs(1)),
        y = grid::unit.c(y_base + bar_h, y_base, y_base, y_base + bar_h),
        gp = grid::gpar(col = tmr_ink, lwd = 1.4)
      ),
      lab(0.5, fmt(d))
    ),
    ruler = c(
      list(grid::segmentsGrob(
        x0 = xs(0), x1 = xs(1), y0 = y_base, y1 = y_base,
        gp = grid::gpar(col = tmr_ink, lwd = 1.2)
      )),
      lapply(0:4, function(k) {
        grid::segmentsGrob(
          x0 = xs(k / 4), x1 = xs(k / 4), y0 = y_base,
          y1 = y_base + if (k %% 2 == 0) bar_h else bar_h * 0.55,
          gp = grid::gpar(col = tmr_ink, lwd = 1.1)
        )
      }),
      list(lab(0, "0"), lab(0.5, fmt(d / 2)), lab(1, fmt(d)))
    ),
    checker = c(
      lapply(0:3, function(k) {
        rect(k / 4, (k + 1) / 4, if (k %% 2 == 0) tmr_ink else "white")
      }),
      list(lab(0, "0"), lab(0.5, fmt(d / 2)), lab(1, fmt(d)))
    ),
    pill = list(
      grid::roundrectGrob(
        x = xs(0), y = y_base, width = grid::unit(len, "npc"), height = bar_h,
        just = c("left", "bottom"), r = grid::unit(0.5, "snpc"),
        gp = grid::gpar(fill = "white", col = tmr_ink, lwd = 1)
      ),
      grid::roundrectGrob(
        x = xs(0), y = y_base, width = grid::unit(len / 2, "npc"), height = bar_h,
        just = c("left", "bottom"), r = grid::unit(0.5, "snpc"),
        gp = grid::gpar(fill = tmr_ink, col = tmr_ink, lwd = 1)
      ),
      lab(0, "0"), lab(0.5, fmt(d / 2)), lab(1, fmt(d), bold = TRUE)
    )
  )
  if (units == "both") {
    di <- tmr_nice_imperial(target)
    li <- di / m_npc
    yy <- y_base - u(5)
    xi <- function(f) x0 + grid::unit(li * f, "npc")
    parts <- c(parts, list(
      grid::polylineGrob(
        x = grid::unit.c(xi(0), xi(0), xi(1), xi(1)),
        y = grid::unit.c(yy + u(2), yy, yy, yy + u(2)),
        gp = grid::gpar(col = tmr_ink, lwd = 1.2)
      ),
      grid::textGrob(tmr_fmt_imperial(di),
        x = xi(1) + u(1.5), y = yy, just = c("left", "bottom"), gp = gp_txt
      )
    ))
  }
  grid::gTree(children = do.call(grid::gList, c(list(box), parts)))
}

# ------------------------------------------------------------------ north arrow

# nolint next: object_name_linter.
GeomTmrNorthArrow <- ggplot2::ggproto("GeomTmrNorthArrow", ggplot2::Geom,
  required_aes = character(),
  default_aes = ggplot2::aes(),
  draw_key = ggplot2::draw_key_blank,
  draw_panel = function(data, panel_params, coord, style = "needle",
                        location = "tr", size = 16, pad = 3) {
    tmr_north_arrow_grob(style, location, size, pad)
  }
)

# Shapes are drawn on a -32..32 square (y up), matching GeoSpaX's SVG
tmr_north_arrow_grob <- function(style, location, size, pad) {
  left <- substr(location, 2, 2) == "l"
  bottom <- substr(location, 1, 1) == "b"
  u <- function(x) grid::unit(x, "mm")
  vp <- grid::viewport(
    x = if (left) u(pad) else grid::unit(1, "npc") - u(pad),
    y = if (bottom) u(pad) else grid::unit(1, "npc") - u(pad),
    width = u(size), height = u(size),
    just = c(if (left) "left" else "right", if (bottom) "bottom" else "top"),
    xscale = c(-34, 34), yscale = c(-32, 36)
  )
  nat <- function(v) grid::unit(v, "native")
  poly <- function(x, y, fill, col = NA, lwd = 0.8) {
    grid::polygonGrob(nat(x), nat(y), gp = grid::gpar(fill = fill, col = col, lwd = lwd))
  }
  circ <- function(r, fill = "white", col = NA, lwd = 0.8, alpha = 0.88) {
    grid::circleGrob(nat(0), nat(0), grid::unit(r / 68, "snpc"),
      gp = grid::gpar(fill = fill, col = col, lwd = lwd, alpha = alpha)
    )
  }
  n_label <- function(y, fs = 9) {
    grid::textGrob("N", nat(0), nat(y),
      gp = grid::gpar(fontsize = fs, fontface = "bold", col = tmr_ink)
    )
  }
  rot <- function(x, y, deg) {
    a <- deg * pi / 180
    list(x = x * cos(a) + y * sin(a), y = -x * sin(a) + y * cos(a))
  }
  parts <- switch(style,
    compass = list(
      circ(24, col = tmr_ink, alpha = 0.85),
      poly(c(0, 8, 0), c(17, -9, -4), tmr_ink),
      poly(c(0, -8, 0), c(17, -9, -4), "white", col = tmr_ink),
      n_label(27)
    ),
    rose = c(
      list(circ(25, alpha = 0.85)),
      unlist(lapply(0:7, function(k) {
        r <- if (k %% 2 == 0) 24 else 14
        w <- if (k %% 2 == 0) 6 else 4
        right <- rot(c(0, w, 0), c(r, 0, 0), k * 45)
        leftp <- rot(c(0, -w, 0), c(r, 0, 0), k * 45)
        list(
          poly(right$x, right$y, if (k == 0) "#c0392b" else tmr_ink),
          poly(leftp$x, leftp$y, "white", col = tmr_ink, lwd = 0.6)
        )
      }), recursive = FALSE),
      list(n_label(29))
    ),
    minimal = list(
      grid::polylineGrob(nat(c(0, 0)), nat(c(-14, 22)),
        gp = grid::gpar(col = tmr_ink, lwd = 2, lineend = "round")
      ),
      grid::polylineGrob(nat(c(-7, 0, 7)), nat(c(12, 22, 12)),
        gp = grid::gpar(col = tmr_ink, lwd = 2, lineend = "round", linejoin = "round")
      ),
      n_label(28, 10)
    ),
    needle = {
      # Ring with a gap at the top for the N
      a <- seq(110, 430, length.out = 120) * pi / 180
      list(
        circ(19, alpha = 0.88),
        grid::polylineGrob(nat(19 * cos(a)), nat(19 * sin(a)),
          gp = grid::gpar(col = tmr_ink, lwd = 1.2)
        ),
        poly(c(0, 5, 0), c(26, 0, -3), "#c0392b"),
        poly(c(0, -5, 0), c(26, 0, -3), "#e06150"),
        poly(c(0, 5, 0), c(-22, 0, 3), tmr_ink),
        poly(c(0, -5, 0), c(-22, 0, 3), "#56636e"),
        grid::circleGrob(nat(0), nat(0), grid::unit(2.2 / 68, "snpc"),
          gp = grid::gpar(fill = "white", col = tmr_ink, lwd = 0.8)
        ),
        n_label(31)
      )
    }
  )
  grid::gTree(children = do.call(grid::gList, parts), vp = vp)
}

# TRUE -> default style, FALSE/NULL/"none" -> NULL, a style name -> itself
tmr_furniture_style <- function(x, kind = c("scale", "north"), call = caller_env()) {
  kind <- match.arg(kind)
  styles <- if (kind == "scale") {
    c("pill", "checker", "line", "ruler")
  } else {
    c("needle", "compass", "rose", "minimal")
  }
  arg <- if (kind == "scale") "scale_bar" else "north_arrow"
  if (is.null(x) || isFALSE(x) || identical(x, "none")) return(NULL)
  if (isTRUE(x)) return(styles[1])
  if (is.character(x) && length(x) == 1 && x %in% styles) return(x)
  cli::cli_abort(
    "{.arg {arg}} must be TRUE, FALSE or one of {.val {styles}}.",
    call = call
  )
}

tmr_facet_first <- function(data, facet) {
  if (is.null(facet) || !facet %in% names(data)) return(NULL)
  out <- data.frame(vctrs::vec_slice(sf::st_drop_geometry(data), 1L)[[facet]])
  names(out) <- facet
  out
}
