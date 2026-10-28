# The transport: canonical requests, credentials, redirects, retries, the
# ETag cache, rate-limit state and deprecation warnings (BEHAVIOR 2-3, 8-11).
# Every exported function builds an `operation` and hands it to perform().

max_redirects <- 5L
max_retry_after <- 60
max_body_bytes <- 64 * 1024^2
redirect_statuses <- c(301L, 302L, 307L, 308L)
retry_statuses <- c(429L, 502L, 503L, 504L)
retry_after_statuses <- c(429L, 503L, 504L)

# curl errors that mean the server's certificate failed verification: never
# retried, since another attempt cannot fix them.
tls_verification_errors <- c(
  "curl_error_peer_failed_verification", "curl_error_ssl_certproblem",
  "curl_error_ssl_cacert_badfile", "curl_error_ssl_issuer_error",
  "curl_error_ssl_pinnedpubkeynotmatch", "curl_error_ssl_invalidcertstatus"
)

# Indirections the tests replace with testthat::local_mocked_bindings().
sleep_for <- function(seconds) Sys.sleep(seconds)
jitter_fraction <- function() stats::runif(1L)
now <- function() Sys.time()

new_operation <- function(name, path, query = new_query(), open_route = FALSE) {
  list(name = name, path = path, query = query_render(query), open_route = open_route)
}

# Send an operation and return list(data = <parsed JSON>, meta = <response
# info>), following the policy above.
perform <- function(client, operation) {
  url <- paste0(client$base_url, operation$path)
  if (nzchar(operation$query)) {
    url <- paste0(url, "?", operation$query)
  }
  key <- client$key()
  send_key <- !is.null(key) && (!operation$open_route || client$send_key_on_open_routes)
  headers <- list(Accept = "application/json", `User-Agent` = client$user_agent)

  cache_key <- NULL
  cached <- NULL
  if (!is.null(client$cache)) {
    identity <- if (send_key) client$key_id else "anonymous"
    cache_key <- cli::hash_sha256(paste(url, identity))
    cached <- cache_get(client$cache, cache_key)
    if (!is.null(cached) && is_fresh(cached)) {
      return(cached_result(cached, url, revalidated = FALSE))
    }
    if (!is.null(cached$etag)) {
      headers[["If-None-Match"]] <- cached$etag
    }
  }

  attempt <- 1L
  repeat {
    outcome <- send_with_redirects(client, url, headers, if (send_key) key)
    if (inherits(outcome, "condition")) {
      if (is_retryable_failure(outcome) && attempt <= client$max_retries) {
        sleep_for(backoff_delay(attempt))
        attempt <- attempt + 1L
        next
      }
      abort_connection(outcome, client)
    }
    status <- outcome$status
    response_headers <- outcome$headers
    client$rate_limit <- parse_rate_limit(response_headers)
    warn_deprecation(operation$name, response_headers)

    if (status == 304L) {
      if (is.null(cached)) {
        abort_unexpected("The API answered 304 Not Modified to a request that sent no ETag.")
      }
      entry <- cache_revalidate(client$cache, cache_key, cached, response_headers)
      return(cached_result(entry, url, revalidated = TRUE, status = 304L))
    }
    if (status >= 200L && status < 300L) {
      cache_store(client$cache, cache_key, response_headers, outcome$body)
      return(list(
        data = parse_json_body(outcome$body, required = TRUE),
        meta = response_meta(status, outcome$url, response_headers, revalidated = FALSE)
      ))
    }
    info <- api_error_info(status, response_headers, outcome$body, client)
    if (status %in% retry_statuses && attempt <= client$max_retries) {
      wait <- if (status %in% retry_after_statuses) info$retry_after
      if (is.null(wait)) {
        wait <- backoff_delay(attempt)
      } else if (wait > max_retry_after) {
        abort_api(info)
      }
      sleep_for(wait)
      attempt <- attempt + 1L
      next
    }
    abort_api(info)
  }
}

