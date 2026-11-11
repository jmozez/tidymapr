#' Bioclimatic rasters (WorldClim and CHELSA)
#'
#' @description
#' Native tidyverse-style verbs for the 19 standard bioclimatic variables
#' used throughout biodiversity studies. [geo_bioclim_vars()] lists the
#' variables with clear names. [geo_worldclim()] and [geo_chelsa()] download
#' or read cached rasters (or accept a user file path when offline), and
#' [geo_bioclim()] is a thin front end that chooses the source. Join values
#' to sites with [geo_extract()].
#'
#' Downloads use a cache directory (default
#' `tools::R_user_dir("tidymapr", "cache")/bioclim`) so repeat calls do
#' not hit the network. Network access is never required in tests: pass a
#' local `path`, or skip downloads on CRAN.
#'
#' @section Citation and licence:
#' * **WorldClim** version 2.1 (Fick and Hijmans 2017). Creative Commons
#'   Attribution 4.0. Cite: Fick, S. E. and Hijmans, R. J. (2017). WorldClim 2:
#'   new 1km spatial resolution climate surfaces for global land areas.
#'   *International Journal of Climatology*, 37, 4302-4315.
#'   \doi{10.1002/joc.5086}. <https://www.worldclim.org/>
#' * **CHELSA** version 2.1 (Karger et al. 2017, 2021). Creative Commons
#'   Attribution 4.0. Cite: Karger, D. N. et al. (2017). Climatologies at high
#'   resolution for the earth's land surface areas. *Scientific Data*, 4,
#'   170122. \doi{10.1038/sdata.2017.122}. <https://chelsa-climate.org/>
#'
#' @param vars Bioclim variable codes such as `"bio1"` or `"bio12"`, or
#'   their tidy names from [geo_bioclim_vars()]. Use `"all"` for bio1-bio19.
#' @param source `"worldclim"` or `"chelsa"`.
#' @param scenario,year,model Optional CHELSA-CMIP6 future climate
#'   arguments (chelsa only). When set, downloads future bioclim layers
#'   (Karger et al. 2023). Use `download = FALSE` on CRAN.
#' @param res WorldClim resolution in minutes: `10`, `5`, `2.5` or `0.5`.
#'   CHELSA downloads use the 30 arc-second product.
#' @param path Optional local file or directory of GeoTIFFs. When supplied,
#'   no download is attempted.
#' @param cache_dir Directory for downloaded rasters.
#' @param download Download missing layers? Set `FALSE` to only read the
#'   cache or `path`.
#' @param version Dataset version string (informational / URL selection).
#' @return A `terra::SpatRaster` with one layer per requested variable.
#'   Layer names are the bioclim codes (`bio1`, ...).
#' @name geo-bioclim
#' @examplesIf requireNamespace("terra", quietly = TRUE)
#' geo_bioclim_vars()
#'
#' \donttest{
#' # Offline: build a tiny stand-in raster and treat it as bio1
#' r <- terra::rast(ncols = 10, nrows = 10, xmin = 144, xmax = 146,
#'   ymin = -7, ymax = -5, crs = "EPSG:4326")
#' names(r) <- "bio1"
#' terra::values(r) <- 20
#' tmp <- tempfile(fileext = ".tif")
#' terra::writeRaster(r, tmp, overwrite = TRUE)
#' geo_worldclim(vars = "bio1", path = tmp, download = FALSE)
#' }
NULL

#' @rdname geo-bioclim
#' @export
geo_bioclim_vars <- function() {
  tibble::tibble(
    code = paste0("bio", 1:19),
    name = c(
      "annual_mean_temperature",
      "mean_diurnal_range",
      "isothermality",
      "temperature_seasonality",
      "max_temperature_warmest_month",
      "min_temperature_coldest_month",
      "temperature_annual_range",
      "mean_temperature_wettest_quarter",
      "mean_temperature_driest_quarter",
      "mean_temperature_warmest_quarter",
      "mean_temperature_coldest_quarter",
      "annual_precipitation",
      "precipitation_wettest_month",
      "precipitation_driest_month",
      "precipitation_seasonality",
      "precipitation_wettest_quarter",
      "precipitation_driest_quarter",
      "precipitation_warmest_quarter",
      "precipitation_coldest_quarter"
    ),
    description = c(
      "Annual mean temperature",
      "Mean diurnal range (mean of monthly max minus min)",
      "Isothermality (bio2 / bio7) * 100",
      "Temperature seasonality (standard deviation * 100)",
      "Maximum temperature of the warmest month",
      "Minimum temperature of the coldest month",
      "Temperature annual range (bio5 minus bio6)",
      "Mean temperature of the wettest quarter",
      "Mean temperature of the driest quarter",
      "Mean temperature of the warmest quarter",
      "Mean temperature of the coldest quarter",
      "Annual precipitation",
      "Precipitation of the wettest month",
      "Precipitation of the driest month",
      "Precipitation seasonality (coefficient of variation)",
      "Precipitation of the wettest quarter",
      "Precipitation of the driest quarter",
      "Precipitation of the warmest quarter",
      "Precipitation of the coldest quarter"
    ),
    unit = c(
      rep("deg_C", 11),
      rep("mm", 2),
      "mm",
      "cv",
      rep("mm", 4)
    )
  )
}

