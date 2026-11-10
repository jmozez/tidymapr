#' Map tree stems over topography
#'
#' @description
#' `plot_topo()` draws individual trees or stems over a topographic backdrop
#' for ForestGEO-style and similar plot inventories (Wanang and other large
#' forest dynamics plots). Points use local projected coordinates in metres
#' (`gx`, `gy`) or geographic lon/lat. The backdrop can be contour lines,
#' a DEM / hillshade raster, or both. Colour by species or size (DBH), and
#' optionally draw the plot boundary.
#'
#' Expected columns for a ForestGEO-like table: `plot`, `treeID`, `stemID`,
#' `gx`, `gy` (metres from the plot origin), `dbh`, `species`, `status`.
#' Geographic inventories may use `lon` / `lat` instead of `gx` / `gy`.
#'
#' Pass your own stem inventory. [geo_example_stems()] is simulated test
#' data for checking code, not a real plot, so do not publish maps drawn
#' from it.
#'
#' @param data A data frame of stems/trees, or an `sf` object.
#' @param x,y <[`data-masking`][dplyr::dplyr_data_masking]> Local metre
#'   columns (defaults `gx`, `gy`). Ignored when `lon`/`lat` are set or
#'   `data` is `sf`.
#' @param lon,lat <[`data-masking`][dplyr::dplyr_data_masking]> Optional
#'   geographic coordinates. When supplied, they override `x`/`y`.
#' @param colour <[`data-masking`][dplyr::dplyr_data_masking]> Grouping
#'   column (species, status) or a continuous size such as DBH.
#' @param size <[`data-masking`][dplyr::dplyr_data_masking]> Optional column
#'   mapped to point size (typically `dbh`). When `NULL` and `dbh` exists,
#'   DBH is used.
#' @param dem Optional `terra::SpatRaster` elevation surface for hillshade
#'   and/or contours. In local metre coordinates the raster should use the
#'   same origin as `gx`/`gy`.
#' @param boundary Optional `sf` polygon of the plot boundary, or a numeric
#'   bbox `c(xmin, ymin, xmax, ymax)`.
#' @param contours Draw contour lines from `dem`?
#' @param hillshade Draw a hillshade backdrop from `dem`?
#' @param contour_breaks Contour interval, or a vector of breaks. When
#'   `NULL`, pretty breaks are chosen.
#' @param basemap Passed to [geo_basemap()] when using lon/lat (for example
#'   `"coast"`). Ignored for local metre coordinates.
#' @param palette Discrete palette when `colour` is categorical.
#' @param point_alpha Point opacity.
#' @return A ggplot object.
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' stems <- geo_example_stems()
#' dem <- geo_example_dem()
#' plot_topo(stems, colour = species, size = dbh, dem = dem, boundary = c(0, 0, 100, 100))
plot_topo <- function(data,
                      x = "gx",
                      y = "gy",
                      lon = NULL,
                      lat = NULL,
                      colour = NULL,
                      size = NULL,
                      dem = NULL,
                      boundary = NULL,
                      contours = TRUE,
                      hillshade = TRUE,
                      contour_breaks = NULL,
                      basemap = "none",
                      palette = c("okabe_ito", "grey"),
                      point_alpha = 0.85) {
  rlang::check_installed("ggplot2")
  palette <- rlang::arg_match(palette)
  tmr_check_data(data)

  lon_q <- enquo(lon)
  lat_q <- enquo(lat)
  use_geo <- !quo_is_null(lon_q) || !quo_is_null(lat_q) || inherits(data, "sf")

  col_q <- enquo(colour)
  size_q <- enquo(size)
  col_nm <- if (quo_is_null(col_q)) NULL else tmr_pick(col_q, data, "colour")
  if (!is.null(col_nm) && (identical(col_nm, "species") ||
                             any(grepl("[_.]", as.character(data[[col_nm]]))))) {
    data[[col_nm]] <- geo_pretty_species(data[[col_nm]])
  }
  if (quo_is_null(size_q)) {
    size_nm <- if ("dbh" %in% names(data)) "dbh" else NULL
  } else {
    size_nm <- tmr_pick(size_q, data, "size")
  }

  if (use_geo) {
    rlang::check_installed("sf")
    if (inherits(data, "sf")) {
      pts <- geo_as_sf(data, drop_na = TRUE)
    } else {
      lon_col <- tmr_pick(lon_q, data, "lon")
      lat_col <- tmr_pick(lat_q, data, "lat")
      pts <- geo_as_sf(
        data,
        lon = !!rlang::sym(lon_col),
        lat = !!rlang::sym(lat_col),
        drop_na = TRUE
      )
    }
    p <- ggplot2::ggplot()
    bb <- sf::st_bbox(pts)
    dx <- max((bb["xmax"] - bb["xmin"]) * 0.05, 1e-4)
    dy <- max((bb["ymax"] - bb["ymin"]) * 0.05, 1e-4)
    bb["xmin"] <- bb["xmin"] - dx
    bb["xmax"] <- bb["xmax"] + dx
    bb["ymin"] <- bb["ymin"] - dy
    bb["ymax"] <- bb["ymax"] + dy
    bm <- geo_basemap_layers(bb, basemap = basemap, crs = sf::st_crs(pts))
    for (ly in bm$layers) p <- p + ly
    p <- plot_topo_dem_layers(
      p, dem,
      contours = contours, hillshade = hillshade,
      contour_breaks = contour_breaks, geographic = TRUE
    )
    p <- plot_topo_boundary(p, boundary, geographic = TRUE, crs = sf::st_crs(pts))
    p <- plot_topo_points_sf(
      p, pts, col_nm, size_nm, palette, point_alpha,
      fill_free = !isTRUE(bm$uses_fill)
    )
    plot_topo_finish(
      p, crs = sf::st_crs(pts), geographic = TRUE,
      col_nm = col_nm, size_nm = size_nm
    )
  } else {
    x_col <- tmr_pick(enquo(x), data, "x")
    y_col <- tmr_pick(enquo(y), data, "y")
    xv <- data[[x_col]]
    yv <- data[[y_col]]
    ok <- is.finite(xv) & is.finite(yv)
    if (!any(ok)) {
      cli::cli_abort("No finite stem coordinates remain to plot.")
    }
    df <- tibble::as_tibble(dplyr::ungroup(data)[ok, , drop = FALSE])
    p <- ggplot2::ggplot()
    p <- plot_topo_dem_layers(
      p, dem,
      contours = contours, hillshade = hillshade,
      contour_breaks = contour_breaks, geographic = FALSE
    )
    p <- plot_topo_boundary(p, boundary, geographic = FALSE)
    p <- plot_topo_points_xy(
      p, df, x_col, y_col, col_nm, size_nm, palette, point_alpha
    )
    plot_topo_finish(
      p, geographic = FALSE, x_lab = paste0(x_col, " (m)"),
      y_lab = paste0(y_col, " (m)"), col_nm = col_nm, size_nm = size_nm
    )
  }
}

