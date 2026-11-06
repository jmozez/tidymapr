#' Administrative boundaries from GADM
#'
#' Downloads (and caches) Global Administrative Areas (GADM) boundaries as an
#' `sf` tibble via **geodata**. Level 0 is the country outline, level 1
#' provinces / states, and level 2 districts. Use the result as `admin` in
#' [plot_sites()] / [plot_geo()], as an overview for `geo_annotation_inset()`,
#' or to clip occurrences with [geo_intersection()] / [geo_raster_mask()].
#'
#' GADM data are free for academic and non-commercial use; redistribution of
#' the full database (or derived commercial products) is restricted. See
#' <https://gadm.org/license.html>. This package never bundles GADM files;
#' each call downloads into a user cache (or reads `path`) and the download
#' is skipped when `download = FALSE` (the CRAN / offline default pattern).
#'
#' @param country ISO3 code or country name understood by
#'   `geodata::gadm()` (for example `"PNG"` or `"Papua New Guinea"`).
#' @param level Administrative level: `0` (country), `1` (province), or
#'   `2` (district).
#' @param path Optional local GeoPackage / shapefile / RDS previously saved
#'   with [geo_vector_write()]. When set, no download is attempted.
#' @param cache_dir Cache directory. Defaults to
#'   `tools::R_user_dir("tidymapr", "cache")/gadm`.
#' @param download Download when the cache is empty? Set `FALSE` on CRAN
#'   or offline runners.
#' @param version GADM version string passed to geodata (default `"4.1"`).
#' @return An `sf` tibble of multipolygons (class `tmr_geo_sf`).
#' @references
#' Global Administrative Areas (GADM). <https://gadm.org/>
#' @seealso [geo_vector_read()], [geo_vector_write()], [plot_sites()]
#' @export
#' @examplesIf requireNamespace("sf", quietly = TRUE)
#' # Offline: read a previously cached GeoPackage
#' # png <- geo_gadm("PNG", level = 1, path = "png_adm1.gpkg")
#' #
#' # Online (needs geodata + network; skipped on CRAN):
#' # png <- geo_gadm("PNG", level = 1)
#' # plot_sites(geo_example_sites("wilhelm"), lon, lat, admin = png)
geo_gadm <- function(country = "PNG",
                     level = 0,
                     path = NULL,
                     cache_dir = NULL,
                     download = TRUE,
                     version = "4.1") {
  rlang::check_installed("sf")
  level <- as.integer(level)
  if (!level %in% 0:2) {
    cli::cli_abort("{.arg level} must be 0, 1 or 2.")
  }
  if (!is.null(path)) {
    return(geo_vector_read(path))
  }
  cache_dir <- cache_dir %||% file.path(
    tools::R_user_dir("tidymapr", "cache"), "gadm"
  )
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  key <- sprintf(
    "gadm_%s_lev%s_v%s.gpkg",
    gsub("[^A-Za-z0-9]+", "_", toupper(as.character(country))),
    level,
    gsub("[^0-9.]", "", version)
  )
  dest <- file.path(cache_dir, key)
  if (file.exists(dest)) {
    return(geo_vector_read(dest))
  }
  if (!isTRUE(download)) {
    cli::cli_abort(
      c(
        paste(
          "No cached GADM file for {.val {country}} level {level}",
          "and {.arg download} is FALSE."
        ),
        "i" = paste(
          "Pass {.arg path} to a local GeoPackage,",
          "or set {.arg download} = TRUE once online."
        ),
        "i" = paste(
          "GADM license: https://gadm.org/license.html",
          "(non-commercial; do not redistribute the full database)."
        )
      )
    )
  }
  rlang::check_installed("geodata")
  vect <- tryCatch(
    geodata::gadm(
      country = country, level = level, path = cache_dir, version = version
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "GADM download failed for {.val {country}} level {level}.",
          "x" = conditionMessage(e),
          "i" = "Check the ISO3 code, network access, and the GADM license terms."
        )
      )
    }
  )
  # geodata returns SpatVector; convert via sf (GDAL/OGR under the hood)
  if (inherits(vect, "SpatVector")) {
    rlang::check_installed("terra")
    tmp <- tempfile(fileext = ".gpkg")
    on.exit(unlink(tmp), add = TRUE)
    terra::writeVector(vect, tmp, overwrite = TRUE)
    out <- geo_vector_read(tmp)
  } else if (inherits(vect, "sf")) {
    out <- vect
  } else {
    cli::cli_abort("Unexpected GADM return type from geodata.")
  }
  # Persist as GeoPackage in the tidymapr cache for next time
  tryCatch(
    geo_vector_write(out, dest, overwrite = TRUE),
    error = function(e) {
      cli::cli_warn("Could not cache GADM to {.path {dest}}: {conditionMessage(e)}")
    }
  )
  class(out) <- unique(c("tmr_geo_sf", class(out)))
  out
}
