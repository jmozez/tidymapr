# tidymapr <img src="man/figures/logo.png" align="right" height="139" alt="tidymapr hex logo" />

Tidy mapping verbs for biodiversity and spatial ecology, designed to work
with [tidydiversity](https://github.com/jmozez/tidydiversity).

This repository reserves the package name. Mapping features now in
tidydiversity will move here. The two packages will stay compatible in
the same way `dplyr` and `ggplot2` work with tidydiversity: load them
together and keep a single tidy workflow. tidydiversity will re-export
the mapping verbs users need, so existing pipelines keep working.

```r
library(tidydiversity)
library(tidymapr)
library(dplyr)
library(ggplot2)
```

## Installation

```r
# install.packages("pak")
pak::pak("jmozez/tidymapr")
```

The package is in early development (0.0.0.9000) and is not on CRAN yet.

## Licence

MIT © 2026 Jimmy Moses
