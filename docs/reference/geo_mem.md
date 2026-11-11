# Distance-based Moran's eigenvector maps (dbMEM)

Builds spatial eigenvectors from a truncated geographic distance matrix
(Dray, Legendre and Peres-Neto 2006). Implemented natively so callers
stay in tidymapr; when **adespatial** is installed, tests compare the
leading eigenvalues.

## Usage

``` r
geo_mem(
  data,
  lon = lon,
  lat = lat,
  site = NULL,
  thresh = NULL,
  method = c("haversine", "euclidean"),
  positive_only = TRUE
)
```

## Arguments

- data:

  A data frame of sites with coordinates.

- lon, lat:

  Coordinate columns (degrees for haversine).

- site:

  Optional site id column retained in the output.

- thresh:

  Truncation threshold in metres (haversine) or coordinate units
  (euclidean). When `NULL`, the longest edge of the minimum spanning
  tree is used.

- method:

  `"haversine"` or `"euclidean"` for the distance matrix.

- positive_only:

  Keep only eigenvectors with positive eigenvalues (the usual dbMEM
  set)?

## Value

A tibble (`tmr_geo_mem`) with site columns and `MEM1`, `MEM2`, ...
Eigenvalues are stored in attribute `eigenvalues`.

## References

Dray, S., Legendre, P. and Peres-Neto, P. R. (2006). Spatial modelling:
a comprehensive framework for principal coordinate analysis of neighbour
matrices (PCNM). *Ecological Modelling*, 196, 483-493.
[doi:10.1016/j.ecolmodel.2006.02.015](https://doi.org/10.1016/j.ecolmodel.2006.02.015)

## Examples

``` r
set.seed(1)
g <- expand.grid(lon = 1:5, lat = 1:4)
g$site <- paste0("s", seq_len(nrow(g)))
mem <- geo_mem(g, lon, lat, site = site, method = "euclidean")
names(mem)[1:5]
#> [1] "site" "lon"  "lat"  "MEM1" "MEM2"
```
