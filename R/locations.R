#' Search for locations
#'
#' Finds named locations by name, for example `"hood meadows"` or
#' `"boston ma"`. Search is an open route: it is sent without the API key, so
#' the answer can come from the API's shared edge cache.
#'
#' @param q The text to search for (at least 2 characters).
#' @inheritParams ew_forecast
#' @param state Limit to one state (USPS code, such as `"or"`).
#' @param county Limit to one county.
#' @param type Limit to one location type, such as `"ski_area"`.
#' @param limit The most results to return (1 to 100; default 20).
#' @return A tibble with one row per hit: `key` (`"state/slug"`), `slug`,
#'   `state`, `name`, `lat`, `lon`, `elevation_m`, `type`, `timezone` and
#'   `county`. A row can be passed straight to [ew_forecast()].
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' hits <- ew_search("hood meadows")
#' hits
#' ew_forecast(hits[1, ])
ew_search <- function(q, ..., state = NULL, county = NULL, type = NULL, limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  q <- check_nonempty(q, "q")
  if (nchar(trimws(q)) < 2L) {
    abort_usage("{.arg q} needs at least 2 characters.")
  }
  check_count(limit, "limit")
  query <- query_add(new_query(), "q", q)
  query <- query_add(query, "state", if (!is.null(state)) canonical_state(state))
  query <- query_add(query, "county", county)
  query <- query_add(query, "type", type)
  query <- query_add(query, "limit", limit, 20)
  operation <- new_operation("searchLocations", "/api/v1/search/locations", query, open_route = TRUE)
  response <- perform(client, operation)
  body <- decode_object(response$data, "SearchLocationsResponse")
  with_meta(body$items, response$meta)
}

#' Nearby locations
#'
#' `ew_nearby()` lists the named locations near a named location, and
#' `ew_nearby_at()` near any coordinates.
#'
#' @inheritParams ew_forecast
#' @inheritParams ew_forecast_at
#' @param limit The most locations to return (1 to 20; default 3).
#' @param radius_km The search radius in kilometres (at most 100; default 50).
#' @return A tibble with one row per location, nearest first, including
#'   `distance_km`. Its attributes hold the rest of the response: `origin`
#'   (the location searched around) or `lat`/`lon`, and `radius_km`.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' ew_nearby("or/mt-hood-meadows", limit = 5)
ew_nearby <- function(location, ..., limit = NULL, radius_km = NULL, units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- nearby_query(new_query(), limit, radius_km, units %||% client$units)
  operation <- new_operation("getNearbyLocations", location_path(location, "/nearby"), query)
  response <- perform(client, operation)
  body <- decode_object(response$data, "NearbyLocationsResponse")
  locations <- body$locations
  attr(locations, "origin") <- body$location
  attr(locations, "radius_km") <- body$radius_km
  with_meta(locations, response$meta)
}

#' @rdname ew_nearby
#' @export
ew_nearby_at <- function(lat, lon, ..., limit = NULL, radius_km = NULL, units = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- nearby_query(coordinates_query(lat, lon), limit, radius_km, units %||% client$units)
  response <- perform(client, new_operation("getNearbyByCoordinates", "/api/v1/nearby", query))
  body <- decode_object(response$data, "NearbyPointResponse")
  locations <- body$locations
  attr(locations, "lat") <- body$lat
  attr(locations, "lon") <- body$lon
  attr(locations, "radius_km") <- body$radius_km
  with_meta(locations, response$meta)
}

nearby_query <- function(query, limit, radius_km, units) {
  check_count(limit, "limit")
  if (!is.null(radius_km)) {
    check_number(radius_km, "radius_km")
  }
  query <- query_add(query, "limit", limit, 3)
  query <- query_add(query, "radius_km", radius_km, 50)
  query_add(query, "units", check_units(units), "metric")
}

