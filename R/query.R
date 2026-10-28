# Canonical request URLs (BEHAVIOR 3.1): one request, one edge-cache entry.
#
# * a parameter the caller did not set, or set to its default, is omitted;
# * parameters are sorted by name (C-locale byte order) and each appears once;
# * a comma list (`sources`, `include`, `network`, `capability`, ...) is
#   sorted and de-duplicated, its items joined by a literal `,`;
# * values are RFC 3986 percent-encoded (space as %20, uppercase hex), except
#   that `prob` and `totals` keep `:` and `,` literal and a comma list keeps
#   its separating `,`;
# * numbers are the shortest decimal that round-trips, never an exponent.

unreserved_bytes <- as.integer(charToRaw(
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
))

# Percent-encode one path segment or query value with RFC 3986 rules.
encode_component <- function(x) {
  bytes <- as.integer(charToRaw(enc2utf8(x)))
  if (length(bytes) == 0L) {
    return("")
  }
  keep <- bytes %in% unreserved_bytes
  out <- character(length(bytes))
  out[keep] <- vapply(bytes[keep], function(b) rawToChar(as.raw(b)), "")
  out[!keep] <- sprintf("%%%02X", bytes[!keep])
  paste(out, collapse = "")
}

# The shortest decimal that reads back as the same double, with no exponent.
# An integral value prints without ".0" (1661, not 1661.0), as in every other
# SDK, so the URL is the same cache key everywhere.
format_number <- function(x) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
    abort_usage("Expected one finite number, not {.val {x}}.")
  }
  x <- as.double(x)
  if (x == 0) {
    return("0")
  }
  if (x == trunc(x) && abs(x) < 1e15) {
    return(sprintf("%.0f", x))
  }
  text <- NULL
  for (digits in 1:17) {
    text <- sprintf("%.*g", digits, x)
    if (as.double(text) == x) {
      break
    }
  }
  if (grepl("e", text, fixed = TRUE)) {
    text <- expand_exponent(text)
  }
  text
}

# "1.5e-07" -> "0.00000015"; "1.25e+20" -> "125000000000000000000".
expand_exponent <- function(text) {
  negative <- startsWith(text, "-")
  text <- sub("^-", "", text)
  parts <- strsplit(text, "e", fixed = TRUE)[[1]]
  mantissa <- parts[[1]]
  exponent <- as.integer(parts[[2]])
  int_part <- sub("\\..*$", "", mantissa)
  frac_part <- if (grepl(".", mantissa, fixed = TRUE)) sub("^.*\\.", "", mantissa) else ""
  digits <- paste0(int_part, frac_part)
  point <- nchar(int_part) + exponent
  if (point <= 0L) {
    out <- paste0("0.", strrep("0", -point), digits)
  } else if (point >= nchar(digits)) {
    out <- paste0(digits, strrep("0", point - nchar(digits)))
  } else {
    out <- paste0(substr(digits, 1L, point), ".", substr(digits, point + 1L, nchar(digits)))
  }
  out <- sub("^0+(?=[0-9])", "", out, perl = TRUE)
  if (negative) paste0("-", out) else out
}

# Format a timestamp the way the API reads it (UTC, ISO 8601, "Z").
format_datetime <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(format(as.POSIXct(x), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)) {
    return(x)
  }
  abort_usage("{.arg run} must be a date-time ({.cls POSIXct}) or an ISO 8601 string.")
}

# One query value, before percent-encoding.
format_value <- function(x, name) {
  if (is.logical(x)) {
    if (length(x) != 1L || is.na(x)) {
      abort_usage("{.arg {name}} must be {.code TRUE} or {.code FALSE}.")
    }
    return(if (x) "true" else "false")
  }
  if (inherits(x, "POSIXt")) {
    return(format_datetime(x))
  }
  if (is.numeric(x)) {
    return(format_number(x))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(x)
  }
  abort_usage("{.arg {name}} must be a single value.")
}

# A query under construction: a named list of character vectors, plus the
# names whose values are sent without percent-encoding.
new_query <- function() {
  structure(list(params = list(), raw = character()), class = "ensembleweather_query")
}

# Add `name=value` unless the value is unset or equals the route's default.
query_add <- function(query, name, value, default = NULL) {
  if (is.null(value)) {
    return(query)
  }
  text <- format_value(value, name)
  if (!is.null(default) && identical(text, format_value(default, name))) {
    return(query)
  }
  query$params[[name]] <- text
  query
}

# Add a comma list, sorted, de-duplicated and joined by a literal ",": the
# server's canonical form (any other is a 301).
query_add_list <- function(query, name, values, default = NULL) {
  if (is.null(values)) {
    return(query)
  }
  values <- sort(unique(check_strings(values, name)), method = "radix")
  if (length(values) == 0L) {
    return(query)
  }
  if (!is.null(default) && identical(paste(values, collapse = ","), default)) {
    return(query)
  }
  query$params[[name]] <- paste(vapply(values, encode_component, "", USE.NAMES = FALSE), collapse = ",")
  query$raw <- c(query$raw, name)
  query
}

# Add a pre-built value sent without percent-encoding (`prob`, `totals`).
query_add_raw <- function(query, name, value) {
  if (nzchar(value)) {
    query$params[[name]] <- value
    query$raw <- c(query$raw, name)
  }
  query
}

# The query string, without "?", in canonical order.
query_render <- function(query) {
  params <- query$params
  if (length(params) == 0L) {
    return("")
  }
  parts <- character()
  for (name in sort(names(params), method = "radix")) {
    for (value in params[[name]]) {
      encoded <- if (name %in% query$raw) value else encode_component(value)
      parts <- c(parts, paste0(name, "=", encoded))
    }
  }
  paste(parts, collapse = "&")
}

check_strings <- function(values, name) {
  if (!is.character(values) || anyNA(values) || !all(nzchar(values))) {
    abort_usage("{.arg {name}} must be a character vector of non-empty strings.")
  }
  values
}
