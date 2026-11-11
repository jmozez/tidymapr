#' Layered maps, built one layer at a time
#'
#' @description
#' A map in the style of a desktop GIS layout: a stack of layers, each with
#' its own legend section and the right symbol for its geometry. Start with
#' `geo_map()`, add layers with the pipe, and print (or [geo_save()]) the
#' result:
#'
#' * `map_raster()` draws a continuous surface (elevation, rainfall, a
#'   diversity surface) with a gradient legend, optionally over a hillshade.
#' * `map_polygons()`, `map_lines()` and `map_points()` draw `sf` features.
#'   Give `fill` or `colour` a column name to colour features by a category
#'   or a classed number, or a colour for one plain symbol. Either way the
#'   layer gets its own legend section: polygon swatches, line keys or point
#'   symbols.
#' * `map_labels()` writes feature names with a white halo, so they stay
#'   readable over any background.
#' * `map_curved_labels()` writes text that follows the shape of any
#'   feature: along lines (roads, rivers, contours), along the long axis or
#'   the outline of polygons (lakes, valleys, regions), or around an arc
#'   above points. The text stays upright and labels longer than their path
#'   are left out. `map_line_labels()` is the same for lines.
#'   `map_contours()` draws contour lines of a raster with their
#'   heights written along them, set straight and aligned with the line
#'   as on topographic maps.
#' * `map_zoom()` zooms in or out, on the centre or on a point, or shows an
#'   exact extent; the scale bar follows.
#'
#' Layers are drawn in the order they are added (the first at the bottom).
#' The legend lists them the other way round, top layer first, as in GeoSpaX,
#' QGIS and ArcGIS layouts. Everything is projected to one coordinate
#' reference system, chosen from the first layer unless you give `crs`.
#'
#' @param title,subtitle,caption Map title, subtitle and caption (for
#'   example the data source).
#' @param crs Coordinate reference system of the map: `"auto"` (the first
#'   layer's, or UTM when that is longitude/latitude), an EPSG code, an
#'   [sf::st_crs()] object, or a projection name understood by [geo_crs()]
#'   such as `"equal_earth"` or `"laea"`.
#' @param scale_bar,north_arrow Style of the scale bar and north arrow (see
#'   [annotation_scale_bar()] and [annotation_north_arrow()]); `FALSE` to
#'   leave them out.
#' @param graticule Draw a labelled graticule? Default `FALSE`: coordinates
#'   appear on the axes.
#' @param legend Legend position: `"right"`, `"bottom"`, `"inside"` (in a
#'   framed box on the map) or `"none"`.
#' @param legend_corner For `legend = "inside"`, the corner: `"auto"`
#'   (default) picks one free of the scale bar and north arrow that hides
#'   the least of the mapped features, or `"tr"`, `"tl"`, `"br"`, `"bl"`.
#' @param map A map started with `geo_map()`.
#' @param ... For `map_line_labels()`, arguments passed to
#'   `map_curved_labels()`.
#' @param x For `map_raster()`, a `SpatRaster` (the first layer is drawn).
#' @param data An `sf` table.
#' @param fill,colour A column name (quoted or not) to colour features by,
#'   or a single colour.
#' @param label Legend entry for a layer drawn in one colour, for example
#'   `"Highways"`. Defaults to the name of `data`.
#' @param group Legend section heading. Defaults to the column name for
#'   coloured layers, and to no heading for one-colour layers.
#' @param palette Colours for a column: `"auto"`, a name from
#'   [grDevices::hcl.pals()], or a vector of colours. For categories,
#'   `"auto"` gives Okabe-Ito colours; for numbers, a sequential ramp.
#' @param n,style For numeric columns, the number of classes and the
#'   classification style, passed to [geo_classify()].
#' @param border,linewidth,linetype,alpha Outline colour, line width (mm),
#'   line type and transparency.
#' @param name Legend title of a raster.
#' @param limits For `map_raster()`, the range of the colour scale, such as
#'   `c(0, 1)` for probabilities. Give the same limits to rasters in
#'   several panels so that one colour means one value and
#'   [geo_panels()] can merge their legends into one.
#' @param hillshade Draw the raster over its own hillshade? Useful for
#'   elevation.
#' @param shape,size Point symbol (a number from [graphics::points()]) and
#'   size.
#' @param text Column with the label text.
#' @param halo Draw a white halo behind the labels?
#' @param draw_line For curved labels, also draw the path (cut where the
#'   text sits)? Default `TRUE` for lines and `FALSE` otherwise; with
#'   `FALSE` the text sits just above the path.
#' @param polygon For polygons, write along the shape's long `"axis"`
#'   (bent with the shape) or along its `"outline"`, just inside the edge.
#' @param radius For points, radius of the label arc in map units; by
#'   default 3.5% of the map width. Point labels are always drawn.
#' @param smooth Rounds of corner smoothing of the label path, so text
#'   reads evenly along jagged lines (0 for none).
#' @param linewidth_label Width of the lines drawn by `map_line_labels()`.
#' @param position Where along each line the label sits, from 0 (start) to
#'   1 (end); default the middle.
#' @param interval,breaks Contour spacing in the raster's units, or the
#'   exact contour levels. By default about eight levels at round numbers.
#' @param label_every Label every nth contour (default every second one,
#'   as on topographic maps).
#' @param preset A standard cartographic symbol by name, such as
#'   `"water"`, `"forest"`, `"protected_area"` (polygons), `"river"`,
#'   `"road_major"`, `"railway"`, `"boundary"` (lines) or `"town"`,
#'   `"peak"`, `"sample_site"` (points); see [map_presets()]. Arguments you
#'   give yourself override the preset.
#' @param fontface Font face of the labels, for example `"italic"` for
#'   rivers or `"bold"` for towns.
#' @param zoom Zoom factor for `map_zoom()`: 2 shows half the width and
#'   height (closer), 0.5 shows twice as much around the data.
#' @param centre Point to zoom on, `c(longitude, latitude)`; by default
#'   the centre of the extent.
#' @param extent Area to show: an `sf` object, a bbox, a terra object, or
#'   `c(xmin, ymin, xmax, ymax)` in degrees. By default all layers.
#' @return `geo_map()` and the `map_*()` functions return a `tmr_map`; it
#'   prints as a map. `map_build()` turns it into an ordinary ggplot, to
#'   which you can add ggplot2 layers, scales and themes.
#' @name geo-map
#' @seealso [geo_automap()] for a one-call map of one layer; [map_legend()]
#'   and [theme_tidymapr()] to restyle the result of `map_build()`.
#' @examplesIf rlang::is_installed(c("ggplot2", "ggnewscale", "terra"))
#' # Luxembourg: elevation, cantons, highways and canton names
#' # (data shipped with terra)
#' elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
#' cantons <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#' roads <- sf::st_as_sf(terra::unwrap(
#'   readRDS(system.file("ex/lux_highways.rds", package = "terra"))
#' ))
#'
#' \donttest{
#' geo_map(title = "Luxembourg", caption = "Data: terra package") |>
#'   map_raster(elev, name = "Elevation (m)", palette = "Terrain 2",
#'     hillshade = TRUE) |>
#'   map_polygons(cantons, fill = NA, border = "grey20", label = "Cantons") |>
#'   map_lines(roads, colour = highway, palette = c("#B2182B", "#F4A582"),
#'     group = "Roads") |>
#'   map_labels(cantons, text = NAME_2)
#' }
NULL

