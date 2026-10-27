# Good first issues (drafts)

Three real starter issues to file with the labels `good first issue` and
`help wanted` when 0.1.0 is released. Each is small, self-contained and
covered by the existing test setup (no network needed).

## 1. Add a `plot_plume` example with base graphics

**What:** a new `examples/plot_plume.R` that draws the p10-p90 and p25-p75
temperature bands and the median for the next 72 hours from
`ew_forecast(..., max_hours = 72)$hourly`, using base R graphics only (no new
dependency).

**Why:** the hourly tibble is made for plotting, and no example shows it.

**Done when:** the example runs in `scripts/run-examples.R` against the stub
(writing to a temporary PNG), it is listed in the README's examples table,
and it reads only the quantile columns (no client-side statistics).

## 2. Test `ew_nearby_at()` and `ew_alerts_at()` against the stub

**What:** add the `/api/v1/nearby` and `/api/v1/alerts` routes to
`scripts/stub-server.R`, and testthat cases in `tests/testthat/` that check
the canonical query (`lat`, `lon`, defaults omitted) and the returned tibble's
columns and attributes, using `local_replay()` from `helper-spec.R`.

**Why:** the coordinate variants are exposed and documented but have fewer
tests than the named-location ones.

**Done when:** the new tests pass and fail if a default (`limit = 3`,
`radius_km = 50`) is sent.

## 3. A `format()` method for `ensembleweather_page`

**What:** `print.ensembleweather_page()` exists, but there is no `format()`
method, so `format(page)` falls back to the default list formatting. Add
`format.ensembleweather_page()` (returning the header line) and have
`print()` use it, as the client and forecast classes do.

**Why:** consistency with the other classes, and nicer output in logs.

**Done when:** a snapshot test (`expect_snapshot()`) covers the output of a
first page and a last page.
