#' Choropleth and bubble maps
#'
#' @description
#' Two classic thematic maps, drawn with ggplot2 and [theme_tidymapr()]:
#'
#' * `plot_choropleth()` shades polygons (regions, plots, provinces) by a
#'   numeric column. Values are grouped into classes with [geo_classify()]
#'   (quantile, equal, Fisher-Jenks, pretty, standard deviation or fixed
#'   breaks), so the legend shows readable ranges such as `"10 - 20"`. The
#'   classification (breaks, counts per class and goodness of variance fit)
#'   is kept in attribute `"classification"` of the plot.
#' * `plot_bubble()` draws a circle at each site with its **area**
#'   proportional to a numeric column, the standard way to map counts such
#'   as species richness or abundance. Larger circles are drawn first, so
#'   small ones stay visible on top. Sites with a value of zero (sampled,
#'   but nothing found) are shown as small open circles, so absences stay
#'   on the map instead of disappearing.
#'
#' Both return an ordinary ggplot, so you can add layers, change scales or
#' save with [geo_save()].
#'
#' @param data For `plot_choropleth()`, an `sf` table of polygons. For
#'   `plot_bubble()`, an `sf` point table or a data frame with longitude and
#'   latitude columns.
#' @param value <[`data-masking`][dplyr::dplyr_data_masking]> Numeric
#'   column that sets the fill class (`plot_choropleth()`).
#' @param size <[`data-masking`][dplyr::dplyr_data_masking]> Numeric
#'   column that sets bubble area (`plot_bubble()`).
#' @param n,style,breaks,digits Classification, passed to [geo_classify()].
#' @param palette For `plot_choropleth()`, the name of a sequential palette
#'   from [grDevices::hcl.colors()] (default `"YlGnBu"`, colour-blind safe and
#'   readable in greyscale).
#' @param reverse Reverse the palette? The default (`TRUE`) runs from light
#'   (low values) to dark (high values).
#' @param border,linewidth Polygon outline colour and width.
#' @param na_fill Fill for polygons with a missing value.
#' @param legend_title Legend title; defaults to the column name.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Coordinate
#'   columns when `data` is not `sf` (`plot_bubble()`).
#' @param colour <[`data-masking`][dplyr::dplyr_data_masking]> Optional
#'   column that colours the bubbles by group (Okabe-Ito palette).
#' @param fill Bubble colour when `colour` is not given.
#' @param max_size Diameter (in points) of the largest bubble.
#' @param alpha Bubble transparency.
#' @param background Optional `sf` layer (for example a coastline or
#'   province boundaries) drawn in light grey under the bubbles.
#' @return A ggplot object.
#' @name thematic-maps
#' @seealso [geo_classify()] for the classes alone; [plot_sites()] for
#'   study-site maps with basemaps.
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("sf", quietly = TRUE)
#' # Choropleth: sudden infant deaths 1974-78 in North Carolina counties
#' # (real data shipped with sf)
#' nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)
#' nc$sids_rate <- 1000 * nc$SID74 / nc$BIR74
#' p <- plot_choropleth(nc, sids_rate, n = 5, style = "jenks",
#'   legend_title = "SIDS per 1000 births")
#' p
#' attr(p, "classification")$gvf
#'
#' # Bubble map: ant species observed on each Mt Wilhelm transect
#' # (Mottl, Moses and Klimes 2023)
#' \donttest{
#' if (requireNamespace("tidydiversity", quietly = TRUE)) {
#'   richness <- tidydiversity::png_ants |>
#'     dplyr::distinct(site, transect, species) |>
#'     dplyr::count(site, transect, name = "species")
#'   # Transects above 2,200 m were baited but no ants came: richness 0
#'   sites <- png_ants_sites |>
#'     dplyr::left_join(richness, by = c("site", "transect")) |>
#'     dplyr::mutate(species = dplyr::coalesce(species, 0L))
#'   plot_bubble(sites, species, legend_title = "Ant species")
#' }
#' }
NULL

