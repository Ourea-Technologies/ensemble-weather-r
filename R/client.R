.state <- new.env(parent = emptyenv())
.state$user_call <- NULL
.state$default_client <- NULL
.state$default_signature <- NULL
.state$warned <- character()

default_base_url <- "https://api.oureawx.com"
default_timeout <- 30
default_max_retries <- 2L

#' Create an Ourea API client
#'
#' A client holds the settings every request uses: the API key, the base URL,
#' the default units, the timeout, the retry policy and the response cache.
#' Every function takes a `client` argument; when it is `NULL` (the default),
#' a shared client built from the environment is used, so most code never
#' calls `ew_client()` at all.
#'
#' @section Credentials:
#' With no key, calls are anonymous and use the Free tier, which is valid and
#' never an error by itself. The key is sent as the `X-API-Key` header, only to
#' the configured base URL (a redirect to another host drops it), and never
#' appears in printed output, logs or error messages.
#'
#' The open routes ([ew_search()], [ew_catalog_location()],
#' [ew_catalog_station()] and [ew_attribution()]) are sent **without** the
#' key even when the client has one, so every caller shares one entry in the
#' API's edge cache. Set `send_key_on_open_routes = TRUE` to attribute every
#' request to your key instead.
#'
#' @section Cache:
#' Responses are kept in an in-memory cache (256 entries, 32 MiB) keyed by the
#' full URL and a SHA-256 digest of the API key (never the key itself), and
#' revalidated with `If-None-Match` on every call: an unchanged forecast then
#' costs a `304 Not Modified` and no download. Pass `cache = FALSE` to turn it
#' off, or a cache object to share one between clients or sessions: the
#' result of [ew_memory_cache()], or any object with `$get(key)`,
#' `$set(key, value)` and `$remove(key)` methods, such as a
#' `cachem::cache_disk()`.
#'
#' @section Retries:
#' Connection errors (except TLS verification failures) and HTTP 429, 502,
#' 503 and 504 are retried up to `max_retries` times. After a 429 or 503 with
#' `Retry-After`, the client waits exactly that long (up to 60 seconds; a
#' longer wait is returned as the error instead). Otherwise it waits a random
#' time between 0 and `min(8, 0.5 * 2^(n - 1))` seconds before retry `n`.
#' Nothing else is retried.
#'
#' @param api_key An Ourea API key. `NULL` (the default) reads the
#'   `OUREA_API_KEY` environment variable; no key at all means anonymous calls.
#' @param base_url The API's base URL. `NULL` reads `OUREA_BASE_URL`, falling
#'   back to the production API. A trailing slash is ignored. Point it at a
#'   proxy or a local stub for tests.
#' @param units The default unit system: `"metric"` (°C, mm, m/s, m),
#'   `"imperial"` (°F, in, mph, ft) or `"kelvin"` (metric with K). Each
#'   function can override it.
#' @param timeout Seconds to wait for each attempt.
#' @param max_retries How many times to retry a failed request; `0` disables
#'   retrying.
#' @param cache `TRUE` for a new in-memory cache, `FALSE` for none, or a cache
#'   object (see the Cache section).
#' @param send_key_on_open_routes Send the key on the open routes too.
#' @param user_agent An optional product token for your app, appended to the
#'   package's own `User-Agent`, for example `"my-app/1.2"`.
#' @return An `ensembleweather_client` object.
#' @seealso [ew_rate_limit()] to read the rate-limit state.
#' @export
#' @examples
#' client <- ew_client(units = "imperial", cache = FALSE)
#' client
ew_client <- function(api_key = NULL,
                      base_url = NULL,
                      units = "metric",
                      timeout = 30,
                      max_retries = 2L,
                      cache = TRUE,
                      send_key_on_open_routes = FALSE,
                      user_agent = NULL) {
  local_user_call()
  key <- api_key %||% Sys.getenv("OUREA_API_KEY", "")
  if (!is.character(key) || length(key) != 1L || is.na(key)) {
    abort_usage("{.arg api_key} must be a single string.")
  }
  key <- if (nzchar(key)) key else NULL
  base <- base_url %||% Sys.getenv("OUREA_BASE_URL", "")
  if (!is.character(base) || length(base) != 1L || is.na(base)) {
    abort_usage("{.arg base_url} must be a single string.")
  }
  if (!nzchar(base)) {
    base <- default_base_url
  }
  base <- sub("/+$", "", base)
  if (!grepl("^https?://[^/]+", base)) {
    abort_usage("{.arg base_url} must be an http(s) URL, not {.val {base}}.")
  }
  check_units(units)
  if (!is.numeric(timeout) || length(timeout) != 1L || !is.finite(timeout) || timeout <= 0) {
    abort_usage("{.arg timeout} must be a positive number of seconds.")
  }
  if (!is_whole_number(max_retries) || max_retries < 0) {
    abort_usage("{.arg max_retries} must be a whole number, 0 or more.")
  }
  if (!is_flag(send_key_on_open_routes)) {
    abort_usage("{.arg send_key_on_open_routes} must be {.code TRUE} or {.code FALSE}.")
  }
  if (!is.null(user_agent) && (!is_string(user_agent) || grepl("[\r\n]", user_agent))) {
    abort_usage("{.arg user_agent} must be a single line of text.")
  }

  client <- new.env(parent = emptyenv())
  # The key lives in a closure: printing or str() of the client never shows it.
  client$key <- local({
    secret <- key
    function() secret
  })
  client$key_id <- if (is.null(key)) NULL else cli::hash_sha256(paste0("ensembleweather:", key))
  client$base_url <- base
  client$origin <- url_origin(base)
  client$units <- units
  client$timeout <- as.double(timeout)
  client$max_retries <- as.integer(max_retries)
  client$cache <- resolve_cache(cache)
  client$send_key_on_open_routes <- send_key_on_open_routes
  client$user_agent <- sdk_user_agent(user_agent)
  client$rate_limit <- NULL
  structure(client, class = "ensembleweather_client")
}

