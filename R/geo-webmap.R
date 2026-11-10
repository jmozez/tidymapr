#' Interactive web maps
#'
#' @description
#' `geo_webmap()` turns a map built with [geo_map()] (or a single `sf` or
#' `SpatRaster` layer) into an interactive web map: pan and zoom, a choice
#' of basemaps, layers that switch on and off, the attributes of any feature
#' on click, a scale bar and a legend. Every layer keeps the symbols of the
#' printed map: the same colours, classes, presets, line dashes and point
#' shapes, and the same legend sections.
#'
#' The result is one self-contained HTML file: features are embedded as
#' GeoJSON and rasters as images, so the page can be emailed, put on a
#' website or opened offline (only the basemap tiles and the Leaflet library
#' are fetched from the web).
#'
#' @param x A map from [geo_map()], an `sf` table, or a `SpatRaster`.
#' @param file Optional path of the HTML file to write.
#' @param basemap Basemap shown first: `"topo"` (Esri World Topographic),
#'   `"imagery"` (Esri World Imagery), `"osm"` (OpenStreetMap) or `"light"`
#'   (CARTO Positron). All four are offered in the layer menu.
#' @param title Page title; defaults to the map's title.
#' @param popup Show feature attributes on click?
#' @param max_pixels Largest side of embedded raster images.
#' @return An object of class `tmr_webmap` holding the HTML; it prints by
#'   opening the page in a browser (or the RStudio viewer) when interactive.
#'   With `file`, the path is returned invisibly.
#' @seealso [geo_map()] for the printed map.
#' @examplesIf rlang::is_installed(c("sf", "terra"))
#' elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
#' cantons <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#' m <- geo_map(title = "Luxembourg") |>
#'   map_raster(elev, name = "Elevation (m)", palette = "Terrain 2") |>
#'   map_polygons(cantons, fill = NA, preset = "admin") |>
#'   map_labels(cantons, text = NAME_2)
#' w <- geo_webmap(m)
#' f <- tempfile(fileext = ".html")
#' geo_webmap(m, file = f)
#' @export
geo_webmap <- function(x,
                       file = NULL,
                       basemap = c("topo", "imagery", "osm", "light"),
                       title = NULL,
                       popup = TRUE,
                       max_pixels = 1600) {
  rlang::check_installed(c("sf", "jsonlite", "png", "htmltools"))
  basemap <- rlang::arg_match(basemap)
  map <- if (inherits(x, "tmr_map")) {
    x
  } else if (inherits(x, "sf")) {
    g <- unique(as.character(sf::st_geometry_type(x)))
    m <- geo_map()
    if (all(g %in% c("POINT", "MULTIPOINT"))) {
      map_points(m, x, label = "Points")
    } else if (all(g %in% c("LINESTRING", "MULTILINESTRING"))) {
      map_lines(m, x, label = "Lines")
    } else {
      map_polygons(m, x, label = "Polygons")
    }
  } else if (inherits(x, "SpatRaster")) {
    map_raster(geo_map(), x)
  } else {
    cli::cli_abort(
      "{.arg x} must be a map from {.fn geo_map}, an {.cls sf} table or a {.cls SpatRaster}."
    )
  }
  if (!length(map$layers)) cli::cli_abort("The map has no layers.")
  title <- title %||% map$title %||% "Map"

  js_layers <- character()
  legend <- character()
  bounds <- NULL
  grow <- function(bb) {
    if (is.null(bounds)) return(bb)
    c(min(bounds[1], bb[1]), min(bounds[2], bb[2]), max(bounds[3], bb[3]), max(bounds[4], bb[4]))
  }
  for (i in seq_along(map$layers)) {
    ly <- map$layers[[i]]
    id <- paste0("L", i)
    out <- switch(ly$kind,
      raster = tmr_web_raster(ly, id, max_pixels),
      labels = tmr_web_labels(ly, id),
      linelabels = NULL,
      tmr_web_feature(ly, id, popup)
    )
    if (is.null(out)) next
    js_layers <- c(js_layers, out$js)
    if (!is.null(out$legend)) legend <- c(out$legend, legend)  # top layer first
    bounds <- grow(out$bbox)
  }
  html <- tmr_web_page(title, map$subtitle, map$caption, js_layers, legend, bounds, basemap)
  obj <- structure(list(html = html, title = title), class = "tmr_webmap")
  if (!is.null(file)) {
    writeLines(html, file, useBytes = TRUE)
    return(invisible(file))
  }
  obj
}

