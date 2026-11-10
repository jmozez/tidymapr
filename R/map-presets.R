#' Standard cartographic symbols
#'
#' @description
#' `map_presets()` lists the named symbols that [map_polygons()],
#' [map_lines()] and [map_points()] accept as `preset`: the colours, line
#' widths, dash patterns and point shapes of topographic and atlas maps
#' (water in blue, forest in green, administrative boundaries dashed,
#' railways in black with long dashes, peaks as triangles), so that layers
#' follow common conventions without setting every argument. Colours are
#' readable for people with colour-vision deficiency and on white paper.
#'
#' @param kind Optional: `"polygon"`, `"line"` or `"point"` to list only
#'   presets of that kind.
#' @return A tibble with `kind`, `preset`, `label` and the style values.
#' @seealso [geo_map()].
#' @examples
#' map_presets("line")
#' @examplesIf rlang::is_installed(c("ggplot2", "ggnewscale", "sf"))
#' cantons <- sf::st_read(system.file("ex/lux.shp", package = "terra"), quiet = TRUE)
#' geo_map() |>
#'   map_polygons(cantons, preset = "admin") |>
#'   map_points(suppressWarnings(sf::st_point_on_surface(cantons)), preset = "town")
#' @export
map_presets <- function(kind = NULL) {
  p <- tmr_presets()
  rows <- lapply(names(p), function(k) {
    v <- p[[k]]
    tibble::tibble(
      kind = v$kind, preset = k, label = v$label,
      colour = v$colour %||% NA_character_, fill = v$fill %||% NA_character_,
      border = v$border %||% NA_character_, linewidth = v$linewidth %||% NA_real_,
      linetype = v$linetype %||% NA_character_, shape = v$shape %||% NA_real_,
      size = v$size %||% NA_real_
    )
  })
  out <- dplyr::bind_rows(rows)
  if (!is.null(kind)) {
    kind <- rlang::arg_match(kind, c("polygon", "line", "point"))
    out <- out[out$kind == kind, ]
  }
  out
}

tmr_presets <- function() {
  poly <- function(label, fill, border, linewidth = 0.3, linetype = "solid") {
    list(
      kind = "polygon", label = label, fill = fill, border = border,
      linewidth = linewidth, linetype = linetype
    )
  }
  line <- function(label, colour, linewidth, linetype = "solid") {
    list(kind = "line", label = label, colour = colour, linewidth = linewidth, linetype = linetype)
  }
  pt <- function(label, fill, shape, size, border = "grey15") {
    list(kind = "point", label = label, fill = fill, shape = shape, size = size, border = border)
  }
  list(
    water = poly("Water", "#A6CEE3", "#4A90C2", 0.3),
    sea = poly("Sea", "#D6EAF8", NA, 0),
    wetland = poly("Wetland", "#C8E6E0", "#5FA59A", 0.25, "22"),
    forest = poly("Forest", "#B5D69A", "#6E9E5A", 0.25),
    grassland = poly("Grassland", "#E6F0C2", "#A9B97A", 0.2),
    cropland = poly("Cropland", "#F5E6B3", "#C9B26B", 0.2),
    urban = poly("Built-up area", "#E3D3C4", "#9C8573", 0.2),
    bare = poly("Bare ground", "#EDE6DA", "#B5A894", 0.2),
    glacier = poly("Ice", "#F2F8FC", "#8DB6D4", 0.3),
    protected_area = poly("Protected area", NA, "#2E8B57", 0.7, "42"),
    admin = poly("Administrative unit", NA, "grey30", 0.4, "22"),
    study_area = poly("Study area", NA, "#D7301F", 0.8, "solid"),
    river = line("River", "#3B83BD", 0.6),
    stream = line("Stream", "#6BAED6", 0.3),
    road_major = line("Main road", "#C0392B", 0.8),
    road_minor = line("Minor road", "grey45", 0.35),
    track = line("Track", "grey35", 0.3, "22"),
    railway = line("Railway", "grey10", 0.5, "42"),
    boundary = line("Boundary", "grey25", 0.45, "2242"),
    coastline = line("Coastline", "#4A90C2", 0.4),
    contour = line("Contour", "#A0785A", 0.25),
    transect = line("Transect", "#D7301F", 0.6, "solid"),
    city = pt("City", "grey10", 22, 3.2, "white"),
    town = pt("Town", "white", 21, 2.4, "grey10"),
    village = pt("Village", "grey40", 21, 1.6, "white"),
    peak = pt("Peak", "#8B5A2B", 24, 2.6, "white"),
    sample_site = pt("Sample site", "#D7301F", 21, 2.4, "white"),
    occurrence = pt("Occurrence", "#0072B2", 21, 1.8, "white"),
    spring = pt("Spring", "#3B83BD", 21, 2, "white"),
    station = pt("Station", "#E69F00", 23, 2.4, "grey15")
  )
}

tmr_preset <- function(name, kind, call = caller_env()) {
  p <- tmr_presets()
  ok <- names(p)[vapply(p, function(v) v$kind == kind, TRUE)]
  if (!is.character(name) || length(name) != 1 || !name %in% ok) {
    cli::cli_abort(
      "{.arg preset} must be one of the {kind} presets: {.val {ok}}.",
      call = call
    )
  }
  p[[name]]
}
