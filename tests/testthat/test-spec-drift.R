# The package against the pinned contract (spec/openapi/v1/openapi.yaml):
# every operation is exposed, every schema's fields and requirements match
# the table in R/schemas.R (through the BEHAVIOR.md 3.0 renames, which
# match the spec's table row for row), and the spec's own examples decode.

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
  getPointForecast = "ew_get_point_forecast",
  getCurrentConditions = "ew_current",
  getCurrentByCoordinates = "ew_get_point_current",
  getLocationAlerts = "ew_alerts",
  getAlertsByCoordinates = "ew_get_point_alerts",
  getNearbyLocations = "ew_nearby",
  getNearbyByCoordinates = "ew_get_point_nearby",
  searchLocations = "ew_search",
  getAllLocations = "ew_locations",
  getLocations = "ew_locations",
  listCatalogLocations = "ew_catalog_locations",
  getCatalogLocation = "ew_catalog_location",
  listCatalogStations = "ew_catalog_stations",
  getCatalogStation = "ew_catalog_station",
  getAvailableRuns = "ew_runs",
  getAttribution = "ew_attribution",
  explore = "ew_explore",
  getComposition = "ew_composition",
  getLocationSeason = "ew_season",
  getLocationSnowTrend = "ew_snow_trend",
  getLocationSnowpack = "ew_snowpack",
  getLocationSnowpackPlume = "ew_snowpack_plume",
  getAlertOutlines = "ew_alert_outlines",
  getAvalancheZones = "ew_avalanche_zones"
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
  props <- list()
  required <- character()
  for (part in schema$allOf) {
    inner <- schema_shape(spec, part)
    props[names(inner$properties)] <- inner$properties
    required <- c(required, inner$required)
  }
  props[names(schema$properties)] <- schema$properties
  list(properties = props, required = c(required, unlist(schema[["required"]])))
}

# A property's inline object (or array of inline objects), if it has one:
# such objects have tables of their own, named in R/schemas.R.
inline_object <- function(node) {
  while (!is.null(node$items)) node <- node$items
  for (alt in c(node$oneOf, node$allOf)) {
    if (!is.null(alt$properties)) node <- alt
  }
  if (!is.null(node$properties) && is.null(node[["$ref"]])) node else NULL
}

# Spec schemas with no table of their own, and why.
modelled_elsewhere <- c(
  ErrorResponse = "becomes the error conditions",
  UnitSystem = "a plain string",
  ConditionIcon = "a plain string",
  NullReason = "a plain string",
  SnowCharacter = "a plain string",
  AlertClass = "a plain string",
  PassStatusLevel = "a plain string",
  NextCursor = "a plain string (NULL on the last page)",
  NullableNumbers = "num[] (a null item is NA)",
  MemberColumn = "num[][] (kept as parsed lists)",
  ModelMeans = "ModelMeansEntry[] (id + ModelStats)",
  FreezingLevel = "one FreezingLevel table for the three variants",
  FreezingLevelBelowSurface = "FreezingLevel",
  FreezingLevelHeight = "FreezingLevel",
  FreezingLevelAboveProfile = "FreezingLevel"
)

# Compare one table with its spec schema, field by field through the wire
# names, and recurse into the tables of its inline objects.
expect_table_matches <- function(spec, table_name, schema, seen = new.env()) {
  tables <- ensembleweather:::schemas
  expect_true(table_name %in% names(tables), label = paste("a table for", table_name))
  if (!(table_name %in% names(tables)) || !is.null(seen[[table_name]])) {
    return(invisible())
  }
  seen[[table_name]] <- TRUE
  table <- tables[[table_name]]
  wire <- ensembleweather:::wire_names[[table_name]]
  wire_of <- function(name) if (name %in% names(wire)) wire[[name]] else name
  wires <- vapply(names(table), wire_of, "", USE.NAMES = FALSE)
  shape <- schema_shape(spec, schema)
  expect_setequal(wires, names(shape$properties))
  required <- wires[endsWith(table, "!")]
  expect_setequal(required, shape$required %||% character())
  for (i in seq_along(table)) {
    inline <- inline_object(shape$properties[[wires[[i]]]])
    if (!is.null(inline)) {
      base <- ensembleweather:::parse_field(table[[i]])$base
      expect_table_matches(spec, base, inline, seen)
    }
  }
}

