# Export a site-by-feature matrix for conservation planning

Builds a wide site-by-feature table (coverage-standardised diversity or
species abundances) suitable for **prioritizr**. Does not call
prioritizr or embed a solver; hand the matrix to that package yourself.

## Usage

``` r
geo_as_features(
  data,
  site = site,
  species = species,
  abundance = NULL,
  value = NULL,
  features = "feature"
)
```

## Arguments

- data:

  Community table or a diversity table with a site column.

- site, species, abundance, value:

  Column selections. For diversity tables, pass `value` (for example
  `diversity`) and omit `species`.

- features:

  Optional feature name when exporting a single diversity metric
  (defaults to `"feature"`).

## Value

A tibble with `site` and one column per feature.

## Details

Spectral diversity / Google Earth Engine workflows remain deferred (link
only; no rgee dependency).

## Examples

``` r
geo_as_features(tidydiversity::png_ants) |> dim()
#> [1]  5 80
```