#' @rdname geo-map
#' @export
geo_map <- function(title = NULL,
                    subtitle = NULL,
                    caption = NULL,
                    crs = "auto",
                    scale_bar = "checker",
                    north_arrow = "needle",
                    graticule = FALSE,
                    legend = c("right", "bottom", "inside", "none"),
                    legend_corner = "auto") {
  legend <- rlang::arg_match(legend)
  legend_corner <- rlang::arg_match(legend_corner, c("auto", "tr", "tl", "br", "bl"))
  structure(
    list(
      layers = list(), title = title, subtitle = subtitle, caption = caption,
      crs = crs, scale_bar = scale_bar, north_arrow = north_arrow,
      graticule = graticule, legend = legend, legend_corner = legend_corner
    ),
    class = "tmr_map"
  )
}

#' @rdname geo-map
#' @export
map_raster <- function(map,
                       x,
                       name = NULL,
                       palette = "auto",
                       hillshade = FALSE,
                       alpha = if (hillshade) 0.65 else 1,
                       limits = NULL) {
  tmr_check_map(map)
  rlang::check_installed("terra")
  if (!is.null(limits) && !(is.numeric(limits) && length(limits) == 2)) {
    cli::cli_abort("{.arg limits} must be two numbers, such as {.code c(0, 1)}.")
  }
  if (!inherits(x, "SpatRaster")) {
    cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
  }
  tmr_map_add(map, list(
    kind = "raster", data = x[[1]], name = name %||% names(x)[1],
    palette = palette, hillshade = hillshade, alpha = alpha, limits = limits
  ))
}

#' @rdname geo-map
#' @export
map_polygons <- function(map,
                         data,
                         fill = "grey90",
                         label = NULL,
                         group = NULL,
                         palette = "auto",
                         n = 5,
                         style = "jenks",
                         border = "grey35",
                         linewidth = 0.25,
                         linetype = "solid",
                         alpha = 1,
                         preset = NULL) {
  tmr_check_map(map)
  fill_q <- rlang::enquo(fill)
  if (!is.null(preset)) {
    ps <- tmr_preset(preset, "polygon")
    if (missing(fill)) fill_q <- rlang::quo(!!ps$fill)
    if (missing(border)) border <- ps$border
    if (missing(linewidth)) linewidth <- ps$linewidth
    if (missing(linetype)) linetype <- ps$linetype
    if (is.null(label)) label <- ps$label
  }
  tmr_map_add(map, tmr_map_feature(
    "polygon", data, fill_q, label %||% rlang::as_label(rlang::enquo(data)),
    group, palette, n, style,
    list(border = border, linewidth = linewidth, linetype = linetype, alpha = alpha)
  ))
}

