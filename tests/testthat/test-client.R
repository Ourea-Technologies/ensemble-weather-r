metric <- function() {
  list(
    status = 200L,
    headers = list(`Content-Type` = "application/json", ETag = "\"v1\""),
    body_raw = readBin(
      file.path(local_spec(), "vectors", "bodies", "forecast-metric.json"), "raw",
      file.size(file.path(local_spec(), "vectors", "bodies", "forecast-metric.json"))
    )
  )
}

test_that("the forecast is tibbles of quantiles, one row per hour", {
  local_quiet_client_env()
  local_replay(list(metric()))
  fc <- ew_forecast("or/mt-hood-meadows", client = ew_client(cache = FALSE))
  expect_s3_class(fc, "ensembleweather_forecast")
  hours <- fc$series$timeseries
  expect_s3_class(hours, "tbl_df")
  expect_identical(nrow(hours), 3L)
  expect_identical(hours$temperature_p50, c(-2, -1, 0))
  expect_s3_class(hours$valid_time, "POSIXct")
  expect_identical(attr(hours$valid_time, "tzone"), "UTC")
  # Wind direction is the circular distribution: a sector crossing north
  # (from above to) is passed through, not "fixed".
  expect_identical(hours$wind_direction_mean[[1]], 5)
  expect_identical(hours$wind_direction_sector_50_from[[1]], 355)
  expect_identical(hours$wind_direction_sector_50_to[[1]], 15)
  expect_false("wind_direction_p50" %in% names(hours))
  # A statistic the server did not send is absent (NA), never 0.
  expect_true(is.na(hours$temperature_probability[[1]]))
  expect_null(fc$probabilities)
  expect_null(fc$window_totals)
  expect_identical(tibble::as_tibble(fc), hours)
  expect_output(print(fc), "Mt. Hood Meadows")
})

test_that("stuttering wire names decode to the BEHAVIOR.md 3.0 names", {
  local_quiet_client_env()
  local_replay(list(json_response(read_body("forecast-full.json"))))
  fc <- ew_forecast("or/mt-hood-meadows", members = TRUE, client = ew_client(cache = FALSE))
  expect_false(any(c("forecast", "elevation_forecasts") %in% names(fc)))
  expect_s3_class(fc$elevations, "tbl_df")
  expect_true("height" %in% names(fc$elevations))
  members <- fc$series$timeseries$members[[1]]
  expect_true(all(c("id", "items") %in% names(members)))
  expect_true("id" %in% names(members$items[[1]]))
  expect_false("member_id" %in% names(members$items[[1]]))
  expect_true(all(c("code", "text", "icon") %in% names(fc$current)))
  # Fields that only look alike keep their wire names.
  expect_true("lead_time_hours" %in% names(fc$series$timeseries))
  expect_true("precipitation_type_type" %in% names(fc$series$timeseries))
})

test_that("members takes TRUE, FALSE or \"plume\", and plume is columns", {
  local_quiet_client_env()
  replay <- local_replay(list(json_response(read_body("forecast-plume.json"))))
  fc <- ew_forecast("or/mt-hood-meadows", members = "plume", client = ew_client(cache = FALSE))
  expect_match(replay$requests[[1]]$url, "members=plume", fixed = TRUE)
  expect_type(fc$series$plume$headline$temperature, "double")
  expect_output(print(fc), "plume")
  expect_error(ew_forecast("or/mt-hood-meadows", members = "all"), class = "ensembleweather_error_usage")
  expect_error(ew_forecast("or/mt-hood-meadows", members = NA), class = "ensembleweather_error_usage")
})

