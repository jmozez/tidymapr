#' Map projections and graticules
#'
#' @description
#' Choose a coordinate reference system by name and draw graticules
#' (latitude/longitude lines), as in GeoSpaX.
#'
#' * `geo_crs()` returns an [sf::st_crs()] object for a named projection,
#'   centred on your data when that matters.
#' * `coord_projection()` draws any ggplot map (including every tidymapr
#'   map) in that projection: add it with `+`.
#' * `map_graticule()` sets the graticule interval and style, and can draw
#'   the outline of the globe on world maps.
#'
#' | `projection` | Use | CRS |
#' |---|---|---|
#' | `"equal_earth"` | World maps with true areas (recommended for world choropleths) | EPSG:8857 |
#' | `"mercator"` | World Mercator: conformal, areas grow towards the poles | EPSG:3395 |
#' | `"web_mercator"` | Matches online tiles (OpenStreetMap, Esri) | EPSG:3857 |
#' | `"robinson"` | Compromise world map | ESRI:54030 |
#' | `"mollweide"` | Equal-area world map, elliptical | ESRI:54009 |
#' | `"winkel_tripel"` | Compromise world map (National Geographic) | `+proj=wintri` |
#' | `"lonlat"` | Plain longitude/latitude (WGS 84) | EPSG:4326 |
#' | `"utm"` | Local maps in metres; UTM zone picked from `data` | EPSG:326xx/327xx |
#' | `"laea"` | Equal-area, centred on `data` (continents, regions) | Lambert azimuthal |
#' | `"albers"` | Equal-area conic for mid-latitude regions | Albers |
#' | `"orthographic"` | The globe seen from space, centred on `data` | orthographic |
#'
#' Any EPSG code (for example `32755`) or PROJ/WKT string also works.
#' World projections accept `lon0` to centre the map elsewhere, for example
#' `lon0 = 150` for a Pacific-centred map that keeps Papua New Guinea in
#' the middle; use [sf::st_break_antimeridian()] on world polygons first so
#' countries crossing the new edge are split cleanly.
#'
#' @param projection Projection name (see table), an EPSG number or a CRS
#'   string.
#' @param data Optional `sf` object or bbox used to centre `"utm"`,
#'   `"laea"`, `"albers"` and `"orthographic"`.
#' @param lon0,lat0 Central longitude and latitude. Default: the centre of
#'   `data`, or 0.
#' @param expand Expand the plot limits a little beyond the data?
#' @param ... Passed to [ggplot2::coord_sf()] (for example `xlim`, `ylim`).
#' @return `geo_crs()`: a `crs` object. `coord_projection()` and
#'   `map_graticule()`: settings to add to a ggplot with `+` (add
#'   `map_graticule()` after `coord_projection()`).
#' @references Šavrič, B., Patterson, T. and Jenny, B. (2019). The Equal
#'   Earth map projection. *International Journal of Geographical
#'   Information Science*, 33, 454-465. \doi{10.1080/13658816.2018.1504949}
#' @name map-projection
#' @examplesIf rlang::is_installed(c("ggplot2", "sf", "spData"))
#' library(ggplot2)
#' # Life expectancy by country (spData::world, Natural Earth and World Bank)
#' world <- spData::world
#' plot_choropleth(world, lifeExp, n = 5, style = "jenks",
#'   legend_title = "Life expectancy (years)") +
#'   coord_projection("equal_earth") +
#'   map_graticule(interval = 30, outline = TRUE)
#'
#' # The same world in Mercator: note how Greenland and Antarctica swell
#' ggplot(world) +
#'   geom_sf(fill = "grey85", colour = "white", linewidth = 0.1) +
#'   coord_projection("mercator", ylim = c(-7e6, 1.2e7)) +
#'   map_graticule(interval = 30) +
#'   theme_tidymapr()
#'
#' # The globe from space, centred on Papua New Guinea
#' png <- world[world$name_long == "Papua New Guinea", ]
#' ggplot(world) +
#'   geom_sf(fill = "grey80", colour = "white", linewidth = 0.1) +
#'   geom_sf(data = png, fill = "#D55E00") +
#'   coord_projection("orthographic", data = png) +
#'   map_graticule(30, outline = TRUE) +
#'   theme_tidymapr(grid = "none")
#'
#' # Local maps: UTM zone picked from the Mt Wilhelm sites (55S)
#' sites <- geo_as_sf(geo_example_sites(), lon, lat)
#' geo_crs("utm", data = sites)$input
#' @export
geo_crs <- function(projection = "equal_earth", data = NULL, lon0 = NULL,
                    lat0 = NULL) {
  rlang::check_installed("sf")
  if (is.numeric(projection) || inherits(projection, "crs")) {
    return(sf::st_crs(projection))
  }
  if (!is.character(projection) || length(projection) != 1) {
    cli::cli_abort("{.arg projection} must be a projection name, an EPSG number or a CRS string.")
  }
  key <- gsub("[ -]", "_", tolower(projection))
  ctr <- geo_crs_centre(data)
  lon0 <- lon0 %||% ctr[1] %||% 0
  lat0 <- lat0 %||% ctr[2] %||% 0
  world <- function(proj, epsg) {
    if (lon0 == 0 && !is.null(epsg)) {
      sf::st_crs(epsg)
    } else {
      sf::st_crs(sprintf("+proj=%s +lon_0=%s +datum=WGS84 +units=m +no_defs", proj, lon0))
    }
  }
  needs_data <- c("utm", "laea", "albers", "orthographic")
  if (key %in% needs_data && is.null(data) && is.null(ctr)) {
    if (key == "utm") {
      cli::cli_abort("{.code projection = \"utm\"} needs {.arg data} to pick the zone.")
    }
  }
  switch(key,
    equal_earth = world("eqearth", "EPSG:8857"),
    mercator = world("merc", "EPSG:3395"),
    web_mercator = sf::st_crs(3857),
    robinson = world("robin", "ESRI:54030"),
    mollweide = world("moll", "ESRI:54009"),
    winkel_tripel = world("wintri", NULL),
    lonlat = ,
    wgs84 = sf::st_crs(4326),
    utm = geo_local_utm_crs(lon0, lat0),
    laea = sf::st_crs(sprintf(
      "+proj=laea +lat_0=%s +lon_0=%s +datum=WGS84 +units=m +no_defs", lat0, lon0
    )),
    albers = {
      lat <- geo_crs_lat_range(data, lat0)
      sf::st_crs(sprintf(
        "+proj=aea +lat_1=%s +lat_2=%s +lat_0=%s +lon_0=%s +datum=WGS84 +units=m +no_defs",
        lat[1], lat[2], lat0, lon0
      ))
    },
    orthographic = sf::st_crs(sprintf(
      "+proj=ortho +lat_0=%s +lon_0=%s +datum=WGS84 +units=m +no_defs", lat0, lon0
    )),
    {
      crs <- tryCatch(sf::st_crs(projection), error = function(e) NA)
      if (is.na(crs)) {
        cli::cli_abort(c(
          "Unknown projection {.val {projection}}.",
          "i" = paste(
            "Use a name such as {.val equal_earth}, {.val mercator},",
            "{.val robinson} or {.val utm}, an EPSG number or a CRS string."
          )
        ))
      }
      crs
    }
  )
}

