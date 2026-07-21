#!/usr/bin/env Rscript
# Refresh data/macro_strip.csv — the fallback cache for the homepage macro
# strip (index.qmd, chunk `macro_strip`). The render fetches fresh and rewrites
# this cache itself, so you only need this script to refresh the cache without
# a full render, or to seed it the first time.
#
# Usage: Rscript scripts/update_macro_data.R
# Requires BLS_KEY in the environment (.Renviron locally) for the diffusion
# index; FRED series use public flat files and need no key.

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

source(file.path("scripts", "build_macro.R"))  # defines build_macro()

cache_path <- file.path("data", "macro_strip.csv")
out <- build_macro()

# Fail loudly on anything structurally off before overwriting the cache.
expected <- c("UNRATE_FULL", "SUPERCORE_YOY", "VU", "DIFFUSION")
stopifnot(
  setequal(unique(out$series_id), expected),
  nrow(out) > 4 * 24,             # each monthly series should have ~48+ obs
  max(out$date) > Sys.Date() - 120
)

write_csv(out, cache_path)
message("Wrote ", cache_path, ": ", nrow(out), " rows, latest obs ", max(out$date))