plot_topo_finish <- function(p,
                             crs = NULL,
                             geographic = FALSE,
                             x_lab = NULL,
                             y_lab = NULL,
                             col_nm = NULL,
                             size_nm = NULL) {
  if (isTRUE(geographic)) {
    p <- p + ggplot2::coord_sf(crs = crs, expand = FALSE)
  } else {
    p <- p + ggplot2::coord_fixed(expand = FALSE)
  }
  # Keep full species names visible: legend outside, wrapped to two rows.
  # Italicise binomial labels only (not the DBH size key).
  col_guide <- if (!is.null(col_nm)) {
    args <- list(
      nrow = 2, byrow = TRUE, order = 1,
      title = geo_pretty_label(col_nm)
    )
    if (identical(col_nm, "species")) {
      args$label.theme <- ggplot2::element_text(face = "italic", size = 9)
    }
    do.call(ggplot2::guide_legend, args)
  } else {
    "none"
  }
  p <- p +
    theme_tidymapr(grid = "none") +
    ggplot2::theme(
      legend.position = "bottom",
      legend.box = "vertical",
      legend.box.just = "left",
      plot.margin = ggplot2::margin(5, 12, 5, 5)
    ) +
    ggplot2::guides(
      colour = col_guide,
      size = if (!is.null(size_nm)) {
        ggplot2::guide_legend(
          order = 2, title = geo_pretty_label(size_nm),
          label.theme = ggplot2::element_text(face = "plain", size = 9)
        )
      } else {
        "none"
      }
    ) +
    ggplot2::labs(x = x_lab, y = y_lab)
  p
}

