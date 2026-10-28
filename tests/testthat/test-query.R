test_that("values are percent-encoded with RFC 3986 rules", {
  encode <- ensembleweather:::encode_component
  expect_identical(encode("Mt. Hood & co/ñ"), "Mt.%20Hood%20%26%20co%2F%C3%B1")
  expect_identical(encode("A-Za-z0-9-._~"), "A-Za-z0-9-._~")
  expect_identical(encode("a+b:c,d"), "a%2Bb%3Ac%2Cd")
  expect_identical(encode(""), "")
})

test_that("numbers are the shortest round-trip decimal, without an exponent", {
  fmt <- ensembleweather:::format_number
  expect_identical(fmt(1661), "1661")
  expect_identical(fmt(1661.0), "1661")
  expect_identical(fmt(45.3311), "45.3311")
  expect_identical(fmt(-121.6649), "-121.6649")
  expect_identical(fmt(0.1), "0.1")
  expect_identical(fmt(1 / 3), "0.3333333333333333")
  expect_identical(fmt(1.5e-7), "0.00000015")
  expect_identical(fmt(-0), "0")
  expect_identical(fmt(1e20 + 2^20), "100000000000001050000") # shortest round-trip digits
  expect_error(fmt(NaN), class = "ensembleweather_error_usage")
  expect_error(fmt(Inf), class = "ensembleweather_error_usage")
})

test_that("the query is sorted, defaults are omitted and booleans are true/false", {
  q <- ensembleweather:::new_query()
  q <- ensembleweather:::query_add(q, "units", "imperial", "metric")
  q <- ensembleweather:::query_add(q, "max_hours", 24, 24)
  q <- ensembleweather:::query_add(q, "include_past", TRUE, FALSE)
  q <- ensembleweather:::query_add(q, "nowcast", TRUE, TRUE)
  q <- ensembleweather:::query_add_list(q, "capability", c("swe", "snow_depth", "swe"))
  q <- ensembleweather:::query_add_list(q, "sources", c("ski resort", "gefs"))
  q <- ensembleweather:::query_add_list(q, "feels_like", "nws", "nws")
  q <- ensembleweather:::query_add_raw(q, "prob", "snowfall:ge:6.000:24h")
  # A comma list is sorted, de-duplicated and joined by a literal "," (else a 301).
  expect_identical(
    ensembleweather:::query_render(q),
    paste0(
      "capability=snow_depth,swe&include_past=true&prob=snowfall:ge:6.000:24h",
      "&sources=gefs,ski%20resort&units=imperial"
    )
  )
})

test_that("parameter names sort in C-locale byte order, whatever the session locale", {
  q <- ensembleweather:::new_query()
  for (name in c("snowfall", "snow_level", "Zeta", "alpha")) {
    q <- ensembleweather:::query_add(q, name, "x")
  }
  expect_identical(ensembleweather:::query_render(q), "Zeta=x&alpha=x&snow_level=x&snowfall=x")
})

test_that("timestamps are sent in UTC", {
  when <- as.POSIXct("2026-11-15 04:00:00", tz = "America/Los_Angeles")
  expect_identical(ensembleweather:::format_datetime(when), "2026-11-15T12:00:00Z")
})

test_that("a location is two percent-encoded path segments", {
  path <- ensembleweather:::location_path
  expect_identical(path("OR/mt-hood-meadows"), "/api/v1/locations/or/mt-hood-meadows")
  expect_identical(path("oregon/mt-hood-meadows"), "/api/v1/locations/oregon/mt-hood-meadows")
  expect_identical(path(list(state = "or", slug = "a b")), "/api/v1/locations/or/a%20b")
  row <- tibble::tibble(state = "or", slug = "x", name = "X")
  expect_identical(path(row, "/current"), "/api/v1/locations/or/x/current")
  expect_error(path("mt-hood-meadows"), class = "ensembleweather_error_usage")
  expect_error(path("or/a/b"), class = "ensembleweather_error_usage")
  expect_error(path(tibble::tibble(state = c("or", "wa"), slug = c("a", "b"))), class = "ensembleweather_error_usage")
})

test_that("redirect targets resolve against the answering URL", {
  resolve <- ensembleweather:::resolve_url
  base <- "https://api.test/ourea/api/v1/locations/oregon/x?units=imperial"
  expect_identical(resolve(base, "/api/v1/locations/or/x"), "https://api.test/api/v1/locations/or/x")
  expect_identical(resolve(base, "https://other.test/y"), "https://other.test/y")
  expect_identical(resolve(base, "//cdn.test/z"), "https://cdn.test/z")
  expect_identical(resolve(base, "x2"), "https://api.test/ourea/api/v1/locations/oregon/x2")
  origin <- ensembleweather:::url_origin
  expect_identical(origin("https://API.test/a"), origin("https://api.test:443/b"))
  expect_false(identical(origin("https://api.test"), origin("http://api.test")))
})
