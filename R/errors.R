#' Errors raised by ensembleweather
#'
#' Every error the package raises is a classed condition that inherits from
#' `ensembleweather_error`, plus one class per category, so you can catch
#' exactly what you mean with [tryCatch()] or [rlang::try_fetch()].
#'
#' * `ensembleweather_error_authentication`: `INVALID_API_KEY`,
#'   `UNAUTHORIZED`, or HTTP 401.
#' * `ensembleweather_error_permission`: `PRO_REQUIRED`, or HTTP 403.
#' * `ensembleweather_error_not_found`: `LOCATION_NOT_FOUND`, `NOT_FOUND`,
#'   or HTTP 404 and 410.
#' * `ensembleweather_error_invalid_request`: `BAD_REQUEST`,
#'   `INVALID_COORDINATES`, `INVALID_ELEVATION`, `ELEVATION_REQUIRED`, or
#'   HTTP 400.
#' * `ensembleweather_error_outside_coverage`: `OUTSIDE_COVERAGE` (a 404;
#'   by code only).
#' * `ensembleweather_error_rate_limited`: `TOO_MANY_REQUESTS`, or HTTP 429.
#' * `ensembleweather_error_unavailable`: `FORECAST_UNAVAILABLE`, `TIMEOUT`,
#'   `INTERNAL_ERROR`, `DATABASE_ERROR`, `AUTH_UNAVAILABLE`, or HTTP 5xx.
#' * `ensembleweather_error_api`: any other HTTP error.
#' * `ensembleweather_error_connection`: no response at all (DNS, TLS, a
#'   reset, a timeout).
#' * `ensembleweather_error_usage`: refused before sending (an invalid
#'   argument or term).
#' * `ensembleweather_error_unexpected_response`: a success body that is not
#'   what the API documents, or one over 64 MiB
#'   (`ensembleweather_error_response_too_large`).
#'
#' A category is chosen by the API's error code first, and by the HTTP status
#' when the code is unknown (an older or newer one) or the body is not JSON.
#'
#' @section Fields:
#' Errors from an HTTP response carry these fields (read them with `$`):
#'
#' * `category`: the category, for example `"not_found"`;
#' * `status`: the HTTP status;
#' * `code`: the API's error code, verbatim (even one this version does not
#'   know), or `NULL` when the body was not JSON;
#' * `request_id`: the request's id, for support (the error body's
#'   `request_id`, else the `X-Request-Id` response header);
#' * `doc_url`: the documentation of the error code, when the body names it;
#' * `param`: the query parameter a 400 is about, when the body names one;
#' * `nearest_location`: on a `PRO_REQUIRED` coordinate request, the nearest
#'   named location whose forecast answers without a key (a list with
#'   `slug`, `url`, `distance_km` and `elevation_m`), when one is within
#'   10 km and 300 m of elevation; else `NULL`;
#' * `retry_after`: the `Retry-After` delay in seconds, if the server sent
#'   one (on 429, 503 and 504);
#' * `rate_limit`: the rate-limit state the response reported (see
#'   [ew_rate_limit()]).
#'
#' The API key never appears in an error's message or fields.
#'
#' @name ensembleweather_error
#' @examples
#' # Catch one category by its class ...
#' result <- tryCatch(
#'   ew_chance("snowfall", ">=", 6, "in", aggregation = "any"),
#'   ensembleweather_error_usage = function(cnd) conditionMessage(cnd)
#' )
#' result
#'
#' @examplesIf interactive() || nzchar(Sys.getenv("OUREA_BASE_URL"))
#' # ... or read the fields of any API error.
#' tryCatch(
#'   ew_forecast("or/no-such-place"),
#'   ensembleweather_error_not_found = function(cnd) {
#'     c(status = cnd$status, code = cnd$code)
#'   }
#' )
NULL

# Error codes per category (BEHAVIOR 8).
error_codes <- list(
  authentication = c("INVALID_API_KEY", "UNAUTHORIZED"),
  permission = "PRO_REQUIRED",
  not_found = c("LOCATION_NOT_FOUND", "NOT_FOUND"),
  invalid_request = c(
    "BAD_REQUEST", "INVALID_COORDINATES", "INVALID_ELEVATION", "ELEVATION_REQUIRED"
  ),
  outside_coverage = "OUTSIDE_COVERAGE",
  rate_limited = "TOO_MANY_REQUESTS",
  unavailable = c(
    "FORECAST_UNAVAILABLE", "TIMEOUT", "INTERNAL_ERROR", "DATABASE_ERROR", "AUTH_UNAVAILABLE"
  )
)

