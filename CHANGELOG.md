# Changelog

All notable changes to this package are documented here, in the format of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The package follows
[Semantic Versioning](https://semver.org/). `NEWS.md` holds the same entries
in R's own format (it is what CRAN and `news()` show). Outside contributors
are credited by GitHub handle.

## [Unreleased]

Targets the v1 contract as deployed (ensemble-weather-spec 8b85fea, the
server's public spec byte for byte). Breaking, as 0.x allows.

### Changed

- The coordinate functions follow the operation ids: `ew_forecast_at()` is
  `ew_get_point_forecast()`, `ew_current_at()` is `ew_get_point_current()`,
  `ew_alerts_at()` is `ew_get_point_alerts()` and `ew_nearby_at()` is
  `ew_get_point_nearby()`. There are no aliases.
- `precip_*` fields and columns are `precipitation_*`: daily
  `total_precipitation`, `total_precipitation_if_wet`,
  `precipitation_probability`, `precipitation_occurrence_probability`,
  `precipitation_type`, `precipitation_display`; hourly
  `precipitation_type`; current `precipitation_probability`; sensor
  `precipitation_rate`; thresholds `daily_precipitation_*`.
- Wind direction (hourly and `model_means`) is the circular distribution:
  `wind_direction_mean`, `_stddev`, `_sector_50_from`/`_to`,
  `_sector_90_from`/`_to` instead of quantile columns.
- `$probabilities` and `$window_totals` are matched to the caller's terms by
  the `term` the server echoes (a new first column), never by position.
- Error categories follow the 16 public error codes: `AUTH_UNAVAILABLE` is
  `unavailable`; `FORBIDDEN`, `GONE`, `MODEL_RUN_NOT_FOUND`, `AMBIGUOUS`,
  `INVALID_MAX_HOURS` and `FEELS_LIKE_UNAVAILABLE` map by status.
  `OUTSIDE_COVERAGE` is a 404. `Retry-After` is honoured on 504 too.
- Comma lists (`sources`, `include`, `network`, `capability`, ...) are sent
  sorted, de-duplicated and joined by a literal `,`; `capability` is one
  list, not a repeated parameter.
- Alert `severity`/`urgency` and the catalog's `network`, `station_status`,
  `template_variant` and `location_type` are snake_case (as served).

### Added

- `include` on `ew_forecast()` / `ew_get_point_forecast()`
  (`skin_temperature`, `mslp`: served only when asked for).
- `null_reason` on probabilities and window totals; `aggregation` on window
  totals.
- Error fields `doc_url`, `param` and `nearest_location`; `request_id` is
  read from the error body first.
- Alert `certainty`; current `station_id`; `ew_runs(cursor =)` and its
  `next_cursor` attribute.

### Removed

- `ew_storm_reports()` and `ew_storm_report()`: storm reports are not in the
  public API.
- `wind_direction_circular`, `feels_like_utci*`, `ptype`, the elevation
  forecasts' legacy `timeseries` and `default`, and the catalog `ads` block.

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
