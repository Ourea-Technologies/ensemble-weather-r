# Where the pinned spec lives. From a source checkout it is ../../spec; R CMD
# check runs the tests from a copy, so CI points ENSEMBLEWEATHER_SPEC at it.
# The CRAN tarball does not ship spec/: there (NOT_CRAN unset) the spec
# tests skip; anywhere else a missing spec is a failure, never a silent skip.
spec_dir <- function() {
  candidates <- c(
    Sys.getenv("ENSEMBLEWEATHER_SPEC", ""),
    testthat::test_path("..", "..", "spec"),
    file.path(getwd(), "..", "..", "spec")
  )
  for (dir in candidates[nzchar(candidates)]) {
    if (file.exists(file.path(dir, "VERSION"))) {
      return(normalizePath(dir))
    }
  }
  NULL
}

local_spec <- function() {
  dir <- spec_dir()
  if (is.null(dir)) {
    if (!identical(Sys.getenv("NOT_CRAN"), "true")) {
      testthat::skip("spec/ is not shipped in the CRAN tarball")
    }
    testthat::fail("spec/ not found: set ENSEMBLEWEATHER_SPEC or run from a source checkout")
  }
  dir
}

read_body <- function(name) {
  jsonlite::read_json(file.path(local_spec(), "vectors", "bodies", name), simplifyVector = FALSE)
}

# Replace the sleep, jitter and environment for one test.
local_quiet_client_env <- function(env = parent.frame()) {
  withr::local_envvar(OUREA_API_KEY = NA, OUREA_BASE_URL = NA, .local_envir = env)
  ensembleweather:::reset_session_state()
}

# A mock transport: replays `responses` in order and records each request.
local_replay <- function(responses, env = parent.frame()) {
  replay <- new.env(parent = emptyenv())
  replay$requests <- list()
  replay$responses <- responses
  httr2::local_mocked_responses(function(req) {
    replay$requests[[length(replay$requests) + 1L]] <- list(
      method = httr2::req_get_method(req),
      url = httr2::req_get_url(req),
      headers = httr2::req_get_headers(req, "reveal"),
      options = req$options
    )
    if (length(replay$responses) == 0L) {
      stop("unexpected request #", length(replay$requests), ": ", req$url)
    }
    spec <- replay$responses[[1]]
    replay$responses <- replay$responses[-1]
    body <- spec$body_raw %||% charToRaw(spec$body %||% "")
    httr2::response(
      status_code = spec$status,
      url = req$url,
      headers = spec$headers %||% list(),
      body = body
    )
  }, env = env)
  replay
}

`%||%` <- function(x, y) if (is.null(x)) y else x

json_response <- function(body, status = 200L, headers = list()) {
  list(
    status = status,
    headers = c(list(`Content-Type` = "application/json"), headers),
    body = as.character(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null", digits = NA))
  )
}

request_header <- function(request, name) {
  names <- tolower(names(request$headers))
  value <- request$headers[names == tolower(name)]
  if (length(value) == 0L) NULL else value[[1]]
}

url_path <- function(url) {
  sub("\\?.*$", "", sub("^[A-Za-z][A-Za-z0-9+.-]*://[^/]*", "", url))
}

url_query <- function(url) {
  if (grepl("?", url, fixed = TRUE)) sub("^[^?]*\\?", "", url) else ""
}
