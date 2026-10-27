# Catching errors by their class, reading their fields, and reading the
# rate-limit state the server reported.
library(ensembleweather)

# Coordinates outside the forecast domain (CONUS). Without a Pro key the
# server answers PRO_REQUIRED first.
tryCatch(
  ew_forecast_at(45.0, 10.0),
  ensembleweather_error_outside_coverage = function(cnd) cat("outside coverage:", cnd$code, "\n"),
  ensembleweather_error_permission = function(cnd) cat("needs Pro:", cnd$code, "\n")
)

# Every API error carries the status, the code (verbatim) and a request id.
tryCatch(
  ew_forecast("or/no-such-place"),
  ensembleweather_error_not_found = function(cnd) {
    cat(cnd$status, cnd$code, "request id:", if (is.null(cnd$request_id)) "none" else cnd$request_id, "\n")
  },
  ensembleweather_error_rate_limited = function(cnd) cat("rate limited; retry after", cnd$retry_after, "s\n"),
  ensembleweather_error = function(cnd) cat("other error:", conditionMessage(cnd), "\n")
)

# Rate-limit state is what the server reported on the last response. It is
# absent on anonymous responses the edge cache may share between callers.
forecast <- ew_forecast("or/mt-hood-meadows")
limit <- ew_rate_limit(forecast)
if (is.null(limit)) {
  cat("rate limit: not reported on this (edge-cacheable) response\n")
} else {
  cat(sprintf("rate limit: %s of %s left, resets in %s s\n", limit$remaining, limit$limit, limit$reset))
}
