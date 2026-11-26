# Current conditions and active alerts for a named location.
library(ensembleweather)

now <- ew_current("or/mt-hood-meadows")
if (!is.null(now$now)) {
  conditions <- now$now
  cat(sprintf(
    "%s: %s, %.1f °C (%s)\n",
    now$location$name, conditions$text, conditions$temperature, conditions$source
  ))
}

alerts <- ew_alerts("or/mt-hood-meadows")
cat(nrow(alerts), "active alerts\n")
for (i in seq_len(nrow(alerts))) {
  cat(" -", alerts$headline[[i]], paste0("(", alerts$severity[[i]], ", ", alerts$certainty[[i]], ")"), "\n")
}