geo_bioclim_resolve_vars <- function(vars) {
  table <- geo_bioclim_vars()
  if (length(vars) == 1 && identical(tolower(vars), "all")) {
    return(table$code)
  }
  vars <- tolower(as.character(vars))
  # Allow tidy names as well as codes
  from_name <- table$code[match(vars, table$name)]
  from_code <- ifelse(vars %in% table$code, vars, NA_character_)
  out <- ifelse(!is.na(from_code), from_code, from_name)
  bad <- vars[is.na(out)]
  if (length(bad) > 0) {
    cli::cli_abort(
      "Unknown bioclim variable{?s}: {.val {bad}}. See {.fn geo_bioclim_vars}."
    )
  }
  unique(out)
}

geo_bioclim_cache_dir <- function(cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- file.path(
      tools::R_user_dir("tidymapr", "cache"),
      "bioclim"
    )
  }
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cache_dir
}

#' @rdname geo-bioclim
#' @export
geo_bioclim <- function(vars = c("bio1", "bio12"),
                        source = c("worldclim", "chelsa"),
                        res = 10,
                        path = NULL,
                        cache_dir = NULL,
                        download = TRUE,
                        version = NULL,
                        scenario = NULL,
                        year = NULL,
                        model = "MPI-ESM1-2-HR") {
  source <- rlang::arg_match(source)
  if (identical(source, "worldclim")) {
    if (!is.null(scenario) || !is.null(year)) {
      cli::cli_abort("CMIP6 future climate is supported for {.val chelsa} only.")
    }
    geo_worldclim(
      vars = vars, res = res, path = path,
      cache_dir = cache_dir, download = download, version = version
    )
  } else {
    geo_chelsa(
      vars = vars, path = path,
      cache_dir = cache_dir, download = download, version = version,
      scenario = scenario, year = year, model = model
    )
  }
}

#' @rdname geo-bioclim
#' @export
geo_worldclim <- function(vars = c("bio1", "bio12"),
                          res = 10,
                          path = NULL,
                          cache_dir = NULL,
                          download = TRUE,
                          version = "2.1") {
  rlang::check_installed("terra")
  vars <- geo_bioclim_resolve_vars(vars)
  res <- as.character(res)
  if (!res %in% c("10", "5", "2.5", "0.5")) {
    cli::cli_abort("{.arg res} must be one of 10, 5, 2.5 or 0.5 minutes.")
  }
  if (!is.null(path)) {
    return(geo_bioclim_from_path(path, vars))
  }
  cache_dir <- geo_bioclim_cache_dir(cache_dir)
  # Prefer geodata when installed (same WorldClim 2.1 source), else direct URL
  if (isTRUE(download) && requireNamespace("geodata", quietly = TRUE)) {
    out <- tryCatch(
      {
        r <- geodata::worldclim_global(
          var = "bio", res = as.numeric(res),
          path = file.path(cache_dir, "geodata")
        )
        geo_bioclim_subset(r, vars)
      },
      error = function(e) NULL
    )
    if (!is.null(out)) {
      return(out)
    }
  }
  layers <- lapply(vars, function(v) {
    geo_worldclim_layer(
      v, res = res, cache_dir = cache_dir,
      download = download, version = version %||% "2.1"
    )
  })
  terra::rast(layers)
}

