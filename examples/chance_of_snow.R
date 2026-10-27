# Several probabilities in one call, each with its window and member count.
# The server computes every probability from the full ensemble; the answers
# come back in the order you asked, with their reference class.
library(ensembleweather)

terms <- list(
  ew_chance("snowfall", ">=", 6, "in"), # the next 24 h
  ew_chance("snowfall", ">=", 12, "in", window = 72), # hours 0-72
  ew_chance("temperature", "<=", 32, "degF", window = c(6, 18), aggregation = "all"),
  ew_chance("wind_speed", ">=", 40, "mph", window = 48)
)
forecast <- ew_forecast("or/mt-hood-meadows", units = "imperial", prob = terms)

p <- forecast$probabilities
print(p[, c("variable", "op", "threshold", "unit", "window_start", "window_end", "members", "probability")])
