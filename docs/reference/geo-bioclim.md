# Bioclimatic rasters (WorldClim and CHELSA)

Native tidyverse-style verbs for the 19 standard bioclimatic variables
used throughout biodiversity studies. `geo_bioclim_vars()` lists the
variables with clear names. `geo_worldclim()` and `geo_chelsa()`
download or read cached rasters (or accept a user file path when
offline), and `geo_bioclim()` is a thin front end that chooses the
source. Join values to sites with
[`geo_extract()`](https://tidymapr.in4metrix.dev/reference/geo_extract.md).

Downloads use a cache directory (default
`tools::R_user_dir("tidymapr", "cache")/bioclim`) so repeat calls do not
hit the network. Network access is never required in tests: pass a local
`path`, or skip downloads on CRAN.

## Usage

``` r
geo_bioclim_vars()

geo_bioclim(
  vars = c("bio1", "bio12"),
  source = c("worldclim", "chelsa"),
  res = 10,
  path = NULL,
  cache_dir = NULL,
  download = TRUE,
  version = NULL,
  scenario = NULL,
  year = NULL,
  model = "MPI-ESM1-2-HR"
)

geo_worldclim(
  vars = c("bio1", "bio12"),
  res = 10,
  path = NULL,
  cache_dir = NULL,
  download = TRUE,
  version = "2.1"
)

geo_chelsa(
  vars = c("bio1", "bio12"),
  path = NULL,
  cache_dir = NULL,
  download = TRUE,
  version = "2.1",
  scenario = NULL,
  year = NULL,
  model = "MPI-ESM1-2-HR"
)
```

## Arguments

- vars:

  Bioclim variable codes such as `"bio1"` or `"bio12"`, or their tidy
  names from `geo_bioclim_vars()`. Use `"all"` for bio1-bio19.

- source:

  `"worldclim"` or `"chelsa"`.

- res:

  WorldClim resolution in minutes: `10`, `5`, `2.5` or `0.5`. CHELSA
  downloads use the 30 arc-second product.

- path:

  Optional local file or directory of GeoTIFFs. When supplied, no
  download is attempted.

- cache_dir:

  Directory for downloaded rasters.

- download:

  Download missing layers? Set `FALSE` to only read the cache or `path`.

- version:

  Dataset version string (informational / URL selection).

- scenario, year, model:

  Optional CHELSA-CMIP6 future climate arguments (chelsa only). When
  set, downloads future bioclim layers (Karger et al. 2023). Use
  `download = FALSE` on CRAN.

## Value

A
[`terra::SpatRaster`](https://rdrr.io/pkg/terra/man/SpatRaster-class.html)
with one layer per requested variable. Layer names are the bioclim codes
(`bio1`, ...).

## Citation and licence

- **WorldClim** version 2.1 (Fick and Hijmans 2017). Creative Commons
  Attribution 4.0. Cite: Fick, S. E. and Hijmans, R. J. (2017).
  WorldClim 2: new 1km spatial resolution climate surfaces for global
  land areas. *International Journal of Climatology*, 37, 4302-4315.
  [doi:10.1002/joc.5086](https://doi.org/10.1002/joc.5086) .
  <https://www.worldclim.org/>

- **CHELSA** version 2.1 (Karger et al. 2017, 2021). Creative Commons
  Attribution 4.0. Cite: Karger, D. N. et al. (2017). Climatologies at
  high resolution for the earth's land surface areas. *Scientific Data*,
  4, 170122.
  [doi:10.1038/sdata.2017.122](https://doi.org/10.1038/sdata.2017.122) .
  <https://chelsa-climate.org/>

## Examples

``` r
geo_bioclim_vars()
#> # A tibble: 19 × 4
#>    code  name                             description                      unit 
#>    <chr> <chr>                            <chr>                            <chr>
#>  1 bio1  annual_mean_temperature          Annual mean temperature          deg_C
#>  2 bio2  mean_diurnal_range               Mean diurnal range (mean of mon… deg_C
#>  3 bio3  isothermality                    Isothermality (bio2 / bio7) * 1… deg_C
#>  4 bio4  temperature_seasonality          Temperature seasonality (standa… deg_C
#>  5 bio5  max_temperature_warmest_month    Maximum temperature of the warm… deg_C
#>  6 bio6  min_temperature_coldest_month    Minimum temperature of the cold… deg_C
#>  7 bio7  temperature_annual_range         Temperature annual range (bio5 … deg_C
#>  8 bio8  mean_temperature_wettest_quarter Mean temperature of the wettest… deg_C
#>  9 bio9  mean_temperature_driest_quarter  Mean temperature of the driest … deg_C
#> 10 bio10 mean_temperature_warmest_quarter Mean temperature of the warmest… deg_C
#> 11 bio11 mean_temperature_coldest_quarter Mean temperature of the coldest… deg_C
#> 12 bio12 annual_precipitation             Annual precipitation             mm   
#> 13 bio13 precipitation_wettest_month      Precipitation of the wettest mo… mm   
#> 14 bio14 precipitation_driest_month       Precipitation of the driest mon… mm   
#> 15 bio15 precipitation_seasonality        Precipitation seasonality (coef… cv   
#> 16 bio16 precipitation_wettest_quarter    Precipitation of the wettest qu… mm   
#> 17 bio17 precipitation_driest_quarter     Precipitation of the driest qua… mm   
#> 18 bio18 precipitation_warmest_quarter    Precipitation of the warmest qu… mm   
#> 19 bio19 precipitation_coldest_quarter    Precipitation of the coldest qu… mm   

# Offline: build a tiny stand-in raster and treat it as bio1
r <- terra::rast(ncols = 10, nrows = 10, xmin = 144, xmax = 146,
  ymin = -7, ymax = -5, crs = "EPSG:4326")
names(r) <- "bio1"
terra::values(r) <- 20
tmp <- tempfile(fileext = ".tif")
terra::writeRaster(r, tmp, overwrite = TRUE)
geo_worldclim(vars = "bio1", path = tmp, download = FALSE)
#> class       : SpatRaster
#> size        : 10, 10, 1  (nrow, ncol, nlyr)
#> resolution  : 0.2, 0.2  (x, y)
#> extent      : 144, 146, -7, -5  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source      : file128c3dbfd9c7.tif
#> name        : bio1
#> min value   :   20
#> max value   :   20
```