test_that("every schema's fields and requirements match the table", {
  spec <- openapi()
  for (name in setdiff(names(spec$components$schemas), names(modelled_elsewhere))) {
    expect_table_matches(spec, name, spec$components$schemas[[name]])
  }
  tables <- ensembleweather:::schemas
  variants <- c("FreezingLevelBelowSurface", "FreezingLevelHeight", "FreezingLevelAboveProfile")
  fields <- unique(unlist(lapply(variants, function(v) {
    names(schema_shape(spec, spec$components$schemas[[v]])$properties)
  })))
  expect_setequal(names(tables$FreezingLevel), fields)
  means <- spec$components$schemas$ModelMeans$items
  expect_setequal(names(tables$ModelMeansEntry), names(schema_shape(spec, means)$properties))
})

# The rename table of spec BEHAVIOR.md 3.0, as (wire, SDK name) pairs.
behaviour_renames <- function() {
  text <- readLines(file.path(local_spec(), "BEHAVIOR.md"), encoding = "UTF-8")
  start <- which(startsWith(text, "| Schema (where the field sits) | Wire name | SDK name |"))
  rows <- character()
  for (line in text[-seq_len(start + 1L)]) {
    if (!startsWith(line, "|")) break
    rows <- c(rows, line)
  }
  pairs <- lapply(rows, function(row) {
    cells <- strsplit(row, "|", fixed = TRUE)[[1]]
    split <- function(cell) trimws(gsub("`", "", strsplit(sub("\\(.*$", "", cell), ",")[[1]]))
    wires <- split(cells[[3]])
    sdks <- split(cells[[4]])
    if (identical(wires, "error")) {
      return(NULL) # the error conditions' `code`
    }
    stopifnot(length(wires) == length(sdks))
    paste(wires, sdks)
  })
  unlist(pairs)
}

test_that("the renames are exactly BEHAVIOR.md 3.0's table", {
  table <- behaviour_renames()
  expect_gt(length(table), 30L)
  wire <- ensembleweather:::wire_names
  ours <- unlist(lapply(wire, function(map) paste(unname(map), names(map))))
  # Every row of the table is applied, and nothing else is renamed.
  expect_setequal(unique(ours), unique(table))
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

# The spec's response examples decode (since 8b85fea the forecast examples match
# their own ForecastResponse schema).
test_that("the spec's examples decode with the documented shapes", {
  spec <- openapi()
  ops <- operations(spec)
  checked <- 0L
  for (id in setdiff(names(ops), out_of_scope)) {
    content <- ops[[id]]$responses[["200"]]$content
    content <- content[["application/json"]] %||% content[["application/geo+json"]]
    ref <- content$schema[["$ref"]]
    if (is.null(ref)) next
    examples <- lapply(content$examples, `[[`, "value")
    if (!is.null(content[["example"]])) examples <- list(content[["example"]])
    for (example in examples) {
      data <- jsonlite::parse_json(jsonlite::toJSON(example, auto_unbox = TRUE, null = "null"))
      expect_no_error(ensembleweather:::decode_object(data, basename(ref)))
      checked <- checked + 1L
    }
  }
  expect_gt(checked, 0L)
})

test_that("the vector bodies decode", {
  bodies <- c(
    "forecast-metric.json" = "ForecastResponse", "forecast-imperial.json" = "ForecastResponse",
    "forecast-prob-mixed.json" = "ForecastResponse", "forecast-prob-snow.json" = "ForecastResponse",
    "forecast-totals.json" = "ForecastResponse", "forecast-unknown-fields.json" = "ForecastResponse",
    "forecast-full.json" = "ForecastResponse", "forecast-plume.json" = "ForecastResponse",
    "forecast-pool.json" = "ForecastResponse",
    "catalog-detail.json" = "PublicCatalogLocationDetail",
    "catalog-detail-full.json" = "PublicCatalogLocationDetail",
    "catalog-station-detail.json" = "PublicCatalogStationDetail",
    "attribution.json" = "AttributionRegistry", "alerts.json" = "AlertsResponse",
    "current-pass.json" = "CurrentResponse", "explore.json" = "ExploreResponse",
    "search-sorted.json" = "SearchLocationsResponse", "composition.json" = "CompositionResponse",
    "season.json" = "SeasonResponse", "snow-trend.json" = "SnowTrendResponse",
    "snowpack.json" = "SnowpackResponse", "snowpack-plume.json" = "SnowpackPlumeResponse",
    "alert-outlines.json" = "AlertOutlineCollection",
    "avalanche-zones.json" = "AvalancheZoneCollection", "runs.json" = "RunsResponse",
    "nearby.json" = "NearbyLocationsResponse", "nearby-point.json" = "NearbyPointResponse",
    "locations-page.json" = "LocationsResponse"
  )
  for (name in names(bodies)) {
    expect_no_error(ensembleweather:::decode_object(read_body(name), bodies[[name]]))
  }
})
