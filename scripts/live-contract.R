# The nightly contract run against the live API (live.yml), with a read-only
# CI key from OUREA_API_KEY. Read-only GETs; never run on pull requests.
#
#   OUREA_API_KEY=... Rscript scripts/live-contract.R

library(ensembleweather)

check <- function(label, ok) {
  cat(if (isTRUE(ok)) "ok   " else "FAIL ", label, "\n", sep = "")
  isTRUE(ok)
}

results <- c(
  check("forecast has an hourly series", {
    forecast <- ew_forecast("or/mt-hood-meadows",
      prob = ew_chance("snowfall", ">=", 6, "in"),
      totals = ew_total("snowfall", 72)
    )
    hours <- forecast$series$timeseries
    nrow(hours) > 0 && nrow(forecast$probabilities) == 1 && nrow(forecast$window_totals) == 1
  }),
  check("results echo their term; wind direction is circular", {
    !is.na(forecast$probabilities$term[[1]]) && "wind_direction_sector_50_from" %in% names(hours)
  }),
  check("the plume view is columns", {
    plume <- ew_forecast("or/mt-hood-meadows", members = "plume", max_hours = 48)$series$plume
    length(plume$headline$valid_time) > 0
  }),
  check("explore ranks and pages", {
    page <- ew_explore_page("snow_5d", limit = 5)
    nrow(page$items) > 0 && !is.na(page$unit)
  }),
  check("search sorts by a metric near a point", {
    hits <- ew_search("mt", sort = "snow_5d", near = c(45.33, -121.66), radius_km = 100)
    "explore_value" %in% names(hits)
  }),
  check("composition lists the served models", ew_composition()$model_count > 0),
  check("season decodes", ew_season("or/mt-hood-meadows", include = "daily")$water_year >= 2027),
  check("snow trend decodes (or needs Plus)", {
    tryCatch(
      nrow(ew_snow_trend("or/mt-hood-meadows")$grids) > 0,
      ensembleweather_error_permission = function(cnd) identical(cnd$code, "PLUS_REQUIRED")
    )
  }),
  check("snowpack is a beta", isTRUE(ew_snowpack("or/mt-hood-meadows")$beta)),
  check("snowpack plume is a beta", isTRUE(ew_snowpack_plume("or/mt-hood-meadows")$beta)),
  check("alert outlines are GeoJSON", identical(ew_alert_outlines()$type, "FeatureCollection")),
  check("avalanche zones are GeoJSON", length(ew_avalanche_zones()$features) > 0),
  check("search finds Mt. Hood Meadows", "mt-hood-meadows" %in% ew_search("hood meadows")$slug),
  check("attribution lists providers", nrow(ew_attribution()) > 0),
  check("runs are listed", nrow(ew_runs()) > 0),
  check("current conditions decode", !is.na(ew_current("or/mt-hood-meadows")$now$measured)),
  check("a pass carries its forecast", !is.null(ew_current("wa/snoqualmie-pass-i-90")$pass)),
  check("alerts decode", inherits(ew_alerts("or/mt-hood-meadows"), "tbl_df")),
  check("catalog first page decodes", inherits(ew_catalog_locations_page(limit = 5)$items, "tbl_df")),
  check("an unknown location is not_found", {
    tryCatch(
      {
        ew_forecast("or/no-such-place-ever")
        FALSE
      },
      ensembleweather_error_not_found = function(cnd) TRUE
    )
  })
)
if (!all(results)) quit(status = 1)
