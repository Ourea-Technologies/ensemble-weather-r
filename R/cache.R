#' An in-memory response cache
#'
#' The cache [ew_client()] uses by default: a least-recently-used store
#' bounded by entry count and total size. Create one yourself to share it
#' between clients, for example a keyed and an anonymous client. Entries
#' stored under one API key are never served under another (or keyless),
#' because the key's digest is part of every cache key.
#'
#' Any object with `$get(key)`, `$set(key, value)` and `$remove(key)` methods
#' can stand in for it, including the caches from the cachem package
#' (`cachem::cache_disk()` shares responses across R sessions). Keys are
#' lowercase hexadecimal strings; `$get()` may return `NULL` or a cachem
#' `key_missing()` value for a miss.
#'
#' @param max_entries The most responses kept.
#' @param max_bytes The most bytes of response bodies kept.
#' @return An `ensembleweather_memory_cache` object.
#' @export
#' @examples
#' cache <- ew_memory_cache()
#' anonymous <- ew_client(api_key = "", cache = cache)
#' cache$size()
ew_memory_cache <- function(max_entries = 256L, max_bytes = 32 * 1024^2) {
  local_user_call()
  if (!is.numeric(max_entries) || length(max_entries) != 1L || is.na(max_entries) || max_entries < 1) {
    abort_usage("{.arg max_entries} must be a positive whole number.")
  }
  if (!is.numeric(max_bytes) || length(max_bytes) != 1L || is.na(max_bytes) || max_bytes < 1) {
    abort_usage("{.arg max_bytes} must be a positive number.")
  }
  store <- new.env(parent = emptyenv())
  store$entries <- list()
  store$bytes <- 0

  entry_size <- function(value) {
    as.double(length(value$body)) + sum(nchar(unlist(value$headers), type = "bytes"))
  }
  remove <- function(key) {
    entry <- store$entries[[key]]
    if (!is.null(entry)) {
      store$bytes <- store$bytes - entry_size(entry)
      store$entries[[key]] <- NULL
    }
    invisible(NULL)
  }
  get <- function(key) {
    entry <- store$entries[[key]]
    if (!is.null(entry)) {
      # Move to the most-recently-used end.
      store$entries[[key]] <- NULL
      store$entries[[key]] <- entry
    }
    entry
  }
  set <- function(key, value) {
    remove(key)
    size <- entry_size(value)
    if (size > max_bytes) {
      return(invisible(NULL))
    }
    store$entries[[key]] <- value
    store$bytes <- store$bytes + size
    while (length(store$entries) > max_entries || store$bytes > max_bytes) {
      remove(names(store$entries)[[1]])
    }
    invisible(NULL)
  }
  size <- function() length(store$entries)
  reset <- function() {
    store$entries <- list()
    store$bytes <- 0
    invisible(NULL)
  }
  structure(
    list(get = get, set = set, remove = remove, size = size, reset = reset),
    class = "ensembleweather_memory_cache"
  )
}

#' @export
print.ensembleweather_memory_cache <- function(x, ...) {
  cat("<ensembleweather_memory_cache> ", x$size(), " entries\n", sep = "")
  invisible(x)
}

resolve_cache <- function(cache) {
  if (isTRUE(cache)) {
    return(ew_memory_cache())
  }
  if (isFALSE(cache) || is.null(cache)) {
    return(NULL)
  }
  methods <- c("get", "set", "remove")
  ok <- all(vapply(methods, function(m) is.function(tryCatch(cache[[m]], error = function(e) NULL)), TRUE))
  if (!ok) {
    abort_usage(c(
      "{.arg cache} must be {.code TRUE}, {.code FALSE}, or a cache object.",
      i = "A cache object has {.code $get()}, {.code $set()} and {.code $remove()} methods."
    ))
  }
  cache
}

cache_get <- function(cache, key) {
  if (is.null(cache)) {
    return(NULL)
  }
  value <- cache$get(key)
  if (is.null(value) || inherits(value, "key_missing") || !is.list(value)) {
    return(NULL)
  }
  value
}

# Cache-Control directives as a named list (values NULL when bare).
cache_control <- function(headers) {
  raw <- header_value(headers, "cache-control")
  out <- list()
  if (is.null(raw)) {
    return(out)
  }
  for (part in strsplit(raw, ",", fixed = TRUE)[[1]]) {
    part <- trimws(part)
    if (!nzchar(part)) next
    name <- tolower(trimws(sub("=.*$", "", part)))
    value <- if (grepl("=", part, fixed = TRUE)) gsub('^"|"$', "", trimws(sub("^[^=]*=", "", part))) else ""
    out[[name]] <- value
  }
  out
}

# The private-cache freshness lifetime: max-age, never s-maxage or
# stale-while-revalidate (those are for the edge).
max_age <- function(headers) {
  directives <- cache_control(headers)
  if ("no-cache" %in% names(directives)) {
    return(0)
  }
  value <- directives[["max-age"]]
  if (is.null(value) || !grepl("^[0-9]+$", value)) {
    return(NULL)
  }
  as.double(value)
}

is_fresh <- function(entry) {
  !is.null(entry$max_age) && entry$max_age > 0 &&
    as.double(now()) < entry$stored_at + entry$max_age
}

cache_store <- function(cache, key, headers, body) {
  if (is.null(cache) || is.null(key)) {
    return(invisible(NULL))
  }
  etag <- header_value(headers, "etag")
  lifetime <- max_age(headers)
  if ("no-store" %in% names(cache_control(headers)) || (is.null(etag) && !isTRUE(lifetime > 0))) {
    cache$remove(key)
    return(invisible(NULL))
  }
  cache$set(key, list(
    body = body,
    etag = etag,
    headers = headers,
    stored_at = as.double(now()),
    max_age = lifetime
  ))
  invisible(NULL)
}

# After a 304: the stored body with the fresh headers merged over the old.
cache_revalidate <- function(cache, key, entry, headers) {
  merged <- entry$headers
  for (name in names(headers)) {
    merged[[tolower(name)]] <- headers[[name]]
  }
  entry$headers <- merged
  entry$etag <- header_value(headers, "etag") %||% entry$etag
  entry$stored_at <- as.double(now())
  entry$max_age <- max_age(headers)
  if (!is.null(cache)) {
    if ("no-store" %in% names(cache_control(headers))) {
      cache$remove(key)
    } else {
      cache$set(key, entry)
    }
  }
  entry
}
