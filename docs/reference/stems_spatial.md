# Spatial verbs for ForestGEO-style stem maps

Stems in forest dynamics plots (ForestGEO / CTFS) are mapped in local
metre coordinates (`gx`, `gy`). These verbs are the spatial part of a
stem workflow:

- `stems_quadrat()` assigns each stem to a square quadrat (ForestGEO
  default 20 m) and adds `quadrat`, `quadrat_x`, `quadrat_y`,
  `quadrat_col` and `quadrat_row`.

- `stems_habitat()` joins quadrat-level habitat or topography by
  `quadrat` or by `quadrat_x`/`quadrat_y`.

- `stems_neighbours()` counts neighbours within `radius` metres of each
  stem, either all stems or conspecifics only.

Census summaries (`stems_abundance()`, `stems_basal_area()`,
`stems_demography()`, `stems_as_community()`) live in tidydiversity. Map
stems with
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md)
and test habitat associations with
[`stems_habitat_test()`](https://tidymapr.in4metrix.dev/reference/stems_habitat_test.md).

## Usage

``` r
stems_quadrat(data, grid = 20, gx = gx, gy = gy)

stems_habitat(data, habitat, grid = 20)

stems_neighbours(
  data,
  radius = 10,
  conspecific = TRUE,
  alive_only = TRUE,
  alive = "A"
)
```

## Arguments

- data:

  A ForestGEO-like stem or tree table with species and local coordinates
  (`gx`/`gy` or `x`/`y`).

- grid:

  Quadrat size in metres (ForestGEO default 20).

- gx, gy:

  Bare column names for local metre coordinates.

- habitat:

  A data frame of quadrat-level habitat or topography (`quadrat`, or
  `quadrat_x`/`quadrat_y`, plus covariates).

- radius:

  Neighbourhood radius in metres.

- conspecific:

  Count only neighbours of the same species (`TRUE`) or all neighbours
  (`FALSE`).

- alive_only:

  Keep only stems whose `status` is in `alive`?

- alive:

  Character codes of `status` that mean alive (default `"A"`).

## Value

A tibble: `data` with the new quadrat, habitat or neighbour columns.

## References

Condit, R. (1998). *Tropical Forest Census Plots*. Springer.
Anderson-Teixeira, K. J. et al. (2015). CTFS-ForestGEO: a worldwide
network monitoring forests in an era of global change. *Global Change
Biology*, 21, 528-549.
[doi:10.1111/gcb.12712](https://doi.org/10.1111/gcb.12712) .

## Examples

``` r
stems <- geo_example_stems()
q <- stems_quadrat(stems, grid = 20)
head(q[c("gx", "gy", "quadrat", "quadrat_col", "quadrat_row")])
#> # A tibble: 6 x 5
#>      gx    gy quadrat quadrat_col quadrat_row
#>   <dbl> <dbl> <chr>         <int>       <int>
#> 1  27.5  97.2 20_80             1           4
#> 2  37.7  49.6 20_40             1           2
#> 3  57.0  48.5 40_40             2           2
#> 4  89.2  18.7 80_0              4           0
#> 5  21.4  74.5 20_60             1           3
#> 6  88.2  45.6 80_40             4           2

hab <- unique(q[c("quadrat", "quadrat_x", "quadrat_y")])
hab$elev <- hab$quadrat_x + hab$quadrat_y
head(stems_habitat(stems, hab))
#> # A tibble: 6 x 16
#>   plot    treeID stemID    gx    gy   dbh species status quadrat_x.x quadrat_y.x
#>   <chr>    <int>  <int> <dbl> <dbl> <dbl> <chr>   <chr>        <dbl>       <dbl>
#> 1 demo100      1      1  27.5  97.2   6.8 Homala~ A               20          80
#> 2 demo100      2      2  37.7  49.6  18.9 Pometi~ A               20          40
#> 3 demo100      3      3  57.0  48.5   8   Homala~ A               40          40
#> 4 demo100      4      4  89.2  18.7   8.2 Ficus_~ A               80           0
#> 5 demo100      5      5  21.4  74.5   8.5 Pteroc~ A               20          60
#> 6 demo100      6      6  88.2  45.6  13.4 Intsia~ D               80          40
#> # i 6 more variables: quadrat <chr>, quadrat_col <int>, quadrat_row <int>,
#> #   quadrat_x.y <dbl>, quadrat_y.y <dbl>, elev <dbl>

head(stems_neighbours(stems, radius = 10))
#> # A tibble: 6 x 11
#>   plot    treeID stemID    gx    gy   dbh species            status n_neighbours
#>   <chr>    <int>  <int> <dbl> <dbl> <dbl> <chr>              <chr>         <int>
#> 1 demo100      1      1  27.5  97.2   6.8 Homalanthus_novog~ A                 0
#> 2 demo100      2      2  37.7  49.6  18.9 Pometia_pinnata    A                 0
#> 3 demo100      3      3  57.0  48.5   8   Homalanthus_novog~ A                 0
#> 4 demo100      4      4  89.2  18.7   8.2 Ficus_sp           A                 0
#> 5 demo100      5      5  21.4  74.5   8.5 Pterocarpus_indic~ A                 0
#> 6 demo100      7      7  92.7  51.1   8.7 Pometia_pinnata    A                 0
#> # i 2 more variables: neighbour_radius <dbl>, conspecific <lgl>
```
