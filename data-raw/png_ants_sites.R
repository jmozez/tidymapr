# Bait-transect coordinates for the Mt Wilhelm ant data in `png_ants`.
# Every bait in the published data carries its own GPS position and
# elevation; this script averages them to one point per elevation band and
# transect (two transects per band, eight bands from 200 to 3700 m).
# Source: Mottl, O., Moses, J. & Klimes, P. (2023). Data and code for
# 'Nutrient use by tropical ant communities varies among three extensive
# elevational gradients: a cross-continental comparison'. Zenodo.
# https://doi.org/10.5281/zenodo.8191946 (open licence).
# Paper: Moses et al. (2023) Global Ecology and Biogeography,
# https://doi.org/10.1111/geb.13757
# Run from the package root to rebuild data/png_ants_sites.rda.
zip <- tempfile(fileext = ".zip")
utils::download.file(
  "https://zenodo.org/records/8191946/files/OndrejMottl/Ant_Nutrient_use-v1.0.1.zip?download=1",
  zip,
  mode = "wb"
)
csv <- grep("data_full_clean_2023-02-11.csv$", utils::unzip(zip, list = TRUE)$Name,
  value = TRUE
)
raw <- utils::read.csv(unz(zip, csv))
raw <- raw[raw$regions == "png", ]
raw <- raw[!duplicated(raw$trap_number_code), ]

key <- interaction(raw$elevational_bands, raw$transect_number, drop = TRUE)
parts <- split(raw, key)
png_ants_sites <- do.call(rbind, lapply(parts, function(d) {
  tibble::tibble(
    site = sprintf("MW%04d", as.integer(d$elevational_bands[1])),
    transect = as.integer(d$transect_number[1]),
    elevation_band = as.integer(d$elevational_bands[1]),
    elevation = as.integer(round(mean(d$elevation))),
    lon = round(mean(d$longitude), 5),
    lat = round(mean(d$latitude), 5),
    baits = nrow(d)
  )
}))
png_ants_sites <- png_ants_sites[
  order(png_ants_sites$elevation_band, png_ants_sites$transect),
]
rownames(png_ants_sites) <- NULL

usethis::use_data(png_ants_sites, overwrite = TRUE)