#' @rdname map-projection
#' @export
coord_projection <- function(projection = "equal_earth", data = NULL,
                             lon0 = NULL, lat0 = NULL, expand = FALSE, ...) {
  rlang::check_installed("ggplot2")
  coord <- ggplot2::coord_sf(
    crs = geo_crs(projection, data = data, lon0 = lon0, lat0 = lat0),
    default_crs = NULL, expand = expand, ...
  )
  structure(list(coord = coord), class = "tmr_coord_projection")
}

#' @exportS3Method ggplot2::ggplot_add
# nolint next: object_name_linter.
ggplot_add.tmr_coord_projection <- function(object, plot, object_name) {
  # Replace the map's coordinate system quietly: geom_sf() always sets one
  plot$coordinates <- object$coord
  plot
}

#' @rdname map-projection
#' @param interval Graticule spacing in degrees: one number for both, or
#'   `c(longitude, latitude)`.
#' @param labels Which graticule lines to label: `"auto"` (latitudes only
#'   on curved world projections, where longitude labels would crowd the
#'   pole line; both elsewhere), `"both"`, `"latitude"`, `"longitude"` or
#'   `"none"`. `TRUE` and `FALSE` mean `"auto"` and `"none"`.
#' @param colour,linewidth,linetype Graticule line style.
#' @param outline Draw the edge of the map: the outline of the world on
#'   world projections, or the horizon circle on `"orthographic"` maps.
#' @export
map_graticule <- function(interval = 30,
                          labels = "auto",
                          colour = "grey80",
                          linewidth = 0.25,
                          linetype = "solid",
                          outline = FALSE) {
  rlang::check_installed("ggplot2")
  interval <- rep_len(interval, 2)
  if (!is.numeric(interval) || any(interval <= 0)) {
    cli::cli_abort("{.arg interval} must be positive degrees.")
  }
  if (isTRUE(labels)) labels <- "auto"
  if (isFALSE(labels)) labels <- "none"
  labels <- rlang::arg_match(labels, c("auto", "both", "latitude", "longitude", "none"))
  structure(
    list(
      interval = interval, labels = labels, outline = isTRUE(outline),
      line = ggplot2::element_line(colour = colour, linewidth = linewidth, linetype = linetype)
    ),
    class = "tmr_graticule"
  )
}

