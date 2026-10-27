# A forecast at coordinates and an elevation: a Pro feature, so it reads a
# Pro key from OUREA_API_KEY (and says so, then exits, without one).
library(ensembleweather)

if (!nzchar(Sys.getenv("OUREA_API_KEY"))) {
  cat("point_forecast needs a Pro key in OUREA_API_KEY; skipping.\n")
  quit(status = 0)
}

forecast <- ew_forecast_at(45.3311, -121.6649, elevation_m = 1661, max_hours = 48)
hours <- forecast$hourly
cat(sprintf("Forecast at %s (%s m), %d hours\n", forecast$location$name, forecast$location$elevation_m, nrow(hours)))
print(hours[, c("valid_time", "temperature_p10", "temperature_p50", "temperature_p90")])