plot_topo_dem_layers <- function(p, dem, contours, hillshade,
                                 contour_breaks, geographic = FALSE) {
  if (is.null(dem)) {
    return(p)
  }
  p + geo_dem_layers(dem,
    hillshade = hillshade, contours = contours,
    contour_breaks = contour_breaks
  )
}

plot_topo_boundary <- function(p, boundary, geographic = FALSE, crs = NULL) {
  if (is.null(boundary)) {
    return(p)
  }
  if (is.numeric(boundary) && length(boundary) == 4) {
    if (is.null(names(boundary))) {
      names(boundary) <- c("xmin", "ymin", "xmax", "ymax")
    }
    rect <- data.frame(
      x = c(
        boundary[["xmin"]], boundary[["xmax"]], boundary[["xmax"]],
        boundary[["xmin"]], boundary[["xmin"]]
      ),
      y = c(
        boundary[["ymin"]], boundary[["ymin"]], boundary[["ymax"]],
        boundary[["ymax"]], boundary[["ymin"]]
      )
    )
    return(p + ggplot2::geom_path(
      data = rect,
      ggplot2::aes(.data$x, .data$y),
      colour = "grey10",
      linewidth = 0.6,
      inherit.aes = FALSE
    ))
  }
  if (inherits(boundary, "sf")) {
    rlang::check_installed("sf")
    if (!is.null(crs)) {
      boundary <- sf::st_transform(boundary, crs)
    }
    return(p + ggplot2::geom_sf(
      data = boundary,
      fill = NA,
      colour = "grey10",
      linewidth = 0.6
    ))
  }
  cli::cli_abort("{.arg boundary} must be an sf polygon or a length-4 bbox.")
}

plot_topo_points_xy <- function(p, df, x_col, y_col, col_nm, size_nm,
                                palette, point_alpha) {
  if (is.null(col_nm) && is.null(size_nm)) {
    return(p + ggplot2::geom_point(
      data = df,
      ggplot2::aes(.data[[x_col]], .data[[y_col]]),
      colour = tmr_palette(1, palette = palette),
      alpha = point_alpha,
      size = 1.6
    ))
  }
  if (!is.null(col_nm) && !is.null(size_nm)) {
    p <- p + ggplot2::geom_point(
      data = df,
      ggplot2::aes(
        .data[[x_col]], .data[[y_col]],
        colour = .data[[col_nm]], size = .data[[size_nm]]
      ),
      alpha = point_alpha
    )
  } else if (!is.null(col_nm)) {
    p <- p + ggplot2::geom_point(
      data = df,
      ggplot2::aes(
        .data[[x_col]], .data[[y_col]],
        colour = .data[[col_nm]]
      ),
      alpha = point_alpha,
      size = 1.8
    )
  } else {
    p <- p + ggplot2::geom_point(
      data = df,
      ggplot2::aes(
        .data[[x_col]], .data[[y_col]],
        size = .data[[size_nm]]
      ),
      colour = tmr_palette(1, palette = palette),
      alpha = point_alpha
    )
  }
  p <- plot_topo_scales(p, df, col_nm, size_nm, palette, aes = "colour")
  p
}

