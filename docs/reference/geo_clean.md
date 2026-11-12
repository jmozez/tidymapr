# Clean occurrence coordinates

Flags and optionally filters occurrence records using tests rebuilt
inside tidymapr, so callers never need CoordinateCleaner. Flags cover
equal longitude and latitude, zero coordinates, country capitals, the
GBIF headquarters, biodiversity institutions, points at sea (when a land
mask is supplied), geographic outliers, invalid coordinates and
duplicates.

## Usage

``` r
geo_clean(
  data,
  lon = lon,
  lat = lat,
  species = NULL,
  tests = c("equal", "zeros", "capitals", "gbif", "institutions", "validity",
    "duplicates", "outliers"),
  capitals_rad = 10000,
  institutions_rad = 100,
  gbif_rad = 1000,
  outliers_method = c("quantile", "mad"),
  outliers_mtp = 5,
  land_mask = NULL,
  value = c("clean", "flagged", "both")
)
```

## Arguments

- data:

  A data frame of occurrence records.

- lon, lat:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Coordinate columns.

- species:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Optional species column for duplicate and outlier tests.

- tests:

  Character vector of tests to run. See Details.

- capitals_rad, institutions_rad, gbif_rad:

  Buffer radius in metres around reference points (defaults match
  CoordinateCleaner).

- outliers_method:

  `"quantile"` or `"mad"`.

- outliers_mtp:

  Multiplier for the outlier threshold (quantile IQR or MAD).

- land_mask:

  Optional `sf`/`SpatVector` polygons of land, or a SpatRaster land
  mask. When `NULL`, the `"seas"` test is skipped.

- value:

  `"clean"` (filtered data), `"flagged"` (logical flag columns plus
  coordinates), or `"both"` (a list). In the flag columns `TRUE` means
  the record was **flagged** by that test, and `.summary` is `TRUE` when
  any test flagged it; CoordinateCleaner uses the opposite convention
  (`TRUE` = passed).

## Value

Depending on `value`: a tibble, a flagged tibble, or a list with `clean`
and `flagged`.

## Details

Available tests: `"equal"`, `"zeros"`, `"capitals"`, `"centroids"`
(treated as capitals for the bundled reference set), `"gbif"`,
`"institutions"`, `"seas"`, `"outliers"`, `"validity"`, `"duplicates"`.

## References

Zizka, A. et al. (2019). CoordinateCleaner: standardized cleaning of
occurrence records from biological collection databases. *Methods in
Ecology and Evolution*, 10, 744-751.
[doi:10.1111/2041-210X.13152](https://doi.org/10.1111/2041-210X.13152)

## Examples

``` r
occ <- tibble::tibble(
  species = c("a", "a", "b", "b", "c"),
  lon = c(147.1, 147.1, 0, 12.58, 151),
  lat = c(-9.4, -9.4, 0, 55.67, -33.9)
)
geo_clean(occ, lon, lat, species = species, value = "flagged")
#> # A tibble: 5 × 12
#>   species   lon   lat .val  .equ  .zer  .cap  .gbf  .inst .dpl  .otl  .summary
#>   <chr>   <dbl> <dbl> <lgl> <lgl> <lgl> <lgl> <lgl> <lgl> <lgl> <lgl> <lgl>   
#> 1 a       147.   -9.4 FALSE FALSE FALSE FALSE FALSE FALSE TRUE  FALSE FALSE   
#> 2 a       147.   -9.4 FALSE FALSE FALSE FALSE FALSE FALSE TRUE  FALSE TRUE    
#> 3 b         0     0   FALSE TRUE  TRUE  FALSE FALSE FALSE FALSE FALSE TRUE    
#> 4 b        12.6  55.7 FALSE FALSE FALSE FALSE TRUE  FALSE FALSE FALSE TRUE    
#> 5 c       151   -33.9 FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE   
```
