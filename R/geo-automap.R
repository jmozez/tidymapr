#' Automatic publication maps that explain their choices
#'
#' @description
#' `geo_automap()` draws a finished map from one call, in the spirit of
#' GeoSpaX's AutoMap. It looks at your data and chooses, with a reason for
#' each choice:
#'
#' * **projection**: Equal Earth for world-wide data (true areas), a
#'   Lambert azimuthal equal-area projection centred on the data for
#'   continents and large regions, and the local UTM zone for study areas
#'   (distances in metres);
#' * **symbology**, following the conventions of GeoSpaX's AutoMap, ArcGIS
#'   and QGIS:
#'   - numbers on points, lines or polygons get **graduated colours in
#'     classes** (a classed legend, never a continuous ramp). The method
#'     follows the shape of the data: equal intervals when roughly
#'     symmetric (|skew| < 0.5), natural breaks (Jenks) when skewed, and
#'     quantiles when heavy-tailed (|skew| >= 2); 5 classes for 30 or more
#'     features, fewer for small samples;
#'   - the colour ramp follows the field's meaning: blues for water and
#'     rain, greens for vegetation, viridis for elevation, slope and
#'     predictions, a diverging ramp when values cross zero, and
#'     yellow-orange-red otherwise;
#'   - small whole-number counts on points get proportional circles;
#'   - categories get qualitative Okabe-Ito colours; features without a
#'     value get a single symbol;
#'   - **continuous surfaces** (a raster `x`, or a `background` such as a
#'     DEM under your sites) get a stretched colour ramp with a gradient
#'     legend, the only place a gradient legend is used;
#' * **basemap**: none for world and regional maps or under a background
#'   surface; topographic tiles for study areas, as muted context that is
#'   not in the legend (the coastline when offline);
#' * **furniture**: graticule and world outline on world maps; scale bar
#'   and north arrow on regional and local maps, in corners chosen to avoid
#'   the data.
#'
#' Everything can be overridden through the arguments, and the result is a
#' normal ggplot you can keep editing. `geo_automap_explain()` returns the
#' decisions as a table, ready for a methods section.
#'
#' @param x An `sf` table (points, lines or polygons) or a `SpatRaster`.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Column to map.
#'   Omit to map the features alone (or the first raster layer).
#' @param projection `"auto"` or any name accepted by [coord_projection()].
#' @param style `"auto"` or a [geo_classify()] style for graduated colours.
#' @param n Number of classes, or `"auto"` (5 for 30 or more features,
#'   fewer for small samples).
#' @param basemap `"auto"` or a basemap name for [geo_basemap()].
#' @param background Optional continuous surface (`SpatRaster` or file
#'   path), for example a DEM or a rainfall layer, drawn under the features
#'   with a gradient legend. With a background, the features are shown as
#'   sites (single symbol, or classes when `value` is given) and no tile
#'   basemap is added.
#' @param background_title Legend title for the background.
#' @param palette,background_palette Colour ramp for the features and for
#'   the background surface: `"auto"` (chosen from the field's meaning),
#'   any palette name from [grDevices::hcl.pals()] (for example
#'   `"viridis"`, `"Blues 3"`, `"YlOrRd"`, `"Terrain 2"`, `"RdYlBu"`), or a
#'   vector of colours. For categories, a vector of colours replaces the
#'   Okabe-Ito colours.
#' @param title,legend_title Map and legend titles.
#' @param scale_bar,north_arrow `"auto"`, `FALSE`, or a style name (see
#'   [annotation_scale_bar()]).
#' @return A ggplot with attribute `"automap"`, the table of decisions.
#' @seealso [geo_classify()], [coord_projection()], [plot_choropleth()],
#'   [plot_bubble()]
#' @export
#' @examplesIf rlang::is_installed(c("ggplot2", "sf", "spData"))
#' # World: life expectancy by country (spData::world)
#' library(sf)
#' m <- geo_automap(spData::world, lifeExp, legend_title = "Life expectancy")
#' m
#' geo_automap_explain(m)
#'
#' # Region: North Carolina SIDS rate 1974-78 (shipped with sf)
#' nc <- st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
#' nc$sids_rate <- 1000 * nc$SID74 / nc$BIR74
#' geo_automap(nc, sids_rate, legend_title = "SIDS per 1000 births")
#'
#' # Study area: the 16 Mt Wilhelm ant transects, classed by elevation
#' sites <- geo_as_sf(png_ants_sites, lon, lat)
#' geo_automap(sites, elevation, legend_title = "Elevation (m)")
#'
#' # Choose your own ramps: an hcl palette name or any colours
#' geo_automap(nc, sids_rate, palette = "Purples 3")
#' geo_automap(nc, sids_rate, palette = c("white", "orange", "darkred"))
#'
#' # Sites over a continuous surface: the surface gets the gradient legend
#' # (here Luxembourg's elevation, shipped with terra, under its cantons)
#' if (rlang::is_installed("terra")) {
#'   dem <- terra::rast(system.file("ex/elev.tif", package = "terra"))
#'   lux <- st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#'   towns <- suppressWarnings(st_centroid(lux))
#'   geo_automap(towns, background = dem, background_title = "Elevation (m)")
#' }
geo_automap <- function(x,
                        value = NULL,
                        projection = "auto",
                        style = "auto",
                        n = "auto",
                        basemap = "auto",
                        background = NULL,
                        background_title = NULL,
                        palette = "auto",
                        background_palette = "auto",
                        title = NULL,
                        legend_title = NULL,
                        scale_bar = "auto",
                        north_arrow = "auto") {
  rlang::check_installed(c("ggplot2", "sf"))
  decisions <- list()
  note <- function(what, choice, reason) {
    decisions[[what]] <<- tibble::tibble( # nolint: assignment_linter.
      element = what, choice = choice, reason = reason
    )
  }
  is_raster <- inherits(x, "SpatRaster")
  if (!is_raster && !inherits(x, "sf")) {
    cli::cli_abort("{.arg x} must be an {.cls sf} table or a {.cls SpatRaster}.")
  }
  has_bg <- !is.null(background)

  # ---- extent and scale ---------------------------------------------------
  bb <- if (is_raster) {
    rlang::check_installed("terra")
    e <- terra::project(terra::as.polygons(terra::ext(x), crs = terra::crs(x)), "EPSG:4326")
    stats::setNames(as.vector(terra::ext(e))[c(1, 3, 2, 4)], c("xmin", "ymin", "xmax", "ymax"))
  } else {
    tmr_bbox_lonlat(x)
  }
  span <- max(bb["xmax"] - bb["xmin"], (bb["ymax"] - bb["ymin"]) * 2)
  scale_class <- if (span > 120) "world" else if (span > 8) "region" else "local"

  # ---- geometry and value -------------------------------------------------
  val_quo <- enquo(value)
  geom_kind <- if (is_raster) {
    "raster"
  } else {
    g <- unique(as.character(sf::st_geometry_type(x)))
    if (all(g %in% c("POLYGON", "MULTIPOLYGON"))) {
      "polygon"
    } else if (all(g %in% c("POINT", "MULTIPOINT"))) {
      "point"
    } else {
      "line"
    }
  }
  col <- if (!rlang::quo_is_null(val_quo) && !is_raster) tmr_pick(val_quo, x, "value") else NULL
  vals <- if (!is.null(col)) x[[col]] else NULL
  numeric_val <- is.numeric(vals)
  vv <- if (numeric_val) vals[!is.na(vals)] else numeric()
  # Counts: whole, non-negative and small (species, individuals); large
  # whole numbers such as elevations or years are measurements, not counts
  counts <- numeric_val && length(vv) > 0 && all(vv >= 0) &&
    all(abs(vv - round(vv)) < 1e-8) && stats::median(vv) <= 500 &&
    geom_kind == "point"
  # With a background surface, features must leave the fill scale to it
  feat_aes <- if (has_bg) "colour" else "fill"

  # ---- symbology ------------------------------------------------------------
  if (is_raster) {
    rr <- terra::project(x[[1]], "EPSG:4326")
    rdf <- terra::as.data.frame(rr, xy = TRUE, na.rm = TRUE)
    p <- tmr_add_surface(
      ggplot2::ggplot() + theme_tidymapr(grid = "none", legend_position = "right"),
      rdf, names(rdf)[3], legend_title %||% names(rdf)[3],
      palette = palette
    )
    note("symbology", "stretched colour ramp", paste(
      "A continuous surface: stretched colour ramp with a gradient legend",
      "(ArcGIS 'Stretch', QGIS 'Singleband pseudocolor')."
    ))
  } else if (numeric_val && !counts) {
    gr <- tmr_graduated(vv, col)
    k <- if (identical(n, "auto")) gr$n else n
    sty <- if (identical(style, "auto")) gr$style else style
    cls <- geo_classify(x, !!rlang::sym(col), n = k, style = sty, name = ".class")
    levs <- levels(cls$.class)
    pal <- stats::setNames(tmr_ramp(palette, gr, length(levs)), levs)
    if (!identical(palette, "auto")) {
      gr$palette <- if (length(palette) == 1) palette else "custom colours"
    }
    info <- attr(cls, "classification")
    p <- ggplot2::ggplot(cls) +
      tmr_feature_layer(geom_kind, ".class", feat_aes) +
      tmr_manual_scale(geom_kind, feat_aes, pal, legend_title %||% col) +
      theme_tidymapr(grid = "none", legend_position = "right")
    why <- if (identical(style, "auto")) gr$why else "Classification chosen by the user."
    note(
      "symbology",
      sprintf("graduated colours (%s, %d classes, %s)", sty, length(levs), gr$palette),
      sprintf("%s Goodness of variance fit %.2f.", why, info$gvf)
    )
  } else if (counts && !has_bg) {
    p <- plot_bubble(x, !!rlang::sym(col), legend_title = legend_title %||% col)
    note(
      "symbology", "proportional circles",
      "Counts on points: circle area proportional to the count."
    )
  } else if (!is.null(col)) {
    lev <- sort(unique(as.character(vals)))
    pal <- if (identical(palette, "auto")) {
      tmr_palette(length(lev))
    } else {
      tmr_ramp(palette, NULL, length(lev))
    }
    pal <- stats::setNames(pal, lev)
    x$.class <- factor(as.character(vals), levels = lev)
    p <- ggplot2::ggplot(x) +
      tmr_feature_layer(geom_kind, ".class", feat_aes) +
      tmr_manual_scale(geom_kind, feat_aes, pal, legend_title %||% col) +
      theme_tidymapr(grid = "none", legend_position = "right")
    note("symbology", "qualitative colours", sprintf(
      "%d categories: Okabe-Ito colours, distinguishable with colour blindness.", length(lev)
    ))
  } else {
    p <- if (geom_kind == "point") {
      ggplot2::ggplot(x) +
        ggplot2::geom_sf(ggplot2::aes(shape = "Sites"),
          fill = "white", colour = "grey10", size = 2.8, stroke = 0.7
        ) +
        ggplot2::scale_shape_manual(values = c(Sites = 21), name = NULL) +
        theme_tidymapr(grid = "none", legend_position = "right")
    } else {
      ggplot2::ggplot(x) +
        ggplot2::geom_sf(fill = NA, colour = "grey15", linewidth = 0.4) +
        theme_tidymapr(grid = "none", legend_position = "right")
    }
    note("symbology", "single symbol", "No value: sites or features in one neutral symbol.")
  }

  # ---- background surface ---------------------------------------------------
  if (has_bg) {
    rlang::check_installed("terra")
    bg <- terra::project(geo_as_raster(background)[[1]][[1]], "EPSG:4326")
    bdf <- terra::as.data.frame(bg, xy = TRUE, na.rm = TRUE)
    btitle <- background_title %||% names(bdf)[3]
    p <- tmr_add_surface(p, bdf, names(bdf)[3], btitle,
      under = TRUE,
      palette = background_palette
    )
    note("background", paste("stretched colour ramp:", btitle), paste(
      "A continuous surface under the features: gradient legend for the surface,",
      "while the sites on top keep their own symbol legend."
    ))
  }

  # ---- basemap ----------------------------------------------------------------
  if (identical(basemap, "auto")) {
    basemap <- if (!has_bg && scale_class == "local" && geom_kind %in% c("point", "line")) {
      "esri_topo"
    } else {
      "none"
    }
    note("basemap", basemap, if (basemap != "none") {
      "Study area with points or lines: topographic tiles as muted context, not in the legend."
    } else if (has_bg) {
      "The background surface gives the context."
    } else {
      "Polygons, rasters and large extents need no basemap."
    })
  } else {
    note("basemap", basemap, "Chosen by the user.")
  }
  tiles <- !identical(basemap, "none") && !is_raster

  # ---- projection ---------------------------------------------------------------
  raster_layers <- tiles || has_bg || is_raster
  if (identical(projection, "auto")) {
    if (raster_layers && scale_class != "world") {
      projection <- "lonlat"
      note("projection", projection, paste(
        "Raster layers (tiles or a surface) are drawn on their own longitude/latitude grid;",
        "the scale bar is still measured on the ground."
      ))
    } else {
      projection <- switch(scale_class,
        world = "equal_earth",
        region = "laea",
        local = "utm"
      )
      note("projection", projection, switch(scale_class,
        world = sprintf("Data span %.0f degrees: a world map; Equal Earth keeps true areas.", span),
        region = sprintf(
          "Data span %.0f degrees: a region; Lambert equal-area centred on the data.", span
        ),
        local = sprintf(
          "Data span %.1f degrees: a study area; local UTM zone, distances in metres.", span
        )
      ))
    }
  } else {
    note("projection", projection, "Chosen by the user.")
  }

  pad_bb <- function(b, f) {
    dx <- max(b["xmax"] - b["xmin"], 1e-6) * f
    dy <- max(b["ymax"] - b["ymin"], 1e-6) * f
    unname(c(b["xmin"] - dx, b["xmax"] + dx, b["ymin"] - dy, b["ymax"] + dy))
  }
  if (tiles) {
    pb <- pad_bb(bb, 0.25)
    bm <- suppressMessages(geo_basemap(
      stats::setNames(pb[c(1, 3, 2, 4)], c("xmin", "ymin", "xmax", "ymax")),
      basemap = basemap
    ))
    keep <- vapply(bm$layers, inherits, logical(1), "LayerInstance")
    p$layers <- c(bm$layers[keep], p$layers)
    if (!is.null(bm$attribution)) p <- p + ggplot2::labs(caption = bm$attribution)
  }
  centre <- if (is_raster) bb else x
  if (scale_class == "world") {
    p <- p + coord_projection(projection, data = centre) + map_graticule(30, outline = TRUE)
    note(
      "graticule", "30 degrees, world outline",
      "World map: graticule and outline show the projection."
    )
  } else {
    crs <- geo_crs(projection, data = centre)
    pbb <- sf::st_bbox(sf::st_transform(
      sf::st_as_sfc(sf::st_bbox(bb, crs = sf::st_crs(4326))), crs
    ))
    f <- if (geom_kind %in% c("point", "line") && !has_bg) 0.15 else 0.02
    lim <- pad_bb(pbb, f)
    p <- p + coord_projection(projection, data = centre, xlim = lim[1:2], ylim = lim[3:4])
  }

  # ---- furniture ------------------------------------------------------------------
  sb <- if (identical(scale_bar, "auto")) {
    if (scale_class == "world") FALSE else "pill"
  } else {
    scale_bar
  }
  na <- if (identical(north_arrow, "auto")) {
    if (scale_class == "world") FALSE else "needle"
  } else {
    north_arrow
  }
  sb <- tmr_furniture_style(sb, "scale")
  na <- tmr_furniture_style(na, "north")
  corners <- tmr_automap_corners(if (is_raster) NULL else x)
  if (!is.null(sb)) {
    p <- p + annotation_scale_bar(sb, location = corners[1])
    note(
      "scale bar", paste(sb, "at", corners[1]),
      "Distances matter at this scale; corner with the fewest features."
    )
  } else if (scale_class == "world") {
    note("scale bar", "none", "Scale varies across a world map, so a single bar would mislead.")
  }
  if (!is.null(na)) {
    p <- p + annotation_north_arrow(na, location = corners[2])
    note("north arrow", paste(na, "at", corners[2]), "Second-emptiest corner.")
  }
  p <- p + ggplot2::labs(x = NULL, y = NULL)
  if (!is.null(title)) p <- p + ggplot2::labs(title = title)
  order <- c(
    "projection", "symbology", "background", "basemap", "graticule",
    "scale bar", "north arrow"
  )
  attr(p, "automap") <- do.call(rbind, unname(decisions[intersect(order, names(decisions))]))
  p
}

