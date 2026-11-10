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
#' @param hillshade Draw the raster over its own hillshade? Useful for
#'   elevation.
#' @param shape,size Point symbol (a number from [graphics::points()]) and
#'   size.
#' @param text Column with the label text.
#' @param halo Draw a white halo behind the labels?
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
#' geo_map(title = "Luxembourg", caption = "Data: terra package") |>
#'   map_raster(elev, name = "Elevation (m)", palette = "Terrain 2",
#'     hillshade = TRUE) |>
#'   map_polygons(cantons, fill = NA, border = "grey20", label = "Cantons") |>
#'   map_lines(roads, colour = highway, palette = c("#B2182B", "#F4A582"),
#'     group = "Roads") |>
#'   map_labels(cantons, text = NAME_2)
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
                       alpha = if (hillshade) 0.65 else 1) {
  tmr_check_map(map)
  rlang::check_installed("terra")
  if (!inherits(x, "SpatRaster")) {
    cli::cli_abort("{.arg x} must be a {.cls SpatRaster}.")
  }
  tmr_map_add(map, list(
    kind = "raster", data = x[[1]], name = name %||% names(x)[1],
    palette = palette, hillshade = hillshade, alpha = alpha
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
                         alpha = 1) {
  tmr_check_map(map)
  tmr_map_add(map, tmr_map_feature(
    "polygon", data, rlang::enquo(fill), label %||% rlang::as_label(rlang::enquo(data)),
    group, palette, n, style,
    list(border = border, linewidth = linewidth, alpha = alpha)
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
                      alpha = 1) {
  tmr_check_map(map)
  tmr_map_add(map, tmr_map_feature(
    "line", data, rlang::enquo(colour), label %||% rlang::as_label(rlang::enquo(data)),
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
                       alpha = 1) {
  tmr_check_map(map)
  tmr_map_add(map, tmr_map_feature(
    "point", data, rlang::enquo(fill), label %||% rlang::as_label(rlang::enquo(data)),
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
      tmr_map_draw_feature(p, ly, crs, ord)
    )
    if (i < n_layers) {
      p <- p + ggnewscale::new_scale_fill() + ggnewscale::new_scale_colour()
    }
  }
  lims <- tmr_map_limits(map, crs)
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
    sfx <- if (inherits(first, "SpatRaster")) NULL else first
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
      levs <- sort(unique(as.character(v)))
      pal <- if (identical(ly$palette, "auto")) {
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
        alpha = lk$alpha, key_glyph = "polygon", inherit.aes = FALSE
      )
    } else {
      ggplot2::geom_sf(
        data = d, mapping, colour = lk$border, linewidth = lk$linewidth,
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
