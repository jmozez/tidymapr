#' Present and future climate: CHELSA, lapse-rate downscaling and canopy buffering
#'
#' @description
#' Climate inputs for range-shift models. Unlike [geo_chelsa()], which
#' downloads whole global files, these read only the area needed, and
#' future climate comes from CHELSA-CMIP6 itself.
#'
#'
#' * `geo_chelsa_area()` reads CHELSA V2.1 climatologies (Karger et al. 2017),
#'   about 1 km, for an area: the 1981-2010 baseline or CMIP6 projections
#'   for 2011-2040, 2041-2070 and 2071-2100 under SSP1-2.6, SSP3-7.0 and
#'   SSP5-8.5 from five global climate models (GCMs). Only the window over
#'   the area is read from the cloud-optimised files; scale and offset are
#'   applied, so temperatures are in degrees C.
#' * `geo_downscale_lapse()` brings a coarse temperature layer down to the
#'   resolution of a fine digital elevation model with a lapse rate:
#'   \deqn{T_{fine} = T_{coarse} + \gamma (z_{coarse} - z_{fine}) / 1000,}{
#'   T_fine = T_coarse + gamma (z_coarse - z_fine) / 1000,}
#'   where \eqn{z_{coarse}} is the elevation the coarse value represents
#'   (by default the mean of the fine DEM within each coarse cell) and
#'   \eqn{\gamma} the lapse rate in degrees C per km. On steep tropical
#'   mountains a 1 km cell can span over 1,000 m, about 5 degrees C, so this
#'   step matters for species with narrow elevational ranges.
#' * `geo_canopy_offset()` adds the buffering of the forest canopy: below
#'   closed forest, maximum temperatures are lower and minimum temperatures
#'   higher than in the open (De Frenne et al. 2019, 2021). The offset is
#'   scaled by canopy cover (0 to 1), for example from [geo_landcover()].
#'
#' @param area Area: `sf`, `SpatRaster`, `SpatVector`, `SpatExtent` or
#'   `c(xmin, ymin, xmax, ymax)` in degrees.
#' @param variables CHELSA variables, for example `"bio1"` (annual mean
#'   temperature), `"bio5"` (maximum temperature of the warmest month),
#'   `"bio6"`, `"bio12"` (annual precipitation).
#' @param period `"1981-2010"` (baseline), `"2011-2040"`, `"2041-2070"` or
#'   `"2071-2100"`.
#' @param gcm,ssp For future periods: GCMs (`"gfdl-esm4"`,
#'   `"ipsl-cm6a-lr"`, `"mpi-esm1-2-hr"`, `"mri-esm2-0"`, `"ukesm1-0-ll"`)
#'   and scenarios (`"ssp126"`, `"ssp370"`, `"ssp585"`). Every combination
#'   is read, giving an ensemble.
#' @return `geo_chelsa_area()`: a `SpatRaster` with one layer per variable (and
#'   GCM and scenario), named for example `"bio1_2071-2100_mpi-esm1-2-hr_ssp585"`.
#' @references
#' De Frenne, P. et al. (2019). Global buffering of temperatures under
#' forest canopies. Nature Ecology & Evolution, 3, 744-749.
#'
#' De Frenne, P. et al. (2021). Forest microclimates and climate change:
#' importance, drivers and future research agenda. Global Change Biology,
#' 27, 2279-2297.
#'
#' Karger, D. N. et al. (2017). Climatologies at high resolution for the
#' earth's land surface areas. Scientific Data, 4, 170122.
#' @name geo-climate
#' @examplesIf interactive() && rlang::is_installed("terra")
#' huon <- c(146.5, -6.5, 147, -6)
#' now <- geo_chelsa_area(huon, "bio1")
#' future <- geo_chelsa_area(huon, "bio1",
#'   period = "2071-2100",
#'   gcm = c("mpi-esm1-2-hr", "ukesm1-0-ll"), ssp = "ssp585"
#' )
#' warming <- future - now
NULL

tmr_chelsa_gcms <- c("gfdl-esm4", "ipsl-cm6a-lr", "mpi-esm1-2-hr", "mri-esm2-0", "ukesm1-0-ll")
tmr_chelsa_ssps <- c("ssp126", "ssp370", "ssp585")
tmr_chelsa_periods <- c("1981-2010", "2011-2040", "2041-2070", "2071-2100")

#' @rdname geo-climate
#' @export
geo_chelsa_area <- function(area,
                            variables = "bio1",
                            period = "1981-2010",
                            gcm = NULL,
                            ssp = NULL) {
  rlang::check_installed("terra")
  urls <- geo_chelsa_urls(variables, period, gcm, ssp)
  bb <- tmr_bbox_numbers(area)
  e <- terra::ext(bb[1], bb[3], bb[2], bb[4])
  layers <- lapply(seq_len(nrow(urls)), function(i) {
    r <- terra::crop(terra::rast(paste0("/vsicurl/", urls$url[i])), e, snap = "out")
    names(r) <- urls$name[i]
    r
  })
  terra::rast(layers)
}

