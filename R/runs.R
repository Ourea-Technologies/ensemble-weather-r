#' Model runs
#'
#' Lists the model runs the API can serve, newest first. Pass one of their
#' `initialized_at` times as `run` to [ew_forecast()] to read a past run.
#'
#' @param limit The most runs to list (at most 100; default 10).
#' @param cursor The `next_cursor` attribute of the previous page; `NULL` for
#'   the first.
#' @inheritParams ew_forecast
#' @return A tibble with one row per run (`initialized_at`). Its `served`
#'   attribute is the run a forecast request serves now (`initialized_at`
#'   and a `models` tibble), or `NULL` when no cycle is servable; its
#'   `next_cursor` attribute is the cursor of the next page (`NULL` on the
#'   last).
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' runs <- ew_runs()
#' attr(runs, "served")$initialized_at
ew_runs <- function(..., limit = NULL, cursor = NULL, client = NULL) {
  local_user_call()
  rlang::check_dots_empty()
  client <- resolve_client(client)
  check_count(limit, "limit")
  query <- query_add(new_query(), "limit", limit, 10)
  query <- query_add(query, "cursor", cursor)
  response <- perform(client, new_operation("getAvailableRuns", "/api/v1/runs", query))
  body <- decode_object(response$data, "RunsResponse")
  runs <- body$runs
  attr(runs, "served") <- body$served
  attr(runs, "next_cursor") <- body$next_cursor
  with_meta(runs, response$meta)
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
