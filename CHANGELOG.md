# Changelog

All notable changes to this package are documented here, in the format of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The package follows
[Semantic Versioning](https://semver.org/). `NEWS.md` holds the same entries
in R's own format (it is what CRAN and `news()` show). Outside contributors
are credited by GitHub handle.

## [Unreleased]

## [0.1.0] - 2026-10-27

### Added

- The official R client for the Ourea probabilistic weather API (contract
  v1): every operation in BEHAVIOR.md section 3 except `getMapsToken`.
- `ew_forecast()` and `ew_forecast_at()`, returning tibbles of quantiles
  (one row per hour and per day).
- `ew_chance()` probabilities with their reference class and `ew_total()`
  window totals, mapped back to the caller's order.
- `ew_current()`, `ew_alerts()`, `ew_nearby()` (each with an `_at()` form for
  coordinates), `ew_search()`, `ew_locations()`, `ew_catalog_locations()`,
  `ew_catalog_stations()` (all pages, or `_page()` one at a time),
  `ew_catalog_location()`, `ew_catalog_station()`, `ew_runs()`,
  `ew_storm_reports()`, `ew_storm_report()` and `ew_attribution()`.
- `ew_client()`: keys from `OUREA_API_KEY`, base URL from `OUREA_BASE_URL`,
  retries per BEHAVIOR 9, an in-memory `ETag` cache (`ew_memory_cache()`, or
  any cachem-style cache), `ew_rate_limit()` and `ew_response_info()`.
- Classed error conditions, one per BEHAVIOR 8 category.
- `citation("ensembleweather")`.

[Unreleased]: https://github.com/Ourea-Technologies/ensemble-weather-r/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ourea-Technologies/ensemble-weather-r/releases/tag/v0.1.0
