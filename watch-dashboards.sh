#!/bin/bash
# watch-dashboards.sh — Auto-sync HTML dashboards to GitHub Pages on file changes
# Usage: ./watch-dashboards.sh        (foreground)
#        ./watch-dashboards.sh start   (background daemon)
#        ./watch-dashboards.sh stop    (kill daemon)
#        ./watch-dashboards.sh status  (check if running)

REPO="/Users/yeehowong/Documents/GitHub/market-dashboards"
VAULT="/Users/yeehowong/Documents/GitHub/obsidian_vault/01-市場日報"
PIDFILE="/tmp/watch-dashboards.pid"
LOG="/tmp/sync-dashboards.log"

case "${1:-}" in
  stop)
    if [ -f "$PIDFILE" ]; then
      kill $(cat "$PIDFILE") 2>/dev/null && echo "Stopped." || echo "Not running."
      rm -f "$PIDFILE"
    else
      echo "Not running."
    fi
    exit 0
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "Running (pid $(cat "$PIDFILE"))"
    else
      echo "Not running"
    fi
    exit 0
    ;;
  start)
    if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
      echo "Already running (pid $(cat "$PIDFILE"))"
      exit 0
    fi
    nohup "$0" _daemon >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    echo "Started in background (pid $!)"
    echo "Log: $LOG"
    exit 0
    ;;
  _daemon)
    # Internal: runs the actual watch loop
    ;;
  "")
    # Foreground mode
    ;;
  *)
    echo "Usage: $0 [start|stop|status]"
    exit 1
    ;;
esac

echo "$(date): Watching for HTML changes in vault..."

fswatch -0 -e '.*' -i '\.html$' --latency 5 \
  "$VAULT/美股/盤前" \
  "$VAULT/美股/盤後" \
  "$VAULT/港股/盤前" \
  "$VAULT/港股/盤後" \
  "$VAULT/TradingAgents" \
  "$VAULT/TradingAgents/US" \
| while IFS= read -r -d '' event; do
    echo "$(date): Change detected: $event"
    # Debounce: sleep briefly in case multiple files are being written
    sleep 3
    bash "$REPO/sync-dashboards.sh"
  done