plot_topo_points_sf <- function(p, pts, col_nm, size_nm, palette,
                                point_alpha, fill_free = TRUE) {
  if (is.null(col_nm) && is.null(size_nm)) {
    return(p + ggplot2::geom_sf(
      data = pts,
      colour = tmr_palette(1, palette = palette),
      alpha = point_alpha,
      size = 1.6
    ))
  }
  if (!is.null(col_nm) && !is.null(size_nm)) {
    p <- p + ggplot2::geom_sf(
      data = pts,
      ggplot2::aes(colour = .data[[col_nm]], size = .data[[size_nm]]),
      alpha = point_alpha
    )
  } else if (!is.null(col_nm)) {
    p <- p + ggplot2::geom_sf(
      data = pts,
      ggplot2::aes(colour = .data[[col_nm]]),
      alpha = point_alpha,
      size = 1.8
    )
  } else {
    p <- p + ggplot2::geom_sf(
      data = pts,
      ggplot2::aes(size = .data[[size_nm]]),
      colour = tmr_palette(1, palette = palette),
      alpha = point_alpha
    )
  }
  plot_topo_scales(p, pts, col_nm, size_nm, palette, aes = "colour")
}

plot_topo_scales <- function(p, data, col_nm, size_nm, palette, aes = "colour") {
  if (!is.null(col_nm)) {
    col_v <- data[[col_nm]]
    pretty_nm <- geo_pretty_label(col_nm)
    if (is.numeric(col_v) && !is.factor(col_v)) {
      p <- p + ggplot2::scale_colour_viridis_c(name = pretty_nm, option = "C")
    } else {
      levs <- if (is.factor(col_v)) levels(col_v) else as.character(
        vctrs::vec_unique(col_v)
      )
      cols <- tmr_palette(length(levs), palette = palette)
      names(cols) <- levs
      p <- p + ggplot2::scale_colour_manual(
        name = pretty_nm, values = cols, breaks = levs, labels = levs
      )
    }
  }
  if (!is.null(size_nm)) {
    p <- p + ggplot2::scale_size_area(
      name = geo_pretty_label(size_nm), max_size = 7
    )
  }
  p
}

#' Simulated ForestGEO-style stem table for tests
#'
#' Returns a small stem inventory in local metre coordinates (`gx`, `gy`)
#' for trying [plot_topo()]. Columns follow the ForestGEO convention
#' (`plot`, `treeID`, `stemID`, `gx`, `gy`, `dbh`, `species`, `status`).
#' Positions, sizes and species are simulated on a 100 m x 100 m plot to
#' check code only. They are not real Wanang or ForestGEO trees: do not
#' present maps or results from this table as field data.
#'
#' @param n Number of stems.
#' @param seed RNG seed for reproducibility.
#' @return A tibble.
#' @references Condit, R. et al. (2019). Complete data from the Barro
#'   Colorado 50-ha plot: 423617 trees, 35 years. *Dryad*.
#'   \doi{10.15146/5xcp-0d46}. ForestGEO network:
#'   <https://forestgeo.si.edu/>. Wanang forest dynamics plot, Papua New
#'   Guinea: Anderson-Teixeira, K. J. et al. (2015). CTFS-ForestGEO: a
#'   worldwide network monitoring forests in an era of global change.
#'   *Global Change Biology*, 21, 528-549. \doi{10.1111/gcb.12712}.
#' @export
#' @examples
#' geo_example_stems()
geo_example_stems <- function(n = 120, seed = 1) {
  tmr_check_number(n, "n", 1, whole = TRUE)
  if (!is.null(seed)) set.seed(seed)
  spp <- c(
    "Pometia_pinnata", "Intsia_bijuga", "Pterocarpus_indicus",
    "Homalanthus_novoguineensis", "Ficus_sp"
  )
  tibble::tibble(
    plot = "demo100",
    treeID = seq_len(n),
    stemID = seq_len(n),
    gx = stats::runif(n, 2, 98),
    gy = stats::runif(n, 2, 98),
    dbh = pmax(1, round(stats::rlnorm(n, meanlog = 2.2, sdlog = 0.55), 1)),
    species = sample(spp, n, replace = TRUE, prob = c(0.3, 0.25, 0.2, 0.15, 0.1)),
    status = sample(c("A", "A", "A", "D"), n, replace = TRUE)
  )
}