#' @rdname geo-map
#' @export
map_lines <- function(map,
                      data,
                      colour = "grey20",
                      label = NULL,
                      group = NULL,
                      palette = "auto",
                      n = 5,
                      style = "jenks",
                      linewidth = 0.6,
                      linetype = "solid",
                      alpha = 1,
                      preset = NULL) {
  tmr_check_map(map)
  colour_q <- rlang::enquo(colour)
  if (!is.null(preset)) {
    ps <- tmr_preset(preset, "line")
    if (missing(colour)) colour_q <- rlang::quo(!!ps$colour)
    if (missing(linewidth)) linewidth <- ps$linewidth
    if (missing(linetype)) linetype <- ps$linetype
    if (is.null(label)) label <- ps$label
  }
  tmr_map_add(map, tmr_map_feature(
    "line", data, colour_q, label %||% rlang::as_label(rlang::enquo(data)),
    group, palette, n, style,
    list(linewidth = linewidth, linetype = linetype, alpha = alpha)
  ))
}

#' @rdname geo-map
#' @export
map_points <- function(map,
                       data,
                       fill = "#0072B2",
                       label = NULL,
                       group = NULL,
                       palette = "auto",
                       n = 5,
                       style = "jenks",
                       shape = 21,
                       size = 2.5,
                       border = "grey15",
                       alpha = 1,
                       preset = NULL) {
  tmr_check_map(map)
  fill_q <- rlang::enquo(fill)
  if (!is.null(preset)) {
    ps <- tmr_preset(preset, "point")
    if (missing(fill)) fill_q <- rlang::quo(!!ps$fill)
    if (missing(shape)) shape <- ps$shape
    if (missing(size)) size <- ps$size
    if (missing(border)) border <- ps$border
    if (is.null(label)) label <- ps$label
  }
  tmr_map_add(map, tmr_map_feature(
    "point", data, fill_q, label %||% rlang::as_label(rlang::enquo(data)),
    group, palette, n, style,
    list(shape = shape, size = size, border = border, alpha = alpha)
  ))
}

#' @rdname geo-map
#' @export
map_labels <- function(map,
                       data,
                       text,
                       size = 3,
                       colour = "grey10",
                       halo = TRUE,
                       fontface = "plain") {
  tmr_check_map(map)
  tmr_check_sf(data)
  col <- tmr_pick(rlang::enquo(text), data, "text")
  tmr_map_add(map, list(
    kind = "labels", data = data, col = col, size = size,
    colour = colour, halo = halo, fontface = fontface
  ))
}

#' @rdname geo-map
#' @export
map_curved_labels <- function(map,
                              data,
                              text,
                              size = 3,
                              colour = "grey15",
                              draw_line = NULL,
                              linewidth_label = 0.4,
                              position = 0.5,
                              polygon = c("axis", "outline"),
                              radius = NULL,
                              smooth = 3,
                              fontface = "plain") {
  tmr_check_map(map)
  tmr_check_sf(data)
  rlang::check_installed("geomtextpath")
  tmr_check_number(position, "position", 0, 1)
  polygon <- rlang::arg_match(polygon)
  col <- tmr_pick(rlang::enquo(text), data, "text")
  g <- unique(as.character(sf::st_geometry_type(data)))
  kind <- if (all(g %in% c("LINESTRING", "MULTILINESTRING"))) {
    "line"
  } else if (all(g %in% c("POLYGON", "MULTIPOLYGON"))) {
    "polygon"
  } else if (all(g %in% c("POINT", "MULTIPOINT"))) {
    "point"
  } else {
    cli::cli_abort("{.arg data} must hold one kind of geometry, not {.val {g}}.")
  }
  tmr_map_add(map, list(
    kind = "linelabels", data = data, col = col, size = size,
    colour = colour, geom = kind, polygon = polygon, radius = radius,
    draw_line = draw_line %||% (kind == "line"), smooth = smooth,
    linewidth = linewidth_label, hjust = position, fontface = fontface
  ))
}

#' @rdname geo-map
#' @export
map_line_labels <- function(map, data, text, ...) {
  map_curved_labels(map, data, {{ text }}, ...)
}

