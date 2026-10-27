# Fail if DESCRIPTION imports a package that .github/CONTRIBUTING.md does not
# justify under "Runtime dependencies" (SDK-STANDARD "Dependencies").
#
#   Rscript scripts/check-dependencies.R

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
description <- read.dcf(file.path(root, "DESCRIPTION"), fields = c("Imports", "Depends", "LinkingTo"))
fields <- description[1, ]
declared <- unlist(strsplit(paste(fields[!is.na(fields)], collapse = ","), ","))
declared <- trimws(sub("\\(.*\\)", "", declared))
declared <- setdiff(declared[nzchar(declared)], "R")

contributing <- readLines(file.path(root, ".github", "CONTRIBUTING.md"), warn = FALSE)
start <- grep("^### Runtime dependencies", contributing)
end <- grep("^#{2,3} ", contributing)
end <- min(end[end > start], length(contributing) + 1L)
section <- contributing[seq(start + 1L, end - 1L)]
justified <- sub("^- `([^`]+)`.*$", "\\1", grep("^- `[^`]+`: ", section, value = TRUE))

missing <- setdiff(declared, justified)
stale <- setdiff(justified, declared)
if (length(missing) > 0L) {
  cat("Runtime dependencies without a justification in .github/CONTRIBUTING.md:", missing, "\n")
}
if (length(stale) > 0L) {
  cat("Justified in .github/CONTRIBUTING.md but not in DESCRIPTION:", stale, "\n")
}
if (length(missing) > 0L || length(stale) > 0L) quit(status = 1)
cat("runtime dependencies justified:", paste(declared, collapse = ", "), "\n")