#' @export
print.tmr_webmap <- function(x, ...) {
  f <- tempfile(fileext = ".html")
  writeLines(x$html, f, useBytes = TRUE)
  if (interactive()) {
    viewer <- getOption("viewer", utils::browseURL)
    viewer(f)
  } else {
    cli::cli_text("Web map {.val {x$title}} written to {.file {f}}.")
  }
  invisible(x)
}

# ---- layers -----------------------------------------------------------------

tmr_web_json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")

# R colour names (such as "grey10") are not CSS colours: write hex codes
tmr_web_hex <- function(x) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  if (any(ok)) {
    m <- grDevices::col2rgb(x[ok], alpha = TRUE)
    out[ok] <- grDevices::rgb(m[1, ], m[2, ], m[3, ], m[4, ], maxColorValue = 255)
    out[ok] <- sub("FF$", "", out[ok])
  }
  out
}

tmr_web_dash <- function(lt) {
  lt <- lt %||% "solid"
  if (is.na(lt) || lt %in% c("solid", "1")) return(NULL)
  named <- c(
    dashed = "6,4", dotted = "1,4", dotdash = "1,4,6,4",
    longdash = "10,4", twodash = "4,4,10,4"
  )
  if (lt %in% names(named)) return(named[[lt]])
  # ggplot hex strings: "42" = 4 on, 2 off (in line widths)
  d <- as.integer(strsplit(lt, "")[[1]], 16L)
  paste(d * 2, collapse = ",")
}

tmr_web_shape <- function(s) {
  s <- as.numeric(s %||% 21)
  if (s %in% c(0, 15, 22)) return("square")
  if (s %in% c(2, 17, 24)) return("triangle")
  if (s %in% c(5, 18, 23)) return("diamond")
  "circle"
}

tmr_web_svg_point <- function(shape, fill, stroke, px = 14) {
  h <- px / 2
  body <- switch(shape,
    square = sprintf('<rect x="2" y="2" width="%s" height="%s"', px - 4, px - 4),
    triangle = sprintf('<polygon points="%s,1 %s,%s 1,%s"', h, px - 1, px - 1, px - 1),
    diamond = sprintf('<polygon points="%s,1 %s,%s %s,%s 1,%s"', h, px - 1, h, h, px - 1, h),
    sprintf('<circle cx="%s" cy="%s" r="%s"', h, h, h - 1.5)
  )
  sprintf(
    paste0(
      '<svg width="%s" height="%s" viewBox="0 0 %s %s">',
      '%s fill="%s" stroke="%s" stroke-width="1.2"/></svg>'
    ),
    px, px, px, px, body, fill, stroke
  )
}

# Colours and legend entries of a feature layer, as in tmr_map_draw_feature()
tmr_web_colours <- function(ly, d) {
  if (is.null(ly$col)) {
    col <- if (is.na(ly$const)) NA_character_ else ly$const
    return(list(
      colour = rep(col, nrow(d)), values = stats::setNames(col, ly$label),
      title = ly$group
    ))
  }
  v <- d[[ly$col]]
  if (is.numeric(v) && length(unique(v)) > 7) {
    cls <- geo_classify(d, !!rlang::sym(ly$col), n = ly$n, style = ly$style, name = ".class")
    levs <- levels(cls$.class)
    gr <- tmr_graduated(v, ly$col)
    values <- stats::setNames(tmr_ramp(ly$palette, gr, length(levs)), levs)
    colour <- unname(values[as.character(cls$.class)])
  } else {
    levs <- sort(unique(as.character(v)))
    pal <- if (identical(ly$palette, "auto")) {
      tmr_palette(length(levs))
    } else {
      tmr_ramp(ly$palette, NULL, length(levs))
    }
    values <- stats::setNames(pal, levs)
    colour <- unname(values[as.character(v)])
  }
  list(colour = colour, values = values, title = ly$group %||% ly$col)
}

