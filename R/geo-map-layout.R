# Map decoration layout: scale bar, north arrow, legend and inset overview
#
# After sites (and labels) are known, corners of the panel are scored by how
# many coordinates fall in a margin box. Decorations are assigned to the
# emptiest free corners so the scale bar, north arrow, inset map and inside
# legend do not sit on top of points or each other. Inspired by tmap's
# tm_layout(legend.*) / tm_compass() / tm_scale_bar() / tm_inset().

#' Choose corners for map decorations with the fewest collisions
#'
#' @param sites An `sf` point object or coordinate data.
#' @param bb Panel `st_bbox` in the plot CRS.
#' @param margin Fraction of panel width/height for each corner box.
#' @param scale_bar,north_arrow,inset,legend_inside Which decorations need a corner.
#' @return A list with corner names, reserved boxes, point counts, and
#'   legend npc position / justification when `legend_inside` is TRUE.
#' @keywords internal
#' @noRd
geo_pick_decoration_corner <- function(sites,
                                       bb,
                                       margin = 0.22,
                                       scale_bar = TRUE,
                                       north_arrow = TRUE,
                                       inset = FALSE,
                                       legend_inside = FALSE) {
  corners <- c("bl", "br", "tl", "tr")
  boxes <- lapply(corners, function(cn) geo_decoration_box(bb, cn, margin = margin))
  names(boxes) <- corners
  xy <- geo_decoration_xy(sites)
  counts <- vapply(boxes, function(bx) {
    if (NROW(xy) == 0) return(0L)
    sum(
      xy[, 1] >= bx[[1]] & xy[, 1] <= bx[[3]] &
        xy[, 2] >= bx[[2]] & xy[, 2] <= bx[[4]],
      na.rm = TRUE
    )
  }, integer(1))

  # Preference order when counts tie
  prefer <- list(
    scale = c("bl", "br", "tl", "tr"),
    north = c("tr", "tl", "br", "bl"),
    inset = c("bl", "br", "tl", "tr"),
    legend = c("tr", "tl", "br", "bl")
  )

  free <- corners
  pick <- function(kind, available) {
    if (length(available) == 0) {
      return(list(corner = NA_character_, remaining = available))
    }
    ord <- order(counts[available], match(available, prefer[[kind]]))
    chosen <- available[[ord[[1]]]]
    list(corner = chosen, remaining = available[available != chosen])
  }

  scale_corner <- NA_character_
  north_corner <- NA_character_
  inset_corner <- NA_character_
  legend_corner <- NA_character_
  if (isTRUE(scale_bar)) {
    got <- pick("scale", free)
    scale_corner <- got$corner
    free <- got$remaining
  }
  if (isTRUE(north_arrow)) {
    got <- pick("north", free)
    north_corner <- got$corner
    free <- got$remaining
  }
  if (isTRUE(inset)) {
    got <- pick("inset", free)
    inset_corner <- got$corner
    free <- got$remaining
  }
  if (isTRUE(legend_inside)) {
    got <- pick("legend", free)
    legend_corner <- got$corner
    free <- got$remaining
  }

  legend_pos <- NULL
  legend_just <- NULL
  if (!is.na(legend_corner)) {
    lj <- geo_legend_npc(legend_corner)
    legend_pos <- lj$position
    legend_just <- lj$justification
  }

  list(
    scale_corner = scale_corner,
    north_corner = north_corner,
    inset_corner = inset_corner,
    legend_corner = legend_corner,
    scale_box = if (!is.na(scale_corner)) boxes[[scale_corner]] else NULL,
    north_box = if (!is.na(north_corner)) boxes[[north_corner]] else NULL,
    inset_box = if (!is.na(inset_corner)) boxes[[inset_corner]] else NULL,
    legend_box = if (!is.na(legend_corner)) boxes[[legend_corner]] else NULL,
    legend_position = legend_pos,
    legend_justification = legend_just,
    counts = counts,
    margin = margin,
    boxes = boxes
  )
}

geo_decoration_box <- function(bb, corner, margin = 0.22) {
  xmin <- unname(bb[["xmin"]])
  xmax <- unname(bb[["xmax"]])
  ymin <- unname(bb[["ymin"]])
  ymax <- unname(bb[["ymax"]])
  w <- xmax - xmin
  h <- ymax - ymin
  mw <- margin * w
  mh <- margin * h
  switch(
    corner,
    bl = c(xmin = xmin, ymin = ymin, xmax = xmin + mw, ymax = ymin + mh),
    br = c(xmin = xmax - mw, ymin = ymin, xmax = xmax, ymax = ymin + mh),
    tl = c(xmin = xmin, ymin = ymax - mh, xmax = xmin + mw, ymax = ymax),
    tr = c(xmin = xmax - mw, ymin = ymax - mh, xmax = xmax, ymax = ymax),
    cli::cli_abort("Unknown corner {.val {corner}}.")
  )
}

