# Classify a numeric column into map classes

`geo_breaks()` returns class breaks for a numeric vector, and
`geo_classify()` adds the class of every row to a data frame, ready for
a choropleth or a bubble map. The styles follow tmap and classInt:

- `"quantile"`: equal numbers of observations per class;

- `"equal"`: equal-width classes over the range;

- `"jenks"`: Fisher-Jenks natural breaks, which minimise the
  within-class sum of squares exactly (Fisher 1958; computed in C++).
  The breaks equal classInt's `"jenks"` style; classInt's `"fisher"`
  style gives the same classes with breaks halfway between neighbouring
  values;

- `"pretty"`: rounded breaks from
  [`base::pretty()`](https://rdrr.io/r/base/pretty.html);

- `"sd"`: breaks at the mean plus or minus whole standard deviations;

- `"fixed"`: the `breaks` you give.

Like GeoSpaX's AutoMap, `geo_classify()` explains its choice: the result
carries the breaks, the number of rows in each class and the goodness of
variance fit (GVF, 1 = classes explain all variance) in attribute
`"classification"`.

## Usage

``` r
geo_breaks(
  x,
  n = 5,
  style = c("quantile", "equal", "jenks", "pretty", "sd", "fixed"),
  breaks = NULL
)

geo_classify(
  data,
  value,
  n = 5,
  style = c("quantile", "equal", "jenks", "pretty", "sd", "fixed"),
  breaks = NULL,
  digits = 3,
  name = NULL
)
```

## Arguments

- x:

  A numeric vector.

- n:

  Number of classes.

- style:

  Classification style (see Description).

- breaks:

  For `style = "fixed"`, the full vector of breaks, including the
  minimum and maximum.

- data:

  A data frame or `sf` table.

- value:

  \<[`data-masking`](https://rdrr.io/pkg/dplyr/man/dplyr_data_masking.html)\>
  Numeric column to classify.

- digits:

  Significant digits used in class labels.

- name:

  Name of the new class column (default `"<value>_class"`).

## Value

`geo_breaks()` returns the sorted breaks (`n + 1` values, minimum to
maximum). `geo_classify()` returns `data` with an ordered factor column
of class labels such as `"10 - 20"`.

## References

Fisher, W. D. (1958). On grouping for maximum homogeneity. *Journal of
the American Statistical Association*, 53, 789-798.
[doi:10.1080/01621459.1958.10501479](https://doi.org/10.1080/01621459.1958.10501479)

Jenks, G. F. (1977). *Optimal data classification for choropleth maps*.
Occasional paper 2, Department of Geography, University of Kansas.

## Examples

``` r
set.seed(1)
x <- c(rnorm(20, 10), rnorm(20, 30), rnorm(20, 60))
geo_breaks(x, n = 3, style = "jenks")
#> [1]  7.78530 11.59528 31.35868 61.98040

sites <- geo_example_sites()
geo_classify(sites, elevation, n = 3, style = "equal")
#> # A tibble: 8 × 7
#>   site     lon   lat elevation elevation_band coordinate_note    elevation_class
#>   <chr>  <dbl> <dbl>     <int> <fct>          <chr>              <ord>          
#> 1 MW0200  145. -5.74       200 200 m          published bait GP… 200 - 1370     
#> 2 MW0700  145. -5.73       700 700 m          published bait GP… 200 - 1370     
#> 3 MW1200  145. -5.72      1200 1200 m         published bait GP… 200 - 1370     
#> 4 MW1700  145. -5.76      1700 1700 m         published bait GP… 1370 - 2530    
#> 5 MW2200  145. -5.76      2200 2200 m         published bait GP… 1370 - 2530    
#> 6 MW2700  145. -5.81      2700 2700 m         published bait GP… 2530 - 3700    
#> 7 MW3200  145. -5.80      3200 3200 m         published bait GP… 2530 - 3700    
#> 8 MW3700  145. -5.78      3700 3700 m         published bait GP… 2530 - 3700    
```