# The category of an HTTP error: by code first, then by status.
error_category <- function(status, code) {
  if (!is.null(code)) {
    for (category in names(error_codes)) {
      if (code %in% error_codes[[category]]) {
        return(category)
      }
    }
  }
  if (status == 401) {
    return("authentication")
  }
  if (status == 403) {
    return("permission")
  }
  if (status %in% c(404, 410)) {
    return("not_found")
  }
  if (status == 400) {
    return("invalid_request")
  }
  if (status == 429) {
    return("rate_limited")
  }
  if (status >= 500) {
    return("unavailable")
  }
  "api"
}

error_classes <- function(category) {
  c(paste0("ensembleweather_error_", category), "ensembleweather_error")
}

# The frame of the exported function the user called, so errors name it.
local_user_call <- function(frame = rlang::caller_env()) {
  if (is.null(.state$user_call)) {
    rlang::local_bindings(user_call = frame, .env = .state, .frame = frame)
  }
  invisible(frame)
}

user_call <- function() .state$user_call

# A usage error: refused before anything is sent.
abort_usage <- function(message, ..., call = user_call(), .envir = parent.frame()) {
  cli::cli_abort(
    message,
    ...,
    class = error_classes("usage"),
    category = "usage",
    call = call,
    .envir = .envir
  )
}

# A response that is not what the API documents.
abort_unexpected <- function(message, ..., class = NULL, call = user_call()) {
  rlang::abort(
    message,
    class = c(class, error_classes("unexpected_response")),
    category = "unexpected_response",
    ...,
    call = call
  )
}

# The fields of an HTTP error, before it is raised (retries read them first).
api_error_info <- function(status, headers, body, client) {
  code <- NULL
  message <- paste("HTTP", status)
  fields <- list()
  nearest <- NULL
  data <- tryCatch(parse_json_body(body), error = function(cnd) NULL)
  if (is.list(data) && is.character(data$error) && length(data$error) == 1L) {
    code <- data$error
    if (is.character(data$message) && length(data$message) == 1L) {
      message <- data$message
    }
    for (name in c("request_id", "doc_url", "param")) {
      if (is_string(data[[name]])) fields[[name]] <- data[[name]]
    }
    if (is.list(data$nearest_location)) {
      nearest <- tryCatch(
        decode_object(data$nearest_location, "NearestLocation"),
        ensembleweather_error = function(cnd) NULL
      )
    }
  } else if (length(body) > 0L) {
    snippet <- trimws(safe_text(body[seq_len(min(length(body), 200L))]))
    if (nzchar(snippet)) {
      message <- paste0("HTTP ", status, ": ", snippet)
    }
  }
  list(
    category = error_category(status, code),
    status = as.integer(status),
    code = code,
    message = scrub_key(message, client),
    request_id = fields$request_id %||% header_value(headers, "x-request-id"),
    doc_url = fields$doc_url,
    param = fields$param,
    nearest_location = nearest,
    retry_after = parse_retry_after(header_value(headers, "retry-after")),
    rate_limit = parse_rate_limit(headers)
  )
}

abort_api <- function(info, call = user_call()) {
  details <- paste0("HTTP ", info$status, if (!is.null(info$code)) paste0(", code ", info$code))
  bullets <- c(info$message, i = details)
  if (!is.null(info$request_id)) {
    bullets <- c(bullets, i = paste0("Request id: ", info$request_id))
  }
  if (!is.null(info$retry_after)) {
    bullets <- c(bullets, i = paste0("Retry after: ", format_number(info$retry_after), " s"))
  }
  rlang::abort(
    bullets,
    class = error_classes(info$category),
    category = info$category,
    status = info$status,
    code = info$code,
    request_id = info$request_id,
    doc_url = info$doc_url,
    param = info$param,
    nearest_location = info$nearest_location,
    retry_after = info$retry_after,
    rate_limit = info$rate_limit,
    call = call
  )
}

abort_connection <- function(cnd, client, call = user_call()) {
  text <- scrub_key(conditionMessage(cnd), client)
  rlang::abort(
    c("Could not reach the Ourea API.", x = text),
    class = error_classes("connection"),
    category = "connection",
    call = call
  )
}

# Never let the key into a message, even if a server or library echoed it.
scrub_key <- function(text, client) {
  key <- client$key()
  if (is.null(key)) {
    return(text)
  }
  gsub(key, "[redacted]", text, fixed = TRUE)
}

safe_text <- function(bytes) {
  text <- rawToChar(bytes[bytes != as.raw(0)])
  Encoding(text) <- "UTF-8"
  if (!validUTF8(text)) {
    text <- iconv(text, "UTF-8", "UTF-8", sub = "?")
  }
  text
}