#' @rdname thematic-maps
#' @export
plot_choropleth <- function(data,
                            value,
                            n = 5,
                            style = c("quantile", "equal", "jenks", "pretty",
                                      "sd", "fixed"),
                            breaks = NULL,
                            digits = 3,
                            palette = "YlGnBu",
                            reverse = TRUE,
                            border = "grey30",
                            linewidth = 0.2,
                            na_fill = "grey85",
                            legend_title = NULL) {
  rlang::check_installed(c("ggplot2", "sf"))
  style <- rlang::arg_match(style)
  if (!inherits(data, "sf")) {
    cli::cli_abort("{.arg data} must be an {.cls sf} table of polygons.")
  }
  geom <- unique(as.character(sf::st_geometry_type(data)))
  if (!all(geom %in% c("POLYGON", "MULTIPOLYGON"))) {
    cli::cli_abort(
      "{.arg data} must contain polygons, not {.val {geom}}; use {.fn plot_bubble} for points."
    )
  }
  if (!palette %in% grDevices::hcl.pals()) {
    cli::cli_abort(
      "{.arg palette} must be a palette from {.fn grDevices::hcl.pals}, not {.val {palette}}."
    )
  }
  col <- tmr_pick(enquo(value), data, "value")
  cls <- geo_classify(data, !!rlang::sym(col),
    n = n, style = style,
    breaks = breaks, digits = digits, name = ".class"
  )
  info <- attr(cls, "classification")
  levs <- levels(cls$.class)
  fills <- grDevices::hcl.colors(max(length(levs), 2), palette, rev = reverse)
  fills <- fills[seq_along(levs)]
  p <- ggplot2::ggplot(cls) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data$.class),
      colour = border, linewidth = linewidth
    ) +
    ggplot2::scale_fill_manual(
      values = stats::setNames(fills, levs), drop = FALSE,
      na.value = na_fill, name = legend_title %||% col
    ) +
    theme_tidymapr(grid = "none", legend_position = "right")
  attr(p, "classification") <- info
  p
}

#' @rdname thematic-maps
#' @export
plot_bubble <- function(data,
                        size,
                        lon = lon,
                        lat = lat,
                        colour = NULL,
                        fill = "#0072B2",
                        max_size = 12,
                        alpha = 0.7,
                        background = NULL,
                        legend_title = NULL) {
  rlang::check_installed(c("ggplot2", "sf"))
  tmr_check_number(max_size, "max_size", 0)
  tmr_check_number(alpha, "alpha", 0, 1)
  if (!inherits(data, "sf")) {
    tmr_check_data(data)
    data <- geo_as_sf(data, {{ lon }}, {{ lat }})
  }
  size_col <- tmr_pick(enquo(size), data, "size")
  if (!is.numeric(data[[size_col]])) {
    cli::cli_abort("{.arg size} must be a numeric column.")
  }
  if (any(data[[size_col]] < 0, na.rm = TRUE)) {
    cli::cli_abort("{.arg size} must not be negative; bubble area shows amounts.")
  }
  col_quo <- enquo(colour)
  colour_col <- if (rlang::quo_is_null(col_quo)) {
    NULL
  } else {
    tmr_pick(col_quo, data, "colour")
  }
  # Big bubbles first, so small ones are drawn on top and stay visible
  data <- data[order(-data[[size_col]], na.last = TRUE), ]
  zero <- !is.na(data[[size_col]]) & data[[size_col]] == 0
  absent <- data[zero, ]
  data <- data[!zero, ]
  p <- ggplot2::ggplot()
  if (!is.null(background)) {
    p <- p + ggplot2::geom_sf(
      data = background, fill = "grey95",
      colour = "grey60", linewidth = 0.2
    )
  }
  if (is.null(colour_col)) {
    p <- p + ggplot2::geom_sf(
      data = data,
      ggplot2::aes(size = .data[[size_col]]),
      shape = 21, fill = fill, colour = "white", stroke = 0.4, alpha = alpha
    )
  } else {
    groups <- sort(unique(as.character(data[[colour_col]])))
    p <- p +
      ggplot2::geom_sf(
        data = data,
        ggplot2::aes(size = .data[[size_col]], fill = .data[[colour_col]]),
        shape = 21, colour = "white", stroke = 0.4, alpha = alpha
      ) +
      ggplot2::scale_fill_manual(
        values = stats::setNames(tmr_palette(length(groups)), groups),
        name = colour_col
      ) +
      ggplot2::guides(fill = ggplot2::guide_legend(
        override.aes = list(size = 4)
      ))
  }
  if (nrow(absent) > 0) {
    p <- p + ggplot2::geom_sf(
      data = absent, ggplot2::aes(shape = "0"),
      size = 2, colour = "grey30", stroke = 0.6
    ) +
      ggplot2::scale_shape_manual(
        values = c("0" = 1), name = NULL,
        labels = paste("0", legend_title %||% size_col)
      )
  }
  p +
    ggplot2::scale_size_area(max_size = max_size, name = legend_title %||% size_col) +
    theme_tidymapr(grid = "none", legend_position = "right")
}
