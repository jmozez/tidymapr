#' ESA WorldCover land cover
#'
#' @description
#' `geo_landcover()` reads the ESA WorldCover 10 m global land-cover map
#' (Zanaga et al. 2022) for an area, straight from its public
#' cloud-optimised GeoTIFFs (3 x 3 degree tiles on AWS; also served as the
#' `"esa-worldcover"` collection of the Microsoft Planetary Computer STAC
#' API, see [geo_stac_search()]). Only the window over the area is read.
#'
#' Classes: 10 tree cover, 20 shrubland, 30 grassland, 40 cropland,
#' 50 built-up, 60 bare or sparse vegetation, 70 snow and ice, 80 permanent
#' water, 90 herbaceous wetland, 95 mangroves, 100 moss and lichen.
#'
#' @param area Area: `sf`, `sfc`, `SpatVector`, `SpatRaster`, `SpatExtent`
#'   or `c(xmin, ymin, xmax, ymax)` in degrees.
#' @param classes Optional class codes to keep, for example `c(10, 95)` for
#'   forest (tree cover and mangroves). The result is then `TRUE` for those
#'   classes and `FALSE` elsewhere.
#' @param template Optional `SpatRaster` (for example a DEM) whose grid the
#'   result should share. Land cover is resampled to it with the modal
#'   class (`"mode"`), reading coarser overviews when the template is
#'   coarser than 10 m.
#' @param year 2021 (version 200, default) or 2020 (version 100).
#' @return A `SpatRaster` of class codes, or a logical layer with `classes`.
#' @references
#' Zanaga, D. et al. (2022). ESA WorldCover 10 m 2021 v200.
#' \doi{10.5281/zenodo.7254221}
#' @export
#' @examplesIf interactive() && rlang::is_installed("terra")
#' forest <- geo_landcover(c(146.5, -6.6, 146.7, -6.4), classes = c(10, 95))
geo_landcover <- function(area,
                          classes = NULL,
                          template = NULL,
                          year = 2021) {
  rlang::check_installed("terra")
  bb <- tmr_bbox_numbers(area)
  urls <- tmr_worldcover_urls(bb, year)
  e <- terra::ext(bb[1], bb[3], bb[2], bb[4])
  parts <- lapply(urls, function(u) {
    r <- terra::rast(paste0("/vsicurl/", u))
    if (is.null(terra::intersect(terra::ext(r), e))) {
      return(NULL)
    }
    if (is.null(template)) {
      terra::crop(r, e)
    } else {
      tmpl <- terra::crop(geo_as_raster(template)[[1]], e, snap = "out")
      terra::project(r, tmpl, method = "mode")
    }
  })
  parts <- Filter(Negate(is.null), parts)
  if (!length(parts)) {
    cli::cli_abort("No WorldCover tiles cover {.arg area}.")
  }
  out <- if (length(parts) == 1) {
    parts[[1]]
  } else if (is.null(template)) {
    terra::merge(terra::sprc(parts))
  } else {
    terra::mosaic(terra::sprc(parts), fun = "max")
  }
  names(out) <- "landcover"
  if (!is.null(classes)) {
    out <- terra::app(out, function(v) v %in% classes)
    names(out) <- "landcover_class"
  }
  out
}

#' @rdname geo_landcover
#' @param bbox `c(xmin, ymin, xmax, ymax)` in degrees.
#' @return `geo_worldcover_tiles()`: tile names such as `"S09E144"` (the
#'   south-west corner of each 3 x 3 degree tile).
#' @export
geo_worldcover_tiles <- function(bbox) {
  bb <- tmr_bbox_numbers(bbox)
  xs <- seq(floor(bb[1] / 3) * 3, ceiling(bb[3] / 3) * 3 - 3, by = 3)
  ys <- seq(floor(bb[2] / 3) * 3, ceiling(bb[4] / 3) * 3 - 3, by = 3)
  g <- expand.grid(x = xs, y = ys)
  sprintf(
    "%s%02d%s%03d", ifelse(g$y < 0, "S", "N"), abs(g$y),
    ifelse(g$x < 0, "W", "E"), abs(g$x)
  )
}

tmr_worldcover_urls <- function(bb, year) {
  ver <- switch(as.character(year),
    "2021" = "v200",
    "2020" = "v100",
    cli::cli_abort("{.arg year} must be 2020 or 2021.")
  )
  sprintf(
    paste0(
      "https://esa-worldcover.s3.eu-central-1.amazonaws.com/",
      "%s/%s/map/ESA_WorldCover_10m_%s_%s_%s_Map.tif"
    ),
    ver, year, year, ver, geo_worldcover_tiles(bb)
  )
}

# c(xmin, ymin, xmax, ymax) from any area
tmr_bbox_numbers <- function(area) {
  is_terra <- inherits(area, c("SpatRaster", "SpatExtent", "SpatVector"))
  e <- if (is_terra) {
    terra::ext(area)
  } else if (inherits(area, "sf") || inherits(area, "sfc")) {
    terra::ext(geo_raster_vect(area, terra::rast()))
  } else {
    tmr_as_extent(area)
  }
  unname(as.vector(e)[c("xmin", "ymin", "xmax", "ymax")])
}
