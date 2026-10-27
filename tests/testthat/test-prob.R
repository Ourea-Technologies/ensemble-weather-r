test_that("rounding is half away from zero on v * 10^d in doubles, not base round()", {
  rounded <- ensembleweather:::format_rounded
  expect_identical(rounded(0.0625, 3L), "0.063")
  expect_identical(round(0.0625, 3), 0.062) # base R goes to even: the wrong answer here
  expect_identical(rounded(1.005, 2L), "1.00")
  expect_identical(rounded(2.5, 0L), "3")
  expect_identical(rounded(-2.5, 0L), "-3")
  expect_identical(rounded(-0.04, 1L), "0.0")
  expect_identical(rounded(-5, 1L), "-5.0")
  expect_identical(rounded(152.4, 2L), "152.40")
  expect_identical(rounded(1524.4, 0L), "1524")
  expect_identical(rounded(0.0004, 3L), "0.000")
})

test_that("thresholds are converted with the exact factors", {
  convert <- ensembleweather:::convert_threshold
  expect_identical(convert(6, "in", "mm"), 6 * 25.4) # 152.39999999999998: rounding makes it 152.40
  expect_identical(convert(32, "degF", "degC"), 0)
  expect_identical(convert(0, "degC", "K"), 273.15)
  expect_identical(convert(10, "mph", "m/s"), 4.4704)
  expect_identical(convert(1000, "ft", "m"), 304.8)
  expect_equal(convert(152.4, "mm", "in"), 6)
})

test_that("a chance serialises in the server's canonical order", {
  terms <- list(
    ew_chance("wind_speed", ">=", 15, "m/s", window = c(12, 36)),
    ew_chance("snow_level", "<=", 1524.4, "m"),
    ew_chance("temperature", "le", -5),
    ew_chance("temperature", "ge", -5),
    ew_chance("snow_level", "<=", 1524.4, "m")
  )
  wire <- ensembleweather:::prob_query(terms, "metric")
  expect_identical(
    wire$wire,
    "snow_level:le:1524:24h,temperature:ge:-5.0:24h,temperature:le:-5.0:24h,wind_speed:ge:15.0:12-36h"
  )
  expect_length(wire$keys, 5L)
})

test_that("the default aggregation is omitted and others are kept", {
  wire <- ensembleweather:::prob_query(list(
    ew_chance("temperature", "<=", 32, "degF", window = c(6, 18), aggregation = "all"),
    ew_chance("temperature", "<=", 0, aggregation = "any"),
    ew_chance("precipitation", ">=", 10, aggregation = "total")
  ), "metric")
  expect_identical(wire$wire, "precipitation:ge:10.00:24h,temperature:le:0.0:24h,temperature:le:0.0:6-18h:all")
})

test_that("invalid terms are refused before sending", {
  usage <- "ensembleweather_error_usage"
  expect_error(ew_chance("precipitation", ">=", 10, "mm", aggregation = "any"), class = usage)
  expect_error(ew_chance("temperature", ">=", 10, aggregation = "total"), class = usage)
  expect_error(ew_chance("snowfall", ">", 6), class = usage)
  expect_error(ew_chance("snowfall", ">=", 6, "degF"), class = usage)
  expect_error(ew_chance("humidity", ">=", 6), class = usage)
  expect_error(ew_chance("snowfall", ">=", NA_real_), class = usage)
  expect_error(ew_chance("snowfall", ">=", 6, window = 361), class = usage)
  expect_error(ew_chance("snowfall", ">=", 6, window = c(24, 12)), class = usage)
  expect_error(ew_chance("snowfall", ">=", 6, window = 1.5), class = usage)
  expect_error(ew_total("temperature", 24), class = usage)
  err <- tryCatch(ew_chance("snowfall", ">=", 6, aggregation = "any"), error = identity)
  expect_identical(err$category, "usage")
  expect_match(format(err), "ew_chance")
})

test_that("window totals are sorted and deduplicated", {
  wire <- ensembleweather:::totals_query(list(
    ew_total("snowfall", 240), ew_total("precipitation", c(24, 48)),
    ew_total("precipitation", 24), ew_total("snowfall", 240)
  ))
  expect_identical(wire$wire, "precipitation:24h,precipitation:24-48h,snowfall:240h")
})

test_that("terms print readably", {
  expect_output(print(ew_chance("snowfall", ">=", 6, "in")), "P\\(snowfall >= 6 in, hours 0-24\\)")
  expect_output(print(ew_total("snowfall", 72)), "snowfall total, hours 0-72")
})