#' @rdname geo-map
#' @export
map_contours <- function(map,
                         x,
                         interval = NULL,
                         breaks = NULL,
                         colour = "grey30",
                         label_every = 2,
                         size = 2.6,
                         linewidth = 0.25) {
  tmr_check_map(map)
  rlang::check_installed(c("terra", "geomtextpath"))
  if (!inherits(x, "SpatRaster")) cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
  rng <- as.numeric(terra::global(x[[1]], "range", na.rm = TRUE))
  levels <- if (!is.null(breaks)) {
    sort(breaks)
  } else if (!is.null(interval)) {
    tmr_check_number(interval, "interval", 0)
    seq(ceiling(rng[1] / interval) * interval, rng[2], by = interval)
  } else {
    pretty(rng, n = 8)
  }
  levels <- levels[levels > rng[1] & levels < rng[2]]
  if (!length(levels)) cli::cli_abort("No contour levels fall inside the raster's range.")
  cl <- sf::st_as_sf(terra::as.contour(x[[1]], levels = levels))
  names(cl)[1] <- "level"
  cl$label <- format(cl$level, big.mark = ",", trim = TRUE)
  # Label every nth level (index contours), starting with the lowest
  is_index <- (match(cl$level, levels) - 1) %% max(1, label_every) == 0
  cl <- suppressWarnings(sf::st_cast(cl, "LINESTRING"))
  is_index <- (match(cl$level, levels) - 1) %% max(1, label_every) == 0
  # Only pieces long enough to carry a label get one
  bb <- sf::st_bbox(cl)
  diag <- sqrt(diff(bb[c(1, 3)])^2 + diff(bb[c(2, 4)])^2)
  long <- as.numeric(sf::st_length(cl)) > 0.15 * as.numeric(diag)
  cl$label[!(is_index & long)] <- NA
  lab <- cl[is_index & long, ]
  plain <- cl[!(is_index & long), ]
  if (nrow(plain)) {
    map <- tmr_map_add(map, list(
      kind = "linelabels", data = plain, col = NULL, size = size, geom = "line", smooth = 3,
      colour = colour, draw_line = TRUE, linewidth = linewidth,
      hjust = 0.5, fontface = "plain"
    ))
  }
  tmr_map_add(map, list(
    kind = "linelabels", data = lab, col = "label", size = size, geom = "line", smooth = 3,
    text_smoothing = 80, hjust = "straight", straight = TRUE,
    colour = colour, draw_line = TRUE, linewidth = linewidth * 1.6,
    fontface = "plain"
  ))
}

#' @rdname geo-map
#' @export
map_zoom <- function(map, zoom = 1, centre = NULL, extent = NULL) {
  tmr_check_map(map)
  tmr_check_number(zoom, "zoom", 0.05, 1000)
  if (!is.null(centre) && !(is.numeric(centre) && length(centre) == 2)) {
    cli::cli_abort("{.arg centre} must be {.code c(longitude, latitude)}.")
  }
  ok_extent <- inherits(extent, c("sf", "sfc", "bbox", "SpatRaster", "SpatVector")) ||
    (is.numeric(extent) && length(extent) == 4)
  if (!is.null(extent) && !ok_extent) {
    cli::cli_abort(
      "{.arg extent} must be an sf object, a bbox, or {.code c(xmin, ymin, xmax, ymax)} in degrees."
    )
  }
  map$zoom <- list(zoom = zoom, centre = centre, extent = extent)
  map
}

#' @rdname geo-map
#' @export
map_build <- function(map) {
  tmr_check_map(map)
  rlang::check_installed(c("ggplot2", "sf", "ggnewscale"))
  if (!length(map$layers)) cli::cli_abort("The map has no layers yet.")
  crs <- tmr_map_crs(map)
  n_layers <- length(map$layers)
  p <- ggplot2::ggplot()
  for (i in seq_len(n_layers)) {
    ly <- map$layers[[i]]
    # Legend order: top layer first
    ord <- n_layers - i + 1
    p <- switch(ly$kind,
      raster = tmr_map_draw_raster(p, ly, crs, ord),
      labels = tmr_map_draw_labels(p, ly, crs),
      linelabels = tmr_map_draw_line_labels(p, ly, crs, ord),
      tmr_map_draw_feature(p, ly, crs, ord)
    )
    if (i < n_layers) {
      p <- p + ggnewscale::new_scale_fill() + ggnewscale::new_scale_colour()
    }
  }
  lims <- tmr_map_limits(map, crs)
  # Narrow maps (panels, insets): drop coordinate labels that would collide
  p <- p + ggplot2::guides(
    x = ggplot2::guide_axis(check.overlap = TRUE),
    y = ggplot2::guide_axis(check.overlap = TRUE)
  )
  p <- p + ggplot2::coord_sf(
    crs = crs, default_crs = crs, expand = FALSE,
    xlim = lims$x, ylim = lims$y
  )
  sb <- tmr_furniture_style(map$scale_bar, "scale")
  na <- tmr_furniture_style(map$north_arrow, "north")
  if (!is.null(sb)) p <- p + annotation_scale_bar(style = sb, location = "bl")
  if (!is.null(na)) p <- p + annotation_north_arrow(style = na, location = "tr")
  if (isTRUE(map$graticule)) p <- p + map_graticule()
  p <- p +
    ggplot2::labs(
      title = map$title, subtitle = map$subtitle, caption = map$caption,
      x = NULL, y = NULL
    ) +
    theme_tidymapr(
      grid = "none",
      legend_position = if (map$legend == "inside") "right" else map$legend
    ) +
    ggplot2::theme(
      legend.key = ggplot2::element_rect(fill = "white", colour = NA),
      legend.spacing.y = ggplot2::unit(2, "mm"),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey30", linewidth = 0.4)
    )
  if (identical(map$legend, "inside")) {
    corner <- map$legend_corner %||% "auto"
    if (corner == "auto") corner <- tmr_inset_corner(p, 0.3, 0.02)
    p <- p + map_legend(position = "inside", corner = corner)
  }
  p
}

#' @export
print.tmr_map <- function(x, ...) {
  if (!length(x$layers)) {
    cli::cli_text("An empty {.cls tmr_map}; add layers with {.fn map_polygons} and friends.")
    return(invisible(x))
  }
  print(map_build(x), ...)
  invisible(x)
}