# Full jitter: a random delay in [0, min(8, 0.5 * 2^(n - 1))] seconds.
backoff_delay <- function(attempt) {
  jitter_fraction() * min(8, 0.5 * 2^(attempt - 1L))
}

is_retryable_failure <- function(cnd) {
  chain <- cnd
  while (!is.null(chain)) {
    if (inherits(chain, tls_verification_errors)) {
      return(FALSE)
    }
    chain <- chain$parent
  }
  TRUE
}

# One logical attempt: send, following same-host redirects (at most 5). The
# key and If-None-Match go only to the configured base URL's origin.
send_with_redirects <- function(client, url, headers, key) {
  current <- url
  for (hop in 0:max_redirects) {
    outcome <- send_once(client, current, headers, key)
    if (inherits(outcome, "condition")) {
      return(outcome)
    }
    location <- header_value(outcome$headers, "location")
    if (!(outcome$status %in% redirect_statuses) || is.null(location)) {
      outcome$url <- current
      return(outcome)
    }
    if (hop == max_redirects) {
      abort_unexpected(paste0("The API redirected more than ", max_redirects, " times."))
    }
    current <- resolve_url(current, location)
    if (!identical(url_origin(current), client$origin)) {
      key <- NULL
      headers[["If-None-Match"]] <- NULL
    }
  }
}

send_once <- function(client, url, headers, key) {
  req <- httr2::request(url)
  req <- httr2::req_headers(req, !!!headers)
  if (!is.null(key)) {
    req <- httr2::req_headers_redacted(req, `X-API-Key` = key)
  }
  req <- httr2::req_options(req, followlocation = FALSE, maxfilesize_large = max_body_bytes)
  req <- httr2::req_timeout(req, client$timeout)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), httr2_failure = function(cnd) cnd)
  if (inherits(resp, "condition")) {
    if (inherits(resp$parent, "curl_error_filesize_exceeded")) {
      abort_too_large()
    }
    return(resp)
  }
  response_headers <- normalize_headers(httr2::resp_headers(resp))
  declared <- header_value(response_headers, "content-length")
  if (!is.null(declared) && grepl("^[0-9]+$", declared) && as.double(declared) > max_body_bytes) {
    abort_too_large()
  }
  body <- if (httr2::resp_has_body(resp)) httr2::resp_body_raw(resp) else raw()
  if (length(body) > max_body_bytes) {
    abort_too_large()
  }
  list(status = as.integer(httr2::resp_status(resp)), headers = response_headers, body = body)
}

abort_too_large <- function() {
  abort_unexpected(
    paste0("The response body is over ", max_body_bytes / 1024^2, " MiB, so it was not read."),
    class = "ensembleweather_error_response_too_large"
  )
}

cached_result <- function(entry, url, revalidated, status = 200L) {
  list(
    data = parse_json_body(entry$body, required = TRUE),
    meta = response_meta(status, url, entry$headers, revalidated = revalidated, from_cache = TRUE)
  )
}

response_meta <- function(status, url, headers, revalidated, from_cache = revalidated) {
  list(
    status = as.integer(status),
    url = url,
    request_id = header_value(headers, "x-request-id"),
    etag = header_value(headers, "etag"),
    revalidated = revalidated,
    from_cache = from_cache,
    rate_limit = parse_rate_limit(headers),
    headers = headers
  )
}

parse_json_body <- function(body, required = FALSE) {
  if (length(body) == 0L) {
    if (required) {
      abort_unexpected("The API sent an empty body where JSON was expected.")
    }
    return(NULL)
  }
  text <- safe_text(body)
  tryCatch(
    jsonlite::parse_json(text, simplifyVector = FALSE),
    error = function(cnd) {
      if (!required) {
        return(NULL)
      }
      abort_unexpected("The API sent a body that is not valid JSON.")
    }
  )
}

# Response headers as a named list with lowercase names (one string each).
normalize_headers <- function(headers) {
  if (length(headers) == 0L) {
    return(list())
  }
  values <- lapply(unclass(headers), function(v) paste(as.character(v), collapse = ", "))
  names(values) <- tolower(names(values))
  values
}

