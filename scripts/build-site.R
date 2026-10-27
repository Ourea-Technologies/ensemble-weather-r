# Build the pkgdown site with the reference examples running against the
# local stub API (scripts/stub-server.R), so no example touches the network
# and every one renders its output. Warnings fail the build.
#
#   Rscript scripts/build-site.R [output dir]     (default: docs/, gitignored)
#
# The package must be installed in the library R uses (R CMD INSTALL .).

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
args <- commandArgs(trailingOnly = TRUE)
destination <- if (length(args) >= 1L) args[[1]] else file.path(root, "docs")
rscript <- file.path(R.home("bin"), "Rscript")
port_file <- tempfile("stub-")

system2(rscript, c(shQuote(file.path(root, "scripts", "stub-server.R")), shQuote(port_file)),
  wait = FALSE, stdout = FALSE, stderr = ""
)
for (i in 1:100) {
  if (file.exists(port_file) && length(readLines(port_file, warn = FALSE)) == 2L) break
  Sys.sleep(0.1)
}
info <- readLines(port_file, warn = FALSE)
if (length(info) != 2L) stop("the stub server did not start")
Sys.setenv(OUREA_BASE_URL = info[[1]], OUREA_API_KEY = "")

warned <- character()
withCallingHandlers(
  pkgdown::build_site(root, override = list(destination = destination), preview = FALSE, new_process = FALSE),
  warning = function(w) {
    warned <<- c(warned, conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)
tools::pskill(as.integer(info[[2]]))
if (length(warned) > 0L) {
  cat("pkgdown warnings:\n", paste0("  ", unique(warned), "\n"), sep = "")
  quit(status = 1)
}
cat("pkgdown site built in", destination, "with no warnings\n")