#' @rdname geo_automap
#' @param map A map from `geo_automap()`.
#' @export
geo_automap_explain <- function(map) {
  out <- attr(map, "automap")
  if (is.null(out)) {
    cli::cli_abort("{.arg map} was not made by {.fn geo_automap}.")
  }
  out
}

# GeoSpaX AutoMap rules for graduated colours: method from the shape of the
# distribution, number of classes from the sample size, ramp from the
# field's meaning (crates/engine/src/automation/automap.rs)
tmr_graduated <- function(v, field) {
  v <- v[is.finite(v)]
  nv <- length(v)
  skew <- if (nv > 2 && stats::sd(v) > 0) mean((v - mean(v))^3) / stats::sd(v)^3 else 0
  k <- if (nv >= 30) 5L else as.integer(min(max(ceiling(log2(max(nv, 1)) + 1), 3), 5))
  k <- max(1L, min(k, length(unique(v))))
  shape <- if (abs(skew) < 0.5) {
    "roughly symmetric"
  } else if (abs(skew) < 2) {
    if (skew > 0) "right-skewed" else "left-skewed"
  } else {
    "heavy-tailed"
  }
  style <- if (abs(skew) < 0.5) "equal" else if (abs(skew) < 2) "jenks" else "quantile"
  lname <- tolower(field)
  has <- function(w) any(vapply(w, grepl, logical(1), x = lname, fixed = TRUE))
  neg <- if (nv) mean(v < 0) else 0
  pal <- if (nv && min(v) < 0 && max(v) > 0 && neg >= 0.1 && neg <= 0.9) {
    list(p = "RdYlBu", rev = FALSE, why = "values cross zero: diverging red-yellow-blue")
  } else if (has(c("water", "rain", "depth", "moist", "precip", "humid"))) {
    list(p = "Blues 3", rev = TRUE, why = "water: blues")
  } else if (has(c("ndvi", "veg", "green", "tree", "forest", "crop", "yield", "biomass"))) {
    list(p = "Greens 3", rev = TRUE, why = "vegetation: greens")
  } else if (has(c("elev", "alt", "height", "dem", "slope", "prediction", "variance", "ph"))) {
    list(p = "viridis", rev = FALSE, why = "elevation or a model surface: viridis")
  } else {
    list(p = "YlOrRd", rev = TRUE, why = "general quantity: yellow-orange-red")
  }
  method <- switch(style,
    equal = "equal intervals",
    jenks = "natural breaks (Jenks)",
    quantile = "quantiles (every class equally full)"
  )
  list(
    n = k, style = style, palette = pal$p, rev = pal$rev,
    why = sprintf(
      "'%s' is numeric and %s (n = %d, skew %.1f), so %s in %d classes; ramp: %s.",
      field, shape, nv, skew, method, k, pal$why
    )
  )
}

