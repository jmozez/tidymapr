# GPS positions of the Mt Wilhelm ant bait transects

Real field coordinates for the bait transects behind
[tidydiversity::png_ants](https://rdrr.io/pkg/tidydiversity/man/png_ants.html).
The published data give a GPS position and elevation for every bait;
this table averages them to one point per elevation band and transect
(two transects per band, eight bands from 200 to 3700 m). Use it to map
the study sites or to join coordinates onto
[`tidydiversity::png_ants`](https://rdrr.io/pkg/tidydiversity/man/png_ants.html)
by `site`.
[`geo_example_sites()`](https://tidymapr.in4metrix.dev/reference/geo_example_sites.md)
returns the band centroids (mean of the two transects).

## Usage

``` r
png_ants_sites
```

## Format

A tibble with 16 rows and 7 columns:

- site:

  Elevation band code, as in `png_ants` (`"MW0200"`).

- transect:

  Transect number within the band (1 or 2).

- elevation_band:

  Nominal elevation band in metres.

- elevation:

  Mean GPS elevation of the baits on the transect, in metres.

- lon, lat:

  Mean WGS84 longitude and latitude of the baits.

- baits:

  Number of bait positions averaged.

## Source

Mottl, O., Moses, J. and Klimes, P. (2023). Data and code for "Nutrient
use by tropical ant communities varies among three extensive elevational
gradients: a cross-continental comparison". Zenodo, open licence.
[doi:10.5281/zenodo.8191946](https://doi.org/10.5281/zenodo.8191946) .
Built by `data-raw/png_ants_sites.R` in the package source.

## References

Moses, J., Peters, M. K., Tiede, Y., Mottl, O., Donoso, D. A., Farwig,
N., Fayle, T. M., Novotny, V., Sanders, N. J. and Klimes, P. (2023).
Nutrient use by tropical ant communities varies among three extensive
elevational gradients: a cross-continental comparison. *Global Ecology
and Biogeography*, 32, 2212-2229.
[doi:10.1111/geb.13757](https://doi.org/10.1111/geb.13757)

## Examples

``` r
png_ants_sites
#> # A tibble: 16 x 7
#>    site   transect elevation_band elevation   lon   lat baits
#>    <chr>     <int>          <int>     <int> <dbl> <dbl> <int>
#>  1 MW0200        1            200       216  145. -5.74    60
#>  2 MW0200        2            200       249  145. -5.74    60
#>  3 MW0700        1            700       716  145. -5.73    60
#>  4 MW0700        2            700       774  145. -5.73    60
#>  5 MW1200        1           1200      1166  145. -5.72    60
#>  6 MW1200        2           1200      1089  145. -5.72    60
#>  7 MW1700        1           1700      1638  145. -5.76    60
#>  8 MW1700        2           1700      1840  145. -5.76    60
#>  9 MW2200        1           2200      2398  145. -5.76    60
#> 10 MW2200        2           2200      2339  145. -5.76    60
#> 11 MW2700        1           2700      2752  145. -5.81    60
#> 12 MW2700        2           2700      2617  145. -5.81    60
#> 13 MW3200        1           3200      3404  145. -5.80    60
#> 14 MW3200        2           3200      3259  145. -5.81    60
#> 15 MW3700        1           3700      3825  145. -5.79    60
#> 16 MW3700        2           3700      3916  145. -5.78    60
```