#' Simulated DEM for testing local metre stem maps
#'
#' Builds a small elevation raster in the same 0-100 m local coordinates as
#' [geo_example_stems()], for testing topographic backdrops in
#' [plot_topo()]. The surface is a formula, not a survey: use a real DEM
#' (for example [geo_elevation()]) for figures.
#'
#' @param res Grid resolution in metres.
#' @return A `terra::SpatRaster`.
#' @export
#' @examplesIf requireNamespace("terra", quietly = TRUE)
#' geo_example_dem()
geo_example_dem <- function(res = 2) {
  rlang::check_installed("terra")
  tmr_check_number(res, "res", 0)
  r <- terra::rast(
    xmin = 0, xmax = 100, ymin = 0, ymax = 100,
    resolution = res
  )
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  # Gentle ridge plus noise, elevation in metres
  z <- 120 + 8 * sin(xy[, 1] / 18) + 5 * cos(xy[, 2] / 22) +
    0.03 * xy[, 2]
  terra::values(r) <- z
  names(r) <- "elevation"
  r
}

#' Two simulated censuses for testing demography code
#'
#' Builds a pair of ForestGEO-style tree tables five years apart, with
#' simulated mortality, recruitment and growth, for testing
#' [tidydiversity::stems_demography()]. Not real census data.
#'
#' @param n Number of trees in census 1.
#' @param seed RNG seed.
#' @param time Interval in years between censuses.
#' @return A list with `census1` and `census2` tibbles.
#' @export
#' @examplesIf requireNamespace("tidydiversity", quietly = TRUE)
#' cens <- geo_example_censuses()
#' tidydiversity::stems_demography(cens$census1, cens$census2, time = 5, dbh_unit = "mm")
geo_example_censuses <- function(n = 80, seed = 1, time = 5) {
  tmr_check_number(n, "n", 1, whole = TRUE)
  tmr_check_number(time, "time", 0)
  if (!is.null(seed)) set.seed(seed)
  c1 <- geo_example_stems(n = n, seed = seed)
  c1$census <- 1L
  c1$date <- as.Date("2015-01-01")
  c1$status <- "A"
  c2 <- c1
  c2$census <- 2L
  c2$date <- as.Date("2015-01-01") + as.integer(round(time * 365.25))
  grow <- stats::runif(n, 0.5, 4)
  c2$dbh <- c1$dbh + grow
  die <- seq_len(n) %in% sample.int(n, max(1, floor(0.08 * n)))
  c2$status[die] <- "D"
  n_rec <- max(2, floor(0.1 * n))
  rec <- geo_example_stems(n = n_rec, seed = seed + 1)
  rec$treeID <- n + seq_len(n_rec)
  rec$stemID <- rec$treeID
  rec$census <- 2L
  rec$date <- c2$date[1]
  rec$status <- "A"
  c2 <- vctrs::vec_rbind(c2, rec)
  list(census1 = tibble::as_tibble(c1), census2 = tibble::as_tibble(c2))
}


# Convert Genus_species / Genus.species to "Genus species" for legends.
# "Ficus_sp" / "Ficus sp" become "Ficus sp."
geo_pretty_species <- function(x) {
  x <- as.character(x)
  x <- gsub("[_.]+", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  x <- sub("(?i)\\bsp$", "sp.", x, perl = TRUE)
  x
}

# Humanise column names for legend titles (elevation_band -> Elevation).
geo_pretty_label <- function(x) {
  if (is.null(x) || !nzchar(as.character(x)[[1]])) return(x)
  x <- as.character(x)[[1]]
  known <- c(
    elevation_band = "Elevation",
    elevation = "Elevation",
    diversity = "Diversity",
    suitability = "Suitability",
    species = "Species",
    dbh = "DBH (mm)",
    season = "Season",
    site = "Site"
  )
  if (x %in% names(known)) return(unname(known[[x]]))
  x <- gsub("[_.]+", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  paste(toupper(substring(x, 1, 1)), substring(x, 2), sep = "")
}