test_that("near and bbox are numbers, sent with literal commas, and checked", {
  local_quiet_client_env()
  replay <- local_replay(list(
    json_response(read_body("explore.json")),
    json_response(read_body("alert-outlines.json"))
  ))
  client <- ew_client(cache = FALSE)
  ew_explore_page("snow_5d", near = list(lon = -121.66, lat = 45.33), client = client)
  expect_match(replay$requests[[1]]$url, "near=45.33,-121.66", fixed = TRUE)
  ew_alert_outlines(bbox = c(north = 49, east = -116, south = 41, west = -125), client = client)
  expect_match(replay$requests[[2]]$url, "bbox=-125,41,-116,49", fixed = TRUE)
  usage <- "ensembleweather_error_usage"
  expect_error(ew_explore_page("snow_5d", near = "45.33,-121.66"), class = usage)
  expect_error(ew_explore_page("snow_5d", near = c(91, 0)), class = usage)
  expect_error(ew_explore_page("snow_5d", near = c(45, 181)), class = usage)
  expect_error(ew_explore_page("snow_5d", near = c(45, -121), radius_km = 0), class = usage)
  expect_error(ew_explore_page("snow_5d", near = c(45, -121), radius_km = 1001), class = usage)
  expect_error(ew_alert_outlines(bbox = c(-116, 41, -125, 49)), class = usage)
  expect_error(ew_alert_outlines(bbox = c(-125, 49, -116, 41)), class = usage)
  expect_error(ew_alert_outlines(bbox = c(-125, 41, -116)), class = usage)
  expect_error(ew_alert_outlines(bbox = c(-125, 41, -116, NA)), class = usage)
  expect_error(ew_explore_page(metric = NULL), class = usage)
})

test_that("GeoJSON is passed through untouched", {
  local_quiet_client_env()
  body <- read_body("avalanche-zones.json")
  local_replay(list(json_response(body)))
  zones <- ew_avalanche_zones(client = ew_client(cache = FALSE))
  expect_s3_class(zones, "ensembleweather_geojson")
  expect_equal(unclass(zones)[names(body)], body) # the integral numbers may read back as integers
  expect_identical(zones$features[[2]]$properties$forecast_url, body$features[[2]]$properties$forecast_url)
  expect_output(print(zones), "FeatureCollection")
})

test_that("a snow-trend day the run has no value for is a row of NAs", {
  local_quiet_client_env()
  body <- read_body("snow-trend.json")
  body$grids[[1]]$runs[[1]]$days <- c(list(NULL), body$grids[[1]]$runs[[1]]$days)
  local_replay(list(json_response(body)))
  trend <- ew_snow_trend("or/mt-hood-meadows", client = ew_client(cache = FALSE))
  days <- trend$grids$runs[[1]]$days[[1]]
  expect_identical(nrow(days), length(body$grids[[1]]$runs[[1]]$days))
  expect_true(is.na(days$amount[[1]]))
  expect_true(is.na(days$date[[1]]))
})

test_that("PLUS_REQUIRED is a permission error", {
  local_quiet_client_env()
  local_replay(list(json_response(
    list(error = "PLUS_REQUIRED", message = "Snow trend needs Plus or Pro."),
    status = 403L
  )))
  expect_error(
    ew_snow_trend("or/mt-hood-meadows", client = ew_client(cache = FALSE)),
    class = "ensembleweather_error_permission"
  )
})

test_that("a present probabilities list without an answer for a term is an error", {
  local_quiet_client_env()
  body <- read_body("forecast-prob-snow.json")
  body$probabilities <- body$probabilities[1]
  local_replay(list(json_response(body)))
  expect_error(
    ew_forecast(
      "or/mt-hood-meadows",
      units = "imperial",
      prob = list(ew_chance("snowfall", ">=", 6, "in"), ew_chance("snowfall", ">=", 12, "in")),
      client = ew_client(cache = FALSE)
    ),
    class = "ensembleweather_error_unexpected_response"
  )
})

test_that("a missing required field is an unexpected response, not a silent NA", {
  local_quiet_client_env()
  body <- read_body("forecast-metric.json")
  body$location$slug <- NULL
  local_replay(list(json_response(body)))
  expect_error(
    ew_forecast("or/mt-hood-meadows", client = ew_client(cache = FALSE)),
    "location.slug",
    class = "ensembleweather_error_unexpected_response"
  )
})

test_that("a non-JSON success body is an unexpected response", {
  local_quiet_client_env()
  local_replay(list(list(status = 200L, headers = list(`Content-Type` = "text/html"), body = "<html>")))
  expect_error(ew_attribution(client = ew_client(cache = FALSE)), class = "ensembleweather_error_unexpected_response")
})

test_that("the client never shows its key", {
  client <- ew_client(api_key = "ow_secret_value")
  expect_false(any(grepl("ow_secret_value", utils::capture.output(print(client)))))
  expect_false(any(grepl("ow_secret_value", utils::capture.output(str(client)))))
  expect_false(any(grepl("ow_secret_value", format(client))))
  expect_false(any(grepl("ow_secret_value", ls(client))))
})