header_value <- function(headers, name) {
  value <- headers[[tolower(name)]]
  if (is.null(value) || !nzchar(value)) NULL else value
}

# "scheme://host:port" in lowercase, with the default port made explicit.
url_origin <- function(url) {
  match <- regmatches(url, regexec("^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)", url))[[1]]
  if (length(match) == 0L) {
    return(NA_character_)
  }
  scheme <- tolower(match[[2]])
  authority <- tolower(sub("^.*@", "", match[[3]]))
  if (!grepl(":[0-9]+$", authority)) {
    authority <- paste0(authority, ":", if (scheme == "https") "443" else "80")
  }
  paste0(scheme, "://", authority)
}

# Resolve a Location header against the URL that answered with it.
resolve_url <- function(base, location) {
  if (grepl("^[A-Za-z][A-Za-z0-9+.-]*://", location)) {
    return(location)
  }
  match <- regmatches(base, regexec("^([A-Za-z][A-Za-z0-9+.-]*:)//([^/?#]*)([^?#]*)", base))[[1]]
  scheme <- match[[2]]
  authority <- match[[3]]
  path <- match[[4]]
  if (startsWith(location, "//")) {
    return(paste0(scheme, location))
  }
  if (startsWith(location, "/")) {
    return(paste0(scheme, "//", authority, location))
  }
  directory <- sub("[^/]*$", "", path)
  paste0(scheme, "//", authority, if (nzchar(directory)) directory else "/", location)
}

# Seconds to wait from a Retry-After header: delta-seconds or an HTTP-date.
parse_retry_after <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  value <- trimws(value)
  if (grepl("^[0-9]+$", value)) {
    return(as.double(value))
  }
  when <- parse_http_date(value)
  if (is.null(when)) {
    return(NULL)
  }
  max(0, as.double(when) - as.double(now()))
}

# An HTTP IMF-fixdate, such as Wed, 01 Dec 2027 00:00:00 GMT, parsed
# without the locale-dependent %a and %b.
parse_http_date <- function(value) {
  months <- c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
  parts <- regmatches(value, regexec(
    "^[A-Za-z]{3}, ([0-9]{1,2}) ([A-Za-z]{3}) ([0-9]{4}) ([0-9]{2}:[0-9]{2}:[0-9]{2}) GMT$", value
  ))[[1]]
  if (length(parts) == 0L) {
    return(NULL)
  }
  month <- match(tolower(parts[[3]]), months)
  if (is.na(month)) {
    return(NULL)
  }
  text <- sprintf("%s-%02d-%02d %s", parts[[4]], month, as.integer(parts[[2]]), parts[[5]])
  out <- as.POSIXct(text, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  if (is.na(out)) NULL else out
}

# The deprecation warning, once per operation per R session (BEHAVIOR 11).
warn_deprecation <- function(operation, headers) {
  deprecation <- header_value(headers, "deprecation")
  sunset <- header_value(headers, "sunset")
  if (is.null(deprecation) && is.null(sunset)) {
    return(invisible())
  }
  if (operation %in% .state$warned) {
    return(invisible())
  }
  .state$warned <- c(.state$warned, operation)
  parts <- paste0("The Ourea API has deprecated ", operation, ".")
  if (!is.null(deprecation)) {
    parts <- c(parts, i = paste0("Deprecation: ", deprecation))
  }
  if (!is.null(sunset)) {
    parts <- c(parts, i = paste0("Sunset: ", sunset))
  }
  link <- deprecation_link(header_value(headers, "link"))
  if (!is.null(link)) {
    parts <- c(parts, i = paste0("See ", link))
  }
  rlang::warn(parts, class = "ensembleweather_deprecation", operation = operation, link = link)
}

deprecation_link <- function(link) {
  if (is.null(link)) {
    return(NULL)
  }
  match <- regmatches(link, regexec('<([^>]*)>[^,]*;\\s*rel="?deprecation"?', link, ignore.case = TRUE))[[1]]
  if (length(match) == 0L) NULL else match[[2]]
}
