#' 3D terrain maps
#'
#' @description
#' `geo_map3d()` renders a digital elevation model as a 3D block diagram:
#' the terrain is lit by the sun with cast shadows, seen from any direction
#' and angle, coloured by elevation or by any other raster draped over it
#' (land cover, NDVI, a diversity surface, a model prediction), with sites
#' and routes placed on the surface and hidden where hills are in front of
#' them. The rendering is done in C++ and needs no OpenGL, rgl or
#' rayshader, so it works on servers and in reports; the result is an
#' ordinary ggplot with a title, legend and caption, saved with
#' [geo_save()].
#'
#' @param dem A `SpatRaster` of elevation (metres). Longitude/latitude
#'   rasters are projected to UTM first so that heights and distances share
#'   units.
#' @param drape What colours the surface: `NULL` (elevation, hypsometric
#'   tints) or a `SpatRaster` resampled onto the DEM.
#' @param palette Colour ramp for the drape: `"auto"` (a hypsometric ramp
#'   for elevation, a sequential ramp otherwise), a name from
#'   [grDevices::hcl.pals()] or a vector of colours.
#' @param exaggeration Vertical exaggeration. `"auto"` makes the relief about
#'   a fifth of the width of the area, a common choice for block diagrams,
#'   between 1 and 8 times.
#' @param theta Direction the viewer looks from, in degrees clockwise from
#'   north (`180` = from the south, `225` = from the south-west).
#' @param phi Viewing angle above the horizon, in degrees (`90` = straight
#'   down).
#' @param sun_azimuth,sun_elevation Direction and height of the sun, in
#'   degrees. The cartographic default lights from the north-west.
#' @param shadow Cast shadows?
#' @param ambient Share of light in shadow (0 = black shadows).
#' @param base Draw the sides of the block down to a base?
#' @param points,lines Optional `sf` layers drawn on the surface.
#' @param label Column of `points` with text labels.
#' @param point_colour,line_colour Colours of the overlays.
#' @param max_cells Largest number of DEM cells along a side; larger DEMs
#'   are averaged down to it.
#' @param width,height Image size in pixels.
#' @param title,subtitle,caption,legend_title Text of the figure.
#' @return A ggplot. Attribute `"render"` holds the image and view.
#' @seealso [geo_stac_read()] to fetch a Copernicus DEM, [map_raster()] for
#'   flat maps.
#' @examplesIf rlang::is_installed(c("terra", "ggplot2"))
#' elev <- terra::rast(system.file("ex/elev.tif", package = "terra"))
#' geo_map3d(elev, theta = 200, phi = 35, title = "Luxembourg")
#' @export
geo_map3d <- function(dem,
                      drape = NULL,
                      palette = "auto",
                      exaggeration = "auto",
                      theta = 200,
                      phi = 35,
                      sun_azimuth = 315,
                      sun_elevation = 35,
                      shadow = TRUE,
                      ambient = 0.35,
                      base = TRUE,
                      points = NULL,
                      lines = NULL,
                      label = NULL,
                      point_colour = "#D7301F",
                      line_colour = "grey10",
                      max_cells = 500,
                      width = 1600,
                      height = 1100,
                      title = NULL,
                      subtitle = NULL,
                      caption = NULL,
                      legend_title = NULL) {
  rlang::check_installed(c("terra", "ggplot2"))
  if (!inherits(dem, "SpatRaster")) cli::cli_abort("{.arg dem} must be a {.cls SpatRaster}.")
  tmr_check_number(phi, "phi", 5, 90)
  tmr_check_number(sun_elevation, "sun_elevation", 1, 90)
  tmr_check_number(ambient, "ambient", 0, 1)
  dem <- dem[[1]]
  if (terra::is.lonlat(dem)) {
    box <- sf::st_as_sf(terra::as.polygons(terra::ext(dem), crs = terra::crs(dem)))
    utm <- geo_crs("utm", data = box)
    dem <- terra::project(dem, utm$wkt, method = "bilinear")
  }
  # Projection leaves empty (NA) wedges along the edges: trim rows and
  # columns at the border until the block has clean sides
  dem <- tmr_trim_na_border(dem)
  # Average large DEMs down to max_cells along the longer side
  f <- ceiling(max(dim(dem)[1:2]) / max_cells)
  if (f > 1) dem <- terra::aggregate(dem, f, fun = "mean", na.rm = TRUE)
  z <- terra::as.matrix(dem, wide = TRUE)
  res <- terra::res(dem)
  zr <- range(z, na.rm = TRUE)
  if (!all(is.finite(zr)) || diff(zr) <= 0) cli::cli_abort("{.arg dem} has no relief.")
  span <- max(dim(z)[2] * res[1], dim(z)[1] * res[2])
  zscale <- if (identical(exaggeration, "auto")) {
    # Capped at 8: flat country turns spiky beyond that
    min(max(1, 0.2 * span / diff(zr)), 8)
  } else {
    tmr_check_number(exaggeration, "exaggeration", 0)
    exaggeration
  }

  # Drape colours per cell
  if (is.null(drape)) {
    vals <- z
    is_elev <- TRUE
  } else {
    if (!inherits(drape, "SpatRaster")) cli::cli_abort("{.arg drape} must be a {.cls SpatRaster}.")
    dr <- terra::project(drape[[1]], dem, method = "bilinear")
    vals <- terra::as.matrix(dr, wide = TRUE)
    is_elev <- FALSE
  }
  vr <- range(vals, na.rm = TRUE)
  pal <- if (identical(palette, "auto")) {
    if (is_elev) {
      c("#5B8A3C", "#9BBB59", "#D8D29A", "#C9A66B", "#9C7650", "#B8B0A8", "#F4F4F4")
    } else {
      tmr_ramp("YlGnBu", NULL, 9)
    }
  } else {
    tmr_ramp(palette, NULL, 9)
  }
  ramp <- grDevices::colorRamp(pal)
  t01 <- (vals - vr[1]) / max(diff(vr), 1e-12)
  rgbm <- ramp(pmin(pmax(as.vector(t01), 0), 1)) / 255
  na <- is.na(as.vector(vals))
  rgbm[na, ] <- NA
  mk <- function(k) matrix(rgbm[, k], nrow(z), ncol(z))
  img <- render_dem_cpp(
    z, res[1], res[2], mk(1), mk(2), mk(3),
    theta = theta + 180, phi = phi, zscale = zscale,
    width = as.integer(width), height = as.integer(height),
    sun_azimuth = sun_azimuth, sun_elevation = sun_elevation,
    shadow = shadow, ambient = ambient, base_frac = if (isTRUE(base)) 0.12 else 0,
    threads = tmr_threads()
  )
  arr <- array(c(img$r, img$g, img$b, img$a), c(width, height, 4))
  arr <- aperm(arr, c(2, 1, 3))
  ras <- grDevices::as.raster(arr)

  p <- ggplot2::ggplot() +
    ggplot2::annotation_raster(ras,
      xmin = 0, xmax = width, ymin = 0, ymax = height, interpolate = TRUE
    ) +
    ggplot2::coord_fixed(xlim = c(0, width), ylim = c(0, height), expand = FALSE)
  # A legend for the drape colours
  leg <- data.frame(x = c(-10, -10), y = c(-10, -10), v = vr)
  p <- p + ggplot2::geom_point(data = leg, ggplot2::aes(.data$x, .data$y, colour = .data$v),
    alpha = 0, show.legend = TRUE
  ) +
    ggplot2::scale_colour_gradientn(
      colours = pal, limits = vr,
      name = legend_title %||% if (is_elev) "Elevation (m)" else names(drape)[1],
      guide = ggplot2::guide_colourbar()
    )

  # Overlays: projected onto the surface, hidden behind terrain
  ctr <- c(
    (terra::xmin(dem) + terra::xmax(dem)) / 2 - res[1] / 2 + res[1] / 2,
    (terra::ymin(dem) + terra::ymax(dem)) / 2
  )
  proj_layer <- function(g) {
    g <- sf::st_transform(g, terra::crs(dem))
    xy <- sf::st_coordinates(g)
    zz <- terra::extract(dem, xy[, 1:2, drop = FALSE], method = "bilinear")[, 1]
    pp <- project_points_cpp(
      xy[, 1] - ctr[1], xy[, 2] - ctr[2], zz * zscale + 2 * zscale * mean(res),
      img$view, as.integer(height)
    )
    px <- pmin(pmax(round(pp[, 1]), 1), width)
    py <- pmin(pmax(round(pp[, 2]), 1), height)
    zb <- img$depth[(py - 1) * width + px]
    tol <- 0.01 * diff(range(img$depth[img$a > 0]))
    list(xy = xy, x = pp[, 1], y = height - pp[, 2], visible = is.finite(zz) & pp[, 3] >= zb - tol)
  }
  if (!is.null(lines)) {
    g <- sf::st_segmentize(sf::st_transform(sf::st_geometry(lines), terra::crs(dem)), mean(res))
    pr <- proj_layer(g)
    grp <- if ("L2" %in% colnames(pr$xy)) pr$xy[, "L2"] else pr$xy[, "L1"]
    # Break lines where they go behind terrain
    run <- cumsum(c(TRUE, diff(pr$visible) != 0 | diff(grp) != 0))
    ld <- data.frame(x = pr$x, y = pr$y, run = run)[pr$visible, ]
    p <- p + ggplot2::geom_path(data = ld, ggplot2::aes(.data$x, .data$y, group = .data$run),
      colour = line_colour, linewidth = 0.5, lineend = "round"
    )
  }
  if (!is.null(points)) {
    pr <- proj_layer(sf::st_geometry(points))
    pd <- data.frame(x = pr$x, y = pr$y)[pr$visible, , drop = FALSE]
    p <- p + ggplot2::geom_point(data = pd, ggplot2::aes(.data$x, .data$y),
      shape = 21, fill = point_colour, colour = "white", size = 2.6, stroke = 0.6
    )
    if (!is.null(label)) {
      lab <- as.character(points[[label]])[pr$visible]
      pd$label <- lab
      fill <- grDevices::adjustcolor("white", 0.8)
      pad <- ggplot2::unit(0.12, "lines")
      p <- p + if (rlang::is_installed("ggrepel")) {
        # Keep labels apart where sites are close together on screen
        ggrepel::geom_label_repel(
          data = pd, ggplot2::aes(.data$x, .data$y, label = .data$label),
          size = 2.8, label.size = 0, fill = fill, label.padding = pad,
          min.segment.length = 0.3, segment.colour = "grey20", seed = 1
        )
      } else {
        ggplot2::geom_label(
          data = pd, ggplot2::aes(.data$x, .data$y, label = .data$label),
          size = 2.8, nudge_y = 0.02 * height, label.size = 0, fill = fill,
          label.padding = pad
        )
      }
    }
  }
  p <- p +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(size = 15, margin = ggplot2::margin(b = 4)),
      plot.subtitle = ggplot2::element_text(colour = "grey30", margin = ggplot2::margin(b = 6)),
      plot.caption = ggplot2::element_text(colour = "grey40", size = 8.5),
      legend.position = "right",
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
  attr(p, "render") <- list(image = ras, view = img$view, exaggeration = zscale)
  p
}

