# ensembleweather (development version)

* Targets the v1 contract as deployed (ensemble-weather-spec 8b85fea).
  Breaking, as 0.x allows.
* The coordinate functions follow the operation ids: `ew_forecast_at()` is
  `ew_get_point_forecast()`, `ew_current_at()` is `ew_get_point_current()`,
  `ew_alerts_at()` is `ew_get_point_alerts()` and `ew_nearby_at()` is
  `ew_get_point_nearby()`. There are no aliases.
* Storm reports are not in the public API: `ew_storm_reports()` and
  `ew_storm_report()` are removed.
* `precip_*` columns are `precipitation_*` (daily `total_precipitation`,
  `precipitation_probability`, `precipitation_type`, ...; hourly
  `precipitation_type_*`; current `precipitation_probability`; sensor
  `precipitation_rate`).
* Wind direction is the circular distribution: `wind_direction_mean`,
  `_stddev` and `_sector_50_from` / `_to`, `_sector_90_from` / `_to`
  replace its quantile columns; `wind_direction_circular_*`, `feels_like_utci*`
  and `ptype` are gone.
* `$probabilities` and `$window_totals` carry the server's `term` (results
  are matched to your terms by it) and `null_reason`; window totals carry
  `aggregation`.
* `ew_forecast()` and `ew_get_point_forecast()` take `include`
  (`"skin_temperature"`, `"mslp"`).
* Errors follow the 16 public codes (`AUTH_UNAVAILABLE` is unavailable;
  `OUTSIDE_COVERAGE` is a 404), carry `doc_url`, `param` and
  `nearest_location`, and read `request_id` from the body first.
  `Retry-After` is honoured on 504 too.
* Comma lists are sent sorted, de-duplicated and joined by a literal `,`;
  `capability` is one list. `ew_runs()` takes `cursor`.

# ensembleweather 0.1.0

* First release: the official R client for the Ourea probabilistic weather
  API (contract v1).
* Forecasts for named locations (`ew_forecast()`) and coordinates
  (`ew_forecast_at()`) as tibbles of quantiles, one row per hour and per day.
* Probabilities with their reference class (`ew_chance()`) and window totals
  (`ew_total()`), computed by the server and returned in your order.
* Current conditions, alerts, nearby locations, search, the location and
  station catalogs (all pages, or page by page), model runs, storm reports
  and attribution.
* Canonical, edge-cacheable request URLs; keyless open routes; an in-memory
  `ETag` cache (or your own, such as `cachem`); retries that follow
  `Retry-After`; classed error conditions; `citation("ensembleweather")`.

Thanks to everyone who reports a bug or sends a pull request: contributors
are credited here by GitHub handle, release by release.
