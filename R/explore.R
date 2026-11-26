#' Places ranked by a metric
#'
#' `ew_explore()` ranks the named locations by one metric, such as the
#' forecast's new snow over the next five days, following the cursor through
#' every page. `ew_explore_page()` fetches one page, for when you want to
#' control the paging yourself.
#'
#' The metrics are `"base_depth"`, `"new_snow_24h"`, `"snow_today"`,
#' `"snow_5d"`, `"snow_10d"`, `"snow_14d"`, `"precip_today"`, `"precip_5d"`,
#' `"precip_10d"`, `"precip_14d"`, `"season_precip"`,
#' `"season_precip_pct_normal"` and `"season_snow"`. Each value is served
#' with its `p10` and `p90` where the metric is a forecast distribution.
#'
#' @param metric The metric to rank by (required), such as `"snow_5d"`.
#' @inheritParams ew_forecast
#' @param order `"desc"` (the default, largest first) or `"asc"`.
#' @param type Only places of one type, such as `"ski_area"`.
#' @param state Only places in one state (USPS code, such as `"or"`).
#' @param near Only places within `radius_km` of a point: `c(lat, lon)`, or a
#'   list or vector named `lat` and `lon`. Each item then has `distance_km`.
#' @param radius_km With `near`: the radius in kilometres (up to 1000;
#'   default 100).
#' @param elevation_min,elevation_max Only points at or above, or at or
#'   below, this elevation, in the response's height unit (m, or ft with
#'   `units = "imperial"`).
#' @param points `"primary"` (the default: each place's own point) or `"all"`
#'   (each named elevation too, so a resort may appear once per elevation).
#' @param limit Items per page (1 to 100; default 25).
#' @param cursor The `next_cursor` of the previous page; `NULL` for the first.
#'   Keep the other arguments the same.
#' @return `ew_explore()`: a tibble with one row per item, in rank order:
#'   `rank`, the place (`location_slug`, `location_state`, `location_name`,
#'   ...), `elevation_name`, `elevation_display_name`, `elevation`, `value`,
#'   `p10`, `p90`, `as_of`, `initialized_at`, `source`, `distance_km` and
#'   `path`. Its attributes `metric`, `order`, `units` and `unit` (the unit
#'   of every `value`) describe the ranking.
#'   `ew_explore_page()`: an `ensembleweather_page`, a list with `items` (that
#'   tibble), `next_cursor` (`NULL` on the last page), `metric`, `order`,
#'   `units`, `unit` and `count`.
#' @seealso [ew_search()] with `sort` ranks name matches by the same metrics.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' # The most new snow over the next five days, in Oregon.
#' page <- ew_explore_page("snow_5d", state = "or", units = "imperial")
#' page$items[, c("rank", "location_name", "value", "p10", "p90")]
#' page$unit
#'
#' # Ski areas within 100 km of Mt. Hood, every page.
#' ew_explore("base_depth", type = "ski_area", near = c(45.33, -121.66), limit = 100)
ew_explore <- function(metric,
                       ...,
                       order = NULL,
                       type = NULL,
                       state = NULL,
                       near = NULL,
                       radius_km = NULL,
                       elevation_min = NULL,
                       elevation_max = NULL,
                       points = NULL,
                       limit = NULL,
                       units = NULL,
                       client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  # The ranking's description, from the first page.
  ranking <- new.env(parent = emptyenv())
  items <- collect_pages(function(cursor) {
    page <- explore_page(
      client, metric, order, type, state, near, radius_km, elevation_min, elevation_max,
      points, limit, cursor, units
    )
    if (is.null(ranking$first)) ranking$first <- page
    page
  })
  for (name in c("metric", "order", "units", "unit")) {
    attr(items, name) <- ranking$first[[name]]
  }
  items
}

#' @rdname ew_explore
#' @export
ew_explore_page <- function(metric,
                            ...,
                            order = NULL,
                            type = NULL,
                            state = NULL,
                            near = NULL,
                            radius_km = NULL,
                            elevation_min = NULL,
                            elevation_max = NULL,
                            points = NULL,
                            limit = NULL,
                            cursor = NULL,
                            units = NULL,
                            client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  explore_page(
    client, metric, order, type, state, near, radius_km, elevation_min, elevation_max,
    points, limit, cursor, units
  )
}

explore_page <- function(client, metric, order, type, state, near, radius_km, elevation_min,
                         elevation_max, points, limit, cursor, units) {
  metric <- check_nonempty(metric, "metric")
  check_count(limit, "limit")
  for (bound in list(list("elevation_min", elevation_min), list("elevation_max", elevation_max))) {
    if (!is.null(bound[[2]])) check_number(bound[[2]], bound[[1]])
  }
  query <- query_add(new_query(), "metric", metric)
  query <- query_add(query, "order", optional_string(order, "order"), "desc")
  query <- query_add(query, "type", optional_string(type, "type"))
  query <- query_add(query, "state", if (!is.null(state)) canonical_state(state))
  query <- query_add_near(query, near, radius_km)
  query <- query_add(query, "elevation_min", elevation_min)
  query <- query_add(query, "elevation_max", elevation_max)
  query <- query_add(query, "points", optional_string(points, "points"), "primary")
  query <- query_add(query, "limit", limit, 25)
  query <- query_add(query, "cursor", optional_string(cursor, "cursor"))
  query <- query_add(query, "units", check_units(units %||% client$units), "metric")
  response <- perform(client, new_operation("explore", "/api/v1/explore", query))
  body <- decode_object(response$data, "ExploreResponse")
  new_page(
    body$items, body$next_cursor, response$meta,
    metric = body$metric, order = body$order, units = body$units, unit = body$unit,
    count = body$count
  )
}
