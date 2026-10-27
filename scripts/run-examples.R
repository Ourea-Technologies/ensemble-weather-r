# Run every program in examples/ against the local stub API
# (scripts/stub-server.R), so they need no network and no key. Each must exit
# 0. point_forecast.R runs twice: without a key (it says so and exits 0) and
# with a placeholder key the stub accepts.
#
#   Rscript scripts/run-examples.R
#
# The package must be installed in the library R uses (R CMD INSTALL .).

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
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
base_url <- info[[1]]
on.exit(tools::pskill(as.integer(info[[2]])), add = TRUE)

run <- function(example, key = "") {
  env <- c(paste0("OUREA_BASE_URL=", base_url), paste0("OUREA_API_KEY=", key))
  cat("== ", basename(example), if (nzchar(key)) " (with a placeholder Pro key)", "\n", sep = "")
  status <- system2(rscript, shQuote(example), env = env)
  if (!identical(status, 0L)) {
    cat("FAILED: ", basename(example), " exited ", status, "\n", sep = "")
  }
  identical(status, 0L)
}

examples <- sort(list.files(file.path(root, "examples"), pattern = "\\.R$", full.names = TRUE))
results <- vapply(examples, run, TRUE)
results <- c(results, run(file.path(root, "examples", "point_forecast.R"), key = "ow_stub_pro_key"))
tools::pskill(as.integer(info[[2]]))
cat(sprintf("\n%d of %d example runs passed\n", sum(results), length(results)))
if (!all(results)) quit(status = 1)
