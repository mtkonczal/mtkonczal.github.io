#!/bin/bash
# Double-click to open the mywork.csv entry/review app in your browser.
# Close this window (or Ctrl-C) to stop the app.
cd "$(dirname "$0")"
exec python3 scripts/add_work_app.py
