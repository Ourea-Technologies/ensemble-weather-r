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
    nrow(forecast$hourly) > 0 && nrow(forecast$probabilities) == 1 && nrow(forecast$window_totals) == 1
  }),
  check("results echo their term; wind direction is circular", {
    !is.na(forecast$probabilities$term[[1]]) && "wind_direction_sector_50_from" %in% names(forecast$hourly)
  }),
  check("search finds Mt. Hood Meadows", "mt-hood-meadows" %in% ew_search("hood meadows")$slug),
  check("attribution lists providers", nrow(ew_attribution()) > 0),
  check("runs are listed", nrow(ew_runs()) > 0),
  check("current conditions decode", inherits(ew_current("or/mt-hood-meadows"), "ensembleweather_current")),
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
