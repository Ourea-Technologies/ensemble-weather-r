# Fail if the README's quickstart is not exactly examples/quickstart.R, so the
# README can never rot (CI runs the example).
#
#   Rscript scripts/check-readme.R

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
readme <- readLines(file.path(root, "README.md"), warn = FALSE)
start <- grep("^## Quickstart", readme)
fence <- which(readme == "```r")
fence <- fence[fence > start][[1]]
close <- which(readme == "```")
close <- close[close > fence][[1]]
snippet <- readme[seq(fence + 1L, close - 1L)]
example <- readLines(file.path(root, "examples", "quickstart.R"), warn = FALSE)
if (!identical(snippet, example)) {
  cat("README quickstart and examples/quickstart.R differ\n")
  quit(status = 1)
}
cat("README quickstart matches examples/quickstart.R\n")
