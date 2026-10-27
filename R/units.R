# Units for the caller's threshold input (BEHAVIOR 4 and 7).
#
# Only the caller's input is converted, with the exact factors below.
# Response values are never converted: to get other units, ask the server.

unit_systems <- c("metric", "imperial", "kelvin")

# The kind of quantity each unit measures, and each variable is.
unit_kinds <- c(
  mm = "depth", `in` = "depth",
  degC = "temperature", degF = "temperature", K = "temperature",
  m = "height", ft = "height",
  `m/s` = "speed", mph = "speed"
)

variable_kinds <- c(
  precipitation = "depth", snowfall = "depth",
  temperature = "temperature", snow_level = "height", wind_speed = "speed"
)

# The unit the server reads a threshold in, per unit system and kind.
system_units <- list(
  metric = c(depth = "mm", temperature = "degC", height = "m", speed = "m/s"),
  imperial = c(depth = "in", temperature = "degF", height = "ft", speed = "mph"),
  kelvin = c(depth = "mm", temperature = "K", height = "m", speed = "m/s")
)

# Exact factors to the metric unit of each kind.
to_metric <- c(`in` = 25.4, ft = 0.3048, mph = 0.44704)

check_units <- function(units, arg = "units") {
  if (!is.character(units) || length(units) != 1L || !(units %in% unit_systems)) {
    abort_usage("{.arg {arg}} must be one of {.or {.val {unit_systems}}}, not {.val {units}}.")
  }
  units
}

# The unit a variable's threshold is read in, for a unit system.
request_unit <- function(variable, units) {
  unname(system_units[[units]][[variable_kinds[[variable]]]])
}

# Convert a caller's threshold between two units of the same kind.
convert_threshold <- function(value, from, to) {
  if (identical(from, to)) {
    return(value)
  }
  if (unit_kinds[[from]] == "temperature") {
    celsius <- switch(from,
      degF = (value - 32) * 5 / 9,
      K = value - 273.15,
      value
    )
    return(switch(to,
      degF = celsius * 9 / 5 + 32,
      K = celsius + 273.15,
      celsius
    ))
  }
  metric <- value * (if (from %in% names(to_metric)) to_metric[[from]] else 1)
  metric / (if (to %in% names(to_metric)) to_metric[[to]] else 1)
}

# The number of decimals the server serves a variable at.
threshold_precision <- function(variable, units) {
  if (variable %in% c("precipitation", "snowfall")) {
    return(if (units == "imperial") 3L else 2L)
  }
  if (variable == "snow_level") {
    return(0L)
  }
  1L
}

# Round half away from zero on value * 10^digits, in doubles, and print the
# result with exactly `digits` decimals.
#
# This is the server's own rounding: 0.0625 at 3 decimals is "0.063" (base
# R's round() goes to even and would give 0.062), and 1.005 at 2 decimals is
# "1.00" because 1.005 * 100 is 100.4999... in doubles. A negative zero
# prints as "0".
format_rounded <- function(value, digits) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
    abort_usage("A threshold must be one finite number, not {.val {value}}.")
  }
  scaled <- as.double(value) * 10^digits
  whole <- trunc(scaled)
  if (abs(scaled - whole) >= 0.5) {
    whole <- whole + sign(scaled)
  }
  magnitude <- sprintf("%.0f", abs(whole))
  sign <- if (whole < 0) "-" else ""
  if (digits == 0L) {
    return(paste0(sign, magnitude))
  }
  if (nchar(magnitude) <= digits) {
    magnitude <- paste0(strrep("0", digits + 1L - nchar(magnitude)), magnitude)
  }
  cut <- nchar(magnitude) - digits
  paste0(sign, substr(magnitude, 1L, cut), ".", substr(magnitude, cut + 1L, nchar(magnitude)))
}
