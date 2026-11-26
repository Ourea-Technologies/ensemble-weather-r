# Where is the snow? Rank Oregon's ski areas by the forecast's new snow over
# the next five days (each value with its p10-p90 range), then read the
# leader's observed season to date against normal.
library(ensembleweather)

ranking <- ew_explore_page("snow_5d", state = "or", type = "ski_area", units = "imperial", limit = 5)
items <- ranking$items
cat(sprintf("Most new snow in the next 5 days (%s):\n", ranking$unit))
cat(sprintf(
  "%2d. %-28s %5.1f (%.1f to %.1f)\n",
  items$rank, items$location_name, items$value, items$p10, items$p90
), sep = "")

leader <- list(state = items$location_state[[1]], slug = items$location_slug[[1]])
season <- ew_season(leader, units = "imperial")
total <- season$precipitation
if (is.null(total)) {
  cat("No observed season yet at", season$location$name, "\n")
} else {
  cat(sprintf(
    "%s, water year %d: %.2f %s of precipitation, %d%% of normal\n",
    season$location$name, season$water_year, total$amount, total$unit, total$percent_of_normal
  ))
}
