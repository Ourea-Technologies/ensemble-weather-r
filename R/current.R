#' Current conditions
#'
#' `ew_current()` gets the current conditions at a named location, and
#' `ew_get_point_current()` at any coordinates (a Pro key). The conditions
#' blend the nearest surface stations with the observation nowcast; the active
#' alerts and the readings of nearby stations come with them.
#'
#' @inheritParams ew_forecast
#' @param include_nowcast_hours Also return the nowcast's hourly series
#'   (`$nowcast_hours`).
#' @return An `ensembleweather_current`: a list with `location`, `current`
#'   (the conditions, or `NULL` when none are available), `alerts` and
#'   `sensors` (tibbles), `nowcast_hours` (a tibble shaped like a forecast's
#'   `$hourly`, or `NULL`), `as_of`, `alerts_as_of`,
#'   `model_run_initialized_at`, `sensor_count`, `units`, `attribution` and
#'   `nowcast_unavailable`.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' now <- ew_current("or/mt-hood-meadows")
#' now$current$temperature
#' now$alerts
ew_current <- function(location,
                       ...,
                       units = NULL,
                       sources = NULL,
                       exclude_sources = NULL,
                       include_nowcast_hours = FALSE,
                       client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  current_request(
    client, "getCurrentConditions", location_path(location, "/current"), new_query(),
    units, sources, exclude_sources, include_nowcast_hours
  )
}

#' @rdname ew_current
#' @inheritParams ew_get_point_forecast
#' @export
ew_get_point_current <- function(lat,
                                 lon,
                                 ...,
                                 elevation_m = NULL,
                                 units = NULL,
                                 sources = NULL,
                                 exclude_sources = NULL,
                                 include_nowcast_hours = FALSE,
                                 client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- coordinates_query(lat, lon)
  if (!is.null(elevation_m)) {
    check_number(elevation_m, "elevation_m")
  }
  query <- query_add(query, "elevation_m", elevation_m)
  current_request(
    client, "getCurrentByCoordinates", "/api/v1/current", query,
    units, sources, exclude_sources, include_nowcast_hours
  )
}

current_request <- function(client, name, path, query, units, sources, exclude_sources,
                            include_nowcast_hours) {
  check_flag(include_nowcast_hours, "include_nowcast_hours")
  query <- query_add(query, "units", check_units(units %||% client$units), "metric")
  query <- query_add_list(query, "sources", sources)
  query <- query_add_list(query, "exclude_sources", exclude_sources)
  if (isTRUE(include_nowcast_hours)) {
    query <- query_add(query, "include", "nowcast_hours")
  }
  response <- perform(client, new_operation(name, path, query))
  body <- decode_object(response$data, "CurrentResponse")
  with_meta(structure(body, class = "ensembleweather_current"), response$meta)
}

#' @export
print.ensembleweather_current <- function(x, ...) {
  cat("<ensembleweather_current> ", x$location$name, " as of ",
    format(x$as_of, "%Y-%m-%d %H:%M UTC"), "\n",
    sep = ""
  )
  if (!is.null(x$current)) {
    cat("  ", x$current$condition_text, ", temperature ", format_number(x$current$temperature),
      " (", x$units, ")\n",
      sep = ""
    )
  }
  cat("  ", nrow(x$alerts), " active alerts, ", nrow(x$sensors), " nearby sensors\n", sep = "")
  invisible(x)
}

#' Active weather alerts
#'
#' `ew_alerts()` lists the active alerts (watches, warnings and advisories)
#' for a named location, and `ew_get_point_alerts()` for any coordinates (a
#' Pro key).
#'
#' @inheritParams ew_forecast
#' @inheritParams ew_get_point_forecast
#' @return A tibble with one row per alert: `id`, `event`, `severity`,
#'   `urgency`, `headline`, `onset`, `expires` and `ends`. Its attributes
#'   `location`, `as_of` and `attribution` hold the rest of the response.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' ew_alerts("or/mt-hood-meadows")
ew_alerts <- function(location, ..., client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  alerts_request(client, "getLocationAlerts", location_path(location, "/alerts"), new_query())
}

#' @rdname ew_alerts
#' @export
ew_get_point_alerts <- function(lat, lon, ..., client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  alerts_request(client, "getAlertsByCoordinates", "/api/v1/alerts", coordinates_query(lat, lon))
}

alerts_request <- function(client, name, path, query) {
  response <- perform(client, new_operation(name, path, query))
  body <- decode_object(response$data, "AlertsResponse")
  alerts <- body$alerts
  attr(alerts, "location") <- body$location
  attr(alerts, "as_of") <- body$as_of
  attr(alerts, "attribution") <- body$attribution
  with_meta(alerts, response$meta)
}
