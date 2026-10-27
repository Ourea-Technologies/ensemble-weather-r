Thank you for contributing to ensembleweather!

## What and why

<!-- What does this change, and why? -->

Closes #<!-- issue number -->

## Tests

<!-- The tests you added or changed. A fix comes with a test that fails without it. -->

## Checks run locally

- [ ] `Rscript -e 'styler::style_pkg(dry = "fail")'` and `Rscript -e 'lintr::lint_package()'`
- [ ] `Rscript -e 'testthat::test_local()'` (unit tests and every vector)
- [ ] `R CMD check --as-cran` on the built tarball: 0 errors, 0 warnings, 0 notes
- [ ] `Rscript scripts/run-examples.R` (if examples changed)
- [ ] `roxygen2::roxygenise()` re-run and committed (if docs changed)
- [ ] No new runtime dependency (or it is justified in CONTRIBUTING.md)
- [ ] The package still computes no statistics (no summing or interpolating quantiles)
- [ ] `NEWS.md` and `CHANGELOG.md` updated under the development version
