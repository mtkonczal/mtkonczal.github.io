# fetch_substack.R — pull the N most recent post titles/links/dates from the
# Substack RSS feed, for the homepage subscribe widget (index.qmd, chunk
# `subscribe_widget`). Sourcing this file defines fetch_substack_posts().
#
# Substack's pubDate format is RFC-822-ish ("Thu, 13 Aug 2026 10:00:32 GMT");
# parse_date_time's "a, d b Y H:M:S" order handles it directly.

suppressPackageStartupMessages({
  library(xml2)
  library(tidyverse)
  library(lubridate)
})

fetch_substack_posts <- function(n = 3, feed_url = "https://newsletter.mikekonczal.com/feed") {
  feed  <- read_xml(feed_url)
  items <- xml_find_all(feed, ".//item")
  stopifnot(length(items) > 0)
  items <- items[seq_len(min(n, length(items)))]

  tibble(
    title = xml_text(xml_find_first(items, "title")),
    link  = xml_text(xml_find_first(items, "link")),
    date  = as.Date(parse_date_time(
      xml_text(xml_find_first(items, "pubDate")),
      orders = "a, d b Y H:M:S", tz = "UTC"
    ))
  )
}