#' @rdname geo-bioclim
#' @export
geo_chelsa <- function(vars = c("bio1", "bio12"),
                       path = NULL,
                       cache_dir = NULL,
                       download = TRUE,
                       version = "2.1",
                       scenario = NULL,
                       year = NULL,
                       model = "MPI-ESM1-2-HR") {
  rlang::check_installed("terra")
  vars <- geo_bioclim_resolve_vars(vars)
  if (!is.null(path)) {
    return(geo_bioclim_from_path(path, vars))
  }
  cache_dir <- geo_bioclim_cache_dir(cache_dir)
  # Future climate (CHELSA-CMIP6 / geodata cmip6)
  if (!is.null(scenario) || !is.null(year)) {
    return(geo_chelsa_cmip6(
      vars = vars, scenario = scenario %||% "ssp585",
      year = year %||% 2050, model = model,
      cache_dir = cache_dir, download = download
    ))
  }
  # Current geodata releases do not export chelsa(); download CHELSA
  # GeoTIFFs directly (geo_chelsa_layer) and cache under cache_dir.
  layers <- lapply(vars, function(v) {
    geo_chelsa_layer(
      v, cache_dir = cache_dir,
      download = download, version = version %||% "2.1"
    )
  })
  terra::rast(layers)
}

#' CHELSA-CMIP6 future bioclim layers
#'
#' Downloads future bioclimatic surfaces for a CMIP6 scenario and year
#' (Karger et al. 2023). Network access is skipped when `download = FALSE`
#' (use on CRAN). Prefer `path` for offline GeoTIFFs.
#'
#' @inheritParams geo_chelsa
#' @param scenario CMIP6 scenario, for example `"ssp126"`, `"ssp370"`,
#'   `"ssp585"`.
#' @param year Target year (for example 2050 or 2070).
#' @param model Climate model id passed to geodata when available.
#' @references
#' Karger, D. N., et al. (2023). Climatologies at high resolution for the
#' earth land surface areas (CHELSA-CMIP6). *Ecography*.
#' \doi{10.1111/ecog.06535}
#' @noRd
geo_chelsa_cmip6 <- function(vars, scenario, year, model, cache_dir, download) {
  year <- as.integer(year)
  scenario <- tolower(as.character(scenario))
  if (isTRUE(download) && requireNamespace("geodata", quietly = TRUE)) {
    out <- tryCatch({
      rs <- lapply(vars, function(v) {
        n <- as.integer(sub("bio", "", v))
        geodata::cmip6_world(
          model = model, ssp = gsub("ssp", "", scenario),
          time = paste0(year, "s"), var = "bioc", res = 5,
          path = file.path(cache_dir, "geodata-cmip6")
        )[[n]]
      })
      r <- terra::rast(rs)
      names(r) <- vars
      r
    }, error = function(e) NULL)
    if (!is.null(out)) return(out)
  }
  # Direct CHELSA-CMIP6 style cache lookup / download attempt
  layers <- lapply(vars, function(v) {
    n <- sub("bio", "", v)
    fname <- sprintf("CHELSA_%s_month_20%d_%s_%s_V.2.1.tif", v, year %% 100, scenario, model)
    # Simpler cache key
    dest <- file.path(cache_dir, "chelsa-cmip6",
                      sprintf("%s_%s_%s_%s.tif", v, scenario, year, model))
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(dest)) {
      r <- terra::rast(dest)
      names(r) <- v
      return(r)
    }
    if (!isTRUE(download)) {
      cli::cli_abort(
        c(
          "CHELSA-CMIP6 layer {.val {v}} ({scenario}, {year}) is not cached.",
          "i" = "Pass {.arg path} or set {.arg download} = TRUE off CRAN."
        )
      )
    }
    cli::cli_abort(
      c(
        "Could not download CHELSA-CMIP6 for {.val {v}} ({scenario}, {year}).",
        "i" = "Install {.pkg geodata} (>= 0.6) or pass local GeoTIFFs via {.arg path}.",
        "i" = "Cite Karger et al. (2023), doi:10.1111/ecog.06535."
      )
    )
  })
  terra::rast(layers)
}

geo_bioclim_from_path <- function(path, vars) {
  rlang::check_installed("terra")
  if (length(path) == 1 && dir.exists(path)) {
    files <- list.files(path, pattern = "\\.(tif|tiff|grd|nc)$",
      full.names = TRUE, ignore.case = TRUE
    )
    if (length(files) == 0) {
      cli::cli_abort("No raster files found in {.path {path}}.")
    }
    r <- terra::rast(files)
  } else {
    r <- terra::rast(path)
  }
  geo_bioclim_subset(r, vars)
}

