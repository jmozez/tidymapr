# Reference points for geo_clean(): national capitals and country centroids
# from Natural Earth (public domain), 1:10m populated places and 1:50m
# admin-0 countries:
#   https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_populated_places_simple.geojson
#   https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
# Download both files to `dir` first (e.g. with curl), then run this script
# from the package root. Writes R/sysdata.rda.
dir <- Sys.getenv("NE_DIR", "data-raw")
sf::sf_use_s2(FALSE)
places <- sf::st_read(file.path(dir, "ne_places.geojson"), quiet = TRUE)
caps <- places[places$featurecla %in% c("Admin-0 capital", "Admin-0 capital alt"), ]
tmr_capitals <- data.frame(
  name = caps$name, iso3 = caps$adm0_a3,
  lon = round(caps$longitude, 5), lat = round(caps$latitude, 5)
)
countries <- sf::st_read(file.path(dir, "ne_countries.geojson"), quiet = TRUE)
geom <- sf::st_geometry(countries)
# Two common definitions of a "country centroid": the centroid of the
# whole territory and of its largest polygon (mainland), plus Natural
# Earth's label point, which many gazetteers use.
whole <- sf::st_coordinates(suppressWarnings(sf::st_centroid(geom)))
main <- t(vapply(seq_along(geom), function(i) {
  p <- sf::st_cast(geom[i], "POLYGON")
  sf::st_coordinates(suppressWarnings(sf::st_centroid(p[which.max(sf::st_area(p))])))[1, 1:2]
}, numeric(2)))
tmr_centroids <- unique(data.frame(
  iso3 = rep(countries$ADM0_A3, 3),
  kind = rep(c("polygon", "mainland", "label"), each = nrow(countries)),
  lon = round(c(whole[, 1], main[, 1], countries$LABEL_X), 5),
  lat = round(c(whole[, 2], main[, 2], countries$LABEL_Y), 5)
))
usethis::use_data(tmr_capitals, tmr_centroids, internal = TRUE, overwrite = TRUE)
