#' Map theme
#'
#' `theme_tidymapr()` is the clean ggplot2 theme used by every tidymapr map:
#' white background, black text, plain facet strips and a legend at the
#' bottom. It matches `tidydiversity::theme_tidydiversity()`, so maps and
#' diversity plots from the two packages look the same side by side.
#'
#' @param base_size Base font size in points.
#' @param base_family Base font family.
#' @param legend_position Legend position, passed to [ggplot2::theme()].
#' @param grid Draw major grid lines: `"y"`, `"x"`, `"xy"` or `"none"`.
#' @return A ggplot2 theme.
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' library(ggplot2)
#' ggplot(geo_example_sites(), aes(lon, lat, colour = elevation_band)) +
#'   geom_point() +
#'   theme_tidymapr(grid = "none")
theme_tidymapr <- function(base_size = 11,
                           base_family = "",
                           legend_position = "bottom",
                           grid = c("y", "x", "xy", "none")) {
  rlang::check_installed("ggplot2")
  grid <- rlang::arg_match(grid)
  blank <- ggplot2::element_blank()
  line <- ggplot2::element_line(colour = "grey90", linewidth = 0.3)
  ggplot2::theme_bw(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = blank,
      panel.grid.major.x = if (grid %in% c("x", "xy")) line else blank,
      panel.grid.major.y = if (grid %in% c("y", "xy")) line else blank,
      panel.border = ggplot2::element_rect(
        colour = "grey30", fill = NA,
        linewidth = 0.4
      ),
      axis.ticks = ggplot2::element_line(colour = "grey30", linewidth = 0.3),
      axis.text = ggplot2::element_text(colour = "black"),
      strip.background = ggplot2::element_rect(
        fill = "grey95",
        colour = "grey30", linewidth = 0.4
      ),
      strip.text = ggplot2::element_text(
        colour = "black",
        face = "bold"
      ),
      legend.position = legend_position,
      legend.key = blank,
      legend.background = blank,
      plot.title.position = "plot",
      panel.spacing = ggplot2::unit(0.9, "lines"),
      # Always a white figure, also on dark web pages and slides
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA)
    )
}

okabe_ito <- c(
  "#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9",
  "#F0E442", "#000000"
)

# Colour-blind-safe discrete colours, as in tidydiversity::plot_palette().
tmr_palette <- function(n, palette = c("okabe_ito", "grey")) {
  palette <- rlang::arg_match(palette)
  tmr_check_number(n, "n", 0, whole = TRUE)
  if (palette == "grey") {
    return(grDevices::grey.colors(n, start = 0, end = 0.7))
  }
  if (n > length(okabe_ito)) {
    return(grDevices::hcl.colors(n, "viridis"))
  }
  okabe_ito[seq_len(n)]
}
