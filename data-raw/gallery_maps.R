# Render the real-data map figures used by the README and the website
# Gallery ("Maps (bonus)"). Run from the package root with network access:
#   Rscript data-raw/gallery_maps.R
# Inputs are all real, citable records:
# * Mt Wilhelm bait GPS: `png_ants_sites` (Mottl, Moses and Klimes 2023,
#   Zenodo, doi:10.5281/zenodo.8191946; Moses et al. 2023 GEB,
#   doi:10.1111/geb.13757).
# * Ant diversity: `png_ants` (same source).
# * Elevation: SRTM 3 arc-second via geodata::elevation_3s() (NASA SRTM,
#   public domain), cached at runtime and not shipped.
# * Green tree ant occurrences: GBIF records of Oecophylla smaragdina in
#   Papua New Guinea under CC0 or CC BY 4.0, saved by this script to
#   inst/extdata/gbif_oecophylla_png.csv (GBIF.org, occurrence search).
# * Climate: WorldClim 2.1 bio1 and bio12 at 5 arc-minutes (Fick and
#   Hijmans 2017, doi:10.1002/joc.5086, CC BY 4.0), cached at runtime.
# Tiles: Esri World Imagery (attribution on each map), cached at runtime.
devtools::load_all(quiet = TRUE)
library(tidydiversity)
library(ggplot2)
fig <- function(name) file.path("man", "figures", name)
sites <- geo_example_sites()

# 1. Study-site map: all eight bands, imagery basemap, PNG inset ----------
p_sites <- plot_sites(
  sites, lon, lat,
  colour = elevation_band, label = site,
  basemap = "esri", inset = "png",
  legend_title = "Elevation band", legend_position = "outside"
) +
  labs(
    title = "Ant bait transects on Mt Wilhelm, Papua New Guinea",
    caption = paste(
      "Bait GPS: Mottl, Moses & Klimes (2023) doi:10.5281/zenodo.8191946.",
      "\nImagery: Esri, Maxar, Earthstar Geographics."
    )
  )
geo_save(p_sites, fig("gallery-map-sites.png"), width = 180, height = 150)

# 2. Hill numbers on a map (observed richness, dry season) ---------------
est <- div_estimate(png_ants, q = 0, nboot = 0, .by = season)
est <- dplyr::left_join(est, sites[c("site", "lon", "lat")], by = "site")
est_dry <- est[est$season == "dry", ]
p_hill <- plot_geo(
  est_dry, estimate, lon, lat,
  label = site, basemap = "esri", inset = "png",
  legend_title = "Estimated\nspecies richness"
) +
  labs(
    title = "Ant species richness (q = 0) along Mt Wilhelm, dry season",
    caption = paste(
      "Data: png_ants (Moses et al. 2023, doi:10.1111/geb.13757).",
      "\nImagery: Esri, Maxar, Earthstar Geographics."
    )
  )
geo_save(p_hill, fig("gallery-map-hill.png"), width = 180, height = 150)

# 3. Elevation (SRTM) with the transects -----------------------------------
# The transects straddle two SRTM 5 x 5 degree tiles (west and east of
# 145 E), so read both and mosaic them before cropping.
srtm_dir <- file.path(tools::R_user_dir("tidymapr", "cache"), "elevation")
dem <- terra::merge(
  geodata::elevation_3s(lon = 144.9, lat = -5.8, path = srtm_dir),
  geodata::elevation_3s(lon = 145.2, lat = -5.8, path = srtm_dir)
)
dem <- terra::crop(dem, terra::ext(144.85, 145.5, -5.98, -5.55))
dem <- terra::aggregate(dem, fact = 2)
names(dem) <- "Elevation (m)"
p_elev <- plot_sites(
  sites, lon, lat,
  label = site, raster = dem, basemap = "none",
  inset = "png", legend_position = "outside"
) +
  labs(
    title = "Mt Wilhelm bait transects over SRTM elevation",
    caption = paste(
      "Elevation: NASA SRTM 3 arc-second (via geodata).",
      "Bait GPS: doi:10.5281/zenodo.8191946."
    )
  )
geo_save(p_elev, fig("gallery-map-elevation.png"), width = 180, height = 150)

# 4. SDM from GBIF occurrences and WorldClim -------------------------------
csv <- file.path("inst", "extdata", "gbif_oecophylla_png.csv")
raw <- rgbif::occ_search(
  scientificName = "Oecophylla smaragdina", country = "PG",
  hasCoordinate = TRUE, hasGeospatialIssue = FALSE, limit = 1000
)$data
keep <- grepl("creativecommons.org/(licenses/by/|publicdomain/zero/)", raw$license) &
  (is.na(raw$coordinateUncertaintyInMeters) |
     raw$coordinateUncertaintyInMeters <= 10000)
occ <- tibble::tibble(
  gbif_id = as.character(raw$gbifID[keep]),
  dataset_key = raw$datasetKey[keep],
  species = "Oecophylla smaragdina",
  lon = round(raw$decimalLongitude[keep], 5),
  lat = round(raw$decimalLatitude[keep], 5),
  year = as.integer(raw$year[keep]),
  basis_of_record = raw$basisOfRecord[keep],
  license = ifelse(grepl("zero", raw$license[keep]), "CC0 1.0", "CC BY 4.0")
)
occ <- geo_clean(occ, lon, lat, species = species)
occ <- occ[order(occ$gbif_id), c(
  "gbif_id", "dataset_key", "species", "lon", "lat", "year",
  "basis_of_record", "license"
)]
utils::write.csv(occ, csv, row.names = FALSE)

clim <- geo_worldclim(c("bio1", "bio12"), res = 5)
clim <- terra::crop(clim, terra::ext(140.8, 156.1, -11.7, -0.8))
png0 <- rnaturalearth::ne_countries(
  country = "Papua New Guinea", scale = "medium", returnclass = "sf"
)
clim <- terra::mask(clim, terra::vect(png0))
fit <- sdm_fit(
  occ, predictors = clim, engine = "maxnet",
  n_background = 2000, seed = 1
)
ev <- sdm_evaluate(fit)
print(ev)
grid <- terra::as.data.frame(clim, xy = TRUE, cells = TRUE, na.rm = TRUE)
names(grid)[2:3] <- c("lon", "lat")
pred <- sdm_predict(fit, newdata = grid)
suit <- clim[[1]]
terra::values(suit) <- NA_real_
suit[grid$cell] <- pred$suitability
names(suit) <- "suitability"
p_sdm <- plot_sdm(suit, basemap = "coast") +
  geom_point(
    data = occ, aes(lon, lat), inherit.aes = FALSE,
    shape = 21, size = 1.3, fill = "white", colour = "black", stroke = 0.3
  ) +
  labs(
    title = expression(paste(
      "Habitat suitability of ", italic("Oecophylla smaragdina"),
      " in Papua New Guinea"
    )),
    subtitle = sprintf(
      "Maxent-like model (linear + quadratic) on WorldClim bio1 and bio12; %d GBIF presences, AUC %.2f",
      ev$n_presence, ev$auc
    ),
    caption = paste(
      "Occurrences: GBIF.org, CC0 / CC BY 4.0 records.",
      "Climate: WorldClim 2.1 (Fick & Hijmans 2017)."
    )
  )
geo_save(p_sdm, fig("gallery-map-sdm.png"), width = 180, height = 150)