# Drop border rows and columns that hold missing values
tmr_trim_na_border <- function(r) {
  m <- is.na(terra::as.matrix(r, wide = TRUE))
  top <- 1
  bottom <- nrow(m)
  left <- 1
  right <- ncol(m)
  for (it in seq_len(nrow(m) + ncol(m))) {
    if (top >= bottom || left >= right) break
    edges <- c(
      t = sum(m[top, left:right]), b = sum(m[bottom, left:right]),
      l = sum(m[top:bottom, left]), r = sum(m[top:bottom, right])
    )
    if (all(edges == 0)) break
    # Only the thin wedges left by reprojection: at most 12% from each side,
    # so irregular outlines (a country, a catchment) are kept
    room <- c(
      t = top - 1 < 0.12 * nrow(m), b = nrow(m) - bottom < 0.12 * nrow(m),
      l = left - 1 < 0.12 * ncol(m), r = ncol(m) - right < 0.12 * ncol(m)
    )
    edges[!room] <- 0
    if (all(edges == 0)) break
    worst <- names(which.max(edges))
    if (worst == "t") top <- top + 1
    if (worst == "b") bottom <- bottom - 1
    if (worst == "l") left <- left + 1
    if (worst == "r") right <- right - 1
  }
  rs <- terra::res(r)
  e <- terra::ext(
    terra::xFromCol(r, left) - rs[1] / 2, terra::xFromCol(r, right) + rs[1] / 2,
    terra::yFromRow(r, bottom) - rs[2] / 2, terra::yFromRow(r, top) + rs[2] / 2
  )
  terra::crop(r, e)
}
