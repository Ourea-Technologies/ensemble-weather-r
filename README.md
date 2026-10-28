# ensembleweather

Official R SDK for the [Ourea](https://oureawx.com) probabilistic weather API.

[![CI](https://github.com/Ourea-Technologies/ensemble-weather-r/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Ourea-Technologies/ensemble-weather-r/actions/workflows/ci.yml)
[![Security](https://github.com/Ourea-Technologies/ensemble-weather-r/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/Ourea-Technologies/ensemble-weather-r/actions/workflows/security.yml)
[![CRAN](https://www.r-pkg.org/badges/version/ensembleweather)](https://cran.r-project.org/package=ensembleweather)
[![R >= 4.1](https://img.shields.io/badge/R-%E2%89%A5%204.1-blue)](https://cran.r-project.org/package=ensembleweather)
[![Licence: BSD-2-Clause](https://img.shields.io/badge/licence-BSD--2--Clause-blue)](LICENSE.md)
[![Docs](https://img.shields.io/badge/docs-docs.oureawx.com%2Fr-blue)](https://docs.oureawx.com/r)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Ourea-Technologies/ensemble-weather-r/badge)](https://scorecard.dev/viewer/?uri=github.com/Ourea-Technologies/ensemble-weather-r)

## Install

```r
install.packages("ensembleweather")
```

## Quickstart

No signup and no API key: anonymous calls use the Free tier.

```r
# Quickstart: an anonymous forecast for Mt. Hood Meadows, with no API key.
# Prints each of the next 24 hours' temperature as a range (p10-p90) and the
# chance of at least 6 in (15 cm) of snow in the next 24 hours.
library(ensembleweather)

forecast <- ew_forecast(
  "or/mt-hood-meadows",
  units = "imperial",
  prob = ew_chance("snowfall", ">=", 6, "in") # window: the next 24 h
)

cat(forecast$location$name, "\n")
hours <- head(forecast$hourly, 24)
cat(sprintf(
  "%s  %.1f to %.1f °F (p10-p90)\n",
  format(hours$valid_time, "%a %H:%M UTC"), hours$temperature_p10, hours$temperature_p90
), sep = "")

snow <- forecast$probabilities
chance <- if (is.na(snow$probability)) "not available" else sprintf("%.0f%%", 100 * snow$probability)
cat(sprintf("Chance of at least 6 in of snow in the next 24 h: %s (%d members)\n", chance, snow$members))
```

This is [`examples/quickstart.R`](examples/quickstart.R); CI runs it.

## Authentication

Pass a key to `ew_client()`, or set `OUREA_API_KEY` (for example in your
`~/.Renviron`, so it never sits in a script):

```r
Sys.setenv(OUREA_API_KEY = "ow_...")          # or: client <- ew_client(api_key = "ow_...")
forecast <- ew_forecast_at(45.3311, -121.6649, elevation_m = 1661)
```

- **Anonymous** (no key): forecasts, current conditions and alerts for named
  locations at the Free tier, plus search and the catalog.
- **Free key**: the same, with your own rate-limit budget.
- **Pro key**: the 15-day horizon, forecasts and current conditions at any
  coordinates (`ew_forecast_at()`, `ew_current_at()`), every member's values,
  per-model statistics and past runs.

See [pricing](https://oureawx.com/pricing). The key is sent only as
`X-API-Key`, only to the API's own host, and never on the open routes
(search, catalog detail, attribution), so those share the edge cache with
everyone; `ew_client(send_key_on_open_routes = TRUE)` attributes every
request to your key instead. The key never appears in printed output, logs
or error messages.

## Probabilities, not single numbers

Every forecast value is a distribution computed by the server from the full
ensemble. Ask for the **chance** of crossing a threshold with `ew_chance()`:

```r
forecast <- ew_forecast("or/mt-hood-meadows", prob = list(
  ew_chance("snowfall", ">=", 12, "in", window = 72), # P(0-72 h snowfall >= 12 in)
  ew_chance("temperature", "<=", 32, "degF", window = c(6, 18), aggregation = "all")
))
forecast$probabilities # in your order (matched by `term`): term, variable, op, threshold,
                       # unit, window_start, window_end, aggregation, from, to, members,
                       # probability, null_reason
```

For a **storm total**, ask for the window total's distribution with
`ew_total()`:

```r
forecast <- ew_forecast("or/mt-hood-meadows", totals = ew_total("snowfall", 72))
forecast$window_totals[, c("variable", "p10", "p50", "p90", "unit", "null_reason")] # NA + reason
```

Read **quantiles** straight from the hourly tibble; `_p50` is the median,
not "the forecast":

```r
forecast$hourly[, c("valid_time", "temperature_p10", "temperature_p50", "temperature_p90")]
```

The package never sums, averages or interpolates quantiles, and never
derives a probability from them: the sum of hourly medians is not the median
total. A threshold you give in another unit is converted exactly into the
request's units before sending; response values are never converted. More in
[Probabilities](https://docs.oureawx.com/concepts/probabilities).

## More examples

| Example | Shows |
|---|---|
| [`quickstart.R`](examples/quickstart.R) | the program above, anonymous |
| [`point_forecast.R`](examples/point_forecast.R) | a forecast at coordinates and an elevation (Pro key from `OUREA_API_KEY`) |
| [`chance_of_snow.R`](examples/chance_of_snow.R) | several `prob` terms in one call, with windows and member counts |
| [`storm_total.R`](examples/storm_total.R) | `totals` window distributions for precipitation and snowfall |
| [`search_and_catalog.R`](examples/search_and_catalog.R) | search, then page through the catalog with the cursor |
| [`current_and_alerts.R`](examples/current_and_alerts.R) | current conditions and active alerts for a location |
| [`error_handling.R`](examples/error_handling.R) | catching an out-of-coverage error by its class, the keyless alternative to `PRO_REQUIRED`; reading rate-limit state |
| [`units.R`](examples/units.R) | the same forecast in metric and imperial |

## Errors, retries and rate limits

Every error is a classed condition inheriting from `ensembleweather_error`,
with one class per category: `ensembleweather_error_authentication`,
`_permission`, `_not_found`, `_invalid_request`, `_outside_coverage`,
`_rate_limited`, `_unavailable`, `_connection` (no response at all),
`_usage` (refused before sending) and `_unexpected_response`. API errors
carry `status`, `code` (the API's string, verbatim), `request_id`, `doc_url`,
`param` (on a 400 about one parameter), `nearest_location` (on a
`PRO_REQUIRED` coordinate request near a named location) and `retry_after`:

```r
tryCatch(
  ew_forecast_at(45.0, 10.0),
  ensembleweather_error_outside_coverage = function(cnd) message(cnd$code)
)
```

Connection errors, 429, 502, 503 and 504 are retried up to `max_retries`
(default 2) with full-jitter backoff, honouring `Retry-After` (on 429, 503
and 504) up to 60 s.
Nothing else is retried. `ew_rate_limit(result)` (or `ew_rate_limit(client)`)
returns the rate-limit state the server reported (`limit`, `remaining`,
`reset`, `policy`); the package never hard-codes limits.

Responses are cached in memory by `ETag` (256 entries, 32 MiB) and
revalidated on every call, so an unchanged forecast costs a `304`. Use
`ew_client(cache = FALSE)` to turn it off, or pass `ew_memory_cache()` or a
`cachem` cache to share one.

## Documentation

- Guides: https://docs.oureawx.com
- This SDK's guide: https://docs.oureawx.com/r
- API reference: the help pages (`?ew_forecast`), also on the
  [pkgdown site](https://ourea-technologies.github.io/ensemble-weather-r/)
- The OpenAPI contract: [ensemble-weather-spec](https://github.com/Ourea-Technologies/ensemble-weather-spec/blob/main/openapi/v1/openapi.yaml)
  (a pinned copy is in [`spec/`](spec/))
- Citing: `citation("ensembleweather")`

This SDK targets API contract **v1**.

## Supported versions

R 4.1 and later. CI tests the current release and the previous release
(oldrel) on Linux, macOS and Windows. Runtime dependencies: httr2, tibble,
rlang, cli and jsonlite.

## Contributing and community

This SDK is open source and we want it to be the best weather package in R.
Bug reports, feature requests, docs fixes and pull requests are all welcome,
including small ones.

- **Report a bug**: open a [bug report](https://github.com/Ourea-Technologies/ensemble-weather-r/issues/new?template=bug_report.yml).
- **Request a feature** or an API capability: open a [feature request](https://github.com/Ourea-Technologies/ensemble-weather-r/issues/new?template=feature_request.yml).
- **Ask a question or share what you built**: [GitHub Discussions](https://github.com/Ourea-Technologies/ensemble-weather-r/discussions).
- **Contribute code or docs**: read [CONTRIBUTING.md](.github/CONTRIBUTING.md) and look for
  [`good first issue`](https://github.com/Ourea-Technologies/ensemble-weather-r/labels/good%20first%20issue)s.
- **Security issues**: never in public issues; see [SECURITY.md](SECURITY.md).

Licensed under the [BSD-2-Clause licence](LICENSE.md), Copyright (c) 2026 Ourea Technologies.
