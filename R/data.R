#' GPS positions of the Mt Wilhelm ant bait transects
#'
#' Real field coordinates for the bait transects behind [tidydiversity::png_ants]. The
#' published data give a GPS position and elevation for every bait; this
#' table averages them to one point per elevation band and transect (two
#' transects per band, eight bands from 200 to 3700 m). Use it to map the
#' study sites or to join coordinates onto `tidydiversity::png_ants` by `site`.
#' [geo_example_sites()] returns the band centroids (mean of the two
#' transects).
#'
#' @format A tibble with 16 rows and 7 columns:
#' \describe{
#'   \item{site}{Elevation band code, as in `png_ants` (`"MW0200"`).}
#'   \item{transect}{Transect number within the band (1 or 2).}
#'   \item{elevation_band}{Nominal elevation band in metres.}
#'   \item{elevation}{Mean GPS elevation of the baits on the transect, in
#'     metres.}
#'   \item{lon, lat}{Mean WGS84 longitude and latitude of the baits.}
#'   \item{baits}{Number of bait positions averaged.}
#' }
#' @source Mottl, O., Moses, J. and Klimes, P. (2023). Data and code for
#'   "Nutrient use by tropical ant communities varies among three extensive
#'   elevational gradients: a cross-continental comparison". Zenodo, open
#'   licence. \doi{10.5281/zenodo.8191946}. Built by
#'   `data-raw/png_ants_sites.R` in the package source.
#' @references Moses, J., Peters, M. K., Tiede, Y., Mottl, O., Donoso, D. A.,
#'   Farwig, N., Fayle, T. M., Novotny, V., Sanders, N. J. and Klimes, P.
#'   (2023). Nutrient use by tropical ant communities varies among three
#'   extensive elevational gradients: a cross-continental comparison.
#'   *Global Ecology and Biogeography*, 32, 2212-2229.
#'   \doi{10.1111/geb.13757}
#' @examples
#' png_ants_sites
"png_ants_sites"
