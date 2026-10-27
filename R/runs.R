#' Model runs
#'
#' Lists the model runs the API can serve, newest first. Pass one of their
#' `initialized_at` times as `run` to [ew_forecast()] to read a past run.
#'
#' @param limit The most runs to list (at most 100; default 10).
#' @inheritParams ew_forecast
#' @return A tibble with one row per run (`initialized_at`). Its `served`
#'   attribute is the run a forecast request serves now (`initialized_at`
#'   and a `models` tibble), or `NULL` when no cycle is servable.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' runs <- ew_runs()
#' attr(runs, "served")$initialized_at
ew_runs <- function(..., limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  check_count(limit, "limit")
  query <- query_add(new_query(), "limit", limit, 10)
  response <- perform(client, new_operation("getAvailableRuns", "/api/v1/runs", query))
  body <- decode_object(response$data, "RunsResponse")
  runs <- body$runs
  attr(runs, "served") <- body$served
  with_meta(runs, response$meta)
}

#' Storm reports
#'
#' Storm reports compare what the ensemble forecast for a past storm with
#' what was observed. `ew_storm_reports()` lists the recent ones and
#' `ew_storm_report()` gets one by its id.
#'
#' @param limit The most reports to list (at most 100; default 20).
#' @param id A report's `id`.
#' @inheritParams ew_forecast
#' @return A tibble with one row per report (one row for `ew_storm_report()`):
#'   `id`, `location_name`, `event_type`, `onset_time`, `end_time`, the
#'   forecast and observed totals in millimetres, and the verification
#'   summary.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' reports <- ew_storm_reports(limit = 5)
#' if (nrow(reports) > 0) ew_storm_report(reports$id[[1]])
ew_storm_reports <- function(..., limit = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  check_count(limit, "limit")
  query <- query_add(new_query(), "limit", limit, 20)
  response <- perform(client, new_operation("getStormReports", "/api/v1/storm-reports", query))
  body <- decode_object(response$data, "StormReportsResponse")
  with_meta(body$reports, response$meta)
}

#' @rdname ew_storm_reports
#' @export
ew_storm_report <- function(id, ..., client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  if (!is.numeric(id) || length(id) != 1L || !is.finite(id) || id != trunc(id) || id < 0) {
    abort_usage("{.arg id} must be a storm report's whole-number id.")
  }
  path <- paste0("/api/v1/storm-reports/", format_number(id))
  response <- perform(client, new_operation("getStormReport", path))
  report <- rows_to_tibble(list(decode_object(response$data, "StormReportCard")), "StormReportCard")
  with_meta(report, response$meta)
}

#' Data attribution
#'
#' The providers whose data the forecasts use, with the credit line, licence
#' and terms each requires. Show the credit wherever you display Ourea data.
#' This is an open route: it is sent without the API key.
#'
#' @inheritParams ew_forecast
#' @return A tibble with one row per provider: `id`, `name`, `credit`,
#'   `licence`, `licence_url`, `terms_url`, `modified`, and list-columns
#'   `notices` (character vectors) and `sources` (tibbles of `id`, `name`,
#'   `kind` and `provider`).
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' providers <- ew_attribution()
#' providers$credit
ew_attribution <- function(..., client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  operation <- new_operation("getAttribution", "/api/v1/attribution", open_route = TRUE)
  response <- perform(client, operation)
  body <- decode_object(response$data, "AttributionRegistry")
  with_meta(body$providers, response$meta)
}
