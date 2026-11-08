#' tidymapr: Tidy Mapping Verbs for Biodiversity and Spatial Ecology
#'
#' Mapping and geospatial verbs for biodiversity data. tidymapr works with
#' tidydiversity in the same way dplyr and ggplot2 do: every verb takes a
#' data frame and returns a tibble, an `sf` table, a `SpatRaster` or a
#' ggplot, so diversity estimates and maps stay in one tidy workflow.
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
