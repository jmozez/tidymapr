#' Publication-ready study-site maps
#'
#' @description
#' `plot_sites()` draws sampling locations for a manuscript figure: points
#' from an `sf` table or longitude/latitude columns, optional grouping as
#' colour and shape, non-overlapping labels, an optional raster or coastline
#' backdrop, faceting, a simple scale bar and a north arrow. The result is a
#' ggplot object, so further layers can be added. Diversity values mapped as
#' a continuous fill still use [plot_geo()]; this verb is for the study-site
#' map that papers usually need first.
#'
#' The Mt Wilhelm ant data ([tidydiversity::png_ants]) come with published bait GPS
#' positions in [png_ants_sites]; [geo_example_sites()] returns them as one
#' point per elevation band, ready to join by `site`.
#'
#' SDM tools such as biomod2 and Maxent are out of scope here; they can be
#' rebuilt later as tidy verbs.
#'
#' @param data A data frame of sites (or occurrence records) with
#'   coordinates, or an `sf` object.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns when `data` is not `sf`.
#' @param colour,shape <[`data-masking`][dplyr::dplyr_data_masking]> Optional
#'   grouping columns (habitat, elevation band, forest type, season).
#' @param label <[`data-masking`][dplyr::dplyr_data_masking]> Optional site
#'   labels; overplotting is avoided with **ggrepel** when installed.
#' @param facet <[`data-masking`][dplyr::dplyr_data_masking]> Optional column
#'   to facet by (taxon, season).
#' @param basemap Basemap for the figure: `"none"`, `"coast"`, `"osm"`,
#'   `"carto"`, `"carto_dark"`, `"esri"`, a `SpatRaster`, or a file path.
#'   See [geo_basemap()]. Online tiles fall back to `"coast"` offline.
#' @param raster Optional `terra::SpatRaster` or file path used as an
#'   elevation / climate backdrop (same as passing that object to
#'   `basemap`). Ignored when `basemap` is not `"none"`.
#' @param coastline Optional `sf` lines or polygons (for example a country
#'   outline) drawn under the sites when using a coast basemap.
#' @param occurrence Optional second data frame of species records with the
#'   same coordinate columns, drawn as smaller points underneath the sites.
#' @param size Point size for sites.
#' @param occurrence_size Point size for occurrence records.
#' @param scale_bar,north_arrow Draw a scale bar and north arrow? `TRUE`
#'   uses the default style, `FALSE` none, or name a style: scale bars
#'   `"pill"`, `"checker"`, `"line"`, `"ruler"`; north arrows `"needle"`,
#'   `"compass"`, `"rose"`, `"minimal"` (see [annotation_scale_bar()]).
#' @param scale_units Scale bar units: `"metric"`, `"imperial"` or `"both"`.
#' @param scale_bar_km Length of the scale bar in kilometres. When `NULL`,
#'   a round length is chosen from the map extent (true metres via a local
#'   UTM projection when the map CRS is geographic).
#' @param palette Discrete palette: `"okabe_ito"` or `"grey"`.
#' @param size Point size, or a bare column name mapped to point size
#'   (combined with `colour` when both are set, like tmap size + col).
#' @param legend_title Optional legend title (defaults to the colour column).
#' @param legend_position `"auto"` (collision-aware inside corner),
#'   `"outside"`, or a corner `"bl"` / `"br"` / `"tl"` / `"tr"`.
#' @param legend_frame Draw a frame around an inside legend?
#' @param inset Overview / locator map: `FALSE`, `TRUE` / `"auto"`,
#'   `"png"` (Papua New Guinea), or a length-4 bbox
#'   `c(xmin, ymin, xmax, ymax)`. Placed in a free corner that does not
#'   overlap sites, the scale bar, north arrow or inside legend. When
#'   GADM data are cached, the PNG inset uses province boundaries from
#'   [geo_gadm()].
#' @param admin Optional administrative boundaries: an `sf` object (for
#'   example from [geo_gadm()]), or an ISO3 country code that is fetched
#'   with `geo_gadm(admin, level = admin_level)`. Drawn as borders, or
#'   filled by province when `admin_fill` is `TRUE`.
#' @param admin_level GADM level used when `admin` is a country code
#'   (`0` country, `1` province, `2` district).
#' @param admin_fill Fill administrative polygons (province choropleth
#'   colours) instead of outline-only borders.
#' @return A ggplot object. Attribute `tmr_decoration` holds the reserved
#'   corner boxes (for tests and debugging).
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' sites <- geo_example_sites("wilhelm")
#' plot_sites(sites, lon, lat, colour = elevation_band, label = site,
#'   basemap = "coast")
#'
#' # Facet by a grouping column
#' sites$season <- rep(c("dry", "wet"), length.out = nrow(sites))
#' plot_sites(sites, lon, lat, colour = elevation_band, facet = season)
plot_sites <- function(data,
                       lon = lon,
                       lat = lat,
                       colour = NULL,
                       shape = NULL,
                       label = NULL,
                       facet = NULL,
                       basemap = "esri",
                       raster = NULL,
                       coastline = NULL,
                       occurrence = NULL,
                       size = 3.2,
                       occurrence_size = 1.4,
                       scale_bar = TRUE,
                       north_arrow = TRUE,
                       scale_bar_km = NULL,
                       scale_units = c("metric", "imperial", "both"),
                       palette = c("okabe_ito", "grey"),
                       legend_title = NULL,
                       legend_position = "auto",
                       legend_frame = TRUE,
                       inset = FALSE,
                       admin = NULL,
                       admin_level = 1,
                       admin_fill = FALSE) {
  rlang::check_installed("ggplot2")
  rlang::check_installed("sf")
  scale_units <- rlang::arg_match(scale_units)
  sb_style <- tmr_furniture_style(scale_bar, "scale")
  na_style <- tmr_furniture_style(north_arrow, "north")
  palette <- rlang::arg_match(palette)
  tmr_check_data(data)

  col_q <- enquo(colour)
  shp_q <- enquo(shape)
  lab_q <- enquo(label)
  fac_q <- enquo(facet)
  col_nm <- if (quo_is_null(col_q)) NULL else tmr_pick(col_q, data, "colour")
  shp_nm <- if (quo_is_null(shp_q)) NULL else tmr_pick(shp_q, data, "shape")
  lab_nm <- if (quo_is_null(lab_q)) NULL else tmr_pick(lab_q, data, "label")
  fac_nm <- if (quo_is_null(fac_q)) NULL else tmr_pick(fac_q, data, "facet")
  # size may be a scalar (default 3.2) or a bare column mapped like colour.
  # Capture with enquo first so a column symbol is not forced-evaluated.
  size_q <- enquo(size)
  size_aes <- NULL
  size_const <- 3.2
  size_expr <- rlang::quo_get_expr(size_q)
  if (is.symbol(size_expr) && as.character(size_expr) %in% names(data)) {
    size_aes <- as.character(size_expr)
  } else {
    size_val <- rlang::eval_tidy(size_q, data = data)
    if (is.numeric(size_val) && length(size_val) == 1L) {
      size_const <- size_val
    }
  }
  leg_title <- legend_title %||% (
    if (!is.null(col_nm)) geo_pretty_label(col_nm) else NULL
  )

  sites <- plot_sites_as_sf(data, enquo(lon), enquo(lat))
  p <- ggplot2::ggplot()

  # Resolve basemap: explicit basemap wins; otherwise honour raster=
  bm <- basemap
  if (identical(bm, "none") && !is.null(raster)) {
    bm <- raster
  }
  bb <- sf::st_bbox(sites)
  # Expand basemap extent a little around the sites
  dx <- max((bb["xmax"] - bb["xmin"]) * 0.35, 0.15)
  dy <- max((bb["ymax"] - bb["ymin"]) * 0.45, 0.12)
  bb["xmin"] <- bb["xmin"] - dx
  bb["xmax"] <- bb["xmax"] + dx
  bb["ymin"] <- bb["ymin"] - dy
  bb["ymax"] <- bb["ymax"] + dy
  bm_layers <- geo_basemap_layers(
    bb,
    basemap = bm,
    coastline = coastline,
    crs = sf::st_crs(sites)
  )
  for (ly in bm_layers$layers) {
    p <- p + ly
  }

  admin_sf <- geo_resolve_admin(admin, level = admin_level, crs = sf::st_crs(sites))
  if (!is.null(admin_sf)) {
    for (ly in geo_admin_layers(admin_sf, fill = isTRUE(admin_fill))) {
      p <- p + ly
    }
  }

  if (!is.null(occurrence)) {
    tmr_check_data(occurrence)
    occ <- plot_sites_as_sf(occurrence, enquo(lon), enquo(lat))
    p <- p + ggplot2::geom_sf(
      data = occ,
      shape = 16,
      colour = "grey55",
      size = occurrence_size,
      alpha = 0.55
    )
  }

  # Site points. Tile/raster basemaps that already use fill map grouping to
  # colour instead. Optional size_aes combines with colour (tmap-like).
  use_fill <- !isTRUE(bm_layers$uses_fill) && is.null(size_aes)
  aes_args <- list()
  if (!is.null(col_nm)) {
    if (use_fill) {
      aes_args$fill <- rlang::sym(col_nm)
    } else {
      aes_args$colour <- rlang::sym(col_nm)
    }
  }
  if (!is.null(shp_nm)) {
    aes_args$shape <- rlang::sym(shp_nm)
  }
  if (!is.null(size_aes)) {
    aes_args$size <- rlang::sym(size_aes)
  }
  if (length(aes_args) == 0) {
    p <- p + ggplot2::geom_sf(
      data = sites, shape = 21,
      fill = tmr_palette(1, palette = palette),
      colour = "grey15", size = size_const, stroke = 0.35
    )
  } else {
    args <- list(
      mapping = ggplot2::aes(!!!aes_args),
      data = sites,
      stroke = 0.35
    )
    if (use_fill) {
      args$shape <- 21
      args$colour <- "grey15"
    } else if (is.null(shp_nm)) {
      args$shape <- 16
    }
    if (is.null(size_aes)) {
      args$size <- size_const
    }
    p <- p + do.call(ggplot2::geom_sf, args)
  }

  if (!is.null(col_nm)) {
    col_v <- sites[[col_nm]]
    if (is.numeric(col_v) && !is.factor(col_v)) {
      if (use_fill) {
        p <- p + ggplot2::scale_fill_viridis_c(
          name = leg_title %||% col_nm, option = "C",
          guide = ggplot2::guide_colourbar(order = 1)
        )
      } else {
        p <- p + ggplot2::scale_colour_viridis_c(
          name = leg_title %||% col_nm, option = "C",
          guide = ggplot2::guide_colourbar(order = 1)
        )
      }
    } else {
      if (is.factor(col_v)) {
        levs <- levels(col_v)
      } else {
        levs <- as.character(vctrs::vec_unique(col_v))
        # Prefer numeric elevation-band order when labels look like "200 m"
        nums <- suppressWarnings(as.numeric(sub(" m$", "", levs)))
        if (all(is.finite(nums))) {
          levs <- levs[order(nums)]
        }
      }
      cols <- tmr_category_colours(palette, levs, function(n) tmr_palette(n, palette = palette))
      if (use_fill) {
        p <- p + ggplot2::scale_fill_manual(
          name = leg_title %||% col_nm, values = cols, breaks = levs,
          guide = ggplot2::guide_legend(order = 1)
        )
      } else {
        p <- p + ggplot2::scale_colour_manual(
          name = leg_title %||% col_nm, values = cols, breaks = levs,
          guide = ggplot2::guide_legend(order = 1)
        )
      }
    }
  }
  if (!is.null(shp_nm)) {
    p <- p + ggplot2::scale_shape_discrete(
      name = shp_nm, guide = ggplot2::guide_legend(order = 2)
    )
  }
  if (!is.null(size_aes)) {
    p <- p + ggplot2::scale_size_area(
      name = geo_pretty_label(size_aes), max_size = 10,
      guide = ggplot2::guide_legend(order = 3)
    )
  }

  if (!is.null(lab_nm)) {
    rlang::check_installed("ggrepel")
    xy <- sf::st_coordinates(sites)
    labs <- tibble::tibble(
      x = xy[, 1],
      y = xy[, 2],
      .lab = as.character(sites[[lab_nm]])
    )
    if (!is.null(fac_nm)) {
      labs[[fac_nm]] <- sites[[fac_nm]]
    }
    p <- p + geo_label_repel_layer(labs)
  }

  if (!is.null(fac_nm)) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data[[fac_nm]]))
  }

  # Use the expanded panel bbox (already in `bb`) for decoration placement
  legend_inside <- !identical(legend_position, "outside") &&
    (identical(legend_position, "auto") ||
       legend_position %in% c("bl", "br", "tl", "tr"))
  want_inset <- !isFALSE(inset) && !is.null(inset)
  decor <- geo_pick_decoration_corner(
    sites, bb,
    scale_bar = !is.null(sb_style),
    north_arrow = !is.null(na_style),
    inset = want_inset,
    legend_inside = legend_inside && (!is.null(col_nm) || !is.null(shp_nm) || !is.null(size_aes))
  )
  if (legend_position %in% c("bl", "br", "tl", "tr")) {
    # Honour an explicit corner even when auto-pick chose another
    lj <- geo_legend_npc(legend_position)
    decor$legend_corner <- legend_position
    decor$legend_position <- lj$position
    decor$legend_justification <- lj$justification
    decor$legend_box <- geo_decoration_box(bb, legend_position)
  }
  if (!is.null(sb_style) && !is.null(decor$scale_box)) {
    p <- p + annotation_scale_bar(
      sb_style,
      location = decor$scale_corner, units = scale_units,
      length = if (!is.null(scale_bar_km)) scale_bar_km * 1000,
      data = tmr_facet_first(sites, fac_nm)
    )
  }
  if (!is.null(na_style) && !is.null(decor$north_box)) {
    p <- p + annotation_north_arrow(
      na_style,
      location = decor$north_corner, data = tmr_facet_first(sites, fac_nm)
    )
  }
  if (want_inset && !is.null(decor$inset_box)) {
    for (ly in geo_annotation_inset(
      bb, decor$inset_box, inset = inset, crs = sf::st_crs(sites)
    )) {
      p <- p + ly
    }
  }
  p <- p +
    ggplot2::coord_sf(
      crs = sf::st_crs(sites), expand = FALSE,
      xlim = unname(bb[c("xmin", "xmax")]), ylim = unname(bb[c("ymin", "ymax")])
    ) +
    theme_tidymapr(grid = "none") +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.border = ggplot2::element_rect(fill = NA, colour = "grey20", linewidth = 0.4)
    ) +
    geo_legend_theme(
      position = legend_position, frame = legend_frame, decor = decor
    ) +
    ggplot2::labs(x = NULL, y = NULL)
  attr(p, "tmr_decoration") <- decor
  p
}

