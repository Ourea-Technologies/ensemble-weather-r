#' Rate-limit state and response details
#'
#' `ew_rate_limit()` returns the rate-limit state the server reported, either
#' on one result or on the client's most recent response. The package never
#' hard-codes limits: these are the `RateLimit-*` headers as sent.
#' Anonymous responses that the edge cache can share between callers carry no
#' rate-limit headers, so the state is then `NULL`.
#'
#' `ew_response_info()` returns what is known about the HTTP response behind
#' a result: its status, final URL, request id, `ETag`, and whether it came
#' from the local cache (`from_cache`) after a `304 Not Modified`
#' revalidation (`revalidated`).
#'
#' @param x A result from any ensembleweather function, or a client from
#'   [ew_client()]. `NULL` reads the shared default client.
#' @return `ew_rate_limit()`: `NULL`, or a list with `limit`, `remaining` and
#'   `reset` (numbers, `NA` when not sent) and `policy` (a string).
#'   `ew_response_info()`: a list with `status`, `url`, `request_id`, `etag`,
#'   `revalidated`, `from_cache`, `rate_limit` and `headers`.
#' @export
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' forecast <- ew_forecast("or/mt-hood-meadows")
#' ew_rate_limit(forecast)
#' ew_response_info(forecast)$revalidated
ew_rate_limit <- function(x = NULL) {
  local_user_call()
  if (is.null(x)) {
    return(default_client()$rate_limit)
  }
  if (inherits(x, "ensembleweather_client")) {
    return(x$rate_limit)
  }
  ew_response_info(x)$rate_limit
}

#' @rdname ew_rate_limit
#' @export
ew_response_info <- function(x) {
  local_user_call()
  meta <- attr(x, "ensembleweather_response", exact = TRUE)
  if (is.null(meta)) {
    abort_usage("{.arg x} is not a result returned by ensembleweather.")
  }
  meta
}

parse_rate_limit <- function(headers) {
  fields <- c(limit = "ratelimit-limit", remaining = "ratelimit-remaining", reset = "ratelimit-reset")
  values <- lapply(fields, function(name) header_value(headers, name))
  policy <- header_value(headers, "ratelimit-policy")
  if (all(vapply(values, is.null, TRUE)) && is.null(policy)) {
    return(NULL)
  }
  number <- function(v) {
    if (is.null(v)) {
      return(NA_real_)
    }
    out <- suppressWarnings(as.double(v))
    if (is.na(out)) NA_real_ else out
  }
  list(
    limit = number(values$limit),
    remaining = number(values$remaining),
    reset = number(values$reset),
    policy = policy %||% NA_character_
  )
}

with_meta <- function(x, meta) {
  attr(x, "ensembleweather_response") <- meta
  x
}