#' @export
format.ensembleweather_client <- function(x, ...) {
  cache <- "custom"
  if (is.null(x$cache)) {
    cache <- "off"
  } else if (inherits(x$cache, "ensembleweather_memory_cache")) {
    cache <- "in memory"
  }
  c(
    "<ensembleweather_client>",
    paste0("  base_url: ", x$base_url),
    paste0("  api_key:  ", if (is.null(x$key())) "none (anonymous, Free tier)" else "set"),
    paste0("  units:    ", x$units),
    paste0("  retries:  ", x$max_retries, ", timeout ", format_number(x$timeout), " s"),
    paste0("  cache:    ", cache)
  )
}

#' @export
print.ensembleweather_client <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# The client used when a function is called with `client = NULL`. It is
# rebuilt when OUREA_API_KEY or OUREA_BASE_URL change, so the environment
# always wins, and otherwise kept so its cache lasts the session.
default_client <- function() {
  signature <- c(Sys.getenv("OUREA_API_KEY", ""), Sys.getenv("OUREA_BASE_URL", ""))
  if (is.null(.state$default_client) || !identical(.state$default_signature, signature)) {
    .state$default_client <- ew_client()
    .state$default_signature <- signature
  }
  .state$default_client
}

resolve_client <- function(client) {
  if (is.null(client)) {
    return(default_client())
  }
  if (!inherits(client, "ensembleweather_client")) {
    abort_usage("{.arg client} must be made by {.fn ew_client}.")
  }
  client
}

sdk_version <- function() unname(getNamespaceVersion("ensembleweather"))

sdk_user_agent <- function(product = NULL) {
  runtime <- paste0("R/", R.version$major, ".", R.version$minor)
  base <- paste0("ensemble-weather-r/", sdk_version(), " (", runtime, ")")
  if (is.null(product)) base else paste(base, product)
}

# Forget the default client and which operations already warned (for tests).
reset_session_state <- function() {
  .state$default_client <- NULL
  .state$default_signature <- NULL
  .state$warned <- character()
  invisible()
}
