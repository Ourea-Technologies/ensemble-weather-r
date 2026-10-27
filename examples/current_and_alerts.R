# Current conditions and active alerts for a named location.
library(ensembleweather)

now <- ew_current("or/mt-hood-meadows")
if (!is.null(now$current)) {
  conditions <- now$current
  cat(sprintf(
    "%s: %s, %.1f °C (%s)\n",
    now$location$name, conditions$condition_text, conditions$temperature, conditions$source
  ))
}

alerts <- ew_alerts("or/mt-hood-meadows")
cat(nrow(alerts), "active alerts\n")
for (headline in alerts$headline) cat(" -", headline, "\n")