test_that("configuration is validated", {
  usage <- "ensembleweather_error_usage"
  expect_error(ew_client(units = "si"), class = usage)
  expect_error(ew_client(timeout = 0), class = usage)
  expect_error(ew_client(max_retries = -1), class = usage)
  expect_error(ew_client(base_url = "ftp://x"), class = usage)
  expect_error(ew_client(cache = "yes"), class = usage)
  expect_error(ew_client(user_agent = "a\nb"), class = usage)
  expect_error(ew_forecast("or/x", client = list()), class = usage)
  expect_error(ew_forecast("or/x", "extra"), class = "rlib_error_dots_nonempty")
})

test_that("the default client follows the environment", {
  local_quiet_client_env()
  withr::local_envvar(OUREA_BASE_URL = "http://stub.test/")
  expect_identical(ensembleweather:::default_client()$base_url, "http://stub.test")
  first <- ensembleweather:::default_client()
  expect_identical(ensembleweather:::default_client(), first)
  withr::local_envvar(OUREA_API_KEY = "ow_new")
  expect_false(identical(ensembleweather:::default_client(), first))
})

test_that("the User-Agent names the SDK and appends the app's token", {
  ua <- ensembleweather:::sdk_user_agent("my-app/1.2")
  expect_match(ua, "^ensemble-weather-r/0\\.1\\.0 \\(R/[0-9.]+\\) my-app/1\\.2$")
})

test_that("a connection failure is retried, then raised as a connection error", {
  local_quiet_client_env()
  delays <- numeric()
  local_mocked_bindings(
    sleep_for = function(s) delays <<- c(delays, s),
    jitter_fraction = function() 1,
    .package = "ensembleweather"
  )
  attempts <- 0L
  httr2::local_mocked_responses(function(req) {
    attempts <<- attempts + 1L
    rlang::abort("Failed to perform HTTP request.", class = "httr2_failure", parent = simpleError("reset"))
  })
  err <- tryCatch(ew_attribution(client = ew_client(cache = FALSE)), error = identity)
  expect_s3_class(err, "ensembleweather_error_connection")
  expect_identical(attempts, 3L)
  expect_identical(delays, c(0.5, 1))
})

test_that("a TLS verification failure is never retried", {
  local_quiet_client_env()
  attempts <- 0L
  httr2::local_mocked_responses(function(req) {
    attempts <<- attempts + 1L
    tls <- structure(
      class = c("curl_error_peer_failed_verification", "curl_error", "error", "condition"),
      list(message = "SSL certificate problem", call = NULL)
    )
    rlang::abort("Failed to perform HTTP request.", class = "httr2_failure", parent = tls)
  })
  expect_error(ew_attribution(client = ew_client(cache = FALSE)), class = "ensembleweather_error_connection")
  expect_identical(attempts, 1L)
})

test_that("bodies are bounded at 64 MiB", {
  local_quiet_client_env()
  replay <- local_replay(list(list(
    status = 200L,
    headers = list(`Content-Type` = "application/json", `Content-Length` = format(65 * 1024^2, scientific = FALSE)),
    body = "{}"
  )))
  expect_error(
    ew_attribution(client = ew_client(cache = FALSE)),
    class = "ensembleweather_error_response_too_large"
  )
  expect_identical(replay$requests[[1]]$options$maxfilesize_large, 64 * 1024^2)
  # curl enforces the same bound while reading, and the SDK never follows
  # redirects inside curl (it follows them itself, dropping the key off-host).
  expect_false(replay$requests[[1]]$options$followlocation)
})

test_that("more than five redirects is an error", {
  local_quiet_client_env()
  hop <- list(status = 302L, headers = list(Location = "/api/v1/attribution"))
  replay <- local_replay(rep(list(hop), 6))
  expect_error(ew_attribution(client = ew_client(cache = FALSE)), class = "ensembleweather_error_unexpected_response")
  expect_length(replay$requests, 6L)
})

test_that("Retry-After as an HTTP-date is honoured", {
  local_quiet_client_env()
  local_mocked_bindings(now = function() as.POSIXct("2027-12-01 00:00:00", tz = "UTC"), .package = "ensembleweather")
  expect_identical(ensembleweather:::parse_retry_after("Wed, 01 Dec 2027 00:00:05 GMT"), 5)
  expect_identical(ensembleweather:::parse_retry_after("7"), 7)
  expect_null(ensembleweather:::parse_retry_after("soon"))
})

