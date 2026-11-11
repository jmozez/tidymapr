#' Spatially constrained rarefaction
#'
#' Accumulates species richness by adding samples in order of increasing
#' distance from a seed sample (spatially contiguous rarefaction), and
#' optionally compares that curve to random-order accumulation. Coverage
#' standardisation ([tidydiversity::div_rarefy()],
#' [tidydiversity::div_standardise()]) remains the default for effort bias;
#' use this verb when you need an aggregation signal along
#' a transect or plot (Chiu 2023; McGlinn et al. 2025).
#'
#' @param data Long community table with coordinates and species.
#' @param lon,lat,site,species Coordinate, site and species columns.
#' @param abundance Optional abundance column; presence is used when `NULL`.
#' @param seed Site id or row index of the starting sample. When `NULL`,
#'   every site is used as a seed and curves are averaged.
#' @param nperm Number of random-order permutations for the null curve.
#' @param .by Optional grouping columns.
#' @return A tibble (`tmr_geo_rarefy`) with `n_sites`, `richness_spatial`,
#'   and when `nperm > 0` also `richness_random` (mean) and
#'   `richness_random_sd`.
#' @export
#' @examples
#' set.seed(1)
#' pts <- expand.grid(x = 1:4, y = 1:3)
#' pts$site <- paste0("s", seq_len(nrow(pts)))
#' com <- expand.grid(site = pts$site, species = paste0("sp", 1:5),
#'                    stringsAsFactors = FALSE)
#' com$abundance <- rpois(nrow(com), 1)
#' com <- dplyr::left_join(com, pts, by = "site")
#' geo_rarefy_spatial(com, lon = x, lat = y, nperm = 19)
geo_rarefy_spatial <- function(data,
                               lon = lon,
                               lat = lat,
                               site = site,
                               species = species,
                               abundance = NULL,
                               seed = NULL,
                               nperm = 0,
                               .by = NULL) {
  if (inherits(data, "sf")) {
    data <- tmr_sf_coords(data, planar = FALSE)
    lon_q <- rlang::quo(!!rlang::sym(".lon"))
    lat_q <- rlang::quo(!!rlang::sym(".lat"))
  } else {
    lon_q <- enquo(lon)
    lat_q <- enquo(lat)
  }
  tmr_check_data(data)
  tmr_check_number(nperm, "nperm", 0, whole = TRUE)
  site_col <- tmr_pick(enquo(site), data, "site")
  sp_col <- tmr_pick(enquo(species), data, "species")
  lon_col <- tmr_pick(lon_q, data, "lon")
  lat_col <- tmr_pick(lat_q, data, "lat")
  abu_q <- enquo(abundance)
  by_cols <- tmr_group_cols(data, enquo(.by))

  # Site coordinates (must be unique)
  coords <- tibble::as_tibble(dplyr::ungroup(data)[unique(c(by_cols, site_col, lon_col, lat_col))])
  coords <- vctrs::vec_unique(coords)
  if (vctrs::vec_duplicate_any(coords[c(by_cols, site_col)])) {
    cli::cli_abort("Coordinates must be constant within each site.")
  }

  # Incidence matrix sites x species
  if (quo_is_null(abu_q)) {
    long <- dplyr::ungroup(data)[unique(c(by_cols, site_col, sp_col))]
    long$.abu <- 1
  } else {
    abu_col <- tmr_pick(abu_q, data, "abundance")
    long <- dplyr::ungroup(data)[unique(c(by_cols, site_col, sp_col, abu_col))]
    names(long)[names(long) == abu_col] <- ".abu"
  }
  split <- if (length(by_cols) == 0) {
    list(key = tibble::tibble(.rows = 1),
         val = list(list(coords = coords, long = long)))
  } else {
    ck <- vctrs::vec_split(coords, coords[by_cols])
    lk <- vctrs::vec_split(long, long[by_cols])
    # Align by key
    keys <- ck$key
    vals <- lapply(seq_len(nrow(keys)), function(i) {
      list(coords = ck$val[[i]], long = lk$val[[i]])
    })
    list(key = keys, val = vals)
  }

  rows <- lapply(seq_along(split$val), function(i) {
    geo_rarefy_one(
      split$val[[i]]$coords, split$val[[i]]$long,
      site_col, sp_col, lon_col, lat_col,
      seed = seed, nperm = nperm
    ) |>
      (\(out) {
        if (length(by_cols) > 0) {
          key <- vctrs::vec_slice(split$key, rep(i, nrow(out)))
          vctrs::vec_cbind(key, out)
        } else {
          out
        }
      })()
  })
  out <- tibble::as_tibble(vctrs::vec_rbind(!!!rows))
  tmr_new(out, "tmr_geo_rarefy")
}

