#' The location catalog
#'
#' The catalog describes each location and station: names, aliases,
#' descriptions, elevations, photos, webcams and nearby stations.
#'
#' `ew_catalog_locations()` lists catalog locations, following the cursor
#' through every page; `ew_catalog_locations_page()` fetches one page.
#' `ew_catalog_location()` gets one location's full entry. The detail route is
#' open (sent without the API key, so it can come from the shared edge
#' cache); the list routes keep the key, because anonymous list pages are
#' capped and slowed per address.
#'
#' @param admin1 Limit to one first-level subdivision, such as `"US-OR"`.
#' @param country Limit to one country, such as `"US"`.
#' @param type Limit to one location type, snake_case, such as `"ski_area"`.
#' @param template Limit to one page template variant, snake_case: `"mountain"`,
#'   `"coastal"`, `"trail"`, `"pass"`, `"generic"` or `"station"`.
#' @param limit The page size (1 to 100; default 20).
#' @param cursor The `next_cursor` of the previous page; `NULL` for the first.
#' @inheritParams ew_forecast
#' @return `ew_catalog_locations()`: a tibble with one row per location.
#'   `ew_catalog_locations_page()`: an `ensembleweather_page` (a list with
#'   `items` and `next_cursor`). `ew_catalog_location()`: a list holding the
#'   entry, with tibbles for `elevations`, `photos`, `webcams`,
#'   `nearby_stations` and `content`. Catalog enumerations (a station's
#'   `network` and `station_status`, a template's `template_variant` and
#'   `location_type`) are snake_case.
#' @seealso [ew_catalog_stations()].
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' ski_areas <- ew_catalog_locations(type = "ski_area")
#' ew_catalog_location("mt-hood-meadows")$name
ew_catalog_locations <- function(..., admin1 = NULL, country = NULL, type = NULL, template = NULL,
                                 limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  collect_pages(function(cursor) {
    catalog_locations_page(client, admin1, country, type, template, limit, cursor)
  })
}

#' @rdname ew_catalog_locations
#' @export
ew_catalog_locations_page <- function(..., admin1 = NULL, country = NULL, type = NULL, template = NULL,
                                      limit = NULL, cursor = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  catalog_locations_page(client, admin1, country, type, template, limit, cursor)
}

catalog_locations_page <- function(client, admin1, country, type, template, limit, cursor) {
  check_count(limit, "limit")
  query <- query_add(new_query(), "admin1", admin1)
  query <- query_add(query, "country", country)
  query <- query_add(query, "type", type)
  query <- query_add(query, "template", template)
  query <- query_add(query, "limit", limit, 20)
  query <- query_add(query, "cursor", cursor)
  response <- perform(client, new_operation("listCatalogLocations", "/api/v1/catalog/locations", query))
  body <- decode_object(response$data, "PublicCatalogLocationPage")
  new_page(body$items, body$next_cursor, response$meta)
}

#' @rdname ew_catalog_locations
#' @param slug The location's (or station's) slug, such as `"mt-hood-meadows"`.
#' @param include Optional blocks to include: `"content"`, `"template"`.
#' @param locale The language of the content (default `"en"`).
#' @export
ew_catalog_location <- function(slug, ..., include = NULL, locale = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  catalog_detail(client, "getCatalogLocation", "locations", slug, include, locale, "PublicCatalogLocationDetail")
}

#' The station catalog
#'
#' `ew_catalog_stations()` lists the observation stations in the catalog,
#' following the cursor through every page; `ew_catalog_stations_page()`
#' fetches one page; `ew_catalog_station()` gets one station's full entry
#' (an open route, sent without the API key).
#'
#' @inheritParams ew_catalog_locations
#' @param network Limit to one or more networks, snake_case, such as
#'   `c("snotel", "raws")`.
#' @param capability Limit to stations measuring every one of these, such as
#'   `c("snow_depth", "swe")` (sent as one sorted list).
#' @param status Limit to one station status, snake_case: `"active"`,
#'   `"intermittent"`, `"inactive"`, `"decommissioned"` or `"unknown"`.
#' @return `ew_catalog_stations()`: a tibble with one row per station.
#'   `ew_catalog_stations_page()`: an `ensembleweather_page`.
#'   `ew_catalog_station()`: a list holding the entry.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' snotel <- ew_catalog_stations(network = "snotel", admin1 = "US-OR")
ew_catalog_stations <- function(..., admin1 = NULL, country = NULL, network = NULL, capability = NULL,
                                status = NULL, limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  collect_pages(function(cursor) {
    catalog_stations_page(client, admin1, country, network, capability, status, limit, cursor)
  })
}

#' @rdname ew_catalog_stations
#' @export
ew_catalog_stations_page <- function(..., admin1 = NULL, country = NULL, network = NULL, capability = NULL,
                                     status = NULL, limit = NULL, cursor = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  catalog_stations_page(client, admin1, country, network, capability, status, limit, cursor)
}

catalog_stations_page <- function(client, admin1, country, network, capability, status, limit, cursor) {
  check_count(limit, "limit")
  query <- query_add(new_query(), "admin1", admin1)
  query <- query_add(query, "country", country)
  query <- query_add_list(query, "network", network)
  query <- query_add_list(query, "capability", capability)
  query <- query_add(query, "status", status)
  query <- query_add(query, "limit", limit, 20)
  query <- query_add(query, "cursor", cursor)
  response <- perform(client, new_operation("listCatalogStations", "/api/v1/catalog/stations", query))
  body <- decode_object(response$data, "PublicCatalogStationPage")
  new_page(body$items, body$next_cursor, response$meta)
}

#' @rdname ew_catalog_stations
#' @export
ew_catalog_station <- function(slug, ..., include = NULL, locale = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  catalog_detail(client, "getCatalogStation", "stations", slug, include, locale, "PublicCatalogStationDetail")
}

catalog_detail <- function(client, name, kind, slug, include, locale, schema) {
  path <- paste0("/api/v1/catalog/", kind, "/", encode_component(check_nonempty(slug, "slug")))
  query <- query_add_list(new_query(), "include", include)
  query <- query_add(query, "locale", locale, "en")
  response <- perform(client, new_operation(name, path, query, open_route = TRUE))
  body <- decode_object(response$data, schema)
  with_meta(structure(body, class = paste0("ensembleweather_catalog_", sub("s$", "", kind))), response$meta)
}

#' @export
print.ensembleweather_catalog_location <- function(x, ...) {
  cat("<ensembleweather_catalog_location> ", x$name, " (", x$state, "/", x$slug, "), ",
    x$type, ", ", format_number(x$elevation_m), " m\n",
    sep = ""
  )
  invisible(x)
}

#' @export
print.ensembleweather_catalog_station <- function(x, ...) {
  cat("<ensembleweather_catalog_station> ", x$name, " (", x$slug, "), ",
    if (is.na(x$network)) "unknown network" else x$network, "\n",
    sep = ""
  )
  invisible(x)
}