tmr_web_feature <- function(ly, id, popup) {
  d <- sf::st_transform(ly$data, 4326)
  d <- d[!sf::st_is_empty(d), ]
  lk <- ly$look
  col <- tmr_web_colours(ly, d)
  col$colour <- tmr_web_hex(col$colour)
  col$values <- stats::setNames(tmr_web_hex(unname(col$values)), names(col$values))
  lk$border <- tmr_web_hex(lk$border %||% "grey30")
  # Popup attributes: plain columns, at most 12
  attrs <- sf::st_drop_geometry(d)
  attrs <- attrs[, vapply(attrs, function(v) is.atomic(v) && !is.list(v), TRUE), drop = FALSE]
  attrs <- attrs[, utils::head(seq_along(attrs), 12), drop = FALSE]
  for (j in seq_along(attrs)) {
    if (is.numeric(attrs[[j]])) attrs[[j]] <- signif(attrs[[j]], 6)
    attrs[[j]] <- as.character(attrs[[j]])
  }
  props <- attrs
  props$`_c` <- col$colour
  g <- sf::st_sf(props, geometry = sf::st_geometry(d))
  tf <- tempfile(fileext = ".geojson")
  on.exit(unlink(tf), add = TRUE)
  sf::st_write(g, tf, driver = "GeoJSON", quiet = TRUE, layer_options = "COORDINATE_PRECISION=6")
  gj <- paste(readLines(tf, warn = FALSE), collapse = "")
  shape <- tmr_web_shape(lk$shape)
  style <- switch(ly$kind,
    polygon = list(
      fillOpacity = if (is.null(ly$col) && is.na(ly$const)) 0 else 0.75 * (lk$alpha %||% 1),
      color = lk$border %||% "#444444", weight = max(0.5, (lk$linewidth %||% 0.3) * 3.8),
      dashArray = tmr_web_dash(lk$linetype)
    ),
    line = list(
      weight = max(1, (lk$linewidth %||% 0.6) * 3.8), opacity = lk$alpha %||% 1,
      dashArray = tmr_web_dash(lk$linetype)
    ),
    point = list(
      size = max(8, (lk$size %||% 2.5) * 5), border = lk$border %||% "#222222",
      shape = shape
    )
  )
  js <- sprintf(
    "addFeatures(%s, %s, %s, %s, %s);",
    tmr_web_json(id), gj, tmr_web_json(ly$kind), tmr_web_json(style),
    tmr_web_json(list(name = col$title %||% ly$label, popup = isTRUE(popup)))
  )
  # Legend section with the same symbols
  entries <- vapply(seq_along(col$values), function(k) {
    cc <- col$values[[k]]
    sym <- switch(ly$kind,
      polygon = tmr_web_swatch(cc, lk$border, style),
      line = tmr_web_line_key(cc, style),
      point = tmr_web_svg_point(shape, cc, style$border)
    )
    key <- htmltools::htmlEscape(names(col$values)[k])
    sprintf('<div class="lg-row">%s<span>%s</span></div>', sym, key)
  }, "")
  head <- ""
  if (!is.null(col$title)) {
    head <- sprintf('<div class="lg-title">%s</div>', htmltools::htmlEscape(col$title))
  }
  legend <- paste0('<div class="lg-sec">', head, paste(entries, collapse = ""), "</div>")
  bb <- as.numeric(sf::st_bbox(d))
  list(js = js, legend = legend, bbox = bb)
}

