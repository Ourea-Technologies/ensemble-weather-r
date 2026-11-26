## Submission

This is a new submission: the first release (0.1.0) of ensembleweather, the
official R client for the Ourea probabilistic weather API
(https://oureawx.com), maintained by Ourea Technologies.

## Test environments

* local: macOS 26 (aarch64-apple-darwin, Homebrew), R 4.6.1,
  `R CMD check --as-cran` (no LaTeX locally, so `--no-manual`; the PDF
  manual is built and checked in CI on ubuntu-latest)
* GitHub Actions (r-lib/actions): ubuntu-latest, macos-latest and
  windows-latest, each on R release and oldrel-1
* win-builder (R-devel): to be run by the maintainer before submission
* R-hub (linux, macos-arm64, windows): to be run by the maintainer before
  submission

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Network use

The package is a web API client. No example, test or vignette calls the
network on CRAN: examples run only when `interactive()` or when
`OUREA_BASE_URL` points at a local stub server, and every test uses
`httr2::local_mocked_responses()`. Tests that need the package's pinned API
specification (not shipped in the tarball) skip on CRAN.

## Downstream dependencies

None (new package).
