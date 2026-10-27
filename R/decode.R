# Turn parsed JSON into typed R values, following `schemas`.
#
# * An object becomes a named list holding every field of its schema: an
#   absent scalar is a typed NA, an absent object or array is NULL. Unknown
#   fields are ignored (BEHAVIOR 1.5). A missing required field is an error.
# * An array of objects becomes a tibble, one row per element. Nested objects
#   made only of scalars are flattened into `parent_child` columns
#   (`temperature_p10`); anything else is a list-column.
# * Timestamps become POSIXct in UTC, dates become Date.

scalar_types <- c("chr", "num", "int", "int64", "lgl", "dttm", "date")

.fields_memo <- new.env(parent = emptyenv())
.columns_memo <- new.env(parent = emptyenv())

parse_field <- function(spec) {
  required <- endsWith(spec, "!")
  base <- sub("!$", "", spec)
  depth <- 0L
  while (endsWith(base, "[]")) {
    base <- substr(base, 1L, nchar(base) - 2L)
    depth <- depth + 1L
  }
  list(base = base, depth = depth, required = required)
}

schema_fields <- function(schema) {
  memo <- .fields_memo[[schema]]
  if (!is.null(memo)) {
    return(memo)
  }
  specs <- schemas[[schema]]
  if (is.null(specs)) {
    stop("internal error: unknown schema ", schema, call. = FALSE)
  }
  fields <- lapply(specs, parse_field)
  names(fields) <- names(specs)
  .fields_memo[[schema]] <- fields
  fields
}

typed_na <- function(type) {
  switch(type,
    chr = NA_character_,
    num = ,
    int64 = NA_real_,
    int = NA_integer_,
    lgl = NA,
    dttm = .POSIXct(NA_real_, tz = "UTC"),
    date = structure(NA_real_, class = "Date")
  )
}

decode_fail <- function(path, problem) {
  abort_unexpected(paste0("The API response does not match its schema at `", path, "`: ", problem, "."))
}

decode_object <- function(x, schema, path = "$") {
  if (!is.list(x) || (length(x) > 0L && is.null(names(x)))) {
    decode_fail(path, paste0("expected an object (", schema, ")"))
  }
  fields <- schema_fields(schema)
  present <- names(x)
  out <- vector("list", length(fields))
  names(out) <- names(fields)
  for (name in names(fields)) {
    field <- fields[[name]]
    here <- paste0(path, ".", name)
    if (!(name %in% present)) {
      if (field$required) {
        decode_fail(here, "a required field is missing")
      }
      out[name] <- list(missing_value(field))
    } else {
      out[name] <- list(decode_value(x[[name]], field, here))
    }
  }
  out
}

missing_value <- function(field) {
  if (field$depth == 0L && field$base %in% scalar_types) typed_na(field$base) else NULL
}

decode_value <- function(value, field, path) {
  if (is.null(value)) {
    return(missing_value(field))
  }
  if (field$depth == 0L) {
    if (field$base %in% scalar_types) {
      return(decode_scalar(value, field$base, path))
    }
    if (field$base == "json") {
      return(value)
    }
    return(decode_object(value, field$base, path))
  }
  if (!is.list(value) || !is.null(names(value))) {
    decode_fail(path, "expected an array")
  }
  if (field$depth > 1L || field$base == "json") {
    return(value)
  }
  if (field$base %in% scalar_types) {
    items <- lapply(seq_along(value), function(i) {
      decode_value(value[[i]], list(base = field$base, depth = 0L), sprintf("%s[%d]", path, i - 1L))
    })
    return(combine_scalars(items, field$base))
  }
  rows <- lapply(seq_along(value), function(i) {
    decode_object(value[[i]], field$base, sprintf("%s[%d]", path, i - 1L))
  })
  rows_to_tibble(rows, field$base)
}

decode_scalar <- function(value, type, path) {
  if (length(value) != 1L) {
    decode_fail(path, paste0("expected one ", type, " value"))
  }
  ok <- switch(type,
    chr = ,
    dttm = ,
    date = is.character(value),
    num = ,
    int = ,
    int64 = is.numeric(value),
    lgl = is.logical(value)
  )
  if (!ok) {
    decode_fail(path, paste0("expected ", type))
  }
  switch(type,
    chr = value,
    num = as.double(value),
    int64 = {
      if (value != trunc(value)) decode_fail(path, "expected a whole number")
      as.double(value)
    },
    int = {
      if (value != trunc(value) || abs(value) > .Machine$integer.max) {
        decode_fail(path, "expected a whole number")
      }
      as.integer(value)
    },
    lgl = value,
    dttm = parse_timestamp(value, path),
    date = {
      out <- as.Date(value, format = "%Y-%m-%d", optional = TRUE)
      if (is.na(out) || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value)) {
        decode_fail(path, "expected a date (YYYY-MM-DD)")
      }
      out
    }
  )
}

