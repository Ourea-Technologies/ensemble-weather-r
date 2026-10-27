# Contributing to ensembleweather

Thanks for helping make Ourea better. Bug reports, feature ideas, docs fixes
and pull requests are all welcome, and small ones count: a typo fix or a
clearer error message is a real improvement.

This is the official R package for the [Ourea](https://oureawx.com) API. Its
behaviour is fixed by the shared [behaviour spec](../spec/BEHAVIOR.md) and
[repository standard](../spec/SDK-STANDARD.md); its public API follows R's
own conventions (the [tidyverse style guide](https://style.tidyverse.org/),
snake_case, tibbles, classed conditions).

## From clone to green

You need R 4.1 or later. Install the development tools into a library of
their own (here `.scratch/rlib`, which git ignores), then run the checks:

```sh
git clone https://github.com/Ourea-Technologies/ensemble-weather-r
cd ensemble-weather-r
export R_LIBS_USER="$PWD/.scratch/rlib" && mkdir -p "$R_LIBS_USER"
Rscript -e 'install.packages(c("httr2", "tibble", "rlang", "cli", "jsonlite", "testthat", "withr", "yaml", "roxygen2", "lintr", "styler", "pkgdown"), repos = "https://cloud.r-project.org")'
Rscript -e 'testthat::test_local()'
```

That last command runs the unit tests and all 43 shared vectors. If it is
green, you are set up.

## The checks

CI runs exactly these; run them before you push:

```sh
Rscript -e 'roxygen2::roxygenise()'                  # docs and NAMESPACE (commit the result)
Rscript -e 'styler::style_pkg(dry = "fail")'         # tidyverse style, no changes
Rscript -e 'lintr::lint_package()'                   # lint (must print "No lints found")
Rscript scripts/security-lint.R                      # no eval(parse()), shelling out or deserialising
Rscript -e 'testthat::test_local()'                  # unit tests + every vector
R CMD build . && R CMD check --as-cran ensembleweather_*.tar.gz   # 0 errors, warnings, notes
R CMD INSTALL . && Rscript scripts/run-examples.R    # every example, against the local stub
Rscript -e 'pkgdown::build_site()'                   # the docs site (needs pandoc)
Rscript scripts/check-dependencies.R                 # runtime dependencies are justified below
Rscript scripts/check-readme.R                       # the README quickstart is examples/quickstart.R
scripts/sync-spec --check                            # spec/ matches spec/VERSION
```

Tests never call the real API. The vectors run through
`httr2::local_mocked_responses()`, with the retry sleep and jitter replaced
by `testthat::local_mocked_bindings()`. R CMD check runs its tests from a copy
of the package, so point it at the spec: `ENSEMBLEWEATHER_SPEC=$PWD/spec`
(and `NOT_CRAN=true`, so a missing spec fails instead of skipping).

The examples run against a small stub API in base R. To try one by hand:

```sh
Rscript scripts/stub-server.R      # prints OUREA_BASE_URL=http://127.0.0.1:PORT
OUREA_BASE_URL=http://127.0.0.1:PORT Rscript examples/quickstart.R
```

## Good bug reports

The [bug report form](https://github.com/Ourea-Technologies/ensemble-weather-r/issues/new?template=bug_report.yml)
asks for what helps us most:

- the package version (`packageVersion("ensembleweather")`), your R version
  and OS (`sessionInfo()` covers both);
- a minimal snippet that shows the problem, and what you expected instead;
- the `request_id` from the error (`cnd$request_id`), if there is one: it
  lets us find the request on our side.

Never paste your API key. The package keeps it out of errors and printed
output, but check anything you copy from a terminal.

## Feature ideas

Open a [feature request](https://github.com/Ourea-Technologies/ensemble-weather-r/issues/new?template=feature_request.yml)
and start with the problem you are solving, then the API you would like.
We decide by asking whether it fits R users, keeps the package small, and
keeps the rule below. The API's behaviour lives in
[ensemble-weather-spec](https://github.com/Ourea-Technologies/ensemble-weather-spec),
so a request that needs the server to do something new may be moved there
(label `needs-spec`). Questions are best asked in
[Discussions](https://github.com/Ourea-Technologies/ensemble-weather-r/discussions).

## How we respond

We aim to give a first response on new issues and pull requests within a few
business days. A small team maintains this package, so a fix can take longer
than that, but you will not be left without an answer.

## Rules of the road

- The server computes, the package carries: no summing, averaging or
  interpolating of quantiles, and no probabilities derived client-side.
- Every bug fix comes with a test that fails without it.
- Every exported function has roxygen2 docs and an example that never hits
  the network on CRAN (`@examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))`).
- Usage errors use `abort_usage()`; HTTP errors are classed conditions (see
  `?ensembleweather_error`).
- Commit messages: an imperative summary line (`Add`, `Fix`, ...) of at most
  72 characters, a blank line, then what changed and why. One logical change
  per commit; `main` has a linear history.
- Add a line to `NEWS.md` (and `CHANGELOG.md`) under the development version,
  crediting yourself by GitHub handle if you like: `(@you, #123)`.

## The spec

`spec/` is a copy of
[ensemble-weather-spec](https://github.com/Ourea-Technologies/ensemble-weather-spec)
at the commit or tag in `spec/VERSION`. Never edit it by hand:

```sh
scripts/sync-spec v1.1.0     # pin a new spec version and copy it in
```

If a vector looks wrong, open an issue on the spec repository instead of
bending the package to it.

## Dependencies

As few as possible: each runtime dependency is a supply-chain risk and an
install cost. `scripts/check-dependencies.R` (run in CI) fails if
`DESCRIPTION` imports a package that is not listed here with its
justification. Adding one needs the maintainers' approval.

### Runtime dependencies

- `httr2`: the HTTP client. Base R has no HTTP client that sets headers,
  timeouts and TLS verification properly; httr2 (on libcurl) does, redacts
  the key header in printed requests, and gives tests
  `local_mocked_responses()`. The package uses httr2 only to send one request
  and read one response: redirects, retries and caching follow BEHAVIOR 3.3,
  9 and 10 exactly, which httr2's `req_retry()`, `req_cache()` and curl's own
  redirect following do not (they cannot refuse a `Retry-After` over 60 s,
  skip TLS failures, or drop a custom key header on a cross-host redirect),
  so the package implements those itself. `req_throttle()` is not used: the
  package never hard-codes limits.
- `tibble`: results are tibbles (one row per hour, per probability, per
  hit), the format R users and the tidyverse expect.
- `rlang`: classed error conditions (`abort()` with fields), `%||%`, dots
  checks, and scoped bindings for the error call.
- `cli`: readable, interpolated usage errors (`cli_abort()`) and SHA-256 for
  the cache key's digest of the API key (`hash_sha256()`).
- `jsonlite`: JSON parsing. Already a dependency of httr2, so it adds
  nothing to install; it parses into plain lists and never evaluates code.
- `stats`: part of base R; `runif()` for the retry jitter.

### Suggested (tests only)

- `testthat`, `withr`, `yaml` (to read the pinned OpenAPI spec), `utils`.

Development tools (roxygen2, lintr, styler, pkgdown) never ship to users.
`renv.lock` pins the versions CI and the security audit use.

## Releasing (maintainers)

CRAN submission is manual: Harrison submits with `devtools::submit_cran()`.

1. Update the version in `DESCRIPTION`, `NEWS.md`, `CHANGELOG.md` and
   `cran-comments.md`.
2. Run every check above on a clean checkout, plus
   `rhub::rhub_check()` and `devtools::check_win_devel()` for the other
   CRAN platforms, and record the results in `cran-comments.md`.
3. Make sure the URLs in `DESCRIPTION` and the docs resolve (CRAN checks
   them).
4. `devtools::submit_cran()`, then confirm the email CRAN sends to the
   maintainer.
5. When CRAN accepts it, tag `vX.Y.Z` on `main` and push the tag:
   `release.yml` builds and checks the tarball and attaches it to the
   GitHub release. It publishes nothing to CRAN.
6. File the issues drafted in `GOOD_FIRST_ISSUES.md` (first release only).
