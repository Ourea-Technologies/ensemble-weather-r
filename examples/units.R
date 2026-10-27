# The same forecast in metric and imperial. The server converts: values are
# never converted on the client, so ask for the units you want.
library(ensembleweather)

metric <- ew_forecast("or/mt-hood-meadows")
imperial <- ew_forecast("or/mt-hood-meadows", units = "imperial")

cat(sprintf(
  "%s  %5.1f °C  %5.1f °F  (median)\n",
  format(metric$hourly$valid_time, "%H:%M UTC"), metric$hourly$temperature_p50, imperial$hourly$temperature_p50
), sep = "")