#' @exportS3Method ggplot2::ggplot_add
ggplot_add.tmr_graticule <- function(object, plot, object_name) { # nolint: object_name_linter.
  iv <- object$interval
  crs <- if (inherits(plot$coordinates, "CoordSf")) plot$coordinates$crs else NULL
  proj4 <- if (is.null(crs)) "" else tryCatch(sf::st_crs(crs)$proj4string, error = function(e) "")
  proj4 <- proj4 %||% ""
  curved <- grepl("\\+proj=(eqearth|robin|moll|wintri|ortho|laea|aea)\\b", proj4)
  ortho <- grepl("\\+proj=ortho\\b", proj4)
  lab <- object$labels
  if (lab == "auto") lab <- if (ortho) "none" else if (curved) "latitude" else "both"
  plot <- plot +
    ggplot2::scale_x_continuous(breaks = seq(-180, 180, by = iv[1])) +
    ggplot2::scale_y_continuous(breaks = seq(-90, 90, by = iv[2])) +
    ggplot2::theme(
      panel.grid.major = object$line,
      panel.grid.major.x = object$line,
      panel.grid.major.y = object$line
    )
  if (inherits(plot$coordinates, "CoordSf")) {
    plot$coordinates$label_axes <- switch(lab,
      both = list(bottom = "E", left = "N", top = "", right = ""),
      latitude = list(bottom = "", left = "N", top = "", right = ""),
      longitude = list(bottom = "E", left = "", top = "", right = ""),
      none = list(bottom = "", left = "", top = "", right = "")
    )
  }
  if (lab == "none") {
    plot <- plot + ggplot2::theme(
      axis.text = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank()
    )
  }
  if (isTRUE(object$outline)) {
    rlang::check_installed("sf")
    edge <- if (ortho) {
      # The horizon: a circle of one Earth radius around the projection centre
      sf::st_sfc(sf::st_buffer(sf::st_point(c(0, 0)), 6378137, nQuadSegs = 90), crs = crs)
    } else {
      geo_globe_outline()
    }
    # geom_sf() also returns a default coord_sf(); add only the layer so the
    # map's projection is not reset
    plot <- plot + ggplot2::geom_sf(
      data = edge, fill = NA, colour = "grey40", linewidth = 0.4,
      inherit.aes = FALSE
    )[[1]]
  }
  plot
}

# The edge of the world (-180..180, -90..90), densified so it curves
# properly in any projection
geo_globe_outline <- function(n = 361) {
  lon <- seq(-180, 180, length.out = n)
  lat <- seq(-90, 90, length.out = (n + 1) / 2)
  ring <- rbind(
    cbind(lon, -90), cbind(180, lat), cbind(rev(lon), 90), cbind(-180, rev(lat))
  )
  sf::st_sfc(sf::st_polygon(list(ring)), crs = 4326)
}

geo_crs_centre <- function(data) {
  if (is.null(data)) return(NULL)
  bb <- if (is.numeric(data) && length(data) == 4) {
    stats::setNames(as.numeric(data), c("xmin", "ymin", "xmax", "ymax"))
  } else {
    sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(data)), 4326))
  }
  round(c(mean(bb[c("xmin", "xmax")]), mean(bb[c("ymin", "ymax")])), 4)
}

geo_crs_lat_range <- function(data, lat0) {
  if (is.null(data)) return(c(lat0 - 10, lat0 + 10))
  bb <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(sf::st_bbox(data)), 4326))
  r <- unname(c(bb["ymin"], bb["ymax"]))
  round(c(r[1] + diff(r) / 6, r[2] - diff(r) / 6), 4)
}
