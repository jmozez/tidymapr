# tidymapr <img src="man/figures/logo.png" align="right" height="139" alt="tidymapr hex logo" />

Tidy mapping verbs for biodiversity and spatial ecology, designed to work
with [tidydiversity](https://github.com/jmozez/tidydiversity).

tidymapr holds the mapping, geospatial and spatial-ecology verbs that used
to live in tidydiversity: study-site maps, sites as `sf` tables, raster
extraction, occurrence cleaning, geographic and environmental distances,
Moran's I, dbMEM, spatial rarefaction, bioclim, elevation and GADM layers,
vector and raster I/O, stem maps over topography and tidy species
distribution models. It works with tidydiversity in the same way `dplyr`
and `ggplot2` do: load them together and keep a single tidy workflow.

```r
library(tidydiversity)
library(tidymapr)

sites <- geo_example_sites("wilhelm")
est <- div_estimate(png_ants, q = 0, nboot = 0, .by = season)
est <- dplyr::left_join(est, sites[c("site", "lon", "lat")], by = "site")
plot_geo(est[est$season == "dry", ], estimate, lon, lat, label = site)
```

**sf**, **terra** and the other spatial packages are Suggests, so install
the ones you need (`install.packages(c("sf", "terra"))`).

## Installation

```r
# install.packages("pak")
pak::pak("jmozez/tidymapr")
```

The package is in early development (0.0.0.9000) and is not on CRAN yet.

## Licence

MIT © 2026 Jimmy Moses