plot_sites_as_sf <- function(data, lon, lat) {
  if (inherits(data, "sf")) {
    out <- geo_as_sf(data, drop_na = TRUE)
  } else {
    lon_col <- tmr_pick(lon, data, "lon")
    lat_col <- tmr_pick(lat, data, "lat")
    out <- geo_as_sf(
      data,
      lon = !!rlang::sym(lon_col),
      lat = !!rlang::sym(lat_col),
      drop_na = TRUE
    )
  }
  if (nrow(out) == 0) {
    cli::cli_abort("No rows with finite coordinates remain to plot.")
  }
  out
}

# Scale bar in map units. When `crs` is geographic, sites are temporarily
# projected (UTM 55S for New Guinea longitudes, else a local UTM) so the
# bar length is true metres, then drawn back in the plot CRS.
geo_annotation_scale_bar <- function(bb, length_km = NULL, facet = NULL,
                                     data = NULL, crs = NULL,
                                     corner = c("bl", "br", "tl", "tr"),
                                     box = NULL) {
  corner <- rlang::arg_match(corner)
  if (!is.null(box)) {
    xmin <- unname(box[1])
    xmax <- unname(box[3])
    ymin <- unname(box[2])
    ymax <- unname(box[4])
  } else {
    xmin <- unname(bb["xmin"])
    xmax <- unname(bb["xmax"])
    ymin <- unname(bb["ymin"])
    ymax <- unname(bb["ymax"])
  }
  # Panel extents still used for nice length heuristics
  panel_w <- unname(bb["xmax"]) - unname(bb["xmin"])
  panel_h <- unname(bb["ymax"]) - unname(bb["ymin"])
  width <- xmax - xmin
  height <- ymax - ymin
  # Decide whether bbox is geographic degrees
  is_geo <- is.null(crs) || geo_crs_is_geographic(crs)
  nice <- c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000)
  if (is_geo) {
    mid_lon <- (xmin + xmax) / 2
    mid_lat <- (ymin + ymax) / 2
    m_per_deg <- 111320 * cos(mid_lat * pi / 180)
    if (is.null(length_km) || !is.finite(length_km)) {
      target_m <- max(panel_w * m_per_deg * 0.2, 1000)
      length_km <- nice[which.min(abs(nice - target_m / 1000))]
    }
    tmr_check_number(length_km, "scale_bar_km", 0)
    # True metres via local UTM scale, drawn back in plot CRS (degrees)
    len_map <- (length_km * 1000) / m_per_deg
    # Keep the bar inside the reserved box
    max_len <- 0.85 * width
    if (len_map > max_len && max_len > 0) {
      length_km <- max(nice[nice <= (max_len * m_per_deg / 1000)], 1)
      len_map <- (length_km * 1000) / m_per_deg
    }
  } else {
    # Projected CRS: map units are metres
    if (is.null(length_km) || !is.finite(length_km)) {
      target_m <- max(panel_w * 0.2, 1000)
      length_km <- nice[which.min(abs(nice - target_m / 1000))]
    }
    tmr_check_number(length_km, "scale_bar_km", 0)
    len_map <- length_km * 1000
    max_len <- 0.85 * width
    if (len_map > max_len && max_len > 0) {
      length_km <- max(nice[nice <= max_len / 1000], 1)
      len_map <- length_km * 1000
    }
  }
  # Place inside the reserved box (or corner inset of the panel)
  # Offsets are fractions of the reserved box (not the full panel)
  pad_x <- 0.10 * width
  if (corner %in% c("bl", "tl")) {
    x0 <- xmin + pad_x
    x1 <- x0 + len_map
  } else {
    x1 <- xmax - pad_x
    x0 <- x1 - len_map
  }
  # Sit the bar in the lower third of the box; label above it
  if (corner %in% c("bl", "br")) {
    y0 <- ymin + 0.28 * height
  } else {
    y0 <- ymax - 0.55 * height
  }
  bar <- tibble::tibble(
    x = c(x0, x1),
    y = c(y0, y0)
  )
  ticks <- tibble::tibble(
    x = c(x0, x1),
    y = c(y0, y0),
    yend = c(y0 + 0.12 * height, y0 + 0.12 * height)
  )
  lab <- tibble::tibble(
    x = (x0 + x1) / 2,
    y = y0 + 0.42 * height,
    label = paste0(length_km, " km")
  )
  # White panel behind the bar so it stays readable on imagery / dark tiles
  panel <- tibble::tibble(
    xmin = min(x0, x1) - 0.08 * abs(width),
    xmax = max(x0, x1) + 0.08 * abs(width),
    ymin = y0 - 0.18 * abs(height),
    ymax = max(lab$y, y0) + 0.22 * abs(height)
  )
  if (!is.null(facet) && !is.null(data) && facet %in% names(data)) {
    first <- vctrs::vec_slice(data, 1L)[[facet]]
    bar[[facet]] <- first
    ticks[[facet]] <- first
    lab[[facet]] <- first
    panel[[facet]] <- first
  }
  list(
    ggplot2::geom_rect(
      data = panel,
      ggplot2::aes(
        xmin = .data$xmin, xmax = .data$xmax,
        ymin = .data$ymin, ymax = .data$ymax
      ),
      fill = "white", colour = "grey25", linewidth = 0.35,
      alpha = 0.95, inherit.aes = FALSE
    ),
    ggplot2::geom_line(
      data = bar,
      ggplot2::aes(.data$x, .data$y),
      linewidth = 1.15,
      colour = "grey5",
      lineend = "butt",
      inherit.aes = FALSE
    ),
    ggplot2::geom_segment(
      data = ticks,
      ggplot2::aes(.data$x, .data$y, xend = .data$x, yend = .data$yend),
      colour = "grey5",
      linewidth = 0.85,
      inherit.aes = FALSE
    ),
    ggplot2::geom_text(
      data = lab,
      ggplot2::aes(.data$x, .data$y, label = .data$label),
      size = 3.1,
      fontface = "bold",
      colour = "grey5",
      inherit.aes = FALSE
    )
  )
}