# Features coloured by a class column, through fill (default) or colour
# (when a background surface owns the fill scale)
tmr_feature_layer <- function(geom_kind, col, how) {
  if (geom_kind == "polygon") {
    if (how == "fill") {
      ggplot2::geom_sf(ggplot2::aes(fill = .data[[col]]), colour = "grey30", linewidth = 0.2)
    } else {
      ggplot2::geom_sf(ggplot2::aes(colour = .data[[col]]), fill = NA, linewidth = 0.7)
    }
  } else if (geom_kind == "point") {
    if (how == "fill") {
      ggplot2::geom_sf(ggplot2::aes(fill = .data[[col]]),
        shape = 21, colour = "grey15", size = 3, stroke = 0.4
      )
    } else {
      ggplot2::geom_sf(ggplot2::aes(colour = .data[[col]]), shape = 16, size = 3)
    }
  } else {
    ggplot2::geom_sf(ggplot2::aes(colour = .data[[col]]), linewidth = 0.8)
  }
}

tmr_manual_scale <- function(geom_kind, how, values, name) {
  f <- if (how == "colour" || geom_kind == "line") {
    ggplot2::scale_colour_manual
  } else {
    ggplot2::scale_fill_manual
  }
  f(values = values, drop = FALSE, na.value = "grey85", name = name)
}

