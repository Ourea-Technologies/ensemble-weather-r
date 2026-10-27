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
