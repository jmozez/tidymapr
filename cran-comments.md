## Submission

This is the first submission of tidymapr.

## Test environments

* Ubuntu 24.04, R 4.3.3 (local), `R CMD check --as-cran`

## R CMD check results

0 errors | 0 warnings | 3 notes

* checking CRAN incoming feasibility ... NOTE
  New submission.

* checking installed package size ... NOTE
  The installed size is about 7 MB, mostly the compiled C++ code
  (spatial statistics, species distribution models, 3D rendering).

* checking compilation flags used ... NOTE
  The flags come from the R installation on the test machine
  (Ubuntu's r-base), not from the package's Makevars.

## Suggested package not on CRAN

tidydiversity, a companion package by the same author, is suggested.
It has been submitted to CRAN separately and should be accepted
before this package. Every use is conditional: code calls
`rlang::check_installed("tidydiversity")`, examples use `@examplesIf`
or `requireNamespace()`, and tests use `skip_if_not_installed()`.