# A continuous surface: stretched ramp with a gradient legend; `under` puts
# it below the existing layers
tmr_add_surface <- function(p, df, nm, title, under = FALSE, palette = "auto") {
  gr <- tmr_graduated(df[[nm]], title)
  layer <- ggplot2::geom_raster(
    data = df, ggplot2::aes(.data$x, .data$y, fill = .data[[nm]]),
    inherit.aes = FALSE, interpolate = TRUE
  )
  p$layers <- if (under) c(list(layer), p$layers) else c(p$layers, list(layer))
  p + ggplot2::scale_fill_gradientn(
    colours = tmr_ramp(palette, gr, 9),
    name = title, guide = ggplot2::guide_colourbar(order = 99)
  )
}

# Bounding box in longitude/latitude. Transforming the bbox polygon can fail
# when PROJ wants a datum grid it cannot fetch; fall back to the features
# and, for geographic data, to the raw bbox.
tmr_bbox_lonlat <- function(x) {
  good <- function(b) all(is.finite(b)) && b["ymax"] > b["ymin"] && b["xmax"] > b["xmin"]
  b <- tryCatch(sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(x)), 4326)),
    error = function(e) NULL
  )
  if (!is.null(b) && good(b)) return(b)
  b <- tryCatch(sf::st_bbox(sf::st_transform(x, 4326)), error = function(e) NULL)
  if (!is.null(b) && good(b)) return(b)
  sf::st_bbox(x)
}