geo_annotation_north_arrow <- function(bb, facet = NULL, data = NULL,
                                       corner = c("tr", "tl", "br", "bl"),
                                       box = NULL) {
  corner <- rlang::arg_match(corner)
  if (!is.null(box)) {
    xmin <- unname(box[1])
    xmax <- unname(box[3])
    ymin <- unname(box[2])
    ymax <- unname(box[4])
  } else {
    xmin <- unname(bb["xmin"])
    xmax <- unname(bb["xmax"])
    ymin <- unname(bb["ymin"])
    ymax <- unname(bb["ymax"])
  }
  width <- xmax - xmin
  height <- ymax - ymin
  # Centre the arrow inside the reserved box
  cx <- (xmin + xmax) / 2
  cy <- ymin + 0.42 * height
  arrow_h <- 0.28 * height
  tip <- tibble::tibble(
    x = c(cx, cx - 0.12 * width, cx + 0.12 * width),
    y = c(cy + arrow_h, cy, cy)
  )
  stem <- tibble::tibble(
    x = c(cx, cx),
    y = c(cy - 0.12 * height, cy)
  )
  lab <- tibble::tibble(x = cx, y = cy + arrow_h + 0.14 * height, label = "N")
  if (!is.null(facet) && !is.null(data) && facet %in% names(data)) {
    first <- vctrs::vec_slice(data, 1L)[[facet]]
    tip[[facet]] <- first
    stem[[facet]] <- first
    lab[[facet]] <- first
  }
  list(
    ggplot2::geom_polygon(
      data = tip,
      ggplot2::aes(.data$x, .data$y),
      fill = "grey10",
      colour = NA,
      inherit.aes = FALSE
    ),
    ggplot2::geom_line(
      data = stem,
      ggplot2::aes(.data$x, .data$y),
      colour = "grey10",
      linewidth = 0.6,
      inherit.aes = FALSE
    ),
    ggplot2::geom_text(
      data = lab,
      ggplot2::aes(.data$x, .data$y, label = .data$label),
      fontface = "bold",
      size = 3,
      colour = "grey10",
      inherit.aes = FALSE
    )
  )
}