geo_bioclim_subset <- function(r, vars) {
  nms <- tolower(names(r))
  # geodata names like wc2.1_10m_bio_1 or CHELSA_bio1_...
  codes <- vapply(nms, function(nm) {
    m <- regmatches(nm, regexpr("bio[_]?[0-9]+", nm))
    if (length(m) == 0 || identical(m, character(0))) {
      return(NA_character_)
    }
    paste0("bio", sub("^bio[_ ]?", "", m))
  }, character(1))
  # Also accept exact bio1..bio19 layer names
  codes[nms %in% vars] <- nms[nms %in% vars]
  names(r) <- ifelse(is.na(codes), nms, codes)
  missing <- setdiff(vars, names(r))
  if (length(missing) > 0) {
    # If single-layer file named generically, rename when one var requested
    if (terra::nlyr(r) == 1 && length(vars) == 1) {
      names(r) <- vars
      return(r)
    }
    cli::cli_abort(
      "Raster does not contain variable{?s} {.val {missing}}."
    )
  }
  r[[vars]]
}

geo_worldclim_layer <- function(var, res, cache_dir, download, version) {
  # WorldClim 2.1 per-variable GeoTIFF zip layout
  res_tag <- paste0(res, "m")
  n <- sub("bio", "", var)
  fname <- paste0("wc", version, "_", res_tag, "_bio_", n, ".tif")
  dest <- file.path(cache_dir, "worldclim", fname)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(dest)) {
    if (!isTRUE(download)) {
      cli::cli_abort(
        "WorldClim layer {.val {var}} is not in the cache and {.arg download} is FALSE."
      )
    }
    # Zip containing all bio layers at this resolution
    zip_name <- paste0("wc", version, "_", res_tag, "_bio.zip")
    zip_path <- file.path(cache_dir, "worldclim", zip_name)
    url <- paste0(
      "https://geodata.ucdavis.edu/climate/worldclim/2_1/base/",
      zip_name
    )
    if (!file.exists(zip_path)) {
      cli::cli_inform("Downloading WorldClim {version} bioclim ({res} min)...")
      ok <- tryCatch(
        {
          utils::download.file(url, zip_path, mode = "wb", quiet = TRUE)
          file.exists(zip_path) && file.info(zip_path)$size > 0
        },
        error = function(e) FALSE
      )
      if (!isTRUE(ok)) {
        cli::cli_abort(
          c(
            "Could not download WorldClim data from {.url {url}}.",
            "i" = "Pass {.arg path} to a local GeoTIFF when offline."
          )
        )
      }
    }
    utils::unzip(zip_path, files = fname, exdir = dirname(dest), overwrite = TRUE)
    # Some zips nest the file
    if (!file.exists(dest)) {
      found <- list.files(dirname(dest), pattern = fname, recursive = TRUE,
        full.names = TRUE
      )
      if (length(found) == 1) {
        file.rename(found, dest)
      }
    }
  }
  if (!file.exists(dest)) {
    cli::cli_abort("WorldClim file {.file {fname}} was not found after download.")
  }
  r <- terra::rast(dest)
  names(r) <- var
  r
}

geo_chelsa_layer <- function(var, cache_dir, download, version) {
  n <- sub("bio", "", var)
  # CHELSA v2.1 climatology bio files
  fname <- paste0("CHELSA_bio", n, "_1981-2010_V.2.1.tif")
  dest <- file.path(cache_dir, "chelsa", fname)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(dest)) {
    if (!isTRUE(download)) {
      cli::cli_abort(
        "CHELSA layer {.val {var}} is not in the cache and {.arg download} is FALSE."
      )
    }
    url <- paste0(
      "https://os.zhdk.cloud.switch.ch/chelsav2/GLOBAL/climatologies/1981-2010/bio/",
      fname
    )
    cli::cli_inform("Downloading CHELSA {version} {.val {var}}...")
    ok <- tryCatch(
      {
        utils::download.file(url, dest, mode = "wb", quiet = TRUE)
        file.exists(dest) && file.info(dest)$size > 0
      },
      error = function(e) FALSE
    )
    if (!isTRUE(ok)) {
      unlink(dest)
      cli::cli_abort(
        c(
          "Could not download CHELSA data from {.url {url}}.",
          "i" = "Pass {.arg path} to a local GeoTIFF when offline."
        )
      )
    }
  }
  r <- terra::rast(dest)
  names(r) <- var
  r
}
