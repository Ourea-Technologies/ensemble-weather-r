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
