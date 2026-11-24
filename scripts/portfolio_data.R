# Data prep for the Portfolio archive (portfolio.qmd): the work database plus
# newsletter posts, mapped to tabs, with per-tab counts. Kept in its own file
# so the tab mapping and the counts live in one place.
#
# Logic moved verbatim from the former homepage Portfolio chunk; no change to
# which rows appear or how they are categorized.

library(tidyverse)
library(lubridate)
library(htmltools)

fix_title_case <- function(x) {
  x <- str_to_title(x)
  for (w in c(" A "," An "," The "," And "," But "," For "," Of "," In "," On "," To "," With ")) {
    x <- str_replace_all(x, w, str_to_lower(w))
  }
  # ASCII \u escapes, NOT literal smart-quote chars: quarto transliterates
  # non-ASCII source bytes to "<U+00D4>" text, which would turn this class into
  # [<U+00D4>...] and silently strip D/U/5/0/4 from every title.
  str_remove_all(x, "[\\u00d4\\u00d5]")
}

link_key <- function(x) str_remove(str_remove(x, "[?#].*$"), "/$")

# Map each Format to a top-level tab. To add a tab later, extend this mapping
# and add a matching <button> in portfolio.qmd's `tabs` chunk.
cat_for <- function(format) {
  case_when(
    format %in% c("Article", "Book Review")          ~ "Writing",
    format == "White Paper"                          ~ "Research",
    format %in% c("TV", "Radio", "Podcast", "Panel") ~ "Media",
    format == "Quote"                                ~ "Press",
    TRUE                                             ~ NA_character_
  )
}

# Label shown in the Type column (distinct from the tab/Category above).
type_label <- function(format) {
  case_when(
    format == "White Paper" ~ "Research",
    format == "Quote"       ~ "Press",
    TRUE                    ~ format
  )
}

# `posts` is the newsletter feed from scripts/fetch_substack.R. New newsletter
# posts appear in Writing without going through the Site Manager review queue;
# database entries win when a link is already curated.
load_portfolio <- function(posts, db_path = "data/work_database.csv") {
  work <- read_csv(db_path, show_col_types = FALSE)

  newsletter_work <- posts %>%
    filter(!link_key(link) %in% link_key(work$Link)) %>%
    transmute(
      Date = date, `Original Title` = title, Outlet = "Substack",
      Format = "Article", Link = link, Highlight = NA_character_,
      Author = NA_character_, Excerpt = NA_character_
    )

  bind_rows(work, newsletter_work) %>%
    mutate(
      Title = if_else(Link %in% newsletter_work$Link,
                      `Original Title`, fix_title_case(`Original Title`)),
      Date  = as.Date(Date)  # ISO YYYY-MM-DD in the CSV
    ) %>%
    arrange(desc(Date)) %>%
    mutate(
      Category = cat_for(Format),
      TypeLab  = type_label(Format)
    ) %>%
    filter(!is.na(Category))
}

# Rows per tab, named in display order.
portfolio_counts <- function(portfolio) {
  cats <- c("Research", "Writing", "Media", "Press")
  set_names(map_int(cats, ~ sum(portfolio$Category == .x)), cats)
}