geo_decoration_xy <- function(sites) {
  if (inherits(sites, "sf")) {
    return(sf::st_coordinates(sf::st_geometry(sites)))
  }
  if (is.matrix(sites)) {
    return(cbind(as.numeric(sites[, 1]), as.numeric(sites[, 2])))
  }
  if (is.data.frame(sites)) {
    if (all(c("lon", "lat") %in% names(sites))) {
      return(cbind(as.numeric(sites$lon), as.numeric(sites$lat)))
    }
    if (all(c("x", "y") %in% names(sites))) {
      return(cbind(as.numeric(sites$x), as.numeric(sites$y)))
    }
  }
  matrix(numeric(), ncol = 2)
}

geo_decoration_contains <- function(sites, box) {
  if (is.null(box)) return(logical(0))
  xy <- geo_decoration_xy(sites)
  if (NROW(xy) == 0) return(logical(0))
  xy[, 1] >= box[[1]] & xy[, 1] <= box[[3]] &
    xy[, 2] >= box[[2]] & xy[, 2] <= box[[4]]
}

geo_legend_npc <- function(corner) {
  switch(
    corner,
    bl = list(position = c(0.02, 0.02), justification = c(0, 0)),
    br = list(position = c(0.98, 0.02), justification = c(1, 0)),
    tl = list(position = c(0.02, 0.98), justification = c(0, 1)),
    tr = list(position = c(0.98, 0.98), justification = c(1, 1)),
    list(position = "right", justification = "center")
  )
}

#' Legend theme helpers for plot_sites / plot_geo (tmap-like)
#'
#' @param position `"auto"`, `"outside"`, or a corner `"bl"`/`"br"`/`"tl"`/`"tr"`.
#' @param frame Draw a frame around the legend?
#' @param title Legend title (passed through by callers to scales).
#' @param decor Optional layout list from [geo_pick_decoration_corner()].
#' @keywords internal
#' @noRd
geo_legend_theme <- function(position = "auto",
                             frame = TRUE,
                             decor = NULL) {
  if (identical(position, "outside")) {
    pos <- "right"
    just <- "center"
  } else if (identical(position, "auto") && !is.null(decor) &&
               !is.null(decor$legend_position)) {
    pos <- decor$legend_position
    just <- decor$legend_justification
  } else if (position %in% c("bl", "br", "tl", "tr")) {
    lj <- geo_legend_npc(position)
    pos <- lj$position
    just <- lj$justification
  } else {
    pos <- "right"
    just <- "center"
  }
  bg <- if (isTRUE(frame)) {
    ggplot2::element_rect(fill = "white", colour = "grey30", linewidth = 0.4)
  } else {
    ggplot2::element_rect(fill = "white", colour = NA)
  }
  ggplot2::theme(
    legend.position = pos,
    legend.justification = just,
    legend.background = bg,
    legend.key = ggplot2::element_rect(fill = "white", colour = NA),
    legend.margin = ggplot2::margin(4, 6, 4, 6)
  )
}

#' Overview / inset map region bbox
#'
#' @param inset `"png"`, `"auto"`, `TRUE`, or a numeric bbox
#'   `c(xmin, ymin, xmax, ymax)`.
#' @param main_bb Main map bbox used when `inset = "auto"`.
#' @keywords internal
#' @noRd
geo_inset_region_bbox <- function(inset, main_bb) {
  if (is.numeric(inset) && length(inset) == 4) {
    bb <- inset
    names(bb) <- c("xmin", "ymin", "xmax", "ymax")
    return(bb)
  }
  key <- if (isTRUE(inset)) "auto" else as.character(inset)
  if (identical(key, "png")) {
    # Papua New Guinea / eastern New Guinea overview
    return(c(xmin = 140.5, ymin = -12.0, xmax = 156.5, ymax = -1.0))
  }
  if (identical(key, "auto") || identical(key, "TRUE")) {
    xmin <- unname(main_bb[["xmin"]])
    xmax <- unname(main_bb[["xmax"]])
    ymin <- unname(main_bb[["ymin"]])
    ymax <- unname(main_bb[["ymax"]])
    # New Guinea-ish longitudes: prefer PNG overview
    if (is.finite(xmin) && xmin > 130 && xmax < 160 &&
          is.finite(ymin) && ymin > -15 && ymax < 2) {
      return(c(xmin = 140.5, ymin = -12.0, xmax = 156.5, ymax = -1.0))
    }
    # Otherwise expand main extent ~8x, capped
    cx <- (xmin + xmax) / 2
    cy <- (ymin + ymax) / 2
    w <- max((xmax - xmin) * 4, 2)
    h <- max((ymax - ymin) * 4, 2)
    return(c(
      xmin = cx - w / 2, ymin = cy - h / 2,
      xmax = cx + w / 2, ymax = cy + h / 2
    ))
  }
  cli::cli_abort(
    "{.arg inset} must be TRUE, {.val png}, {.val auto}, or a length-4 bbox."
  )
}

