#!/bin/bash
# Double-click to open the Site Manager app in your browser.
# Always restarts the app so it serves the current code, then opens the tab.
# The app keeps running in the background after this window closes; stop it
# with the "Quit app" link on the page.
cd "$(dirname "$0")"
LOG=".addwork.log"
echo "=== launch $(date) ===" >> "$LOG"

# Replace any instance already holding the port (stale code otherwise).
OLD=$(lsof -ti tcp:4747)
if [ -n "$OLD" ]; then
  echo "stopping old instance (pid $OLD)" >> "$LOG"
  kill $OLD 2>/dev/null
  sleep 1
fi

echo "Starting the app... (log: $LOG)"
nohup python3 scripts/add_work_app.py >> "$LOG" 2>&1 &
sleep 1
tail -n 3 "$LOG"
echo "If no browser tab opened, send Mike the contents of $LOG"
sleep 2
exit 0
