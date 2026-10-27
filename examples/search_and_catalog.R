# Search for a location, then walk the catalog: all at once, and page by
# page with the cursor.
library(ensembleweather)

hits <- ew_search("hood meadows")
print(hits[, c("key", "name", "county", "type")])

# One forecast straight from a search hit.
forecast <- ew_forecast(hits[1, ])
cat("First hit:", forecast$location$name, "\n")

# Every page, collected into one tibble.
everything <- ew_catalog_locations()
cat("Catalog locations:", nrow(everything), "\n")

# Or one page at a time.
page <- ew_catalog_locations_page(limit = 1)
repeat {
  cat("page:", paste(page$items$slug, collapse = ", "), "\n")
  if (is.null(page$next_cursor)) break
  page <- ew_catalog_locations_page(limit = 1, cursor = page$next_cursor)
}

detail <- ew_catalog_location(hits$slug[[1]])
cat(detail$name, "is a", detail$type, "at", detail$elevation_m, "m\n")
