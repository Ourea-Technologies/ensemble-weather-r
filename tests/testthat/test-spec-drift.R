# The package against the pinned contract (spec/openapi/v1/openapi.yaml):
# every operation is exposed, every schema's fields and requirements match
# the table in R/schemas.R, and the spec's own examples decode.

# Sequences stay lists, so a one-element array is still an array in JSON.
openapi <- function() {
  yaml::read_yaml(
    file.path(local_spec(), "openapi", "v1", "openapi.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
}

out_of_scope <- "getMapsToken" # BEHAVIOR 3: a web-map credential, not in the 0.x SDKs

exposed <- c(
  getLocationForecast = "ew_forecast",
  getPointForecast = "ew_forecast_at",
  getCurrentConditions = "ew_current",
  getCurrentByCoordinates = "ew_current_at",
  getLocationAlerts = "ew_alerts",
  getAlertsByCoordinates = "ew_alerts_at",
  getNearbyLocations = "ew_nearby",
  getNearbyByCoordinates = "ew_nearby_at",
  searchLocations = "ew_search",
  getAllLocations = "ew_locations",
  getLocations = "ew_locations",
  listCatalogLocations = "ew_catalog_locations",
  getCatalogLocation = "ew_catalog_location",
  listCatalogStations = "ew_catalog_stations",
  getCatalogStation = "ew_catalog_station",
  getAvailableRuns = "ew_runs",
  getStormReports = "ew_storm_reports",
  getStormReport = "ew_storm_report",
  getAttribution = "ew_attribution"
)

operations <- function(spec) {
  ops <- list()
  for (item in spec$paths) {
    if (!is.null(item$get)) ops[[item$get$operationId]] <- item$get
  }
  ops
}

test_that("every operation in the spec is exposed", {
  ids <- names(operations(openapi()))
  missing <- setdiff(ids, c(out_of_scope, names(exposed)))
  expect_identical(missing, character(), label = "operations the package does not expose")
  for (fn in exposed) {
    expect_true(is.function(getExportedValue("ensembleweather", fn)), label = fn)
  }
})

# The properties and required names of a schema, through allOf and $ref.
schema_shape <- function(spec, schema) {
  if (!is.null(schema[["$ref"]])) {
    return(schema_shape(spec, spec$components$schemas[[basename(schema[["$ref"]])]]))
  }
  if (!is.null(schema$allOf)) {
    parts <- lapply(schema$allOf, schema_shape, spec = spec)
    return(list(
      properties = unlist(lapply(parts, `[[`, "properties")),
      required = unlist(lapply(parts, `[[`, "required"))
    ))
  }
  list(properties = names(schema$properties), required = unlist(schema[["required"]]))
}

# Spec schemas with no table of their own, and why.
modelled_elsewhere <- c(
  ErrorResponse = "becomes the error conditions",
  UnitSystem = "a plain string",
  ModelMeans = "ModelMeansEntry[] (id + ModelStats)",
  FreezingLevel = "one FreezingLevel table for the three variants",
  FreezingLevelBelowSurface = "FreezingLevel",
  FreezingLevelHeight = "FreezingLevel",
  FreezingLevelAboveProfile = "FreezingLevel"
)

test_that("every schema's fields and requirements match the table", {
  spec <- openapi()
  tables <- ensembleweather:::schemas
  for (name in setdiff(names(spec$components$schemas), names(modelled_elsewhere))) {
    expect_true(name %in% names(tables), label = paste("a table for", name))
    if (!(name %in% names(tables))) next
    shape <- schema_shape(spec, spec$components$schemas[[name]])
    expect_setequal(names(tables[[name]]), shape$properties)
    required <- names(tables[[name]])[endsWith(tables[[name]], "!")]
    expect_setequal(required, shape$required %||% character())
  }
  variants <- c("FreezingLevelBelowSurface", "FreezingLevelHeight", "FreezingLevelAboveProfile")
  fields <- unique(unlist(lapply(variants, function(v) schema_shape(spec, spec$components$schemas[[v]])$properties)))
  expect_setequal(names(tables$FreezingLevel), fields)
  means <- spec$components$schemas$ModelMeans$items
  expect_setequal(names(tables$ModelMeansEntry), schema_shape(spec, means)$properties)
})

test_that("every type in the table is known", {
  tables <- ensembleweather:::schemas
  known <- c(ensembleweather:::scalar_types, "json", names(tables))
  for (name in names(tables)) {
    for (spec in tables[[name]]) {
      base <- ensembleweather:::parse_field(spec)$base
      expect_true(base %in% known, label = paste(name, spec))
    }
  }
})

test_that("tibble columns are unique for every schema", {
  for (name in names(ensembleweather:::schemas)) {
    expect_no_error(ensembleweather:::schema_columns(name))
  }
})

# The spec's response examples. The two forecast examples do not match the
# spec's own ForecastResponse schema (their location has no slug, state or
# timezone, `elevation` where the schema says `elevation_m`, a camelCase
# type, an abridged forecast): a spec bug, so they are expected to be refused.
spec_bug_examples <- c("getLocationForecast", "getPointForecast")

test_that("the spec's examples decode with the documented shapes", {
  spec <- openapi()
  ops <- operations(spec)
  checked <- 0L
  for (id in setdiff(names(ops), out_of_scope)) {
    content <- ops[[id]]$responses[["200"]]$content[["application/json"]]
    ref <- content$schema[["$ref"]]
    if (is.null(ref)) next
    examples <- lapply(content$examples, `[[`, "value")
    if (!is.null(content[["example"]])) examples <- list(content[["example"]])
    for (example in examples) {
      data <- jsonlite::parse_json(jsonlite::toJSON(example, auto_unbox = TRUE, null = "null"))
      if (id %in% spec_bug_examples) {
        expect_error(ensembleweather:::decode_object(data, basename(ref)),
          class = "ensembleweather_error_unexpected_response"
        )
      } else {
        expect_no_error(ensembleweather:::decode_object(data, basename(ref)))
      }
      checked <- checked + 1L
    }
  }
  expect_gt(checked, 0L)
})

test_that("the vector bodies decode", {
  for (name in c(
    "forecast-metric.json", "forecast-imperial.json", "forecast-prob-mixed.json",
    "forecast-totals.json", "forecast-unknown-fields.json"
  )) {
    expect_no_error(ensembleweather:::decode_object(read_body(name), "ForecastResponse"))
  }
  expect_no_error(ensembleweather:::decode_object(read_body("catalog-detail.json"), "PublicCatalogLocationDetail"))
  expect_no_error(ensembleweather:::decode_object(read_body("attribution.json"), "AttributionRegistry"))
})