#' Build a small overview ggplot grob with the main extent marked
#'
#' @keywords internal
#' @noRd
geo_inset_grob <- function(main_bb, inset = "auto", crs = 4326) {
  rlang::check_installed("ggplot2")
  rlang::check_installed("sf")
  ov <- geo_inset_region_bbox(inset, main_bb)
  ov_bb <- sf::st_bbox(ov, crs = crs)
  land <- tryCatch(
    geo_inset_land(ov_bb, crs = crs),
    error = function(e) sf::st_sf(geometry = sf::st_sfc(crs = crs))
  )
  extent_poly <- sf::st_as_sf(sf::st_as_sfc(main_bb, crs = crs))
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(
      data = land, fill = "grey88", colour = "grey55", linewidth = 0.2
    ) +
    ggplot2::geom_sf(
      data = extent_poly, fill = NA, colour = "#B2182B", linewidth = 0.55
    ) +
    ggplot2::coord_sf(
      xlim = c(ov[["xmin"]], ov[["xmax"]]),
      ylim = c(ov[["ymin"]], ov[["ymax"]]),
      expand = FALSE, crs = crs
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = "grey25", linewidth = 0.5),
      panel.background = ggplot2::element_rect(fill = "#D6ECF5", colour = NA),
      plot.margin = ggplot2::margin(2, 2, 2, 2)
    )
  ggplot2::ggplotGrob(p)
}

geo_inset_land <- function(bbox, crs = 4326, prefer_gadm = TRUE) {
  # Prefer cached GADM provinces for a PNG / New Guinea overview
  xmin <- unname(bbox[["xmin"]])
  xmax <- unname(bbox[["xmax"]])
  ymin <- unname(bbox[["ymin"]])
  ymax <- unname(bbox[["ymax"]])
  png_ish <- is.finite(xmin) && xmin > 130 && xmax < 160 &&
    is.finite(ymin) && ymin > -15 && ymax < 2
  land <- NULL
  if (isTRUE(prefer_gadm) && png_ish) {
    land <- tryCatch(
      geo_gadm("PNG", level = 1, download = FALSE),
      error = function(e) NULL
    )
  }
  if (is.null(land) && requireNamespace("rnaturalearth", quietly = TRUE)) {
    land <- tryCatch(
      rnaturalearth::ne_countries(scale = "medium", returnclass = "sf"),
      error = function(e) NULL
    )
  }
  if (is.null(land) && requireNamespace("rnaturalearthdata", quietly = TRUE)) {
    land <- tryCatch(
      sf::st_as_sf(rnaturalearthdata::countries50),
      error = function(e) NULL
    )
  }
  if (is.null(land)) {
    return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  }
  land <- sf::st_transform(sf::st_make_valid(land), crs)
  crop_win <- sf::st_as_sfc(bbox, crs = crs)
  out <- tryCatch(
    suppressWarnings(sf::st_crop(land, crop_win)),
    error = function(e) land
  )
  out
}

#' Resolve admin argument to an sf table in the plot CRS
#' @keywords internal
#' @noRd
geo_resolve_admin <- function(admin, level = 1, crs = 4326) {
  if (is.null(admin) || isFALSE(admin)) return(NULL)
  rlang::check_installed("sf")
  if (inherits(admin, "sf") || inherits(admin, "sfc")) {
    out <- if (inherits(admin, "sfc")) sf::st_sf(geometry = admin) else admin
  } else if (is.character(admin) && length(admin) == 1) {
    out <- tryCatch(
      geo_gadm(admin, level = level, download = TRUE),
      error = function(e) {
        cli::cli_warn("Could not load GADM for {.val {admin}}: {conditionMessage(e)}")
        NULL
      }
    )
    if (is.null(out)) return(NULL)
  } else {
    cli::cli_abort("{.arg admin} must be NULL, an sf object, or an ISO3 country code.")
  }
  if (!is.na(sf::st_crs(out)) && !is.na(sf::st_crs(crs)) &&
        sf::st_crs(out) != sf::st_crs(crs)) {
    out <- sf::st_transform(out, crs)
  }
  out
}

