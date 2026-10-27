# Runs every shared vector in spec/vectors/ (BEHAVIOR.md section 13) over a
# mocked transport (httr2::local_mocked_responses), with the retry sleep and
# jitter replaced, so nothing touches the network or waits. A vector this
# runner cannot execute fails; none is skipped.
#
# The only per-language code is `vector_call()`, which maps a vector's
# semantic operation and arguments onto this package's functions, and
# `vector_value()`, which maps a result path onto the R result.

expected_vector_count <- 43L

vector_files <- function() {
  dir <- file.path(local_spec(), "vectors")
  files <- list.files(dir, pattern = "\\.json$", recursive = TRUE, full.names = TRUE)
  sort(files[!grepl("/bodies/", files, fixed = TRUE)])
}

operation_functions <- c(
  getLocationForecast = "ew_forecast",
  getPointForecast = "ew_forecast_at",
  getCurrentConditions = "ew_current",
  getCurrentByCoordinates = "ew_current_at",
  getLocationAlerts = "ew_alerts",
  getAlertsByCoordinates = "ew_alerts_at",
  getNearbyLocations = "ew_nearby",
  getNearbyByCoordinates = "ew_nearby_at",
  searchLocations = "ew_search",
  getAllLocations = "ew_locations_page",
  getLocations = "ew_locations_page",
  listCatalogLocations = "ew_catalog_locations_page",
  getCatalogLocation = "ew_catalog_location",
  listCatalogStations = "ew_catalog_stations_page",
  getCatalogStation = "ew_catalog_station",
  getAvailableRuns = "ew_runs",
  getStormReports = "ew_storm_reports",
  getStormReport = "ew_storm_report",
  getAttribution = "ew_attribution"
)

# `iterate: true` uses the function that collects every page.
collecting_functions <- c(
  ew_locations_page = "ew_locations",
  ew_catalog_locations_page = "ew_catalog_locations",
  ew_catalog_stations_page = "ew_catalog_stations"
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
  if (!is.null(args$state) && !is.null(args$name)) {
    args$location <- list(state = args$state, slug = args$name)
    args$state <- NULL
    args$name <- NULL
  }
  if (!is.null(args$prob)) {
    args$prob <- lapply(args$prob, function(term) {
      ew_chance(
        term$variable, term$op, term$threshold$value, term$threshold$unit,
        window = vector_window(term$window), aggregation = term$aggregation
      )
    })
  }
  if (!is.null(args$totals)) {
    args$totals <- lapply(args$totals, function(t) ew_total(t$variable, vector_window(t$window)))
  }
  args$client <- client
  do.call(fn, args, envir = asNamespace("ensembleweather"))
}

# Rename the vector's semantic path segments to this package's names.
vector_value <- function(result, path) {
  tokens <- regmatches(path, gregexpr("[^.\\[\\]]+|\\[[0-9]+\\]", path, perl = TRUE))[[1]]
  if (tokens[[1]] == "revalidated") {
    return(ew_response_info(result)$revalidated)
  }
  if (tokens[[1]] == "rate_limit") {
    return(ew_rate_limit(result)[[tokens[[2]]]])
  }
  # A forecast's hourly series is $hourly, one row per hour, with the
  # ensemble's quantiles as <variable>_<stat> columns.
  if (identical(tokens[1:2], c("forecast", "timeseries"))) {
    row <- as.integer(gsub("\\D", "", tokens[[3]])) + 1L
    rest <- tokens[-(1:3)]
    if (rest[[1]] == "ensemble") rest <- rest[-1]
    return(result$hourly[[paste(rest, collapse = "_")]][[row]])
  }
  # Probabilities and window totals are tibbles in the caller's order.
  if (tokens[[1]] %in% c("probabilities", "window_totals")) {
    table <- result[[tokens[[1]]]]
    row <- as.integer(gsub("\\D", "", tokens[[2]])) + 1L
    field <- paste(tokens[-(1:2)], collapse = ".")
    renamed <- c(window_start_hours = "window_start", window_end_hours = "window_end")
    if (field %in% names(renamed)) field <- renamed[[field]]
    if (startsWith(field, "quantiles")) {
      stat <- sub("^quantiles\\.?", "", field)
      if (!nzchar(stat)) {
        quantiles <- unlist(table[row, c("mean", "p10", "p25", "p50", "p75", "p90", "min", "max")])
        return(if (all(is.na(quantiles))) NULL else quantiles)
      }
      field <- stat
    }
    return(table[[field]][[row]])
  }
  # Search returns its hits as the tibble itself.
  if (tokens[[1]] == "count") {
    return(nrow(result))
  }
  if (tokens[[1]] == "items") {
    row <- as.integer(gsub("\\D", "", tokens[[2]])) + 1L
    return(result[[tokens[[3]]]][[row]])
  }
  value <- result
  for (token in tokens) {
    value <- value[[token]]
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
