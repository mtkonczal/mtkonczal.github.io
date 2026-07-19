#!/bin/bash
# Double-click to open the mywork.csv entry/review app in your browser.
# The app keeps running in the background even if you close this window;
# stop it with the "Quit app" link on the page. Double-clicking again when
# it's already running just reopens the browser tab.
cd "$(dirname "$0")"
LOG=".addwork.log"
echo "=== launch $(date) ===" >> "$LOG"
echo "Starting the app... (log: $LOG)"
nohup python3 scripts/add_work_app.py >> "$LOG" 2>&1 &
sleep 1
tail -n 3 "$LOG"
echo "If no browser tab opened, send Mike the contents of $LOG"
sleep 2
exit 0
