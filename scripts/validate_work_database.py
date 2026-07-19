#!/usr/bin/env python3
"""Validate data/work_database.csv before the site renders.

Run by .github/workflows/build-site.yml on every push, and available
locally: python3 scripts/validate_work_database.py

Errors (exit 1, blocks the render): bad schema, unparseable/future dates,
unknown Format values, malformed links, wrong field counts.
Warnings (exit 0): duplicate URLs beyond the known baseline.
"""

import csv
import datetime
import sys
from collections import Counter
from pathlib import Path

CSV_PATH = Path(__file__).resolve().parent.parent / "data" / "work_database.csv"

EXPECTED_HEADER = [
    "Date", "Original Title", "Outlet", "Format",
    "Link", "Highlight", "Author", "Excerpt",
]

# Must match the categories index.qmd knows how to display (cat_for()).
ALLOWED_FORMATS = {
    "Article", "Book Review", "White Paper",
    "TV", "Radio", "Podcast", "Panel", "Quote",
}

# Pre-existing intentional duplicates (double entries from 2018-2021).
# New duplicates beyond these are flagged.
KNOWN_DUPLICATE_URLS = 3

errors, warnings = [], []

with open(CSV_PATH, newline="", encoding="utf-8") as f:
    rows = list(csv.reader(f))

header, body = rows[0], rows[1:]

if header != EXPECTED_HEADER:
    errors.append(f"header mismatch: {header}")

today = datetime.date.today()
for i, row in enumerate(body, start=2):
    if len(row) != len(EXPECTED_HEADER):
        errors.append(f"line {i}: {len(row)} fields (expected {len(EXPECTED_HEADER)})")
        continue
    date, title, outlet, fmt, link, highlight, _, _ = row
    try:
        d = datetime.datetime.strptime(date.strip(), "%Y-%m-%d").date()
        if d > today + datetime.timedelta(days=1):
            errors.append(f"line {i}: date {date} is in the future")
    except ValueError:
        errors.append(f"line {i}: bad date {date!r} (need YYYY-MM-DD)")
    if fmt not in ALLOWED_FORMATS:
        errors.append(f"line {i}: unknown Format {fmt!r}")
    if not link.strip().startswith(("http://", "https://")):
        errors.append(f"line {i}: bad link {link!r}")
    if highlight not in ("", "X"):
        errors.append(f"line {i}: Highlight must be '' or 'X', got {highlight!r}")
    if not title.strip():
        errors.append(f"line {i}: empty title")
    if not outlet.strip():
        errors.append(f"line {i}: empty outlet")

url_counts = Counter(r[4].strip() for r in body if len(r) == len(EXPECTED_HEADER))
dups = {u: n for u, n in url_counts.items() if n > 1}
if len(dups) > KNOWN_DUPLICATE_URLS:
    for u, n in dups.items():
        warnings.append(f"duplicate URL x{n}: {u}")

for w in warnings:
    print(f"WARNING: {w}")
for e in errors:
    print(f"ERROR: {e}")

if errors:
    print(f"\n{len(errors)} error(s) — fix data/work_database.csv before the site will build.")
    sys.exit(1)

print(f"OK: {len(body)} rows validated.")
