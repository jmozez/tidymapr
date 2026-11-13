# Did the models predict the climb? A hindcast of New Guinea birds

A range-shift model earns trust when it predicts shifts that have
already happened. This article tests the tidymapr range-shift workflow
against one of the best tropical resurveys: the birds of Mt Karimui,
Chimbu Province, Papua New Guinea, surveyed along a 1,130 to 2,520 m
transect in 1965 by Jared Diamond and again in 2012 by Freeman and Class
Freeman (2014). Over those 47 years, the upper limits of 119 species
with edges inside the transect moved upslope by 120 m on average, and
lower limits of 55 species by 107 m.

The species’ edges are published in the supplement of Freeman and Class
Freeman (2014) and are not redistributed here. To repeat the analysis,
take Table S2 from the paper and arrange it as one row per species with
the columns `species`, `lower_t1`, `upper_t1`, `lower_t2` and `upper_t2`
(metres; `NA` where an edge lies beyond the transect). The code below
then runs as shown. Only summary results are reported here.

## 1. Climate in 1965 and 2012

The paper used 0.39 degrees C of warming from a regional record. We
measure warming at Karimui itself from CHELSAcruts (Karger et al. 2017),
monthly maximum and minimum temperature and precipitation from 1901 to
2016 at about 1 km. We use five-year means around each survey (1963 to
1967 and 2010 to 2014) to damp single-year noise. Only the window over
the mountain is read from each file.

``` r

library(terra)
library(tidymapr)
library(tidydiversity)

win <- ext(144.6, 145.0, -6.7, -6.3)
cru <- function(var, month, year) {
  url <- sprintf(paste0(
    "/vsicurl/https://os.zhdk.cloud.switch.ch/chelsav1/chelsa_cruts/",
    "%s/CHELSAcruts_%s_%d_%d_V.1.0.tif"
  ), var, var, month, year)
  crop(rast(url), win, snap = "out")
}
period <- function(years) {
  temp <- prec <- list()
  for (y in years) {
    for (m in 1:12) {
      # stored as degrees C x 10
      temp[[length(temp) + 1]] <- (cru("tmax", m, y) + cru("tmin", m, y)) / 20
      prec[[length(prec) + 1]] <- cru("prec", m, y)
    }
  }
  out <- c(mean(rast(temp)), sum(rast(prec)) / length(years))
  names(out) <- c("temp", "prec")
  out
}
c65 <- period(1963:1967)
c12 <- period(2010:2014)
```

Mt Karimui warmed by 0.76 degrees C (0.756 to 0.759 across the
mountain), almost twice the regional figure, and became 61 to 82 mm
wetter per year.

## 2. Fine climate along the transect

The baseline is CHELSA V2.1 (1981 to 2010), brought down to a 90 m SRTM
elevation model with the lapse rate measured on the transect (5.1
degrees C per km). The CHELSAcruts change is added to it (the delta
method), as in
[`geo_climate_scenarios()`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md).

``` r

dem <- geo_elevation(bbox = c(144.6, -6.7, 145.0, -6.3), buffer = 0)[[1]]
loc <- geo_chelsa_area(win, c("bio1", "bio12"))
names(loc) <- c("bio1", "bio12")
t0 <- geo_downscale_lapse(loc$bio1, dem, lapse_rate = 5.1)
p0 <- resample(loc$bio12, dem, "bilinear")
d_temp <- resample(c12$temp - c65$temp, dem, "bilinear")
d_prec <- resample(c12$prec - c65$prec, dem, "bilinear")

# Mean climate in 25 m bands within 8 km of the summit
summit <- vect(cbind(144.7997, -6.598056), crs = "EPSG:4326")
v <- as.data.frame(c(dem, t0, p0, d_temp, d_prec, distance(dem, summit)))
names(v) <- c("z", "t", "p", "dt", "dp", "d")
v <- v[v$d < 8000 & complete.cases(v), ]
v$band <- round(v$z / 25) * 25
profile <- aggregate(cbind(t, p, dt, dp) ~ band, v, mean)
```

On this surface temperature falls by 5.3 degrees C per km along the
transect, so the warming moves each isotherm up by about 142 to 149 m.

## 3. One integrated niche model per species