# ---- internals ------------------------------------------------------------

tmr_check_map <- function(map, call = caller_env()) {
  if (!inherits(map, "tmr_map")) {
    cli::cli_abort("{.arg map} must be a map started with {.fn geo_map}.", call = call)
  }
}

tmr_check_sf <- function(data, call = caller_env()) {
  rlang::check_installed("sf")
  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} table.", call = call)
  }
}

tmr_map_add <- function(map, layer) {
  map$layers[[length(map$layers) + 1]] <- layer
  map
}

# A feature layer: a column to colour by, or one constant colour
tmr_map_feature <- function(kind, data, quo, label, group, palette, n, style,
                            look, call = caller_env()) {
  tmr_check_sf(data, call = call)
  value <- tryCatch(rlang::eval_tidy(quo), error = function(e) NULL)
  col <- NULL
  if (rlang::quo_is_symbol(quo) && rlang::as_name(quo) %in% names(data)) {
    col <- rlang::as_name(quo)
  } else if (is.character(value) && length(value) == 1 && value %in% names(data)) {
    col <- value
  }
  const <- if (is.null(col)) value else NULL
  if (is.null(col) && !(length(const) == 1 && (is.na(const) || tmr_is_colour(const)))) {
    cli::cli_abort(
      "The colour must be a column of {.arg data} or a single colour.",
      call = call
    )
  }
  list(
    kind = kind, data = data, col = col, const = const, label = label,
    group = group, palette = palette, n = n, style = style, look = look
  )
}

tmr_is_colour <- function(x) {
  is.character(x) && !inherits(try(grDevices::col2rgb(x), silent = TRUE), "try-error")
}

tmr_map_crs <- function(map) {
  first <- map$layers[[1]]$data
  data_crs <- if (inherits(first, "SpatRaster")) {
    sf::st_crs(terra::crs(first))
  } else {
    sf::st_crs(first)
  }
  crs <- map$crs
  if (identical(crs, "auto")) {
    if (isTRUE(data_crs$IsGeographic)) {
      sfx <- if (inherits(first, "SpatRaster")) {
        sf::st_as_sf(terra::as.polygons(terra::ext(first), crs = terra::crs(first)))
      } else {
        first
      }
      return(geo_crs("utm", data = sfx))
    }
    return(data_crs)
  }
  if (is.character(crs) && !grepl("^(EPSG|ESRI):|^\\+proj|^PROJCRS|^GEOGCRS", crs)) {
    # Centre named projections on the data, rasters included
    sfx <- if (inherits(first, "SpatRaster")) {
      sf::st_as_sf(terra::as.polygons(terra::ext(first), crs = terra::crs(first)))
    } else {
      first
    }
    return(geo_crs(crs, data = sfx))
  }
  sf::st_crs(crs)
}

tmr_map_draw_raster <- function(p, ly, crs, ord) {
  r <- terra::project(ly$data, crs$wkt)
  # Smooth coarse rasters for display (bilinear, up to about 250k cells)
  f <- floor(sqrt(250000 / terra::ncell(r)))
  if (f >= 2) r <- terra::disagg(r, min(f, 4), method = "bilinear")
  if (isTRUE(ly$hillshade)) {
    sl <- terra::terrain(r, "slope", unit = "radians")
    as <- terra::terrain(r, "aspect", unit = "radians")
    hs <- terra::shade(sl, as, angle = 40, direction = 315)
    hdf <- terra::as.data.frame(hs, xy = TRUE, na.rm = TRUE)
    names(hdf)[3] <- "shade"
    p <- p +
      tmr_map_tiles(hdf, "shade", r) +
      ggplot2::scale_fill_gradient(low = "grey25", high = "white", guide = "none") +
      ggnewscale::new_scale_fill()
  }
  df <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "value"
  gr <- tmr_graduated(df$value, ly$name)
  p +
    tmr_map_tiles(df, "value", r, alpha = ly$alpha) +
    ggplot2::scale_fill_gradientn(
      colours = tmr_ramp(ly$palette, gr, 9), name = ly$name,
      limits = ly$limits, oob = function(x, range = c(0, 1), ...) pmin(pmax(x, range[1]), range[2]),
      guide = ggplot2::guide_colourbar(order = ord)
    )
}