#' Published GPS coordinates for the Mt Wilhelm study sites
#'
#' Returns one row per elevation band of the Mt Wilhelm ant survey
#' ([tidydiversity::png_ants]), with WGS84 longitude and latitude averaged from the bait
#' GPS positions published by Mottl, Moses and Klimes (2023). These are real
#' field coordinates; see [png_ants_sites] for the two transects per band.
#'
#' @param which Study area. Only `"wilhelm"` (the eight elevation bands from
#'   200 to 3700 m) is available: the package has no published coordinates
#'   for other areas, so none are invented.
#' @return A tibble with `site`, `lon`, `lat`, `elevation` (nominal band in
#'   metres), `elevation_band` (ordered factor) and `coordinate_note`.
#' @source Mottl, O., Moses, J. and Klimes, P. (2023). Zenodo.
#'   \doi{10.5281/zenodo.8191946}
#' @export
#' @examples
#' geo_example_sites()
geo_example_sites <- function(which = "wilhelm") {
  which <- rlang::arg_match(which, "wilhelm")
  src <- png_ants_sites
  bands <- sort(unique(src$elevation_band))
  out <- tibble::tibble(
    site = sprintf("MW%04d", bands),
    lon = round(vapply(bands, function(b) {
      mean(src$lon[src$elevation_band == b])
    }, numeric(1)), 5),
    lat = round(vapply(bands, function(b) {
      mean(src$lat[src$elevation_band == b])
    }, numeric(1)), 5),
    elevation = as.integer(bands)
  )
  labs <- paste0(out$elevation, " m")
  out$elevation_band <- factor(labs, levels = labs)
  out$coordinate_note <- "published bait GPS, doi:10.5281/zenodo.8191946"
  out
}
