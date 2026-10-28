#' Ensemble forecast for a location
#'
#' `ew_forecast()` gets the forecast for a named location, such as
#' `"or/mt-hood-meadows"`, and works without an API key. `ew_forecast_at()`
#' gets it for any coordinates (and optionally an elevation), which needs a
#' Pro key.
#'
#' Every value is a distribution computed by the server from the full
#' ensemble. The hourly series has one row per hour and, for each variable,
#' the columns `<variable>_mean`, `_p10`, `_p25`, `_p50`, `_p75`, `_p90` and,
#' `_min` and `_max`. The p50 column is the median, not "the forecast".
#' Wind direction is the circular distribution instead: `wind_direction_mean`,
#' `_stddev`, and the sectors `wind_direction_sector_50_from` / `_to` and
#' `wind_direction_sector_90_from` / `_to`, each running clockwise from `from`
#' to `to`, so `to` may be numerically less than `from` (it crosses north);
#' it is passed through as served.
#'
#' Values are in the request's units: metric is °C, mm, m/s and m; imperial
#' is °F, in, mph and ft; kelvin is metric with K. They are never converted
#' on the client: to get other units, ask for them with `units`.
#'
#' @param location A named location: `"state/slug"` (for example
#'   `"or/mt-hood-meadows"`), or a one-row data frame or list with `state` and
#'   `slug`, such as a row of [ew_search()].
#' @param ... These dots are for future extensions and must be empty.
#' @param units `"metric"`, `"imperial"` or `"kelvin"`. `NULL` uses the
#'   client's units.
#' @param prob Probabilities to ask for: one [ew_chance()] term or a list of
#'   them. The answers come back in `$probabilities`, in your order.
#' @param totals Window totals to ask for: one [ew_total()] or a list of them.
#'   The answers come back in `$window_totals`, in your order.
#' @param max_hours How many hours to serve (6 to 360; default 24).
#' @param include_past Include the hours since the run's start.
#' @param models Include each model's own statistics (`model_means`).
#' @param members Include every member's values (`members`), for plumes.
#' @param elevations Names of the location's elevation points to forecast too
#'   (for example `c("base", "summit")`); see `$elevation_forecasts`.
#' @param daily Include daily summaries (default `TRUE`).
#' @param max_days How many days of daily summaries to serve (1 to 15).
#' @param hourly Include the hourly series (default `TRUE`).
#' @param run A past model run to read (a `POSIXct` or an ISO 8601 string);
#'   see [ew_runs()].
#' @param sources,exclude_sources Character vectors of model sources to use or
#'   leave out.
#' @param nowcast Apply the observation nowcast to the first hours (default
#'   `TRUE`).
#' @param diagnostics Character vector of diagnostic blocks to include
#'   (`"provenance"`).
#' @param include Character vector of opt-in variables: `"skin_temperature"`,
#'   `"mslp"` (served only when asked for).
#' @param feels_like The feels-like index (`"nws"`, the default and only one).
#' @param client A client from [ew_client()]; `NULL` uses the shared default
#'   client.
#' @return An `ensembleweather_forecast`: a list with
#'   * `location`, `model_run` (with a `models` tibble) and `units`;
#'   * `hourly`: a tibble, one row per hour (`NULL` with `hourly = FALSE`);
#'   * `daily`: a tibble, one row per day (`NULL` with `daily = FALSE`);
#'   * `probabilities`: when you asked with `prob`, a tibble with the
#'     canonical `term` the server echoes (each answer is matched to your
#'     term by it), the reference class of each answer (`variable`, `op`,
#'     `threshold`, `unit`, `window_start`, `window_end`, `aggregation`,
#'     `from`, `to`, `members`) and its `probability`, which is `NA` (never 0)
#'     when it cannot be answered, with the reason in `null_reason`
#'     (`"window_not_covered"`, `"too_few_members"`, `"variable_unavailable"`);
#'   * `window_totals`: when you asked with `totals`, a tibble of each
#'     window's `term`, `aggregation` and distribution (`mean`, `p10` ...
#'     `p90`, `min`, `max`, all `NA` when it cannot be answered, with the
#'     reason in `null_reason`);
#'   * `snow_outlook`, `elevation_forecasts`, `nearest_sensors`, `point`,
#'     `current`, `thresholds`, `applied`, `attribution` and the other fields
#'     of the API's `ForecastResponse`, when served.
#'
#'   [tibble::as_tibble()] on it gives the hourly series. Use
#'   [ew_response_info()] and [ew_rate_limit()] for the HTTP details.
#' @seealso [ew_chance()], [ew_total()], [ew_current()].
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' forecast <- ew_forecast(
#'   "or/mt-hood-meadows",
#'   units = "imperial",
#'   prob = ew_chance("snowfall", ">=", 6, "in"),
#'   totals = ew_total("snowfall", 72)
#' )
#' forecast$hourly[, c("valid_time", "temperature_p10", "temperature_p90")]
#' forecast$probabilities
#' forecast$window_totals
ew_forecast <- function(location,
                        ...,
                        units = NULL,
                        prob = NULL,
                        totals = NULL,
                        max_hours = NULL,
                        include_past = NULL,
                        models = NULL,
                        members = NULL,
                        elevations = NULL,
                        daily = NULL,
                        max_days = NULL,
                        hourly = NULL,
                        run = NULL,
                        sources = NULL,
                        exclude_sources = NULL,
                        nowcast = NULL,
                        diagnostics = NULL,
                        include = NULL,
                        feels_like = NULL,
                        client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- query_add_list(new_query(), "elevations", elevations)
  forecast_request(
    client, "getLocationForecast", location_path(location), query,
    units = units, prob = prob, totals = totals, max_hours = max_hours,
    include_past = include_past, models = models, members = members, daily = daily,
    max_days = max_days, hourly = hourly, run = run, sources = sources,
    exclude_sources = exclude_sources, nowcast = nowcast, diagnostics = diagnostics,
    include = include, feels_like = feels_like
  )
}