#' List the forecast locations
#'
#' `ew_locations()` lists every named location (in one state, or in all of
#' them), following the cursor through every page. `ew_locations_page()`
#' fetches one page, for when you want to control the paging yourself.
#'
#' @param state A state's USPS code, such as `"or"`, or `NULL` for every state.
#' @inheritParams ew_forecast
#' @param type Only locations of one type, such as `"ski_area"`.
#' @param limit The page size (1 to 5000).
#' @param cursor The `next_cursor` of the previous page; `NULL` for the first.
#' @return `ew_locations()`: a tibble with one row per location.
#'   `ew_locations_page()`: an `ensembleweather_page`, a list with `items` (a
#'   tibble) and `next_cursor` (`NULL` on the last page).
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' oregon <- ew_locations("or", type = "ski_area")
#'
#' page <- ew_locations_page("or", limit = 50)
#' while (!is.null(page$next_cursor)) {
#'   page <- ew_locations_page("or", limit = 50, cursor = page$next_cursor)
#' }
ew_locations <- function(state = NULL, ..., type = NULL, units = NULL, limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  collect_pages(function(cursor) {
    locations_page(client, state, type, units, limit, cursor)
  })
}

#' @rdname ew_locations
#' @export
ew_locations_page <- function(state = NULL, ..., type = NULL, units = NULL, limit = NULL,
                              cursor = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  locations_page(client, state, type, units, limit, cursor)
}

locations_page <- function(client, state, type, units, limit, cursor) {
  check_count(limit, "limit")
  query <- query_add(new_query(), "type", type)
  query <- query_add(query, "units", check_units(units %||% client$units), "metric")
  query <- query_add(query, "limit", limit)
  query <- query_add(query, "cursor", cursor)
  if (is.null(state)) {
    operation <- new_operation("getAllLocations", "/api/v1/locations", query)
  } else {
    path <- paste0("/api/v1/locations/", encode_component(canonical_state(state)))
    operation <- new_operation("getLocations", path, query)
  }
  response <- perform(client, operation)
  body <- decode_object(response$data, "LocationsResponse")
  new_page(body$locations, body$next_cursor, response$meta)
}

new_page <- function(items, next_cursor, meta) {
  if (!is.null(next_cursor) && (is.na(next_cursor) || !nzchar(next_cursor))) {
    next_cursor <- NULL
  }
  with_meta(structure(list(items = items, next_cursor = next_cursor), class = "ensembleweather_page"), meta)
}

# Follow next_cursor until it is null, binding the pages' rows together.
collect_pages <- function(fetch) {
  pages <- list()
  cursor <- NULL
  seen <- character()
  repeat {
    page <- fetch(cursor)
    pages[[length(pages) + 1L]] <- page$items
    cursor <- page$next_cursor
    if (is.null(cursor)) break
    if (cursor %in% seen) {
      abort_unexpected("The API returned the same page cursor twice.")
    }
    seen <- c(seen, cursor)
  }
  with_meta(bind_pages(pages), ew_response_info(page))
}

bind_pages <- function(pages) {
  if (length(pages) == 1L) {
    return(pages[[1]])
  }
  columns <- names(pages[[1]])
  data <- lapply(columns, function(column) {
    values <- lapply(pages, `[[`, column)
    if (is.list(values[[1]])) do.call(c, values) else vec_concat(values)
  })
  names(data) <- columns
  tibble::new_tibble(data, nrow = sum(vapply(pages, nrow, 0L)))
}

# Concatenate typed vectors, keeping POSIXct (UTC) and Date classes.
vec_concat <- function(values) {
  first <- values[[1]]
  if (inherits(first, "POSIXct")) {
    return(.POSIXct(unlist(lapply(values, as.double)), tz = "UTC"))
  }
  if (inherits(first, "Date")) {
    return(structure(unlist(lapply(values, as.double)), class = "Date"))
  }
  unlist(values, use.names = FALSE)
}

#' @export
print.ensembleweather_page <- function(x, ...) {
  cat("<ensembleweather_page> ", nrow(x$items), " items, ",
    if (is.null(x$next_cursor)) "last page" else "more pages (see $next_cursor)", "\n",
    sep = ""
  )
  print(x$items, ...)
  invisible(x)
}
