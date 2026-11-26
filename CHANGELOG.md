# Changelog

All notable changes to this package are documented here, in the format of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The package follows
[Semantic Versioning](https://semver.org/). `NEWS.md` holds the same entries
in R's own format (it is what CRAN and `news()` show). Outside contributors
are credited by GitHub handle.

## [Unreleased]

## [0.1.0] - unreleased

The first release on CRAN: the official R client for the Ourea
probabilistic weather API. Targets the v1 contract at ensemble-weather-spec
7954268 (the server's public spec at 256cd770, byte for byte), and passes
all 58 of its shared test vectors.

### Added

- Forecasts for named locations (`ew_forecast()`) and coordinates
  (`ew_get_point_forecast()`), as tibbles of quantiles (one row per hour and
  per day), with `include` (`skin_temperature`, `mslp`) and `members`
  (`TRUE`, `FALSE` or `"plume"`: the members in columns, in
  `$series$plume`).
- Probabilities with their reference class (`ew_chance()`) and window totals
  (`ew_total()`), computed by the server, matched to the caller's terms by
  the `term` it echoes (never by position), with `null_reason`.
- `ew_current()`, `ew_alerts()`, `ew_nearby()` (each with an
  `ew_get_point_*()` form for coordinates), `ew_search()`,
  `ew_locations()`, `ew_catalog_locations()`, `ew_catalog_stations()` (all
  pages, or `_page()` one at a time), `ew_catalog_location()`,
  `ew_catalog_station()`, `ew_runs()` and `ew_attribution()`.
- `ew_explore()` and `ew_explore_page()`: places ranked by a metric
  (`snow_5d`, `base_depth`, `season_precip`, ...), with `order`, `type`,
  `state`, `near`, `radius_km`, elevation bounds, `points` and cursor paging.
- `ew_season()` (observed season to date against normal), `ew_snow_trend()`
  (each recent run's daily snowfall; Plus or Pro), `ew_snowpack()` and
  `ew_snowpack_plume()` (beta), `ew_composition()` (an open route, sent
  without the key), and the GeoJSON routes `ew_alert_outlines()` (`classes`,
  `bbox`) and `ew_avalanche_zones()`, passed through untouched.
- `ew_search()` takes `sort`, `order`, `near`, `radius_km` and `units`; with
  a metric `sort`, each hit carries its `explore_*` value.
- Every field of the v1 schemas, including the pass forecast and place
  summary on current conditions, the avalanche forecast and snow on ground
  on a forecast, daily normals, departures and percentiles, wet-bulb snow
  levels, the members' spread and 6-hour totals, and the NWS fields of an
  alert.
- `ew_client()`: keys from `OUREA_API_KEY`, base URL from `OUREA_BASE_URL`,
  retries per BEHAVIOR 9 (`Retry-After` honoured on 429, 503 and 504), an
  in-memory `ETag` cache (`ew_memory_cache()`, or any cachem-style cache),
  `ew_rate_limit()` and `ew_response_info()`.
- Classed error conditions, one per BEHAVIOR 8 category, with `code`,
  `status`, `request_id`, `doc_url`, `param`, `nearest_location` and
  `retry_after`. `PLUS_REQUIRED` is a permission error.
- Canonical, edge-cacheable request URLs: defaults omitted, parameters
  sorted, comma lists (`sources`, `include`, `class`, ...) sorted,
  de-duplicated and joined by a literal `,`, and `near` and `bbox` built
  from numbers with literal commas.
- `citation("ensembleweather")`.

### Changed (from the never-published draft of 2026-10-27)

- Field names follow spec BEHAVIOR.md 3.0: a JSON field that repeats a word
  of its holder has a package name, mapped by the decoder. A forecast's
  `forecast` is `series` (so the hourly tibble is `$series$timeseries`, not
  `$hourly`), `elevation_forecasts` is `elevations`, current conditions'
  `current` is `now` (with `code`, `text` and `icon`), a probability's
  `probability` is `value`, a window total's `window_*_hours` are
  `start_hours` and `end_hours`, and the rest of the table in the README.
  Probabilities keep `window_start_hours` and `window_end_hours`.
- The coordinate functions follow the operation ids: `ew_forecast_at()` is
  `ew_get_point_forecast()`, `ew_current_at()` is `ew_get_point_current()`,
  `ew_alerts_at()` is `ew_get_point_alerts()` and `ew_nearby_at()` is
  `ew_get_point_nearby()`.
- `precip_*` fields and columns are `precipitation_*`; wind direction is the
  circular distribution (`wind_direction_mean`, `_stddev`,
  `_sector_50_from`/`_to`, `_sector_90_from`/`_to`).
- A location's `elevations` are `ElevationSummary` rows (`name`,
  `display_name`, `height`, `default`).

### Removed (from the draft)

- `ew_storm_reports()` and `ew_storm_report()`: storm reports are not in the
  public API.

[Unreleased]: https://github.com/Ourea-Technologies/ensemble-weather-r/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ourea-Technologies/ensemble-weather-r/releases/tag/v0.1.0
