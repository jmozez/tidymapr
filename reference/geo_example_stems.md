# Simulated ForestGEO-style stem table for tests

Returns a small stem inventory in local metre coordinates (`gx`, `gy`)
for trying
[`plot_topo()`](https://tidymapr.in4metrix.dev/reference/plot_topo.md).
Columns follow the ForestGEO convention (`plot`, `treeID`, `stemID`,
`gx`, `gy`, `dbh`, `species`, `status`). Positions, sizes and species
are simulated on a 100 m x 100 m plot to check code only. They are not
real Wanang or ForestGEO trees: do not present maps or results from this
table as field data.

## Usage

``` r
geo_example_stems(n = 120, seed = 1)
```

## Arguments

- n:

  Number of stems.

- seed:

  RNG seed for reproducibility.

## Value

A tibble.

## References

Condit, R. et al. (2019). Complete data from the Barro Colorado 50-ha
plot: 423617 trees, 35 years. *Dryad*.
[doi:10.15146/5xcp-0d46](https://doi.org/10.15146/5xcp-0d46) . ForestGEO
network: <https://forestgeo.si.edu/>. Wanang forest dynamics plot, Papua
New Guinea: Anderson-Teixeira, K. J. et al. (2015). CTFS-ForestGEO: a
worldwide network monitoring forests in an era of global change. *Global
Change Biology*, 21, 528-549.
[doi:10.1111/gcb.12712](https://doi.org/10.1111/gcb.12712) .

## Examples

``` r
geo_example_stems()
#> # A tibble: 120 × 8
#>    plot    treeID stemID    gx    gy   dbh species                    status
#>    <chr>    <int>  <int> <dbl> <dbl> <dbl> <chr>                      <chr> 
#>  1 demo100      1      1 27.5   97.2   6.8 Homalanthus_novoguineensis A     
#>  2 demo100      2      2 37.7   49.6  18.9 Pometia_pinnata            A     
#>  3 demo100      3      3 57.0   48.5   8   Homalanthus_novoguineensis A     
#>  4 demo100      4      4 89.2   18.7   8.2 Ficus_sp                   A     
#>  5 demo100      5      5 21.4   74.5   8.5 Pterocarpus_indicus        A     
#>  6 demo100      6      6 88.2   45.6  13.4 Intsia_bijuga              D     
#>  7 demo100      7      7 92.7   51.1   8.7 Pometia_pinnata            A     
#>  8 demo100      8      8 65.4   21.9   8.8 Pometia_pinnata            A     
#>  9 demo100      9      9 62.4   24.0   6.2 Homalanthus_novoguineensis A     
#> 10 demo100     10     10  7.93  59.2   7.6 Pometia_pinnata            A     
#> # ℹ 110 more rows
```