tmr_web_raster <- function(ly, id, max_pixels) {
  rlang::check_installed("terra")
  r <- ly$data
  r <- terra::project(r, "EPSG:3857", method = "bilinear")
  f <- ceiling(max(dim(r)[1:2]) / max_pixels)
  if (f > 1) r <- terra::aggregate(r, f, fun = "mean", na.rm = TRUE)
  m <- terra::as.matrix(r, wide = TRUE)
  vr <- range(m, na.rm = TRUE)
  gr <- tmr_graduated(as.vector(m), ly$name)
  pal <- tmr_web_hex(tmr_ramp(ly$palette, gr, 9))
  ramp <- grDevices::colorRamp(pal)
  t01 <- (m - vr[1]) / max(diff(vr), 1e-12)
  rgbv <- ramp(pmin(pmax(as.vector(t01), 0), 1)) / 255
  na <- is.na(as.vector(m))
  rgbv[na, ] <- 0
  arr <- array(0, c(nrow(m), ncol(m), 4))
  for (k in 1:3) arr[, , k] <- matrix(rgbv[, k], nrow(m), ncol(m))
  arr[, , 4] <- matrix(ifelse(na, 0, ly$alpha %||% 1), nrow(m), ncol(m))
  b64 <- gsub("[\r\n]", "", jsonlite::base64_enc(png::writePNG(arr)))
  e <- terra::ext(r)
  corners <- sf::st_transform(sf::st_sfc(
    sf::st_point(c(e$xmin, e$ymin)), sf::st_point(c(e$xmax, e$ymax)),
    crs = 3857
  ), 4326)
  cc <- sf::st_coordinates(corners)
  js <- sprintf(
    "addImage(%s, 'data:image/png;base64,%s', [[%f,%f],[%f,%f]], %s);",
    tmr_web_json(id), b64, cc[1, 2], cc[1, 1], cc[2, 2], cc[2, 1], tmr_web_json(ly$name)
  )
  pct <- seq(0, 100, length.out = length(pal))
  stops <- paste(sprintf("%s %.0f%%", rev(pal), pct), collapse = ",")
  legend <- sprintf(
    paste0(
      '<div class="lg-sec"><div class="lg-title">%s</div><div class="lg-bar">',
      '<span class="bar" style="background:linear-gradient(to bottom,%s)"></span>',
      '<span class="ticks"><span>%s</span><span>%s</span></span></div></div>'
    ),
    htmltools::htmlEscape(ly$name), stops, format(signif(vr[2], 4), big.mark = ","),
    format(signif(vr[1], 4), big.mark = ",")
  )
  list(js = js, legend = legend, bbox = c(cc[1, 1], cc[1, 2], cc[2, 1], cc[2, 2]))
}

tmr_web_labels <- function(ly, id) {
  d <- sf::st_transform(ly$data, 4326)
  pts <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(d)))
  xy <- sf::st_coordinates(pts)
  lab <- data.frame(lat = xy[, 2], lng = xy[, 1], text = as.character(d[[ly$col]]))
  js <- sprintf("addLabels(%s, %s);", tmr_web_json(id), jsonlite::toJSON(lab, dataframe = "rows"))
  list(js = js, legend = NULL, bbox = c(min(xy[, 1]), min(xy[, 2]), max(xy[, 1]), max(xy[, 2])))
}

# ---- page -------------------------------------------------------------------

tmr_web_page <- function(title, subtitle, caption, js_layers, legend, bounds, basemap) {
  esc <- htmltools::htmlEscape
  read <- function(f) {
    paste(readLines(system.file("webmap", f, package = "tidymapr"), warn = FALSE), collapse = "\n")
  }
  sub <- if (!is.null(subtitle)) sprintf('<div class="sub">%s</div>', esc(subtitle)) else ""
  cap <- if (!is.null(caption)) sprintf('<div class="cap">%s</div>', esc(caption)) else ""
  opts <- list(
    basemap = switch(basemap,
      topo = "Topographic (Esri)",
      imagery = "Imagery (Esri)",
      osm = "OpenStreetMap",
      light = "Light (CARTO)"
    ),
    title = paste0('<div class="ttl">', esc(title), "</div>", sub),
    legend = paste0(paste(legend, collapse = ""), cap),
    bounds = list(c(bounds[2], bounds[1]), c(bounds[4], bounds[3]))
  )
  page <- read("template.html")
  fill <- list(
    TITLE = esc(title), CSS = read("webmap.css"), JS = read("webmap.js"),
    LAYERS = paste(js_layers, collapse = "\n"), OPTIONS = tmr_web_json(opts)
  )
  # Fill the template in one pass, so no inserted text is read as a marker
  parts <- strsplit(page, "\\{\\{|\\}\\}")[[1]]
  keys <- seq(2, length(parts), by = 2)
  parts[keys] <- vapply(parts[keys], function(k) fill[[k]] %||% "", "")
  paste(parts, collapse = "")
}

tmr_web_swatch <- function(fill, border, style) {
  sprintf(
    '<span class="sw" style="background:%s;border:%spx %s %s"></span>',
    if (is.na(fill)) "transparent" else fill, max(1, round(style$weight / 2)),
    if (is.null(style$dashArray)) "solid" else "dashed", border
  )
}

tmr_web_line_key <- function(colour, style) {
  dash <- if (is.null(style$dashArray)) "" else sprintf(' stroke-dasharray="%s"', style$dashArray)
  sprintf(
    paste0(
      '<svg width="26" height="12"><line x1="1" y1="6" x2="25" y2="6" ',
      'stroke="%s" stroke-width="%s"%s/></svg>'
    ),
    colour, min(style$weight, 5), dash
  )
}