#' @rdname ew_forecast
#' @param lat,lon Latitude and longitude in decimal degrees, sent exactly as
#'   given.
#' @param elevation_m The elevation to forecast at, in metres (-500 to 9000).
#'   `NULL` uses the terrain elevation.
#' @export
ew_forecast_at <- function(lat,
                           lon,
                           ...,
                           elevation_m = NULL,
                           units = NULL,
                           prob = NULL,
                           totals = NULL,
                           max_hours = NULL,
                           include_past = NULL,
                           models = NULL,
                           members = NULL,
                           daily = NULL,
                           max_days = NULL,
                           hourly = NULL,
                           run = NULL,
                           sources = NULL,
                           exclude_sources = NULL,
                           nowcast = NULL,
                           diagnostics = NULL,
                           include = NULL,
                           feels_like = NULL,
                           client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- coordinates_query(lat, lon)
  if (!is.null(elevation_m)) {
    check_number(elevation_m, "elevation_m")
  }
  query <- query_add(query, "elevation_m", elevation_m)
  forecast_request(
    client, "getPointForecast", "/api/v1/forecast", query,
    units = units, prob = prob, totals = totals, max_hours = max_hours,
    include_past = include_past, models = models, members = members, daily = daily,
    max_days = max_days, hourly = hourly, run = run, sources = sources,
    exclude_sources = exclude_sources, nowcast = nowcast, diagnostics = diagnostics,
    include = include, feels_like = feels_like
  )
}