# The two corners holding the fewest features: scale bar, then north arrow
tmr_automap_corners <- function(x) {
  corners <- c("bl", "br", "tl", "tr")
  if (is.null(x)) return(c("bl", "tr"))
  geom <- sf::st_geometry(x)
  xy <- suppressWarnings(sf::st_coordinates(sf::st_centroid(geom)))[, 1:2, drop = FALSE]
  bb <- sf::st_bbox(x)
  fx <- (xy[, 1] - bb["xmin"]) / max(bb["xmax"] - bb["xmin"], 1e-9)
  fy <- (xy[, 2] - bb["ymin"]) / max(bb["ymax"] - bb["ymin"], 1e-9)
  count <- c(
    bl = sum(fx < 0.3 & fy < 0.3), br = sum(fx > 0.7 & fy < 0.3),
    tl = sum(fx < 0.3 & fy > 0.7), tr = sum(fx > 0.7 & fy > 0.7)
  )
  pref <- c(bl = 1, br = 2, tl = 4, tr = 3)
  ord <- corners[order(count[corners], pref[corners])]
  rest <- setdiff(ord, ord[1])
  arrow <- rest[order(count[rest], -match(rest, corners))][1]
  c(ord[1], arrow)
}

# Colours from "auto" (the GeoSpaX ramp in `gr`), an hcl palette name, or a
# vector of colours (interpolated to n)
tmr_ramp <- function(palette, gr, n, call = caller_env()) {
  n <- max(n, 1)
  if (identical(palette, "auto")) {
    return(grDevices::hcl.colors(max(n, 2), gr$palette, rev = gr$rev)[seq_len(n)])
  }
  if (length(palette) == 1 && palette %in% grDevices::hcl.pals()) {
    return(grDevices::hcl.colors(max(n, 2), palette)[seq_len(n)])
  }
  ok <- tryCatch(
    {
      grDevices::col2rgb(palette)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!ok) {
    cli::cli_abort(
      "{.arg palette} must be {.val auto}, a name from {.fn grDevices::hcl.pals}, or colours.",
      call = call
    )
  }
  if (length(palette) == n) palette else grDevices::colorRampPalette(palette)(n)
}
