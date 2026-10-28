category <- function(status, code = NULL) ensembleweather:::error_category(status, code)

test_that("errors map by code first, then by status", {
  expect_identical(category(400, "OUTSIDE_COVERAGE"), "outside_coverage")
  expect_identical(category(404, "OUTSIDE_COVERAGE"), "outside_coverage")
  expect_identical(category(401, "INVALID_API_KEY"), "authentication")
  expect_identical(category(403, "PRO_REQUIRED"), "permission")
  expect_identical(category(410), "not_found")
  expect_identical(category(404, "A_CODE_ADDED_LATER"), "not_found")
  expect_identical(category(400, "FEELS_LIKE_UNAVAILABLE"), "invalid_request") # retired: by status
  expect_identical(category(503, "AUTH_UNAVAILABLE"), "unavailable")
  expect_identical(category(429), "rate_limited")
  expect_identical(category(504), "unavailable")
  expect_identical(category(418), "api")
})

test_that("every error code in the spec maps to a category", {
  spec <- yaml::read_yaml(file.path(local_spec(), "openapi", "v1", "openapi.yaml"))
  codes <- unlist(spec$components$schemas$ErrorResponse$properties$error$enum)
  expect_gt(length(codes), 10L)
  for (code in codes) {
    expect_true(category(400, code) %in% c(names(ensembleweather:::error_codes), "invalid_request"))
  }
})

test_that("an API error carries status, code, request id, retry_after and its classes", {
  local_quiet_client_env()
  local_replay(list(list(
    status = 429L,
    headers = list(
      `Content-Type` = "application/json", `Retry-After` = "120", `X-Request-Id` = "req-123",
      `RateLimit-Limit` = "60", `RateLimit-Remaining` = "0", `RateLimit-Reset` = "30"
    ),
    body = '{"error": "TOO_MANY_REQUESTS", "message": "Slow down {please}."}'
  )))
  err <- tryCatch(ew_runs(client = ew_client(cache = FALSE)), error = identity)
  expect_s3_class(err, c("ensembleweather_error_rate_limited", "ensembleweather_error", "rlang_error"))
  expect_identical(err$status, 429L)
  expect_identical(err$code, "TOO_MANY_REQUESTS")
  expect_identical(err$request_id, "req-123")
  expect_identical(err$retry_after, 120)
  expect_identical(err$rate_limit$remaining, 0)
  expect_match(conditionMessage(err), "Slow down {please}.", fixed = TRUE)
  expect_match(conditionMessage(err), "req-123", fixed = TRUE)
  expect_match(format(err), "ew_runs", fixed = TRUE)
})

test_that("an error body's request id, doc_url, param and nearest location are carried", {
  local_quiet_client_env()
  local_replay(list(list(
    status = 403L,
    headers = list(`Content-Type` = "application/json", `X-Request-Id` = "header-id"),
    body = paste0(
      '{"error": "PRO_REQUIRED", "message": "Pro.", "request_id": "body-id", "param": "lat",',
      ' "doc_url": "https://docs.oureawx.com/features/errors/#pro_required",',
      ' "nearest_location": {"slug": "mt-hood-meadows", "url": "/api/v1/locations/or/mt-hood-meadows",',
      ' "distance_km": 4.25, "elevation_m": 1635.6}}'
    )
  )))
  err <- tryCatch(ew_forecast_at(45.33, -121.67, client = ew_client(cache = FALSE)), error = identity)
  expect_s3_class(err, "ensembleweather_error_permission")
  expect_identical(err$request_id, "body-id")
  expect_identical(err$doc_url, "https://docs.oureawx.com/features/errors/#pro_required")
  expect_identical(err$param, "lat")
  expect_identical(err$nearest_location$url, "/api/v1/locations/or/mt-hood-meadows")
  expect_identical(err$nearest_location$distance_km, 4.25)
})

test_that("a key echoed by a server never reaches the message", {
  local_quiet_client_env()
  local_replay(list(list(
    status = 401L, headers = list(`Content-Type` = "application/json"),
    body = '{"error": "INVALID_API_KEY", "message": "Key ow_leaky is not valid."}'
  )))
  err <- tryCatch(ew_runs(client = ew_client(api_key = "ow_leaky", cache = FALSE)), error = identity)
  expect_false(grepl("ow_leaky", conditionMessage(err), fixed = TRUE))
  expect_match(conditionMessage(err), "[redacted]", fixed = TRUE)
})

test_that("the deprecation warning is classed and names the link", {
  local_quiet_client_env()
  ok <- json_response(read_body("attribution.json"), headers = list(
    Sunset = "Wed, 01 Dec 2027 00:00:00 GMT",
    Link = "<https://docs.oureawx.com/changelog>; rel=\"deprecation\""
  ))
  local_replay(list(ok, ok))
  client <- ew_client(cache = FALSE)
  expect_warning(ew_attribution(client = client), "docs.oureawx.com/changelog", class = "ensembleweather_deprecation")
  expect_no_warning(ew_attribution(client = client))
})
