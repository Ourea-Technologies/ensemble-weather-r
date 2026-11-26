# Runs every shared vector in spec/vectors/ (BEHAVIOR.md section 13) over a
# mocked transport (httr2::local_mocked_responses), with the retry sleep and
# jitter replaced, so nothing touches the network or waits. A vector this
# runner cannot execute fails; none is skipped.
#
# The only per-language code is `vector_call()`, which maps a vector's
# semantic operation and arguments onto this package's functions, and
# `vector_value()`, which maps a result path onto the R result.

expected_vector_count <- 58L

vector_files <- function() {
  dir <- file.path(local_spec(), "vectors")
  files <- list.files(dir, pattern = "\\.json$", recursive = TRUE, full.names = TRUE)
  sort(files[!grepl("/bodies/", files, fixed = TRUE)])
}

operation_functions <- c(
  getLocationForecast = "ew_forecast",
  getPointForecast = "ew_get_point_forecast",
  getCurrentConditions = "ew_current",
  getCurrentByCoordinates = "ew_get_point_current",
  getLocationAlerts = "ew_alerts",
  getAlertsByCoordinates = "ew_get_point_alerts",
  getNearbyLocations = "ew_nearby",
  getNearbyByCoordinates = "ew_get_point_nearby",
  searchLocations = "ew_search",
  getAllLocations = "ew_locations_page",
  getLocations = "ew_locations_page",
  listCatalogLocations = "ew_catalog_locations_page",
  getCatalogLocation = "ew_catalog_location",
  listCatalogStations = "ew_catalog_stations_page",
  getCatalogStation = "ew_catalog_station",
  getAvailableRuns = "ew_runs",
  getAttribution = "ew_attribution",
  explore = "ew_explore_page",
  getComposition = "ew_composition",
  getLocationSeason = "ew_season",
  getLocationSnowTrend = "ew_snow_trend",
  getLocationSnowpack = "ew_snowpack",
  getLocationSnowpackPlume = "ew_snowpack_plume",
  getAlertOutlines = "ew_alert_outlines",
  getAvalancheZones = "ew_avalanche_zones"
)

# `iterate: true` uses the function that collects every page.
collecting_functions <- c(
  ew_locations_page = "ew_locations",
  ew_catalog_locations_page = "ew_catalog_locations",
  ew_catalog_stations_page = "ew_catalog_stations",
  ew_explore_page = "ew_explore"
)

vector_window <- function(window) {
  if (is.null(window)) {
    return(24)
  }
  if (!is.null(window$hours)) window$hours else c(window$start_hours, window$end_hours)
}

vector_call <- function(call, client) {
  fn <- operation_functions[[call$operation]]
  args <- call$args %||% list()
  if (isTRUE(args$iterate)) {
    fn <- collecting_functions[[fn]]
  }
  args$iterate <- NULL
  # A named location is `location` here; on explore, `state` is a filter.
  if (!is.null(args$state) && !is.null(args$slug)) {
    args$location <- list(state = args$state, slug = args$slug)
    args$state <- NULL
    args$slug <- NULL
  }
  # JSON arrays of strings are character vectors; `near` and `bbox` are
  # numbers by name.
  for (name in names(args)) {
    value <- args[[name]]
    if (is.list(value) && is.null(names(value)) && all(vapply(value, is.character, TRUE))) {
      args[[name]] <- unlist(value)
    } else if (name %in% c("near", "bbox")) {
      args[[name]] <- unlist(value)
    }
  }
  if (!is.null(args$prob)) {
    args$prob <- lapply(call$args$prob, function(term) {
      ew_chance(
        term$variable, term$op, term$threshold$value, term$threshold$unit,
        window = vector_window(term$window), aggregation = term$aggregation
      )
    })
  }
  if (!is.null(args$totals)) {
    args$totals <- lapply(call$args$totals, function(t) ew_total(t$variable, vector_window(t$window)))
  }
  args$client <- client
  do.call(fn, args, envir = asNamespace("ensembleweather"))
}

# One row of a tibble as a named list: a list-column gives its element.
tibble_row <- function(table, row) {
  if (row > nrow(table)) {
    return(NULL)
  }
  out <- lapply(table, function(column) column[[row]])
  names(out) <- names(table)
  out
}

# Follow one name. A tibble row's nested object is spread over
# `<name>_<field>` columns, so a name that is not a column gathers those;
# a window total's quantiles are its bare `mean` ... `max` columns; the
# hourly series' `ensemble` is inlined; a list result's other response
# fields are its attributes.
vector_field <- function(value, name) {
  if (is.data.frame(value)) {
    if (name == "items") {
      return(value)
    }
    if (name == "count") {
      return(nrow(value))
    }
    return(attr(value, name, exact = TRUE))
  }
  if (!is.list(value)) {
    return(NULL)
  }
  fields <- names(value)
  if (name %in% fields) {
    return(value[[name]])
  }
  prefix <- paste0(name, "_")
  nested <- startsWith(fields %||% character(), prefix)
  if (any(nested)) {
    out <- value[nested]
    names(out) <- substring(fields[nested], nchar(prefix) + 1L)
    return(out)
  }
  stats <- c("mean", "p10", "p25", "p50", "p75", "p90", "min", "max")
  if (name == "quantiles" && all(stats %in% fields)) {
    out <- value[stats]
    return(if (all(is.na(unlist(out)))) NULL else out)
  }
  if (name == "ensemble") {
    return(value)
  }
  attr(value, name, exact = TRUE)
}

