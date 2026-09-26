# mtkonczal.github.io

This is my personal website, built with Quarto. It's very easy to use, implementing R Markdown and can be entirely run within RStudio. I recommend you give it a try!

## Newsletter posts

The homepage reads `https://newsletter.mikekonczal.com/feed` when it renders. It
shows the three newest posts in the newsletter section and adds new RSS posts to
the Portfolio's Writing tab. `data/substack_feed.csv` keeps posts after they
leave the feed's recent window; entries already in `data/work_database.csv` take
precedence. No Site Manager approval is needed for newsletter posts.

`.github/workflows/refresh-newsletter.yml` checks RSS weekly with Python's
standard library. It installs R and Quarto only when posts are new or changed,
then renders and publishes the updated homepage. For a local newsletter
refresh without changing the economic-indicator cache, run:

```sh
MK_MACRO_FROM_CACHE=1 quarto render index.qmd
```
