# fetch_substack.R — pull newsletter titles/links/dates from RSS and retain
# previously seen posts so they remain in the Portfolio after leaving the feed.
#
# Substack's pubDate format is RFC-822-ish ("Thu, 13 Aug 2026 10:00:32 GMT");
# parse_date_time's "a, d b Y H:M:S" order handles it directly.

suppressPackageStartupMessages({
  library(xml2)
  library(tidyverse)
  library(lubridate)
})

fetch_substack_posts <- function(feed_url = "https://newsletter.mikekonczal.com/feed") {
  feed  <- read_xml(feed_url)
  items <- xml_find_all(feed, ".//item")
  if (!length(items)) stop("Newsletter RSS feed contains no posts.")

  posts <- tibble(
    title = xml_text(xml_find_first(items, "title")),
    link  = xml_text(xml_find_first(items, "link")),
    date  = as.Date(parse_date_time(
      xml_text(xml_find_first(items, "pubDate")),
      orders = "a, d b Y H:M:S", tz = "UTC"
    ))
  )
  if (any(is.na(posts$date)) || any(!nzchar(posts$title)) ||
      any(!str_detect(posts$link, "^https://newsletter\\.mikekonczal\\.com/p/"))) {
    stop("Newsletter RSS feed has an invalid title, date, or post URL.")
  }
  posts
}

load_substack_posts <- function(cache_path = "data/substack_feed.csv", strict = FALSE) {
  cached <- if (file.exists(cache_path)) {
    read_csv(cache_path, show_col_types = FALSE) %>%
      mutate(date = as.Date(date))
  } else {
    tibble(title = character(), link = character(), date = as.Date(character()))
  }

  fresh <- tryCatch(fetch_substack_posts(), error = function(e) {
    if (strict) stop("Newsletter RSS fetch failed: ", conditionMessage(e))
    if (!nrow(cached)) stop("Newsletter RSS fetch failed and no cache exists: ",
                            conditionMessage(e))
    message("Newsletter RSS fetch failed; using cached posts: ", conditionMessage(e))
    NULL
  })
  if (is.null(fresh)) return(cached %>% arrange(desc(date)))

  # RSS lists recent items only. Keep older posts in the committed cache so
  # feed-sourced Portfolio entries do not vanish when they leave that window.
  posts <- bind_rows(fresh, cached) %>%
    distinct(link, .keep_all = TRUE) %>%
    arrange(desc(date))
  if (!identical(as.data.frame(posts), as.data.frame(cached))) {
    write_csv(posts, cache_path)
  }
  posts
}
