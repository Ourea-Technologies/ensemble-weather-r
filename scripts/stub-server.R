# A tiny local stand-in for the Ourea API, so the examples run with no
# network and no key. It serves the shared vector bodies
# (spec/vectors/bodies) and answers prob= / totals= with placeholder values:
# it is a test double, not a forecast. Base R sockets only.
#
#   Rscript scripts/stub-server.R [port-file]
#
# prints "OUREA_BASE_URL=http://127.0.0.1:<port>" (and writes the URL to
# port-file, if given), then serves until killed.

args <- commandArgs(trailingOnly = TRUE)
port_file <- if (length(args) >= 1L) args[[1]] else NULL
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
bodies <- file.path(root, "spec", "vectors", "bodies")
start <- "2026-11-15T00:00:00Z"

body <- function(name) jsonlite::read_json(file.path(bodies, name), simplifyVector = FALSE)

hours_after <- function(hours) {
  format(as.POSIXct(start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") + hours * 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

window <- function(text) {
  span <- sub("h$", "", text)
  if (grepl("-", span, fixed = TRUE)) as.integer(strsplit(span, "-", fixed = TRUE)[[1]]) else c(0L, as.integer(span))
}

probabilities <- function(spec) {
  lapply(strsplit(spec, ",", fixed = TRUE)[[1]], function(term) {
    parts <- strsplit(term, ":", fixed = TRUE)[[1]]
    amounts <- parts[[1]] %in% c("precipitation", "snowfall")
    hours <- window(parts[[4]])
    list(
      term = term, variable = parts[[1]], op = parts[[2]], threshold = as.double(parts[[3]]),
      window_start_hours = hours[[1]], window_end_hours = hours[[2]],
      aggregation = if (length(parts) > 4L) parts[[5]] else if (amounts) "total" else "any",
      from = hours_after(hours[[1]]), to = hours_after(hours[[2]]),
      probability = 0.42, members = 131L, null_reason = NULL
    )
  })
}

totals <- function(spec) {
  lapply(strsplit(spec, ",", fixed = TRUE)[[1]], function(item) {
    parts <- strsplit(item, ":", fixed = TRUE)[[1]]
    hours <- window(parts[[2]])
    list(
      term = item, variable = parts[[1]], window_start_hours = hours[[1]],
      window_end_hours = hours[[2]], aggregation = "total",
      from = hours_after(hours[[1]]), to = hours_after(hours[[2]]),
      quantiles = list(mean = 31, p10 = 12, p25 = 20, p50 = 29, p75 = 40, p90 = 52, min = 4, max = 88),
      members = 131L, null_reason = NULL
    )
  })
}

alert <- function() {
  list(
    id = "urn:oid:2.49.0.1.840.0.example", event = "Winter Storm Warning", severity = "severe",
    urgency = "expected", certainty = "likely", headline = "Winter Storm Warning until Sunday 4 AM PST",
    onset = start, expires = "2026-11-16T12:00:00Z"
  )
}

forecast <- function(query) {
  out <- body(if (identical(query$units, "imperial")) "forecast-imperial.json" else "forecast-metric.json")
  if (!is.null(query$prob)) out$probabilities <- probabilities(query$prob)
  if (!is.null(query$totals)) out$window_totals <- totals(query$totals)
  out
}

error <- function(code, message) {
  list(
    error = code, message = message, request_id = "01JBQ6ZK3V8M4T2N7XQH5R9W0C",
    doc_url = paste0("https://docs.oureawx.com/features/errors/#", tolower(code))
  )
}

route <- function(path, query, keyed) {
  location <- body("forecast-metric.json")$location
  attribution <- body("forecast-metric.json")$attribution
  parts <- vapply(strsplit(path, "/", fixed = TRUE)[[1]], utils::URLdecode, "", USE.NAMES = FALSE)
  parts <- parts[nzchar(parts)][-(1:2)]
  if (length(parts) == 3L && parts[[1]] == "locations") {
    if (!identical(parts[2:3], c("or", "mt-hood-meadows"))) {
      return(list(404L, error("LOCATION_NOT_FOUND", paste0("No location ", parts[[2]], "/", parts[[3]], "."))))
    }
    return(list(200L, forecast(query)))
  }
  if (length(parts) == 4L && parts[[1]] == "locations" && parts[[4]] == "current") {
    return(list(200L, list(
      location = location, alerts = list(alert()), alerts_as_of = start, sensor_count = 0L,
      sensors = list(), as_of = start, model_run_initialized_at = start, nowcast_hours = NULL,
      units = "metric", attribution = attribution,
      current = list(
        time = start, temperature = -2, condition = "snow", condition_text = "Snow",
        condition_icon = "night_snow", wind_speed = 6, wind_direction = 5, source = "nowcast"
      )
    )))
  }
  if (length(parts) == 4L && parts[[1]] == "locations" && parts[[4]] == "alerts") {
    return(list(200L, list(
      location = location, alert_count = 1L, as_of = start, alerts = list(alert()),
      attribution = attribution
    )))
  }
  if (length(parts) == 4L && parts[[1]] == "locations" && parts[[4]] == "nearby") {
    summary <- c(location, list(county = "Hood River"))
    nearby <- c(summary, list(distance_km = 0))
    nearby$slug <- "timberline-lodge"
    nearby$name <- "Timberline Lodge"
    return(list(200L, list(location = summary, radius_km = 50, count = 1L, locations = list(nearby))))
  }
  if (identical(parts, "forecast")) {
    if (!keyed) {
      return(list(403L, body("error-pro-required.json")))
    }
    if (as.double(query$lon) > -60) {
      return(list(404L, body("error-outside-coverage.json")))
    }
    return(list(200L, forecast(query)))
  }
  if (identical(parts, c("search", "locations"))) {
    return(list(200L, body("search.json")))
  }
  if (identical(parts, c("catalog", "locations"))) {
    return(list(200L, body(if (is.null(query$cursor)) "catalog-page-1.json" else "catalog-page-2.json")))
  }
  if (length(parts) == 3L && identical(parts[1:2], c("catalog", "locations"))) {
    if (parts[[3]] != "mt-hood-meadows") {
      return(list(404L, error("NOT_FOUND", "No such catalog location.")))
    }
    return(list(200L, body("catalog-detail.json")))
  }
  if (length(parts) %in% 1:2 && parts[[1]] == "locations") {
    summary <- c(location, list(county = "Hood River"))
    state <- if (length(parts) == 2L) parts[[2]] else "all"
    return(list(200L, list(state = state, count = 1L, locations = list(summary), next_cursor = NULL)))
  }
  if (identical(parts, c("catalog", "stations"))) {
    station <- list(
      slug = "mt-hood-test-site-snotel", state = "or", name = "Mt Hood Test Site", lat = 45.32,
      lon = -121.72, elevation_m = 1637, type = "observation_station", timezone = "America/Los_Angeles",
      network = "snotel", station_status = "active"
    )
    return(list(200L, list(items = list(station), next_cursor = NULL)))
  }
  if (identical(parts, "runs")) {
    return(list(200L, list(
      served = list(initialized_at = start, models = list(list(id = "ifs_ens", cycle = start))),
      runs = list(list(initialized_at = start)), count = 1L, next_cursor = NULL
    )))
  }
  if (identical(parts, "attribution")) {
    return(list(200L, body("attribution.json")))
  }
  list(404L, error("NOT_FOUND", paste0("No route ", path, ".")))
}

parse_query <- function(text) {
  out <- list()
  if (!nzchar(text)) {
    return(out)
  }
  for (pair in strsplit(text, "&", fixed = TRUE)[[1]]) {
    kv <- strsplit(pair, "=", fixed = TRUE)[[1]]
    out[[utils::URLdecode(kv[[1]])]] <- if (length(kv) > 1L) utils::URLdecode(kv[[2]]) else ""
  }
  out
}

handle <- function(con) {
  request_line <- readLines(con, n = 1L, warn = FALSE)
  if (length(request_line) == 0L) {
    return(invisible())
  }
  keyed <- FALSE
  repeat {
    line <- sub("\r$", "", readLines(con, n = 1L, warn = FALSE))
    if (length(line) == 0L || !nzchar(line)) break
    if (grepl("^x-api-key:", line, ignore.case = TRUE)) keyed <- TRUE
  }
  target <- strsplit(sub("\r$", "", request_line), " ", fixed = TRUE)[[1]][[2]]
  path <- sub("\\?.*$", "", target)
  query <- parse_query(if (grepl("?", target, fixed = TRUE)) sub("^[^?]*\\?", "", target) else "")
  answer <- tryCatch(route(path, query, keyed), error = function(e) {
    list(500L, error("INTERNAL_ERROR", conditionMessage(e)))
  })
  json <- jsonlite::toJSON(answer[[2]], auto_unbox = TRUE, null = "null", digits = NA)
  payload <- charToRaw(enc2utf8(as.character(json)))
  reason <- c(
    "200" = "OK", "400" = "Bad Request", "403" = "Forbidden", "404" = "Not Found",
    "500" = "Internal Server Error"
  )
  headers <- c(
    sprintf("HTTP/1.1 %d %s", answer[[1]], reason[[as.character(answer[[1]])]]),
    "Content-Type: application/json",
    sprintf("Content-Length: %d", length(payload)),
    "Connection: close",
    if (keyed) {
      c(
        "Cache-Control: private, max-age=0", "RateLimit-Limit: 60", "RateLimit-Remaining: 59",
        "RateLimit-Reset: 1", "RateLimit-Policy: 60;w=60"
      )
    } else {
      "Cache-Control: public, max-age=0, s-maxage=60"
    }
  )
  writeBin(c(charToRaw(paste0(paste(headers, collapse = "\r\n"), "\r\n\r\n")), payload), con)
  flush(con)
}

server <- NULL
for (try in 1:50) {
  port <- sample(20000:60000, 1L)
  server <- tryCatch(serverSocket(port), error = function(e) NULL)
  if (!is.null(server)) break
}
if (is.null(server)) stop("no free port")
url <- paste0("http://127.0.0.1:", port)
cat("OUREA_BASE_URL=", url, "\n", sep = "")
if (!is.null(port_file)) writeLines(c(url, Sys.getpid()), port_file)
repeat {
  con <- socketAccept(server, blocking = TRUE, open = "r+b", timeout = 86400)
  tryCatch(handle(con), error = function(e) message("stub: ", conditionMessage(e)))
  close(con)
}
