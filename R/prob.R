variables <- c("precipitation", "snow_level", "snowfall", "temperature", "wind_speed")
amount_variables <- c("precipitation", "snowfall")
aggregations <- c("total", "any", "all")
max_window_hours <- 360L

#' The chance of crossing a threshold
#'
#' `ew_chance()` describes one probability for [ew_forecast()] and
#' [ew_forecast_at()] to ask for: the chance that a variable is at least (or
#' at most) a threshold over a window of hours. The server computes it from
#' the full ensemble; the package never derives a probability itself.
#'
#' A threshold given with a `unit` is converted exactly into the request's
#' units before sending (1 in = 25.4 mm, 1 ft = 0.3048 m, 1 mph = 0.44704 m/s,
#' °F = °C × 9/5 + 32, K = °C + 273.15), then rounded the way the server
#' rounds: half away from zero, to 2 decimals for metric amounts, 3 for
#' imperial amounts, 1 for temperature and wind and 0 for snow level.
#'
#' @param variable One of `"precipitation"`, `"snowfall"`, `"temperature"`,
#'   `"wind_speed"` or `"snow_level"`.
#' @param op `">="` (or `"ge"`) for "at least", `"<="` (or `"le"`) for "at most".
#' @param threshold The threshold, a number.
#' @param unit The threshold's unit: `"mm"`, `"in"`, `"degC"`, `"degF"`,
#'   `"K"`, `"m"`, `"ft"`, `"m/s"` or `"mph"`. `NULL` means it is already in
#'   the request's units.
#' @param window The hours the probability covers, counted from the first
#'   served hour: one number `n` for hours 0 to `n`, or `c(start, end)`. The
#'   default is the next 24 hours; the window may end at most at hour 360.
#' @param aggregation How the hours combine. Precipitation and snowfall are
#'   always the window `"total"`. For the others, `"any"` (the default: the
#'   threshold is crossed in at least one hour) or `"all"` (in every hour).
#' @return An `ensembleweather_chance` object.
#' @seealso [ew_total()] for a window total's distribution.
#' @export
#' @examples
#' # At least 6 inches of snow in the next 24 hours.
#' ew_chance("snowfall", ">=", 6, "in")
#'
#' # At or below freezing in every hour from hour 6 to hour 18.
#' ew_chance("temperature", "<=", 32, "degF", window = c(6, 18), aggregation = "all")
ew_chance <- function(variable, op, threshold, unit = NULL, window = 24, aggregation = NULL) {
  local_user_call()
  variable <- check_choice(variable, variables, "variable")
  op <- check_op(op)
  if (!is.numeric(threshold) || length(threshold) != 1L || !is.finite(threshold)) {
    abort_usage("{.arg threshold} must be one finite number.")
  }
  if (!is.null(unit)) {
    unit <- check_choice(unit, names(unit_kinds), "unit")
    if (unit_kinds[[unit]] != variable_kinds[[variable]]) {
      abort_usage("{.val {variable}} cannot be given in {.val {unit}}.")
    }
  }
  if (!is.null(aggregation)) {
    aggregation <- check_choice(aggregation, aggregations, "aggregation")
    if (variable %in% amount_variables && aggregation != "total") {
      abort_usage(c(
        "{.val {variable}} supports only aggregation {.val total}, not {.val {aggregation}}.",
        i = "A precipitation or snowfall chance is always about the window total."
      ))
    }
    if (!(variable %in% amount_variables) && aggregation == "total") {
      abort_usage("{.val {variable}} supports aggregation {.val any} or {.val all}, not {.val total}.")
    }
  }
  structure(
    list(
      variable = variable,
      op = op,
      threshold = as.double(threshold),
      unit = unit,
      window = check_window(window),
      aggregation = aggregation
    ),
    class = "ensembleweather_chance"
  )
}

#' A window total's distribution
#'
#' `ew_total()` asks [ew_forecast()] for the distribution of each ensemble
#' member's total precipitation or snowfall over a window: the storm total.
#' It is the only storm total the package offers. Never add up hourly
#' quantiles instead: the sum of hourly medians is not the median total.
#'
#' @param variable `"precipitation"` or `"snowfall"`.
#' @inheritParams ew_chance
#' @return An `ensembleweather_total` object.
#' @export
#' @examples
#' # The 0-72 hour snowfall total.
#' ew_total("snowfall", 72)
#'
#' # Precipitation between hours 24 and 48.
#' ew_total("precipitation", c(24, 48))
ew_total <- function(variable, window = 24) {
  local_user_call()
  variable <- check_choice(variable, amount_variables, "variable")
  structure(list(variable = variable, window = check_window(window)), class = "ensembleweather_total")
}

#' @export
format.ensembleweather_chance <- function(x, ...) {
  symbol <- if (x$op == "ge") ">=" else "<="
  unit <- if (is.null(x$unit)) "(request units)" else x$unit
  aggregation <- if (is.null(x$aggregation)) "" else paste0(", ", x$aggregation)
  sprintf(
    "<ensembleweather_chance> P(%s %s %s %s, hours %s%s)",
    x$variable, symbol, format_number(x$threshold), unit, window_label(x$window), aggregation
  )
}