Each species gets an
[`sdm_integrated()`](https://tidymapr.in4metrix.dev/reference/sdm_integrated.md)
model joining two kinds of data:

- presence-only records from GBIF in central Papua New Guinea (143 to
  147.5 E, 5 to 8 S; up to 300 per species, median 300), against 10,000
  background cells;
- the 1965 transect as a presence-absence survey: presence in each 50 m
  band between the species’ 1965 lower and upper limits, absence
  elsewhere.

Temperature (`bio1`) gets a forced hump (`unimodal`), so suitability
cannot keep rising into warmer climates; precipitation (`bio12`) is
free. GBIF records were found for 136 of the 138 Karimui species.

``` r

reg <- geo_chelsa_area(c(143, -8, 147.5, -5), c("bio1", "bio12"))
names(reg) <- c("bio1", "bio12")
background <- as.data.frame(spatSample(reg, 10000, na.rm = TRUE))
area <- sum(!is.na(values(reg$bio1)))

z <- seq(930, max(profile$band), by = 5)
at <- function(col) approx(profile$band, profile[[col]], z, rule = 2)$y
now <- data.frame(bio1 = at("t"), bio12 = at("p"))
then <- data.frame(bio1 = now$bio1 + at("dt"), bio12 = now$bio12 + at("dp"))

hindcast_species <- function(gbif, lower, upper) {
  sites <- seq(1150, 2500, by = 50)
  survey <- data.frame(
    bio1 = approx(profile$band, profile$t, sites)$y,
    bio12 = approx(profile$band, profile$p, sites)$y,
    present = as.integer(sites >= lower & sites <= upper)
  )
  presence <- extract(reg, as.matrix(gbif[, c("lon", "lat")]), ID = FALSE)
  fit <- sdm_integrated(presence[complete.cases(presence), ], background, area,
    survey = survey, covariates = c("bio1", "bio12"), unimodal = "bio1"
  )
  list(p1965 = predict(fit, now), p2012 = predict(fit, then))
}
```

## 4. From suitability to edges

A predicted edge moves to where the 2012 suitability equals the 1965
suitability at the observed 1965 edge: the elevation nearest the old
edge at which the 2012 curve crosses that threshold. Upper edges are
capped at the top of the transect, as observed edges are. The predicted
shifts are then scored against the observed ones with
[`tidydiversity::range_shift_validate()`](https://tidydiversity.in4metrix.dev/reference/range_shift_validate.html),
leaving out edges at the ends of the transect.

``` r

new_edge <- function(p1965, p2012, edge) {
  threshold <- approx(z, p1965, edge)$y
  s <- sign(p2012 - threshold)
  i <- which(diff(s) != 0)
  crossings <- z[i] + 2.5
  crossings[which.min(abs(crossings - edge))]
}

range_shift_validate(observed, predicted, nboot = 999, seed = 1)
range_shift_validate(observed, data.frame(
  species = observed$species,
  shift = range_shift_expected(warming = 0.76, lapse_rate = 5.1)
))
```

## 5. Results

Upper limits (117 to 119 species; observed mean shift 120 m):

| Prediction | Predicted (m) | Bias (m) | MAE (m) | r | Tracking (95% CI) |
|----|---:|---:|---:|---:|----|
| Isotherm, regional warming 0.39 C | 76 | -43 | 145 | \- | 1.57 (1.11 to 2.06) |
| Isotherm, local warming 0.76 C | 149 | +29 | 151 | \- | 0.81 (0.57 to 1.06) |
| Integrated model, temperature | 145 | +26 | 161 | 0.23 | 0.82 (0.56 to 1.10) |
| Integrated model, temperature + rain | 164 | +45 | 198 | 0.21 | 0.73 (0.51 to 1.00) |

Lower limits (53 to 55 species; observed mean shift 107 m):

| Prediction | Predicted (m) | Bias (m) | MAE (m) | r | Tracking (95% CI) |
|----|---:|---:|---:|---:|----|
| Isotherm, regional warming 0.39 C | 76 | -31 | 154 | \- | 1.40 (0.67 to 2.20) |
| Isotherm, local warming 0.76 C | 149 | +41 | 162 | \- | 0.72 (0.35 to 1.13) |
| Integrated model, temperature | 131 | +40 | 151 | -0.09 | 0.70 (0.32 to 1.09) |
| Integrated model, temperature + rain | 107 | +14 | 146 | 0.08 | 0.87 (0.40 to 1.40) |

Tracking is the observed over the predicted mean shift: 1 means the
birds moved as far as the climate did.

## 6. What the hindcast tells us

- **Local climate matters most.** With the regional warming the birds
  seem to have “over-tracked” climate by 57%. With warming measured on
  the mountain itself, their upper limits tracked it at 0.81, and the
  interval includes 1. The apparent over-tracking reported for Karimui
  can largely be explained by the coarse temperature record.
- **The models get the mean right.** Both integrated models predict mean
  upper-limit shifts within 30 to 45 m of the observed 120 m, and their
  tracking intervals include 1.
- **Species-level prediction is weak.** The models rank species only
  weakly (r about 0.2 for upper limits, none for lower limits), and
  their errors per species (MAE 150 to 200 m) are no smaller than the
  isotherm’s. Single species’ edges move for reasons climate alone does
  not capture: sampling noise in 1965 and 2012, competitors, and lags.
- **Precipitation added noise, not skill.** Adding rainfall raised the
  error for upper limits; on a very wet mountain (over 3,000 mm a year)
  rainfall is unlikely to limit these birds.

For projections, the lesson is to use local climate and to report
community-level shifts with their uncertainty (as
[`geo_shift_ensemble()`](https://tidymapr.in4metrix.dev/reference/geo-shift-ensemble.md)
does) rather than to trust any single species’ predicted edge.

## References

Freeman, B. G. and Class Freeman, A. M. (2014). Rapid upslope shifts in
New Guinean birds illustrate strong distributional responses of tropical
montane species to global warming. PNAS, 111, 4490-4494.

Karger, D. N. et al. (2017). Climatologies at high resolution for the
earth’s land surface areas. Scientific Data, 4, 170122.