# A result path ("series.timeseries[0].members[0].items[0].id") over the R
# result: `[i]` takes a tibble's row, a list's element or a vector's item.
vector_value <- function(result, path) {
  tokens <- regmatches(path, gregexpr("[^.\\[\\]]+|\\[[0-9]+\\]", path, perl = TRUE))[[1]]
  if (tokens[[1]] == "revalidated") {
    return(ew_response_info(result)$revalidated)
  }
  if (tokens[[1]] == "rate_limit") {
    return(ew_rate_limit(result)[[tokens[[2]]]])
  }
  value <- result
  for (token in tokens) {
    if (is.null(value)) {
      return(NULL)
    }
    if (startsWith(token, "[")) {
      index <- as.integer(gsub("\\D", "", token)) + 1L
      if (is.data.frame(value)) {
        value <- tibble_row(value, index)
      } else {
        value <- if (index <= length(value)) value[[index]] else NULL
      }
    } else {
      value <- vector_field(value, token)
    }
  }
  value
}

known_location_types <- c(
  "airport", "backcountry", "beach_coast", "campground", "city_town", "climbing_area",
  "coastal_point", "event_venue", "fire_lookout", "fishing_river_access", "golf_course",
  "hot_spring", "lake", "mountain_pass", "national_park", "observation_station", "other",
  "park", "recreation_area", "reservoir_lake", "scenic_tourist", "ski_area", "state_park",
  "summit", "trailhead", "volcano", "waterfall", "wine_agritourism"
)

expect_vector_value <- function(actual, expected, label) {
  if (is.null(expected)) {
    absent <- is.null(actual) || (length(actual) == 1L && is.na(actual))
    expect_true(absent, label = paste(label, "is absent"))
  } else if (is.list(expected) && identical(names(expected), "unknown")) {
    # Enumerations are strings: an unknown value keeps its raw string.
    expect_identical(actual, expected$unknown, label = label)
    expect_false(actual %in% known_location_types, label = paste(label, "is not a known value"))
  } else if (is.character(expected) && inherits(actual, "POSIXct")) {
    # A timestamp matches the expected string as an instant (BEHAVIOR 13).
    expect_equal(actual, ensembleweather:::parse_timestamp(expected, label), label = label)
  } else if (is.logical(expected)) {
    expect_identical(actual, expected, label = label)
  } else if (is.numeric(expected)) {
    expect_true(is.numeric(actual) && length(actual) == 1L && !is.na(actual), label = paste(label, "is a number"))
    expect_equal(as.double(actual), as.double(expected), tolerance = 1e-12, label = label)
  } else {
    expect_identical(actual, expected, label = label)
  }
}

expect_vector_request <- function(request, expected, label) {
  if (!is.null(expected$method)) {
    expect_identical(request$method, expected$method, label = label)
  }
  if (!is.null(expected$path)) {
    expect_identical(url_path(request$url), expected$path, label = paste(label, "path"))
  }
  if (!is.null(expected$url_prefix)) {
    expect_true(startsWith(request$url, expected$url_prefix), label = paste(label, "url prefix"))
  }
  raw_query <- url_query(request$url)
  if (!is.null(expected$query_string)) {
    expect_identical(raw_query, expected$query_string, label = paste(label, "query string"))
  }
  pairs <- if (nzchar(raw_query)) strsplit(strsplit(raw_query, "&", fixed = TRUE)[[1]], "=", fixed = TRUE) else list()
  names <- vapply(pairs, function(p) utils::URLdecode(p[[1]]), "")
  values <- vapply(pairs, function(p) if (length(p) > 1L) utils::URLdecode(p[[2]]) else "", "")
  expect_false(anyDuplicated(names) > 0L, label = paste(label, "has a repeated parameter"))
  for (name in names(expected$query)) {
    expect_true(name %in% names, label = paste(label, "has", name))
    expect_identical(values[names == name][1], expected$query[[name]], label = paste(label, name))
  }
  for (name in unlist(expected$query_absent)) {
    expect_false(name %in% names, label = paste(label, "has no", name))
  }
  for (name in names(expected$headers)) {
    expect_identical(request_header(request, name), expected$headers[[name]], label = paste(label, "header", name))
  }
  for (name in unlist(expected$headers_absent)) {
    expect_null(request_header(request, name), label = paste(label, "header", name, "absent"))
  }
  for (name in names(expected$headers_match)) {
    value <- request_header(request, name) %||% ""
    expect_true(grepl(expected$headers_match[[name]], value, perl = TRUE), label = paste(label, "header", name))
  }
}

