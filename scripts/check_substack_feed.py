"""Quick RSS comparison before installing R and Quarto in GitHub Actions."""

import csv
import os
import sys
from datetime import timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from urllib.request import Request, urlopen
from xml.etree import ElementTree


FEED_URL = "https://newsletter.mikekonczal.com/feed"
CACHE_PATH = Path("data/substack_feed.csv")
POST_PREFIX = "https://newsletter.mikekonczal.com/p/"
# Substack returns 403 to urllib's default "Python-urllib" user agent.
USER_AGENT = "Mozilla/5.0 (compatible; mtkonczal-site-rss/1.0; +https://mtkonczal.github.io)"


def feed_posts(xml_bytes):
    root = ElementTree.fromstring(xml_bytes)
    items = root.findall(".//item")
    if not items:
        raise ValueError("Newsletter RSS feed contains no posts")

    posts = {}
    for item in items:
        title = item.findtext("title") or ""
        link = item.findtext("link") or ""
        published = item.findtext("pubDate") or ""
        if not title or not link.startswith(POST_PREFIX):
            raise ValueError("Newsletter RSS feed has an invalid title or post URL")
        date = parsedate_to_datetime(published).astimezone(timezone.utc).date().isoformat()
        posts[link] = (title, date)
    return posts


def cache_posts(path):
    if not path.exists():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        return {row["link"]: (row["title"], row["date"])
                for row in csv.DictReader(handle)}


def has_updates(xml_bytes, cache_path=CACHE_PATH):
    cached = cache_posts(cache_path)
    return any(cached.get(link) != details
               for link, details in feed_posts(xml_bytes).items())


if __name__ == "__main__":
    request = Request(FEED_URL, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=20) as response:
        changed = has_updates(response.read())
    print(f"changed={'true' if changed else 'false'}")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write(f"changed={'true' if changed else 'false'}\n")
    print("Newsletter RSS has updates" if changed else "Newsletter RSS is unchanged",
          file=sys.stderr)
