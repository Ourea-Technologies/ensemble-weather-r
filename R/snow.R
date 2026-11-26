#' Season to date
#'
#' The observed precipitation of a location's water year so far, against its
#' normal, from the nearest gauge.
#'
#' @inheritParams ew_forecast
#' @param water_year The water year by its ending year (`2027` is 1 October
#'   2026 to 30 September 2027). `NULL` is the one in progress.
#' @param include `"daily"` to add one row per observed local day
#'   (`$daily`).
#' @return The API's `SeasonResponse` as a list: `location`, `water_year`,
#'   `starts`, `through`, `as_of`, `units`, `precipitation` and `snowfall`
#'   (each `NULL`, or a season total whose `amount` is JSON `total`, with
#'   `unit`, `normal_to_date` and `percent_of_normal`), `station` (the gauge,
#'   or `NULL`), `daily` (a tibble, with `include = "daily"`) and
#'   `attribution`.
#' @family snow
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' season <- ew_season("or/mt-hood-meadows", include = "daily")
#' season$precipitation$percent_of_normal
ew_season <- function(location, ..., water_year = NULL, include = NULL, units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  if (!is.null(water_year) && !is_whole_number(water_year)) {
    abort_usage("{.arg water_year} must be a whole number, such as {.val {2027}}.")
  }
  query <- query_add(new_query(), "water_year", water_year)
  query <- query_add_list(query, "include", include)
  query <- query_add(query, "units", check_units(units %||% client$units), "metric")
  location_request(client, "getLocationSeason", location, "/season", query, "SeasonResponse")
}

#' Snow trend: each recent run's daily snowfall
#'
#' How the forecast of daily snowfall has changed run by run: for Ourea's own
#' forecast and for each model, every recent run's snowfall for each local
#' day. This route needs a Plus or Pro key; anonymous and Free callers get an
#' `ensembleweather_error_permission` (`PLUS_REQUIRED`).
#'
#' @inheritParams ew_forecast
#' @param elevation One of the location's named elevations (the `name` of an
#'   entry of a forecast's `location$elevations`). `NULL` is the location's
#'   own point.
#' @return The API's `SnowTrendResponse` as a list: `location`, `units`,
#'   `elevation` (its `height` is JSON `elevation`), `retention_days`, `dates`
#'   (the local days), and `grids`, a tibble with one row per source (`ourea`
#'   or a model id) whose `runs` list-column holds a tibble of runs, oldest
#'   first. A run's `days` is a tibble aligned to `dates`: `amount` (JSON
#'   `snow`), `p10`, `p90`, `partial` and `kind`, all `NA` where the run has
#'   no value.
#' @family snow
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' trend <- ew_snow_trend("or/mt-hood-meadows", units = "imperial")
#' trend$grids$runs[[1]]
ew_snow_trend <- function(location, ..., elevation = NULL, units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- query_add(new_query(), "elevation", optional_string(elevation, "elevation"))
  query <- query_add(query, "units", check_units(units %||% client$units), "metric")
  location_request(client, "getLocationSnowTrend", location, "/snow-trend", query, "SnowTrendResponse")
}

#' Snowpack forecast (beta)
#'
#' `ew_snowpack()` gets the modelled snowpack at a location's spots (its own
#' point, then its named elevations): depth, new snow, surface and layers,
#' with each aspect's slope where served. `ew_snowpack_plume()` gets the
#' spread of snow depth over the forecast's members. Both are a beta: the
#' body carries `beta = TRUE`, and fields may be added.
#'
#' @inheritParams ew_forecast
#' @return `ew_snowpack()`: the API's `SnowpackResponse` as a list: `beta`,
#'   `location`, `units`, `model_run`, `stale`, `spots` (a tibble, one row
#'   per spot, with `depth`, `steps`, `layers` and `aspects` list-columns)
#'   and `definitions` (named lists of what each `surface` and `layer_form`
#'   code means).
#'   `ew_snowpack_plume()`: the API's `SnowpackPlumeResponse` as a list:
#'   `beta`, `location`, `units`, `model_run`, `stale`, `depth` (the
#'   members' depth statistics, each a vector from `start_time` every
#'   `interval_hours`), `models` (a tibble), `member_depths` and `spread`.
#' @family snow
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' snowpack <- ew_snowpack("or/mt-hood-meadows")
#' snowpack$spots$depth[[1]]$p50
#' plume <- ew_snowpack_plume("or/mt-hood-meadows")
#' plume$depth$p50
ew_snowpack <- function(location, ..., units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- query_add(new_query(), "units", check_units(units %||% client$units), "metric")
  location_request(client, "getLocationSnowpack", location, "/snowpack", query, "SnowpackResponse")
}

#' @rdname ew_snowpack
#' @export
ew_snowpack_plume <- function(location, ..., units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- query_add(new_query(), "units", check_units(units %||% client$units), "metric")
  location_request(
    client, "getLocationSnowpackPlume", location, "/snowpack/plume", query, "SnowpackPlumeResponse"
  )
}

# GET a named location's subroute and decode its body as `schema`.
location_request <- function(client, name, location, suffix, query, schema) {
  response <- perform(client, new_operation(name, location_path(location, suffix), query))
  with_meta(decode_object(response$data, schema), response$meta)
}
