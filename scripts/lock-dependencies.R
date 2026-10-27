# Write renv.lock: the exact versions of the runtime, test and development
# packages installed in the library R uses, in renv's lockfile format, so
# CI installs the same tree and osv-scanner can audit it (security.yml).
#
#   Rscript scripts/lock-dependencies.R

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(script), ".."))
roots <- c(
  "cli", "httr2", "jsonlite", "rlang", "tibble",
  "testthat", "withr", "yaml", "roxygen2", "lintr", "styler", "pkgdown"
)
installed <- installed.packages()
base <- rownames(installed)[installed[, "Priority"] %in% "base"]
deps <- tools::package_dependencies(roots,
  db = installed, recursive = TRUE,
  which = c("Depends", "Imports", "LinkingTo")
)
names <- sort(setdiff(unique(c(roots, unlist(deps))), c(base, "R")), method = "radix")
packages <- lapply(names, function(name) {
  list(
    Package = name,
    Version = unname(installed[name, "Version"]),
    Source = "Repository",
    Repository = "CRAN"
  )
})
names(packages) <- names
lock <- list(
  R = list(
    Version = paste(R.version$major, R.version$minor, sep = "."),
    Repositories = list(list(Name = "CRAN", URL = "https://cloud.r-project.org"))
  ),
  Packages = packages
)
writeLines(
  jsonlite::toJSON(lock, auto_unbox = TRUE, pretty = 2),
  file.path(root, "renv.lock")
)
cat("renv.lock:", length(packages), "packages\n")