test_that("a fresh cached entry (max-age > 0) is served without a request", {
  local_quiet_client_env()
  ok <- metric()
  ok$headers$`Cache-Control` <- "private, max-age=600"
  replay <- local_replay(list(ok))
  client <- ew_client()
  ew_forecast("or/mt-hood-meadows", client = client)
  again <- ew_forecast("or/mt-hood-meadows", client = client)
  expect_length(replay$requests, 1L)
  expect_true(ew_response_info(again)$from_cache)
  expect_false(ew_response_info(again)$revalidated)
})

test_that("s-maxage is for the edge: the client still revalidates", {
  local_quiet_client_env()
  ok <- metric()
  ok$headers$`Cache-Control` <- "public, max-age=0, s-maxage=3600, stale-while-revalidate=60"
  replay <- local_replay(list(ok, list(status = 304L, headers = list(ETag = "\"v1\""))))
  client <- ew_client()
  ew_forecast("or/mt-hood-meadows", client = client)
  again <- ew_forecast("or/mt-hood-meadows", client = client)
  expect_length(replay$requests, 2L)
  expect_identical(request_header(replay$requests[[2]], "If-None-Match"), "\"v1\"")
  expect_true(ew_response_info(again)$revalidated)
})

test_that("a retried request keeps its If-None-Match", {
  local_quiet_client_env()
  local_mocked_bindings(sleep_for = function(s) NULL, .package = "ensembleweather")
  replay <- local_replay(list(
    metric(),
    list(status = 503L, headers = list(`Content-Type` = "text/plain"), body = "busy"),
    list(status = 304L, headers = list(ETag = "\"v1\""))
  ))
  client <- ew_client()
  ew_forecast("or/mt-hood-meadows", client = client)
  ew_forecast("or/mt-hood-meadows", client = client)
  expect_identical(request_header(replay$requests[[2]], "If-None-Match"), "\"v1\"")
  expect_identical(request_header(replay$requests[[3]], "If-None-Match"), "\"v1\"")
})

test_that("a 504 with Retry-After waits exactly that long (BEHAVIOR 9)", {
  local_quiet_client_env()
  slept <- c()
  local_mocked_bindings(sleep_for = function(s) slept <<- c(slept, s), .package = "ensembleweather")
  local_replay(list(
    list(
      status = 504L, headers = list(`Content-Type` = "application/json", `Retry-After` = "5"),
      body = '{"error": "TIMEOUT", "message": "Timed out."}'
    ),
    json_response(read_body("attribution.json"))
  ))
  ew_attribution(client = ew_client(cache = FALSE))
  expect_identical(slept, 5)
})

test_that("the memory cache is a bounded LRU", {
  cache <- ew_memory_cache(max_entries = 2, max_bytes = 100)
  entry <- function(n) list(body = as.raw(seq_len(n) %% 256), headers = list())
  cache$set("a", entry(10))
  cache$set("b", entry(10))
  cache$get("a")
  cache$set("c", entry(10))
  expect_null(cache$get("b"))
  expect_false(is.null(cache$get("a")))
  cache$set("big", entry(200))
  expect_null(cache$get("big"))
  cache$set("d", entry(60))
  cache$set("e", entry(60))
  expect_identical(cache$size(), 1L)
  expect_output(print(cache), "1 entries")
})

test_that("a cachem-style cache can be plugged in", {
  local_quiet_client_env()
  store <- new.env()
  cache <- list(
    get = function(key) if (exists(key, store)) get(key, store) else structure(list(), class = "key_missing"),
    set = function(key, value) assign(key, value, envir = store),
    remove = function(key) if (exists(key, store)) rm(list = key, envir = store)
  )
  replay <- local_replay(list(metric(), list(status = 304L, headers = list(ETag = "\"v1\""))))
  client <- ew_client(cache = cache)
  ew_forecast("or/mt-hood-meadows", client = client)
  expect_true(all(grepl("^[0-9a-f]{64}$", ls(store))))
  ew_forecast("or/mt-hood-meadows", client = client)
  expect_identical(request_header(replay$requests[[2]], "If-None-Match"), "\"v1\"")
})
