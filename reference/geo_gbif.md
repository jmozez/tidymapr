# Import GBIF-style occurrence records

Accepts a pre-downloaded GBIF (or rgbif-like) data frame, or downloads
records with **rgbif** when it is installed. The result is standardised
to `species`, `lon`, `lat` and optional extras, then optionally passed
through
[`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md)
and
[`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md).

## Usage

``` r
geo_gbif(
  data = NULL,
  scientificName = NULL,
  country = NULL,
  limit = 500,
  clean = TRUE,
  as_sf = FALSE,
  ...
)
```

## Arguments

- data:

  Optional data frame already holding GBIF columns such as
  `decimalLongitude`, `decimalLatitude` and `species` /
  `scientificName`.

- scientificName, country, limit:

  Arguments forwarded to
  [`rgbif::occ_search()`](https://docs.ropensci.org/rgbif/reference/occ_search.html)
  when `data` is `NULL`.

- clean:

  Run
  [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md)?

- as_sf:

  Convert cleaned points with
  [`geo_as_sf()`](https://tidymapr.in4metrix.dev/reference/geo_as_sf.md)?

- ...:

  Passed to
  [`geo_clean()`](https://tidymapr.in4metrix.dev/reference/geo_clean.md)
  when `clean = TRUE`.

## Value

A tibble, or an `sf` tibble when `as_sf = TRUE`.

## Examples

``` r
gbif_like <- tibble::tibble(
  scientificName = "Camponotus",
  decimalLongitude = 147.1,
  decimalLatitude = -9.4,
  countryCode = "PG"
)
geo_gbif(gbif_like, clean = FALSE, as_sf = FALSE)
#> # A tibble: 1 × 4
#>   species      lon   lat countryCode
#>   <chr>      <dbl> <dbl> <chr>      
#> 1 Camponotus  147.  -9.4 PG         
```
