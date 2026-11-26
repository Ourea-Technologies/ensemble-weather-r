# ensembleweather 0.1.0

* First release: the official R client for the Ourea probabilistic weather
  API (contract v1, ensemble-weather-spec 7954268).
* Forecasts for named locations (`ew_forecast()`) and coordinates
  (`ew_get_point_forecast()`) as tibbles of quantiles, one row per hour and
  per day; `members = "plume"` gives the members in columns.
* Probabilities with their reference class (`ew_chance()`) and window totals
  (`ew_total()`), computed by the server and returned in your order.
* Current conditions (with a mountain pass's forecast and DOT status),
  alerts, nearby locations, search (with metric sorting and `near`), the
  location and station catalogs (all pages, or page by page), model runs,
  the served composition and attribution.
* Places ranked by a metric (`ew_explore()`), the season to date
  (`ew_season()`), the snow trend (`ew_snow_trend()`, Plus or Pro), the
  snowpack forecast and its plume (`ew_snowpack()`, `ew_snowpack_plume()`,
  beta), and GeoJSON alert outlines and avalanche zones.
* Field names follow the spec's BEHAVIOR.md 3.0: a JSON field that repeats
  its holder's word gets a package name (`series`, `now`, `value`, `items`,
  ...); the README lists them all.
* Canonical, edge-cacheable request URLs; keyless open routes; an in-memory
  `ETag` cache (or your own, such as `cachem`); retries that follow
  `Retry-After`; classed error conditions; `citation("ensembleweather")`.

Thanks to everyone who reports a bug or sends a pull request: contributors
are credited here by GitHub handle, release by release.
