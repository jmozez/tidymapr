#' tidymapr: Tidy Mapping, Spatial Analysis and Publication Cartography
#'
#' Publication-quality maps and spatial analysis in R, in the style of a
#' desktop GIS: automatic, explained map design ([geo_automap()]),
#' projections, legends and map furniture, GIS, CAD and remote sensing
#' formats, and fast C++ spatial statistics. Compatible with the GeoSpaX
#' desktop GIS, whose cartographic conventions it follows. For ecology it
#' works with tidydiversity in the same way dplyr and ggplot2 do: every
#' verb takes a data frame and returns a tibble, an `sf` table, a
#' `SpatRaster` or a ggplot.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data enquo quo_is_null caller_env %||% :=
#' @useDynLib tidymapr, .registration = TRUE
#' @importFrom Rcpp sourceCpp
## usethis namespace: end
NULL

# Lazy-loaded package data used inside functions.
utils::globalVariables("png_ants_sites")
