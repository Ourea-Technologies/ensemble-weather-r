#' Alert outlines and avalanche zones (GeoJSON)
#'
#' `ew_alert_outlines()` gets the outlines of the active wind and winter
#' alerts, and `ew_avalanche_zones()` the avalanche forecast zones with each
#' zone's current danger rating. Both are GeoJSON `FeatureCollection`s.
#'
#' The body is returned as the API sends it (spec BEHAVIOR.md 3.0): every key
#' keeps its wire name (a zone's `properties$forecast_url` stays
#' `forecast_url`, unlike a forecast's `avalanche$url`), and geometries are
#' never reprojected or simplified. A position is `[longitude, latitude]` in
#' WGS84. The body is checked against its schema, and returned as parsed
#' lists, so it goes straight to a map library: for example
#' `sf::st_read(jsonlite::toJSON(unclass(zones), auto_unbox = TRUE,
#' null = "null", digits = NA), quiet = TRUE)`.
#'
#' @inheritParams ew_forecast
#' @param classes Only these alert classes: `"wind"`, `"winter"`, or both
#'   (sent as one sorted list). `NULL` serves every class.
#' @param bbox Only alerts whose bounding box touches this box:
#'   `c(west, south, east, north)` in degrees, or a vector or list with those
#'   names. Each feature is served whole, not clipped.
#' @return An `ensembleweather_geojson`: the `FeatureCollection` as a list
#'   with `type`, `features` (each with `type`, `geometry` and `properties`)
#'   and `attribution`.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' outlines <- ew_alert_outlines(classes = "winter", bbox = c(-125, 41, -116, 49))
#' vapply(outlines$features, function(f) f$properties$event, "")
#'
#' zones <- ew_avalanche_zones()
#' vapply(zones$features, function(f) f$properties$zone_name, "")
ew_alert_outlines <- function(..., classes = NULL, bbox = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  query <- query_add_list(new_query(), "class", classes)
  query <- query_add_raw(query, "bbox", bbox_value(bbox) %||% "")
  geojson_request(client, "getAlertOutlines", "/api/v1/alerts/outlines", query, "AlertOutlineCollection")
}

#' @rdname ew_alert_outlines
#' @export
ew_avalanche_zones <- function(..., client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  geojson_request(client, "getAvalancheZones", "/api/v1/avalanche/zones", new_query(), "AvalancheZoneCollection")
}

# The body is validated against its schema, then passed through untouched.
geojson_request <- function(client, name, path, query, schema) {
  response <- perform(client, new_operation(name, path, query))
  decode_object(response$data, schema)
  with_meta(structure(response$data, class = "ensembleweather_geojson"), response$meta)
}

#' @export
print.ensembleweather_geojson <- function(x, ...) {
  cat("<ensembleweather_geojson> ", x$type, ", ", length(x$features), " features\n", sep = "")
  invisible(x)
}