geo_rarefy_one <- function(coords, long, site_col, sp_col, lon_col, lat_col,
                           seed, nperm) {
  sites <- as.character(coords[[site_col]])
  n <- length(sites)
  spp <- sort(unique(as.character(long[[sp_col]])))
  inc <- matrix(0L, nrow = n, ncol = length(spp))
  rownames(inc) <- sites
  colnames(inc) <- spp
  for (r in seq_len(nrow(long))) {
    s <- as.character(long[[site_col]][r])
    sp <- as.character(long[[sp_col]][r])
    if (s %in% sites && long$.abu[r] > 0) {
      inc[s, sp] <- 1L
    }
  }
  xy_lon <- as.numeric(coords[[lon_col]])
  xy_lat <- as.numeric(coords[[lat_col]])

  seed_ids <- if (is.null(seed)) {
    sites
  } else if (is.numeric(seed)) {
    sites[seed]
  } else {
    as.character(seed)
  }
  seed_ids <- intersect(seed_ids, sites)
  if (length(seed_ids) == 0) {
    cli::cli_abort("{.arg seed} did not match any site.")
  }

  curves <- lapply(seed_ids, function(sid) {
    i0 <- match(sid, sites)
    d <- if (exists("geo_haversine_pair_cpp", mode = "function") &&
               max(abs(xy_lon), na.rm = TRUE) <= 180) {
      geo_haversine_m(rep(xy_lon[i0], n), rep(xy_lat[i0], n), xy_lon, xy_lat)
    } else {
      sqrt((xy_lon - xy_lon[i0])^2 + (xy_lat - xy_lat[i0])^2)
    }
    if (exists("geo_spatial_rarefy_cpp", mode = "function")) {
      geo_spatial_rarefy_cpp(d, inc)
    } else {
      geo_spatial_rarefy_r(d, inc)
    }
  })
  spat <- Reduce(`+`, curves) / length(curves)

  out <- tibble::tibble(
    n_sites = seq_len(n),
    richness_spatial = as.numeric(spat)
  )
  if (nperm > 0) {
    rand <- matrix(NA_real_, nperm, n)
    for (b in seq_len(nperm)) {
      ord <- sample.int(n)
      d_fake <- seq_len(n)  # order by permutation via fake distances
      d_fake[ord] <- seq_len(n)
      # Better: shuffle rows of incidence
      inc_b <- inc[sample.int(n), , drop = FALSE]
      d0 <- seq_len(n) - 1
      if (exists("geo_spatial_rarefy_cpp", mode = "function")) {
        rand[b, ] <- geo_spatial_rarefy_cpp(as.numeric(d0), inc_b)
      } else {
        rand[b, ] <- geo_spatial_rarefy_r(as.numeric(d0), inc_b)
      }
    }
    out$richness_random <- colMeans(rand)
    out$richness_random_sd <- apply(rand, 2, stats::sd)
  }
  out
}

geo_spatial_rarefy_r <- function(dist_to_seed, incidence) {
  ord <- order(dist_to_seed, seq_along(dist_to_seed))
  seen <- rep(FALSE, ncol(incidence))
  out <- integer(length(ord))
  rich <- 0L
  for (k in seq_along(ord)) {
    row <- incidence[ord[k], ]
    new <- which(row > 0 & !seen)
    if (length(new) > 0) {
      seen[new] <- TRUE
      rich <- rich + length(new)
    }
    out[k] <- rich
  }
  out
}