tmr_map_draw_feature <- function(p, ly, crs, ord) {
  d <- sf::st_transform(ly$data, crs)
  lk <- ly$look
  aes_name <- if (ly$kind == "line") "colour" else "fill"
  key <- if (ly$kind == "polygon") "polygon" else if (ly$kind == "line") "line" else "point"
  if (is.null(ly$col)) {
    # One colour: one legend entry named by `label`
    d$.layer <- factor(ly$label)
    mapping <- tmr_aes_layer(aes_name)
    values <- stats::setNames(if (is.na(ly$const)) "white" else ly$const, ly$label)
    if (is.na(ly$const) && ly$kind == "polygon") {
      # Hollow polygons: show the outline in the legend
      mapping <- ggplot2::aes(colour = .data$.layer)
      aes_name <- "colour"
      values <- stats::setNames(lk$border, ly$label)
    }
    title <- ly$group
  } else {
    v <- d[[ly$col]]
    if (is.numeric(v) && length(unique(v)) > 7) {
      cls <- geo_classify(d, !!rlang::sym(ly$col), n = ly$n, style = ly$style, name = ".class")
      d <- cls
      levs <- levels(d$.class)
      gr <- tmr_graduated(v, ly$col)
      values <- stats::setNames(tmr_ramp(ly$palette, gr, length(levs)), levs)
      d$.layer <- d$.class
    } else {
      levs <- if (is.factor(v)) {
        intersect(levels(v), unique(as.character(v)))
      } else {
        sort(unique(as.character(v)))
      }
      named <- !is.null(names(ly$palette)) && all(levs %in% names(ly$palette))
      pal <- if (named) {
        # A named palette maps each category to its own colour
        unname(ly$palette[levs])
      } else if (identical(ly$palette, "auto")) {
        tmr_palette(length(levs))
      } else {
        tmr_ramp(ly$palette, NULL, length(levs))
      }
      values <- stats::setNames(pal, levs)
      d$.layer <- factor(as.character(v), levels = levs)
    }
    mapping <- tmr_aes_layer(aes_name)
    title <- ly$group %||% ly$col
  }
  layer <- switch(ly$kind,
    polygon = if (aes_name == "colour") {
      ggplot2::geom_sf(
        data = d, mapping, fill = NA, linewidth = lk$linewidth,
        linetype = lk$linetype %||% "solid",
        alpha = lk$alpha, key_glyph = "polygon", inherit.aes = FALSE
      )
    } else {
      ggplot2::geom_sf(
        data = d, mapping, colour = lk$border, linewidth = lk$linewidth,
        linetype = lk$linetype %||% "solid",
        alpha = lk$alpha, key_glyph = "polygon", inherit.aes = FALSE
      )
    },
    line = ggplot2::geom_sf(
      data = d, mapping, linewidth = lk$linewidth, linetype = lk$linetype,
      alpha = lk$alpha, key_glyph = "path", inherit.aes = FALSE
    ),
    point = if (lk$shape %in% 21:25) {
      ggplot2::geom_sf(
        data = d, mapping, shape = lk$shape, size = lk$size, colour = lk$border,
        stroke = 0.4, alpha = lk$alpha, key_glyph = "point", inherit.aes = FALSE
      )
    } else {
      ggplot2::geom_sf(
        data = d, ggplot2::aes(colour = .data$.layer), shape = lk$shape,
        size = lk$size, alpha = lk$alpha, key_glyph = "point", inherit.aes = FALSE
      )
    }
  )
  if (ly$kind == "point" && !lk$shape %in% 21:25) aes_name <- "colour"
  scale_fun <- if (aes_name == "colour") {
    ggplot2::scale_colour_manual
  } else {
    ggplot2::scale_fill_manual
  }
  override <- switch(key,
    polygon = list(linewidth = max(lk$linewidth, 0.3)),
    line = list(linewidth = max(lk$linewidth, 0.6)),
    point = list(size = max(lk$size, 2.5))
  )
  p + layer + scale_fun(
    values = values, name = title, drop = FALSE, na.value = "grey85",
    guide = ggplot2::guide_legend(order = ord, override.aes = override)
  )
}

tmr_map_draw_labels <- function(p, ly, crs) {
  d <- sf::st_transform(ly$data, crs)
  pts <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(d)))
  xy <- sf::st_coordinates(pts)
  df <- data.frame(x = xy[, 1], y = xy[, 2], label = as.character(d[[ly$col]]))
  if (isTRUE(ly$halo)) {
    # A white halo: the label drawn eight times, offset in a ring
    off <- expand.grid(dx = c(-1, 0, 1), dy = c(-1, 0, 1))
    off <- off[off$dx != 0 | off$dy != 0, ]
    for (k in seq_len(nrow(off))) {
      p <- p + ggplot2::geom_text(
        data = df, ggplot2::aes(.data$x, .data$y, label = .data$label),
        size = ly$size, colour = "white", fontface = ly$fontface,
        position = ggplot2::position_nudge(
          x = off$dx[k] * tmr_halo_offset(df, ly$size),
          y = off$dy[k] * tmr_halo_offset(df, ly$size)
        ),
        inherit.aes = FALSE
      )
    }
  }
  p + ggplot2::geom_text(
    data = df, ggplot2::aes(.data$x, .data$y, label = .data$label),
    size = ly$size, colour = ly$colour, fontface = ly$fontface,
    inherit.aes = FALSE
  )
}

# Halo offset in map units: a small fraction of the label extent
tmr_halo_offset <- function(df, size) {
  span <- max(diff(range(df$x)), diff(range(df$y)), 1)
  span * 0.0012 * size / 3
}

# aes(<aesthetic> = .data$.layer) for an aesthetic chosen at run time
tmr_aes_layer <- function(aesthetic) {
  m <- ggplot2::aes(fill = .data$.layer)
  names(m) <- aesthetic
  m
}

