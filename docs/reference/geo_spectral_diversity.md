# Spectral diversity in Hill numbers

`geo_spectral_diversity()` maps diversity from satellite or drone
imagery with the same Hill numbers used for species (Jost 2006), so
spectral and field diversity are on one scale. Following the spectral
species approach (Féret and Asner 2014):

1.  the bands are standardised and reduced with principal components
    (keeping the components that explain `pca_var` of the variance);

2.  pixels are grouped into `k` **spectral species** by k-means;

3.  in a moving window around each pixel, the spectral species are
    counted and their Hill numbers of order `q` computed (q = 0: number
    of spectral species; 1: exponential Shannon; 2: inverse Simpson).

The window step runs in C++ on several cores.

## Usage

``` r
geo_spectral_diversity(
  x,
  window = 5,
  k = 20,
  q = c(0, 1, 2),
  pca_var = 0.95,
  min_cells = NULL,
  sample = 20000
)
```

## Arguments

- x:

  A multi-band `SpatRaster` or file path.

- window:

  Window size in cells (odd; 5 means 5 x 5).

- k:

  Number of spectral species.

- q:

  Orders of diversity.

- pca_var:

  Share of variance the principal components must keep.

- min_cells:

  Minimum valid cells in a window; fewer gives `NA`.

- sample:

  Number of pixels used to fit the PCA and k-means (all pixels are then
  classified).

## Value

A `SpatRaster` with layers `q0`, `q1`, `q2` (one per `q`) and
`spectral_species`; attribute `"spectral"` holds the PCA variance kept,
number of components and the k-means centres.

## References

Féret, J.-B. and Asner, G. P. (2014). Mapping tropical forest canopy
diversity using high-fidelity imaging spectroscopy. *Ecological
Applications*, 24, 1289-1296.
[doi:10.1890/13-1824.1](https://doi.org/10.1890/13-1824.1)

Jost, L. (2006). Entropy and diversity. *Oikos*, 113, 363-375.
[doi:10.1111/j.2006.0030-1299.14714.x](https://doi.org/10.1111/j.2006.0030-1299.14714.x)

## Examples

``` r
s2 <- terra::rast(system.file("ex/sent2_L2A_2024-08-24.tif", package = "terra"))
set.seed(1)
sd <- geo_spectral_diversity(s2, window = 5, k = 15)
sd
#> class       : SpatRaster
#> size        : 90, 95, 4  (nrow, ncol, nlyr)
#> resolution  : 0.008333333, 0.008333333  (x, y)
#> extent      : 5.741667, 6.533333, 49.44167, 50.19167  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varnames    : sent2_L2A_2024-08-24
#>               sent2_L2A_2024-08-24
#>               sent2_L2A_2024-08-24
#>               sent2_L2A_2024-08-24
#> names       : q0,        q1,        q2, spectral_species
#> min values  :  2,  1.735126,  1.555556,                1
#> max values  : 14, 12.493226, 11.363636,               15
attr(sd, "spectral")$components
#> [1] 2
```