forecast_request <- function(client, name, path, query, units, prob, totals, max_hours,
                             include_past, models, members, daily, max_days, hourly, run,
                             sources, exclude_sources, nowcast, diagnostics, include, feels_like) {
  units <- check_units(units %||% client$units)
  chances <- as_terms(prob, "ensembleweather_chance")
  wanted <- as_terms(totals, "ensembleweather_total")
  for (arg in list(
    list("include_past", include_past), list("models", models), list("members", members),
    list("daily", daily), list("hourly", hourly), list("nowcast", nowcast)
  )) {
    check_flag(arg[[2]], arg[[1]])
  }
  check_count(max_hours, "max_hours")
  check_count(max_days, "max_days")
  query <- query_add(query, "units", units, "metric")
  query <- query_add(query, "max_hours", max_hours, 24)
  query <- query_add(query, "include_past", include_past, FALSE)
  query <- query_add(query, "models", models, FALSE)
  query <- query_add(query, "members", members, FALSE)
  query <- query_add(query, "daily", daily, TRUE)
  query <- query_add(query, "max_days", max_days)
  query <- query_add(query, "hourly", hourly, TRUE)
  query <- query_add(query, "run", if (!is.null(run)) format_datetime(run))
  query <- query_add_list(query, "sources", sources)
  query <- query_add_list(query, "exclude_sources", exclude_sources)
  query <- query_add(query, "nowcast", nowcast, TRUE)
  query <- query_add_list(query, "diagnostics", diagnostics)
  query <- query_add_list(query, "include", include)
  query <- query_add_list(query, "feels_like", feels_like, "nws")
  prob_wire <- prob_query(chances, units)
  totals_wire <- totals_query(wanted)
  query <- query_add_raw(query, "prob", prob_wire$wire)
  query <- query_add_raw(query, "totals", totals_wire$wire)

  response <- perform(client, new_operation(name, path, query))
  forecast <- new_forecast(response$data, units, prob_wire$terms, totals_wire$terms)
  with_meta(forecast, response$meta)
}

new_forecast <- function(data, units, chance_terms, total_terms) {
  body <- decode_object(data, "ForecastResponse")
  forecast <- body$forecast
  structure(
    list(
      location = body$location,
      units = body$units,
      model_run = body$model_run,
      max_hours = forecast$max_hours,
      interval_hours = forecast$interval_hours,
      hourly = forecast$timeseries,
      daily = forecast$daily,
      snow_outlook = forecast$snow_outlook,
      probabilities = answer_probabilities(body$probabilities, units, chance_terms),
      window_totals = answer_totals(body$window_totals, units, total_terms),
      elevation_forecasts = body$elevation_forecasts,
      nowcast_applied = body$nowcast_applied,
      nowcast_unavailable = body$nowcast_unavailable,
      members_view = body$members_view,
      gap_flow = body$gap_flow,
      nearest_sensors = body$nearest_sensors,
      point = body$point,
      current = body$current,
      thresholds = body$thresholds,
      applied = body$applied,
      attribution = body$attribution
    ),
    class = "ensembleweather_forecast"
  )
}

# Put the server's answers (in the order sent) back in the caller's order by
# the canonical `term` each one echoes, never by position (BEHAVIOR 4, 5),
# labelled with their units. An absent list stays absent; a present list
# without an answer for one of the caller's terms is an error.
match_terms <- function(results, terms, what) {
  index <- match(terms, results$term)
  if (anyNA(index)) {
    abort_unexpected(paste0(
      "The API's response has no answer for the ", what, " ", terms[[which(is.na(index))[[1]]]], "."
    ))
  }
  index
}

answer_probabilities <- function(results, units, terms) {
  if (is.null(results)) {
    return(NULL)
  }
  if (length(terms) > 0L) {
    results <- results[match_terms(results, terms, "term"), ]
  }
  units_of <- vapply(results$variable, function(v) {
    if (v %in% names(variable_kinds)) request_unit(v, units) else NA_character_
  }, "", USE.NAMES = FALSE)
  tibble::tibble(
    term = results$term,
    variable = results$variable,
    op = results$op,
    threshold = results$threshold,
    unit = units_of,
    window_start = results$window_start_hours,
    window_end = results$window_end_hours,
    aggregation = results$aggregation,
    from = results$from,
    to = results$to,
    members = results$members,
    probability = results$probability,
    null_reason = results$null_reason
  )
}

answer_totals <- function(results, units, terms) {
  if (is.null(results)) {
    return(NULL)
  }
  if (length(terms) > 0L) {
    results <- results[match_terms(results, terms, "window total"), ]
  }
  unit <- vapply(results$variable, function(v) {
    if (v %in% amount_variables) request_unit(v, units) else NA_character_
  }, "", USE.NAMES = FALSE)
  tibble::tibble(
    term = results$term,
    variable = results$variable,
    unit = unit,
    window_start = results$window_start_hours,
    window_end = results$window_end_hours,
    aggregation = results$aggregation,
    from = results$from,
    to = results$to,
    members = results$members,
    null_reason = results$null_reason,
    mean = results$quantiles_mean,
    p10 = results$quantiles_p10,
    p25 = results$quantiles_p25,
    p50 = results$quantiles_p50,
    p75 = results$quantiles_p75,
    p90 = results$quantiles_p90,
    min = results$quantiles_min,
    max = results$quantiles_max
  )
}