#' ggplot layers for administrative borders / fills
#' @keywords internal
#' @noRd
geo_admin_layers <- function(admin_sf, fill = FALSE) {
  if (is.null(admin_sf) || nrow(admin_sf) == 0) return(list())
  if (isTRUE(fill)) {
    # Colour by first NAME_* column when present
    nm <- intersect(c("NAME_1", "NAME_2", "NAME_0", "COUNTRY", "name"), names(admin_sf))
    if (length(nm) > 0) {
      return(list(
        ggplot2::geom_sf(
          data = admin_sf,
          ggplot2::aes(fill = .data[[nm[[1]]]]),
          colour = "grey30", linewidth = 0.25, alpha = 0.35,
          show.legend = FALSE, inherit.aes = FALSE
        )
      ))
    }
    return(list(
      ggplot2::geom_sf(
        data = admin_sf, fill = "grey90", colour = "grey30",
        linewidth = 0.25, alpha = 0.4, inherit.aes = FALSE
      )
    ))
  }
  list(
    ggplot2::geom_sf(
      data = admin_sf, fill = NA, colour = "grey25",
      linewidth = 0.35, inherit.aes = FALSE
    )
  )
}

#' Add an overview inset into a reserved corner box
#'
#' @keywords internal
#' @noRd
geo_annotation_inset <- function(bb, box, inset = "auto", crs = 4326) {
  if (is.null(box)) return(list())
  grob <- tryCatch(
    geo_inset_grob(bb, inset = inset, crs = crs),
    error = function(e) NULL
  )
  if (is.null(grob)) return(list())
  # Shrink slightly so the frame does not touch panel edges
  xmin <- box[[1]]
  ymin <- box[[2]]
  xmax <- box[[3]]
  ymax <- box[[4]]
  dx <- 0.06 * (xmax - xmin)
  dy <- 0.06 * (ymax - ymin)
  list(
    ggplot2::annotation_custom(
      grob = grob,
      xmin = xmin + dx, xmax = xmax - dx,
      ymin = ymin + dy, ymax = ymax - dy
    )
  )
}


geo_crs_is_geographic <- function(crs) {
  if (is.null(crs)) return(TRUE)
  if (inherits(crs, "crs")) {
    return(isTRUE(sf::st_is_longlat(crs)))
  }
  # EPSG integer / character / WKT
  tryCatch({
    isTRUE(sf::st_is_longlat(sf::st_crs(crs)))
  }, error = function(e) TRUE)
}

# Local UTM CRS for true-metre scale bars near a lon/lat. New Guinea uses
# UTM 55S (EPSG:32755) for longitudes ~144-150 E.
geo_local_utm_crs <- function(lon, lat) {
  if (!is.finite(lon) || !is.finite(lat)) return(NULL)
  zone <- as.integer(floor((lon + 180) / 6) + 1)
  zone <- max(1L, min(60L, zone))
  epsg <- if (lat >= 0) 32600L + zone else 32700L + zone
  sf::st_crs(epsg)
}


#' Padded white label-repel layer shared by plot_sites / plot_geo
#' @keywords internal
#' @noRd
geo_label_repel_layer <- function(labs, facet = NULL) {
  rlang::check_installed("ggrepel")
  repel_fun <- if (is.function(ggrepel::geom_label_repel)) {
    ggrepel::geom_label_repel
  } else {
    ggrepel::geom_text_repel
  }
  # Prefer labels on the uphill/NW side of a SW-NE transect so large
  # high-elevation markers (MW3200/MW3700) are not covered.
  xr <- diff(range(labs$x, na.rm = TRUE))
  yr <- diff(range(labs$y, na.rm = TRUE))
  nudge_x <- if (is.finite(xr) && xr > 0) -0.04 * xr else 0
  nudge_y <- if (is.finite(yr) && yr > 0)  0.05 * yr else 0
  repel_args <- list(
    data = labs,
    mapping = ggplot2::aes(.data$x, .data$y, label = .data$.lab),
    size = 2.8,
    min.segment.length = 0,
    box.padding = 0.9,
    point.padding = 1.0,
    max.overlaps = Inf,
    force = 2.8,
    force_pull = 0.15,
    max.iter = 12000,
    nudge_x = nudge_x,
    nudge_y = nudge_y,
    colour = "grey10",
    segment.colour = "grey40",
    segment.size = 0.35,
    seed = 1,
    inherit.aes = FALSE
  )
  if (identical(repel_fun, ggrepel::geom_label_repel)) {
    repel_args$fill <- "white"
    repel_args$label.size <- 0.15
    repel_args$label.padding <- ggplot2::unit(0.15, "lines")
  }
  do.call(repel_fun, repel_args)
}
