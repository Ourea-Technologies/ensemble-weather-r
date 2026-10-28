# Window totals: the distribution of each member's total precipitation and
# snowfall over a window. This is the storm total; never add up hourly
# quantiles instead (the sum of hourly medians is not the median total).
library(ensembleweather)

forecast <- ew_forecast(
  "or/mt-hood-meadows",
  totals = list(ew_total("snowfall", 72), ew_total("precipitation", c(24, 48)))
)

totals <- forecast$window_totals
for (i in seq_len(nrow(totals))) {
  row <- totals[i, ]
  range <- if (is.na(row$p10)) {
    paste("no distribution:", row$null_reason)
  } else {
    sprintf("%.0f to %.0f %s (p10-p90), median %.0f", row$p10, row$p90, row$unit, row$p50)
  }
  cat(sprintf("%s, hours %d-%d: %s\n", row$variable, row$window_start, row$window_end, range))
}
