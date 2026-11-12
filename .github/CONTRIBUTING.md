# Contributing to tidymapr

Thank you for helping to improve tidymapr. Contributions of every size are
welcome: bug reports, documentation fixes, examples and new features.

## Reporting a problem

Open an issue at <https://github.com/jmozez/tidymapr/issues> with a minimal
reproducible example, ideally made with the [reprex](https://reprex.tidyverse.org)
package, and the output of `sessionInfo()`. Say what you expected and what
happened instead.

## Proposing a change

1. For anything beyond a small fix, open an issue first so the approach can
   be discussed.
2. Fork the repository and create a branch from `main`.
3. Make your change, with tests in `tests/testthat/` and documentation in
   roxygen comments (run `devtools::document()`).
4. Check that `devtools::check()` passes and `lintr::lint_package()` is
   clean.
5. Add a bullet to the top section of `NEWS.md`.
6. Open a pull request against `main`.

## Standards

* Code follows the [tidyverse style guide](https://style.tidyverse.org).
* New statistical methods are tested against a reference implementation or
  against known true values, and cite the method in their help page.
* User-facing text uses plain language and British spelling.

## Code of conduct

Please note that tidymapr is released with a
[Contributor Code of Conduct](https://ropensci.org/code-of-conduct/). By
contributing to this project you agree to abide by its terms.