#' @rdname geo-climate
#' @return `geo_chelsa_urls()`: a tibble of `name` and `url` of the files
#'   `geo_chelsa_area()` would read (no download).
#' @export
geo_chelsa_urls <- function(variables = "bio1",
                            period = "1981-2010",
                            gcm = NULL,
                            ssp = NULL) {
  period <- rlang::arg_match0(period, tmr_chelsa_periods)
  base <- "https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies"
  if (period == "1981-2010") {
    if (!is.null(gcm) || !is.null(ssp)) {
      cli::cli_abort("{.arg gcm} and {.arg ssp} apply only to future periods.")
    }
    return(tibble::tibble(
      name = paste(variables, period, sep = "_"),
      url = sprintf("%s/%s/bio/CHELSA_%s_%s_V.2.1.tif", base, period, variables, period)
    ))
  }
  gcm <- gcm %||% tmr_chelsa_gcms
  ssp <- ssp %||% "ssp585"
  bad <- c(setdiff(gcm, tmr_chelsa_gcms), setdiff(ssp, tmr_chelsa_ssps))
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown GCM or scenario: {.val {bad}}.",
      "i" = "GCMs: {.val {tmr_chelsa_gcms}}; scenarios: {.val {tmr_chelsa_ssps}}."
    ))
  }
  g <- expand.grid(v = variables, m = gcm, s = ssp, stringsAsFactors = FALSE)
  tibble::tibble(
    name = paste(g$v, period, g$m, g$s, sep = "_"),
    url = sprintf(
      "%s/%s/%s/%s/bio/CHELSA_%s_%s_%s_%s_V.2.1.tif",
      base, period, toupper(g$m), g$s, g$v, period, g$m, g$s
    )
  )
}

#' @rdname geo-climate
#' @param climate Coarse temperature `SpatRaster` (one or more layers).
#' @param dem Fine elevation `SpatRaster` (metres); the result has its grid.
#' @param lapse_rate Temperature lapse rate in degrees C per km (positive:
#'   cooler with height). Use one measured on your mountain where possible;
#'   about 5 to 6.5 is typical of humid tropical mountains.
#' @param coarse_dem Elevation that the coarse values represent; by default
#'   the mean of `dem` within each cell of `climate`.
#' @return `geo_downscale_lapse()`: a `SpatRaster` on the grid of `dem`.
#' @export
geo_downscale_lapse <- function(climate, dem, lapse_rate, coarse_dem = NULL) {
  rlang::check_installed("terra")
  if (!is.numeric(lapse_rate) || length(lapse_rate) != 1 || is.na(lapse_rate)) {
    cli::cli_abort("{.arg lapse_rate} must be one number (degrees C per km).")
  }
  clim <- geo_as_raster(climate)[[1]]
  z <- geo_as_raster(dem)[[1]][[1]]
  if (!terra::same.crs(clim, z)) {
    clim <- terra::project(clim, terra::crs(z))
  }
  if (is.null(coarse_dem)) {
    zc <- terra::resample(z, clim[[1]], method = "average")
  } else {
    zc <- geo_as_raster(coarse_dem)[[1]][[1]]
    if (!terra::compareGeom(zc, clim[[1]], stopOnError = FALSE)) {
      zc <- terra::resample(zc, clim[[1]], method = "bilinear")
    }
  }
  t_fine <- terra::resample(clim, z, method = "bilinear")
  zc_fine <- terra::resample(zc, z, method = "bilinear")
  out <- t_fine + lapse_rate * (zc_fine - z) / 1000
  names(out) <- names(clim)
  out
}

#' @rdname geo-climate
#' @param temperature Temperature `SpatRaster` (degrees C).
#' @param canopy Canopy cover `SpatRaster`, 0 (open) to 1 (closed forest),
#'   or a logical forest layer.
#' @param offset Temperature difference below closed canopy relative to the
#'   open, in degrees C: one number, or a `SpatRaster`. There is no default
#'   because it depends on the variable: forests cool maximum temperatures by
#'   about 4 degrees C on average and warm minimum temperatures by about 1
#'   degree C (De Frenne et al. 2019), with larger offsets in dense tropical
#'   forest. Use a value measured with loggers where possible.
#' @return `geo_canopy_offset()`: `temperature + canopy * offset`.
#' @export
geo_canopy_offset <- function(temperature, canopy, offset) {
  rlang::check_installed("terra")
  t <- geo_as_raster(temperature)[[1]]
  cv <- geo_as_raster(canopy)[[1]][[1]] * 1
  if (!terra::compareGeom(cv, t[[1]], stopOnError = FALSE)) {
    cv <- terra::resample(cv, t[[1]], method = "average")
  }
  rng <- terra::global(cv, "range", na.rm = TRUE)
  if (any(unlist(rng) < 0 | unlist(rng) > 1, na.rm = TRUE)) {
    cli::cli_abort("{.arg canopy} must lie between 0 and 1.")
  }
  if (is.numeric(offset) && (length(offset) != 1 || is.na(offset))) {
    cli::cli_abort("{.arg offset} must be one number or a raster.")
  }
  off <- if (inherits(offset, "SpatRaster")) offset[[1]] else offset
  out <- t + cv * off
  names(out) <- names(t)
  out
}
