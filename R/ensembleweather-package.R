#' ensembleweather: the official R client for the Ourea probabilistic weather API
#'
#' Ourea serves ensemble weather forecasts: every value is a distribution
#' computed by the server from the full set of model members. This package
#' asks for those distributions and returns them as tibbles.
#'
#' Start with [ew_forecast()]. Ask for the chance of crossing a threshold with
#' [ew_chance()], and for a storm total's distribution with [ew_total()].
#' Errors are classed conditions (see [ensembleweather_error]). Calls work
#' without an API key (the Free tier); see [ew_client()] for keys, units,
#' retries and the cache.
#'
#' The package never sums, averages or interpolates quantiles and never
#' derives a probability from them: the server computes every probability and
#' window total from the full ensemble, and the package only carries them.
#'
#' @section Citing:
#' Run `citation("ensembleweather")` for a reference to the package and the
#' forecast data.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||%
## usethis namespace: end
NULL