# Raster cells as tiles: geom_raster() cannot draw in coord_sf(), and plain
# tiles leave hairline seams, so each tile is drawn 3% larger
tmr_map_tiles <- function(df, col, r, alpha = 1) {
  res <- terra::res(r)
  ggplot2::geom_tile(
    data = df, ggplot2::aes(.data$x, .data$y, fill = .data[[col]]),
    width = res[1] * 1.03, height = res[2] * 1.03, colour = NA,
    alpha = alpha, inherit.aes = FALSE
  )
}

# Map limits in the map CRS from map_zoom(): the extent (or all layers),
# then zoomed about its centre (or a given centre)
tmr_map_limits <- function(map, crs) {
  z <- map$zoom
  if (is.null(z)) return(list(x = NULL, y = NULL))
  to_box <- function(x) {
    if (inherits(x, c("SpatRaster", "SpatVector"))) {
      x <- sf::st_as_sfc(sf::st_bbox(
        stats::setNames(as.vector(terra::ext(x))[c(1, 3, 2, 4)], c("xmin", "ymin", "xmax", "ymax")),
        crs = sf::st_crs(terra::crs(x))
      ))
    } else if (is.numeric(x) && !inherits(x, "bbox")) {
      x <- sf::st_as_sfc(sf::st_bbox(
        stats::setNames(x, c("xmin", "ymin", "xmax", "ymax")),
        crs = sf::st_crs(4326)
      ))
    } else if (inherits(x, "bbox")) {
      x <- sf::st_as_sfc(x)
    }
    sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(x)), crs))
  }
  bb <- if (!is.null(z$extent)) {
    to_box(z$extent)
  } else {
    boxes <- lapply(Filter(function(l) l$kind != "labels", map$layers), function(l) to_box(l$data))
    m <- do.call(rbind, lapply(boxes, as.numeric))
    stats::setNames(
      c(min(m[, 1]), min(m[, 2]), max(m[, 3]), max(m[, 4])),
      c("xmin", "ymin", "xmax", "ymax")
    )
  }
  cx <- (bb[["xmin"]] + bb[["xmax"]]) / 2
  cy <- (bb[["ymin"]] + bb[["ymax"]]) / 2
  if (!is.null(z$centre)) {
    pt <- sf::st_coordinates(sf::st_transform(
      sf::st_sfc(sf::st_point(z$centre), crs = 4326), crs
    ))
    cx <- pt[1, 1]
    cy <- pt[1, 2]
  }
  hw <- (bb[["xmax"]] - bb[["xmin"]]) / 2 / z$zoom
  hh <- (bb[["ymax"]] - bb[["ymin"]]) / 2 / z$zoom
  list(x = c(cx - hw, cx + hw), y = c(cy - hh, cy + hh))
}

tmr_map_draw_line_labels <- function(p, ly, crs, ord) {
  d <- sf::st_transform(ly$data, crs)
  geom <- ly$geom %||% "line"
  if (geom == "line") {
    d <- suppressWarnings(sf::st_cast(d, "LINESTRING"))
  } else if (geom == "polygon") {
    d <- tmr_polygon_label_path(d, ly$polygon %||% "axis")
  } else {
    span <- diff(sf::st_bbox(d)[c("xmin", "xmax")])
    d <- tmr_point_arcs(d, ly$radius %||% max(as.numeric(span) * 0.035, 1))
  }
  if ((ly$smooth %||% 0) > 0) {
    sf::st_geometry(d) <- tmr_chaikin(sf::st_geometry(d), ly$smooth)
  }
  if (is.null(ly$col)) {
    return(p + ggplot2::geom_sf(
      data = d, colour = ly$colour, linewidth = ly$linewidth, inherit.aes = FALSE
    ))
  }
  d$.label <- as.character(d[[ly$col]])
  # "straight": each label at the straightest stretch of its line
  d$.hjust <- if (identical(ly$hjust, "straight")) {
    vapply(sf::st_geometry(d), tmr_straightest, numeric(1))
  } else {
    ly$hjust
  }
  p + geomtextpath::geom_textsf(
    data = d, ggplot2::aes(label = .data$.label, hjust = .data$.hjust),
    colour = ly$colour,
    linecolour = if (isTRUE(ly$draw_line)) ly$colour else NA,
    linewidth = ly$linewidth, size = ly$size, fontface = ly$fontface,
    vjust = if (isTRUE(ly$draw_line)) 0.5 else -0.2,
    straight = isTRUE(ly$straight),
    text_smoothing = ly$text_smoothing %||% 30, remove_long = geom != "point", inherit.aes = FALSE
  )
}

# Chaikin corner cutting: each round replaces every corner by two points at
# 1/4 and 3/4 along its edges, rounding jagged lines while keeping the ends
tmr_chaikin <- function(g, n) {
  one <- function(xy) {
    for (k in seq_len(n)) {
      if (nrow(xy) < 3) break
      a <- xy[-nrow(xy), , drop = FALSE]
      b <- xy[-1, , drop = FALSE]
      q <- 0.75 * a + 0.25 * b
      r <- 0.25 * a + 0.75 * b
      mid <- matrix(t(cbind(q, r)), ncol = 2, byrow = TRUE)
      xy <- rbind(xy[1, ], mid, xy[nrow(xy), ])
    }
    xy
  }
  out <- lapply(g, function(x) {
    if (inherits(x, "LINESTRING")) {
      sf::st_linestring(one(unclass(x)[, 1:2, drop = FALSE]))
    } else {
      x
    }
  })
  sf::st_sfc(out, crs = sf::st_crs(g))
}