#' @export
print.ensembleweather_chance <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

#' @export
format.ensembleweather_total <- function(x, ...) {
  sprintf("<ensembleweather_total> %s total, hours %s", x$variable, window_label(x$window))
}

#' @export
print.ensembleweather_total <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

window_label <- function(window) paste0(window[[1]], "-", window[[2]])

check_choice <- function(value, choices, arg) {
  if (!is.character(value) || length(value) != 1L || !(value %in% choices)) {
    abort_usage("{.arg {arg}} must be one of {.or {.val {choices}}}, not {.val {value}}.")
  }
  value
}

check_op <- function(op) {
  ops <- c(">=" = "ge", ge = "ge", "<=" = "le", le = "le")
  if (!is.character(op) || length(op) != 1L || !(op %in% names(ops))) {
    abort_usage("{.arg op} must be {.val >=} (or {.val ge}) or {.val <=} (or {.val le}), not {.val {op}}.")
  }
  unname(ops[[op]])
}

check_window <- function(window) {
  whole <- is.numeric(window) && length(window) %in% 1:2 && !anyNA(window)
  if (!whole || any(window != trunc(window))) {
    abort_usage("{.arg window} must be a whole number of hours, or {.code c(start, end)}.")
  }
  bounds <- if (length(window) == 1L) c(0, window) else window
  if (bounds[[1]] < 0 || bounds[[1]] >= bounds[[2]] || bounds[[2]] > max_window_hours) {
    abort_usage("{.arg window} must satisfy 0 <= start < end <= {max_window_hours}.")
  }
  as.integer(bounds)
}

# --- the wire form (BEHAVIOR 4 and 5) ----------------------------------------

as_terms <- function(x, class) {
  if (is.null(x)) {
    return(list())
  }
  if (inherits(x, class)) {
    return(list(x))
  }
  if (is.list(x) && is.null(attr(x, "class")) && all(vapply(x, inherits, TRUE, class))) {
    return(unname(x))
  }
  if (class == "ensembleweather_chance") {
    abort_usage("{.arg prob} must be one {.fn ew_chance} term or a list of them.")
  }
  abort_usage("{.arg totals} must be one {.fn ew_total} or a list of them.")
}

effective_aggregation <- function(chance) {
  chance$aggregation %||% (if (chance$variable %in% amount_variables) "total" else "any")
}

# The identity of a term as the server sees it, in a unit system: two terms
# with the same key are one term on the wire and share a result.
chance_key <- function(chance, units) {
  value <- chance$threshold
  if (!is.null(chance$unit)) {
    value <- convert_threshold(value, chance$unit, request_unit(chance$variable, units))
  }
  list(
    variable = chance$variable,
    op = chance$op,
    threshold = format_rounded(value, threshold_precision(chance$variable, units)),
    start = chance$window[[1]],
    end = chance$window[[2]],
    aggregation = effective_aggregation(chance)
  )
}

key_string <- function(key) paste(unlist(key), collapse = "|")

wire_window <- function(start, end) {
  if (start == 0L) paste0(end, "h") else paste0(start, "-", end, "h")
}

# The canonical `prob=` value (deduplicated, in the server's sort order) and
# each caller term's key, in the caller's order.
prob_query <- function(chances, units) {
  keys <- lapply(chances, chance_key, units = units)
  unique_keys <- keys[!duplicated(vapply(keys, key_string, ""))]
  if (length(unique_keys) == 0L) {
    return(list(wire = "", keys = keys))
  }
  field <- function(name) vapply(unique_keys, function(k) k[[name]], if (name %in% c("start", "end")) 0L else "")
  order <- order(
    field("variable"),
    match(field("op"), c("ge", "le")),
    field("start"),
    field("end"),
    match(field("aggregation"), aggregations),
    as.double(field("threshold")),
    method = "radix"
  )
  wire <- vapply(unique_keys[order], function(k) {
    text <- paste(k$variable, k$op, k$threshold, wire_window(k$start, k$end), sep = ":")
    default <- if (k$variable %in% amount_variables) "total" else "any"
    if (k$aggregation != default) paste0(text, ":", k$aggregation) else text
  }, "")
  list(wire = paste(wire, collapse = ","), keys = keys)
}

total_key <- function(total) {
  list(variable = total$variable, start = total$window[[1]], end = total$window[[2]])
}

totals_query <- function(totals) {
  keys <- lapply(totals, total_key)
  unique_keys <- keys[!duplicated(vapply(keys, key_string, ""))]
  if (length(unique_keys) == 0L) {
    return(list(wire = "", keys = keys))
  }
  order <- order(
    vapply(unique_keys, function(k) k$variable, ""),
    vapply(unique_keys, function(k) k$start, 0L),
    vapply(unique_keys, function(k) k$end, 0L),
    method = "radix"
  )
  wire <- vapply(unique_keys[order], function(k) paste0(k$variable, ":", wire_window(k$start, k$end)), "")
  list(wire = paste(wire, collapse = ","), keys = keys)
}
