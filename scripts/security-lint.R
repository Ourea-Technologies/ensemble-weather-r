# The static security lint (SDK-STANDARD "Security", the R row): lintr's
# security-relevant linters over the package code, and a gate that no code
# evaluates text (no eval(parse()), no str2lang/str2expression) or shells out.
#
#   Rscript scripts/security-lint.R

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))

dangerous <- c(
  eval = "evaluates code", evalq = "evaluates code", parse = "turns text into code",
  str2lang = "turns text into code", str2expression = "turns text into code",
  source = "runs a file", sys.source = "runs a file", system = "runs a shell command",
  system2 = "runs a shell command", shell = "runs a shell command", attach = "changes the search path",
  library = "attaches packages", require = "attaches packages",
  unserialize = "deserialises arbitrary R objects", readRDS = "deserialises arbitrary R objects",
  load = "deserialises arbitrary R objects", Sys.setenv = "changes the environment",
  options = "changes global state", setwd = "changes global state"
)
linters <- list(
  lintr::undesirable_function_linter(fun = dangerous, symbol_is_undesirable = FALSE),
  lintr::undesirable_operator_linter(op = c(":::" = "reaches into another namespace", "<<-" = "assigns globally"))
)
found <- lintr::lint_dir(file.path(root, "R"), linters = linters, parse_settings = FALSE)
print(found)

code <- unlist(lapply(list.files(file.path(root, "R"), full.names = TRUE), readLines, warn = FALSE))
gate <- grep("eval\\s*\\(\\s*parse\\s*\\(", code, value = TRUE)
if (length(gate) > 0L) {
  cat("eval(parse()) found:\n", paste0("  ", gate, "\n"), sep = "")
}
if (length(found) > 0L || length(gate) > 0L) {
  quit(status = 1)
}
cat("security lint: clean\n")