# A label path for each polygon: its long axis (the longest chord through
# the centre along the main direction, bent through the middle of the shape)
# or its outline pulled slightly inside
tmr_polygon_label_path <- function(d, how) {
  geoms <- lapply(seq_len(nrow(d)), function(i) {
    poly <- sf::st_geometry(d)[i]
    if (how == "outline") {
      span <- sqrt(as.numeric(sf::st_area(poly)))
      inner <- suppressWarnings(sf::st_buffer(poly, -0.04 * span))
      if (sf::st_is_empty(inner[1])) inner <- poly
      ring <- suppressWarnings(sf::st_cast(sf::st_boundary(inner), "LINESTRING"))
      lens <- as.numeric(sf::st_length(ring))
      # Start the outline at its top so text runs across the top first
      xy <- sf::st_coordinates(ring[which.max(lens)])[, 1:2]
      top <- which.max(xy[, 2])
      xy <- rbind(xy[top:nrow(xy), ], xy[seq_len(top), ])
      return(sf::st_linestring(xy))
    }
    xy <- sf::st_coordinates(poly)[, 1:2]
    ctr <- colMeans(xy)
    ev <- eigen(stats::cov(xy))$vectors[, 1]
    half <- max(abs(sweep(xy, 2, ctr) %*% ev)) * 1.2
    # Sample across the main axis and take the midpoint of each cross
    # section, so the path bends with the shape
    ts <- seq(-half, half, length.out = 25)
    perp <- c(-ev[2], ev[1])
    mids <- t(vapply(ts, function(t0) {
      c0 <- ctr + t0 * ev
      cut <- sf::st_linestring(rbind(c0 - perp * half * 3, c0 + perp * half * 3))
      hit <- suppressWarnings(sf::st_intersection(
        sf::st_sfc(cut, crs = sf::st_crs(poly)), poly
      ))
      if (!length(hit) || sf::st_is_empty(hit[1])) return(c(NA_real_, NA_real_))
      hx <- sf::st_coordinates(hit)[, 1:2, drop = FALSE]
      colMeans(hx)
    }, numeric(2)))
    ok <- stats::complete.cases(mids)
    if (sum(ok) < 4) {
      path <- rbind(ctr - ev * half / 2, ctr + ev * half / 2)
    } else {
      # A gentle bend: the sideways offset of the cross-section midpoints,
      # fitted as a quadratic along the axis, over the middle of the shape
      tt <- ts[ok]
      off <- as.vector(sweep(mids[ok, , drop = FALSE], 2, ctr) %*% perp)
      fit <- stats::lm(off ~ stats::poly(tt, 2, raw = TRUE))
      tin <- seq(min(tt) * 0.75, max(tt) * 0.75, length.out = 40)
      ofs <- stats::predict(fit, data.frame(tt = tin))
      path <- t(vapply(seq_along(tin), function(k) ctr + tin[k] * ev + ofs[k] * perp, numeric(2)))
    }
    # Run left to right so the text reads upright
    if (path[1, 1] > path[nrow(path), 1]) path <- path[rev(seq_len(nrow(path))), ]
    sf::st_linestring(path)
  })
  sf::st_set_geometry(d, sf::st_sfc(geoms, crs = sf::st_crs(d)))
}

# An arc above each point, from 150 to 30 degrees, for text curving over it
tmr_point_arcs <- function(d, r) {
  pts <- sf::st_coordinates(suppressWarnings(sf::st_centroid(sf::st_geometry(d))))
  a <- seq(150, 30, length.out = 30) * pi / 180
  geoms <- lapply(seq_len(nrow(pts)), function(i) {
    sf::st_linestring(cbind(pts[i, 1] + r * cos(a), pts[i, 2] + r * sin(a)))
  })
  sf::st_set_geometry(d, sf::st_sfc(geoms, crs = sf::st_crs(d)))
}

# Position (0 to 1 along the line) of the straightest stretch: the least
# total turning over a window of a fifth of the line
tmr_straightest <- function(g) {
  xy <- unclass(g)[, 1:2, drop = FALSE]
  n <- nrow(xy)
  if (n < 5) return(0.5)
  seg <- diff(xy)
  len <- sqrt(rowSums(seg^2))
  ang <- atan2(seg[, 2], seg[, 1])
  turn <- abs(atan2(sin(diff(ang)), cos(diff(ang))))
  pos <- cumsum(len) / sum(len)
  w <- 0.2
  centres <- seq(w / 2 + 0.05, 1 - w / 2 - 0.05, by = 0.02)
  if (!length(centres)) return(0.5)
  cost <- vapply(centres, function(cc) {
    sum(turn[abs(pos[-length(pos)] - cc) <= w / 2])
  }, numeric(1))
  centres[which.min(cost)]
}