#' @export
format.ensembleweather_forecast <- function(x, ...) {
  hours <- if (is.null(x$hourly)) 0L else nrow(x$hourly)
  days <- if (is.null(x$daily)) 0L else nrow(x$daily)
  lines <- c(
    paste0("<ensembleweather_forecast> ", x$location$name, " (", x$location$state, "/", x$location$slug, ")"),
    paste0(
      "  run ", format(x$model_run$initialized_at, "%Y-%m-%d %H:%M UTC"), ", ",
      x$model_run$total_members, " members, ", x$units, " units"
    ),
    paste0("  ", hours, " hours in $hourly, ", days, " days in $daily")
  )
  if (!is.null(x$probabilities)) {
    lines <- c(lines, paste0("  ", nrow(x$probabilities), " probabilities in $probabilities"))
  }
  if (!is.null(x$window_totals)) {
    lines <- c(lines, paste0("  ", nrow(x$window_totals), " window totals in $window_totals"))
  }
  lines
}

#' @export
print.ensembleweather_forecast <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' @importFrom tibble as_tibble
#' @export
as_tibble.ensembleweather_forecast <- function(x, ...) {
  x$hourly %||% tibble::tibble()
}

# --- arguments shared by several operations ------------------------------------

# A named location's path: "/api/v1/locations/<state>/<slug>", both encoded.
location_path <- function(location, suffix = "") {
  if (is.character(location) && length(location) == 1L && !is.na(location)) {
    parts <- strsplit(location, "/", fixed = TRUE)[[1]]
    if (length(parts) != 2L || !all(nzchar(parts)) || lengths(regmatches(location, gregexpr("/", location))) != 1L) {
      abort_usage(c(
        "{.arg location} must be {.val state/slug}, for example {.val or/mt-hood-meadows}.",
        x = "Got {.val {location}}."
      ))
    }
    state <- parts[[1]]
    slug <- parts[[2]]
  } else if (is.list(location) && all(c("state", "slug") %in% names(location))) {
    if (is.data.frame(location) && nrow(location) != 1L) {
      abort_usage("{.arg location} must be one row, not {nrow(location)}.")
    }
    state <- location$state[[1]]
    slug <- location$slug[[1]]
  } else {
    abort_usage("{.arg location} must be {.val state/slug} or have {.field state} and {.field slug}.")
  }
  paste0(
    "/api/v1/locations/", encode_component(canonical_state(state)), "/",
    encode_component(check_nonempty(slug, "slug")), suffix
  )
}

# Lowercase a two-letter USPS code; pass anything else through (the server
# answers a state name with a redirect).
canonical_state <- function(state) {
  state <- check_nonempty(state, "state")
  if (grepl("^[A-Za-z]{2}$", state)) tolower(state) else state
}

check_nonempty <- function(value, arg) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    abort_usage("{.arg {arg}} must be a non-empty string.")
  }
  value
}

coordinates_query <- function(lat, lon) {
  check_number(lat, "lat", 90)
  check_number(lon, "lon", 180)
  query <- query_add(new_query(), "lat", lat)
  query_add(query, "lon", lon)
}

check_number <- function(value, arg, bound = Inf) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) || abs(value) > bound) {
    if (is.finite(bound)) {
      abort_usage("{.arg {arg}} must be a number between -{bound} and {bound}.")
    }
    abort_usage("{.arg {arg}} must be one finite number.")
  }
  invisible(value)
}

check_flag <- function(value, arg) {
  if (!is.null(value) && !is_flag(value)) {
    abort_usage("{.arg {arg}} must be {.code TRUE}, {.code FALSE} or {.code NULL}.")
  }
  invisible(value)
}

check_count <- function(value, arg) {
  if (!is.null(value) && (!is_whole_number(value) || value < 1)) {
    abort_usage("{.arg {arg}} must be a positive whole number.")
  }
  invisible(value)
}

is_flag <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)

is_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

is_whole_number <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x) && x == trunc(x)
}
