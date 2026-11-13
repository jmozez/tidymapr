---
title: 'tidymapr: Tidy mapping, spatial analysis and publication cartography in R'
tags:
  - R
  - cartography
  - spatial statistics
  - species distribution models
  - biodiversity
authors:
  - name: Jimmy Moses
    orcid: 0000-0003-3342-2384
    affiliation: 1
affiliations:
  - name: School of Forestry, Faculty of Natural Resources, Papua New Guinea University of Technology, Private Mail Bag, Lae 411, Morobe Province, Papua New Guinea
    index: 1
date: 12 November 2026
bibliography: paper.bib
---

# Summary

`tidymapr` is an R package for making publication-quality maps and for
the spatial analyses that usually come with them. A map is built as a
pipeline of layers (`geo_map() |> map_raster() |> map_polygons()`), and
each design decision a cartographer would make by hand (projection,
classification method, colour ramp, legend, scale bar and north arrow)
is made automatically and reported back to the user with its reason.
The same pipeline style covers occurrence-record cleaning, spatial
autocorrelation (global and local Moran's I, Getis-Ord $G_i^*$),
hot-spot and cluster detection, kriging and inverse-distance
interpolation, species distribution models with spatially blocked
cross-validation, Moran's eigenvector maps, landscape metrics and
interactive web maps. Every result is a tidy data frame, an `sf` object
[@pebesma2018], a `terra` raster [@terra] or a `ggplot2` plot
[@ggplot2], so it can be passed on to the rest of the tidyverse
[@tidyverse]. Analyses can also be written as YAML recipes that run
unchanged in R and in the GeoSpaX desktop GIS, so a colleague who does
not use R can repeat them.

![A species distribution model ensemble made with `tidymapr`: predicted
habitat suitability with occurrence records, scale bar and north
arrow.](figure-sdm.png)

# Statement of need

Researchers often need a finished map and a defensible spatial
analysis from the same data. In R, the building blocks are spread over
packages with different conventions: `sf` and
`terra` for data, `ggplot2` or `tmap` [@tmap] for maps, `spdep`
[@spdep] for autocorrelation, `gstat` [@gstat] for kriging,
`CoordinateCleaner` [@coordinatecleaner] for occurrence cleaning,
`maxnet` [@maxnet] and `biomod2` [@biomod2] for distribution models,
`adespatial` for eigenvector maps, `landscapemetrics`
[@landscapemetrics] for landscape structure and `dbscan` [@dbscan] for
density clustering. Assembling them takes experience, and the
cartographic choices (which projection preserves area, how many
classes, which palette is colour-blind safe) are left to the user, who
is often a domain scientist rather than a cartographer.

`tidymapr` targets that user. Its contribution is threefold:

1. **Explained, automatic design.** `geo_automap()` and the `map_*()`
   layers choose an equal-area or conformal projection from the data's
   extent [@savric2019], a classification method from the data's
   distribution, and a palette suited to the variable type, and print
   why. Users can override any choice.
2. **One interface for common spatial analyses**, each returning tidy
   output that maps directly: `geo_moran()`, `geo_lisa()` [@anselin1995],
   `geo_hotspot()` [@getis1992], `geo_interpolate()` [@cressie1993],
   `geo_sdm()` with spatial block cross-validation [@roberts2017],
   `geo_mem()` [@dray2006], `geo_cluster()` [@ester1996],
   `geo_mde()` and `geo_mde_3d()` [@colwell2000],
   `geo_clean()`, `geo_decay()` and `geo_raster_diversity()`
   [@feret2014].
3. **A companion to `tidydiversity`** [@tidydiversity], which estimates
   taxonomic, phylogenetic and functional diversity with Hill numbers
   [@chao2014], so diversity estimates can be mapped, tested for
   spatial structure and modelled against the environment in one
   workflow.

Unlike `tmap`, `tidymapr` couples the map to the analysis and explains
its design; unlike `biomod2`, it is not limited to distribution models;
and its functions share arguments and return objects that combine.

# Geometric null models in two and three dimensions

Ranges placed at random within a bounded region overlap most in its
interior, so richness can peak there from geometry alone: the
mid-domain effect [@colwell2000]. Existing tools work along one gradient
[@colwell2008]. `geo_mde()` randomises the observed ranges within a
domain of any shape on an equal-area grid, growing each range cell by
cell [@jetz2001] so that it stays contiguous and follows the coastline;
`geo_mde_3d()` extends this to the sea, where ranges also grow in depth
and cannot pass the sea floor. On a one-cell-wide domain the C++ kernel
reproduces rangemodelR, which the tests check.

For 71 lemur species in Madagascar (GBIF), the island's shape explains
45% of the variation in richness, but richness exceeds the null model
along the eastern rainforest (Figure 2), a classic test case
[@lees1999]. Around Papua New Guinea (OBIS records of 166 coral and
1,414 fish species with depths, GEBCO bathymetry), geometry predicts
the richest depths at 30-100 m, whereas both groups peak at 0-20 m
(Figure 3), partly because most depth records come from divers.

![Lemurs of Madagascar on a 25 km equal-area grid: (a) observed
richness, (b) richness expected from the island's shape alone (199
randomisations), (c) standardised effect size.](figure-mde-2d.png)

![Richness per depth band of reef corals and fishes around Papua New
Guinea against the three-dimensional null model and its 95%
interval.](figure-mde-3d.png)

# Correctness and performance

Where `tidymapr` re-implements an established method it is tested
against the reference implementation, and the tests run in
`R CMD check`: Moran's I and its randomisation variance equal
`spdep::moran.test()`; local Moran's I equals `spdep::localmoran()`;
kriging equals `gstat::krige()`; occurrence flags equal
`CoordinateCleaner`; Moran's eigenvector maps equal
`adespatial::dbmem()`; DBSCAN core and noise points equal
`dbscan::dbscan()`; and landscape metrics equal `landscapemetrics`.
Areas, distances and buffers of longitude-latitude data are geodesic
and are checked against analytical values (for example, one degree of
longitude at 60° N is 55.6 km). The test suite has about 650
expectations with 77% line coverage.

The computationally demanding steps are written in C++ with OpenMP. On
four cores, a LISA permutation test with 500 sites and 999 permutations
runs in 0.05 s instead of 5 s, and ordinary kriging of 300 points onto
40,000 cells in 0.9 s instead of 20 s, with results identical to the
single-threaded reference and permutation p-values reproducible for a
given seed whatever the number of cores.

# Documentation

Every exported function has a help page with a runnable example. A
nine-chapter user guide at <https://tidymapr.in4metrix.dev> takes users
from installation to reporting, with the concept, a worked example on
real data, how to read the output and how to report it in a paper.
Version 0.2.0 is archived on Zenodo [@tidymapr].

# AI usage disclosure

Generative AI tools were used to assist with writing code, tests and
documentation. All output was reviewed, edited and validated by the
author, who takes responsibility for the software and this paper.
Numerical correctness rests on the reference comparisons and analytical
tests described above, not on the AI tools.

# Acknowledgements

I thank the authors of `sf`, `terra`, `ggplot2`, `spdep`, `gstat`,
`adespatial`, `CoordinateCleaner` and `landscapemetrics`, whose
packages are the references `tidymapr` is tested against, and the GBIF
data publishers whose records are used in the examples.

# References