# RFC 3339 timestamps: "2026-11-15T00:00:00Z", with optional fractional
# seconds and a numeric offset.
parse_timestamp <- function(value, path) {
  pattern <- "^([0-9]{4}-[0-9]{2}-[0-9]{2})[Tt ]([0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?)([Zz]|[+-][0-9]{2}:?[0-9]{2})?$"
  parts <- regmatches(value, regexec(pattern, value))[[1]]
  if (length(parts) == 0L) {
    decode_fail(path, "expected an RFC 3339 timestamp")
  }
  out <- as.POSIXct(paste(parts[[2]], parts[[3]]), format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  if (is.na(out)) {
    decode_fail(path, "expected an RFC 3339 timestamp")
  }
  offset <- parts[[5]]
  if (nzchar(offset) && !(offset %in% c("Z", "z"))) {
    digits <- gsub(":", "", substr(offset, 2L, nchar(offset)), fixed = TRUE)
    seconds <- as.integer(substr(digits, 1L, 2L)) * 3600 + as.integer(substr(digits, 3L, 4L)) * 60
    out <- out - (if (startsWith(offset, "-")) -seconds else seconds)
  }
  out
}

combine_scalars <- function(items, type) {
  switch(type,
    chr = vapply(items, function(v) v, ""),
    num = ,
    int64 = vapply(items, function(v) v, 0),
    int = vapply(items, function(v) v, 0L),
    lgl = vapply(items, function(v) v, NA),
    dttm = .POSIXct(vapply(items, as.double, 0), tz = "UTC"),
    date = structure(vapply(items, as.double, 0), class = "Date")
  )
}

# Whether a schema is made only of scalars and such schemas (so it can be
# spread over columns).
is_flat <- function(schema) {
  for (field in schema_fields(schema)) {
    if (field$depth > 0L) {
      return(FALSE)
    }
    if (field$base %in% scalar_types) next
    if (field$base == "json" || !is_flat(field$base)) {
      return(FALSE)
    }
  }
  TRUE
}

# The columns of a tibble of `schema` rows: name, path into a decoded
# object, and type ("list" for a list-column).
schema_columns <- function(schema) {
  memo <- .columns_memo[[schema]]
  if (!is.null(memo)) {
    return(memo)
  }
  columns <- flatten_columns(schema, "", character())
  names <- vapply(columns, `[[`, "", "name")
  if (anyDuplicated(names)) {
    stop("internal error: duplicate columns in ", schema, call. = FALSE)
  }
  .columns_memo[[schema]] <- columns
  columns
}

flatten_columns <- function(schema, prefix, path) {
  out <- list()
  fields <- schema_fields(schema)
  for (name in names(fields)) {
    field <- fields[[name]]
    here <- c(path, name)
    if (field$depth == 0L && field$base %in% scalar_types) {
      out[[length(out) + 1L]] <- list(name = paste0(prefix, name), path = here, type = field$base)
    } else if (field$depth == 0L && field$base != "json" && is_flat(field$base)) {
      key <- paste0(schema, ".", name)
      inner <- if (key %in% inline_fields) {
        prefix
      } else if (key %in% names(column_prefixes)) {
        paste0(prefix, column_prefixes[[key]])
      } else {
        paste0(prefix, name, "_")
      }
      out <- c(out, flatten_columns(field$base, inner, here))
    } else {
      out[[length(out) + 1L]] <- list(name = paste0(prefix, name), path = here, type = "list")
    }
  }
  out
}

pluck_path <- function(x, path) {
  for (name in path) {
    if (is.null(x)) {
      return(NULL)
    }
    x <- x[[name]]
  }
  x
}

rows_to_tibble <- function(rows, schema) {
  columns <- schema_columns(schema)
  data <- lapply(columns, function(column) {
    values <- lapply(rows, pluck_path, column$path)
    if (column$type == "list") {
      return(values)
    }
    missing <- typed_na(column$type)
    values <- lapply(values, function(v) if (is.null(v)) missing else v)
    combine_scalars(values, column$type)
  })
  names(data) <- vapply(columns, `[[`, "", "name")
  tibble::new_tibble(data, nrow = length(rows))
}
