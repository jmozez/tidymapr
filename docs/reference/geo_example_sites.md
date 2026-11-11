# Published GPS coordinates for the Mt Wilhelm study sites

Returns one row per elevation band of the Mt Wilhelm ant survey
([tidydiversity::png_ants](https://tidydiversity.in4metrix.dev/reference/png_ants.html)),
with WGS84 longitude and latitude averaged from the bait GPS positions
published by Mottl, Moses and Klimes (2023). These are real field
coordinates; see
[png_ants_sites](https://tidymapr.in4metrix.dev/reference/png_ants_sites.md)
for the two transects per band.

## Usage

``` r
geo_example_sites(which = "wilhelm")
```

## Source

Mottl, O., Moses, J. and Klimes, P. (2023). Zenodo.
[doi:10.5281/zenodo.8191946](https://doi.org/10.5281/zenodo.8191946)

## Arguments

- which:

  Study area. Only `"wilhelm"` (the eight elevation bands from 200 to
  3700 m) is available: the package has no published coordinates for
  other areas, so none are invented.

## Value

A tibble with `site`, `lon`, `lat`, `elevation` (nominal band in
metres), `elevation_band` (ordered factor) and `coordinate_note`.

## Examples

``` r
geo_example_sites()
#> # A tibble: 8 × 6
#>   site     lon   lat elevation elevation_band coordinate_note                   
#>   <chr>  <dbl> <dbl>     <int> <fct>          <chr>                             
#> 1 MW0200  145. -5.74       200 200 m          published bait GPS, doi:10.5281/z…
#> 2 MW0700  145. -5.73       700 700 m          published bait GPS, doi:10.5281/z…
#> 3 MW1200  145. -5.72      1200 1200 m         published bait GPS, doi:10.5281/z…
#> 4 MW1700  145. -5.76      1700 1700 m         published bait GPS, doi:10.5281/z…
#> 5 MW2200  145. -5.76      2200 2200 m         published bait GPS, doi:10.5281/z…
#> 6 MW2700  145. -5.81      2700 2700 m         published bait GPS, doi:10.5281/z…
#> 7 MW3200  145. -5.80      3200 3200 m         published bait GPS, doi:10.5281/z…
#> 8 MW3700  145. -5.78      3700 3700 m         published bait GPS, doi:10.5281/z…
```