replay_responses <- function(case, dir) {
  lapply(case$responses %||% list(), function(spec) {
    if (!is.null(spec$body_file)) {
      spec$body_raw <- readBin(file.path(dir, spec$body_file), "raw", file.size(file.path(dir, spec$body_file)))
    }
    spec
  })
}

run_vector <- function(path) {
  dir <- file.path(local_spec(), "vectors")
  case <- jsonlite::read_json(path, simplifyVector = FALSE)
  local_quiet_client_env()
  env <- case$client$env %||% list()
  if (length(env) > 0L) {
    withr::local_envvar(unlist(env))
  }
  delays <- numeric()
  local_mocked_bindings(
    sleep_for = function(seconds) delays <<- c(delays, seconds),
    jitter_fraction = function() 1,
    .package = "ensembleweather"
  )
  replay <- local_replay(replay_responses(case, dir))

  spec <- case$client %||% list()
  cache <- if (isFALSE(spec$cache)) FALSE else ew_memory_cache()
  make_client <- function(api_key = spec$api_key) {
    ew_client(
      api_key = api_key,
      base_url = spec$base_url,
      max_retries = spec$max_retries %||% 2L,
      cache = cache,
      send_key_on_open_routes = isTRUE(spec$send_key_on_open_routes)
    )
  }
  main <- make_client()
  results <- list()
  error <- NULL
  warnings <- list()
  calls <- case$calls %||% list(case$call)
  withCallingHandlers(
    error <- tryCatch(
      {
        for (call in calls) {
          client <- if (!is.null(call$with_api_key)) make_client(call$with_api_key) else main
          results[[length(results) + 1L]] <- vector_call(call, client)
        }
        NULL
      },
      ensembleweather_error = function(cnd) cnd
    ),
    ensembleweather_deprecation = function(cnd) {
      warnings[[length(warnings) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )

  expect <- case$expect %||% list()
  if (!is.null(expect$error)) {
    expect_s3_class(error, "ensembleweather_error")
    expect_s3_class(error, paste0("ensembleweather_error_", expect$error$category))
    expect_identical(error$category, expect$error$category)
    for (field in intersect(c("code", "status", "retry_after"), names(expect$error))) {
      expect_vector_value(error[[field]], expect$error[[field]], field)
    }
    secret <- expect$error$string_excludes
    if (!is.null(secret)) {
      texts <- c(conditionMessage(error), format(error), utils::capture.output(print(error)))
      expect_false(any(grepl(secret, texts, fixed = TRUE)), label = "the key appears in the error")
      fields <- unlist(lapply(unclass(error), function(f) if (is.character(f)) f))
      expect_false(any(grepl(secret, fields, fixed = TRUE)), label = "the key appears in an error field")
    }
  } else if (!is.null(error)) {
    stop(error)
  }

  requests <- replay$requests
  if ("expect_request" %in% names(case)) {
    if (is.null(case$expect_request)) {
      expect_length(requests, 0L)
    } else {
      expect_gt(length(requests), 0L)
      for (i in seq_along(requests)) {
        expect_vector_request(requests[[i]], case$expect_request, paste("request", i))
      }
    }
  }
  if (!is.null(case$expect_requests)) {
    expect_length(requests, length(case$expect_requests))
    for (i in seq_along(case$expect_requests)) {
      expect_vector_request(requests[[i]], case$expect_requests[[i]], paste("request", i))
    }
  }
  if (!is.null(expect$requests)) {
    expect_length(requests, expect$requests)
  }
  if ("delays_s" %in% names(expect)) {
    expect_equal(delays, as.double(unlist(expect$delays_s)) %||% numeric())
  }
  checks <- if (!is.null(expect$result)) list(expect$result) else expect$results
  if (!is.null(expect$results)) {
    expect_length(results, length(expect$results))
  }
  for (i in seq_along(checks)) {
    for (path in names(checks[[i]])) {
      expect_vector_value(vector_value(results[[i]], path), checks[[i]][[path]], path)
    }
  }
  if (!is.null(expect$items)) {
    expect_identical(results[[length(results)]]$slug, unlist(expect$items))
  }
  expected_warnings <- expect$warnings %||% list()
  expect_length(warnings, length(expected_warnings))
  for (i in seq_along(expected_warnings)) {
    expect_match(conditionMessage(warnings[[i]]), expected_warnings[[i]]$contains, fixed = TRUE)
  }
}

test_that("every shared vector is collected", {
  expect_length(vector_files(), expected_vector_count)
})

for (path in tryCatch(vector_files(), condition = function(cnd) character())) {
  name <- sub("\\.json$", "", sub("^.*/vectors/", "", path))
  test_that(paste("vector", name), run_vector(path))
}
