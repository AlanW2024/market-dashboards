#!/bin/bash
# sync-dashboards.sh — Copy HTML dashboards from Obsidian vault to GitHub Pages repo
# Runs automatically via launchd when vault HTML files change, or manually.

set -e

VAULT="/Users/yeehowong/Documents/GitHub/obsidian_vault/01-市場日報"
REPO="/Users/yeehowong/Documents/GitHub/market-dashboards"
LOCK="/tmp/sync-dashboards.lock"
LOG="/tmp/sync-dashboards.log"

# Prevent concurrent runs
if [ -f "$LOCK" ]; then
  pid=$(cat "$LOCK")
  if kill -0 "$pid" 2>/dev/null; then
    echo "$(date): Already running (pid $pid), skipping" >> "$LOG"
    exit 0
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

echo "$(date): Sync started" >> "$LOG"

cd "$REPO"

# Source directories to sync
declare -a DIRS=(
  "美股/盤前"
  "美股/盤後"
  "港股/盤前"
  "港股/盤後"
  "TradingAgents"
  "TradingAgents/US"
)

count=0
for dir in "${DIRS[@]}"; do
  mkdir -p "$REPO/$dir"
  if ls "$VAULT/$dir/"*.html 1>/dev/null 2>&1; then
    rsync -u "$VAULT/$dir/"*.html "$REPO/$dir/"
    n=$(ls "$REPO/$dir/"*.html 2>/dev/null | wc -l | tr -d ' ')
    count=$((count + n))
  fi
done

# Generate files.js for index.html
cat > "$REPO/files.js" << 'HEADER'
const FILES = {
HEADER

declare -a SECTIONS=(
  "🇺🇸 美股盤前:美股/盤前"
  "🇺🇸 美股盤後:美股/盤後"
  "🇭🇰 港股盤前:港股/盤前"
  "🇭🇰 港股盤後:港股/盤後"
  "📈 個股分析:TradingAgents"
  "📈 個股分析 (US):TradingAgents/US"
)

for entry in "${SECTIONS[@]}"; do
  label="${entry%%:*}"
  dir="${entry##*:}"
  echo "  \"$label\": [" >> "$REPO/files.js"
  if ls "$REPO/$dir/"*.html 1>/dev/null 2>&1; then
    for f in "$REPO/$dir/"*.html; do
      name=$(basename "$f")
      path="$dir/$name"
      echo "    {\"name\":\"$name\",\"path\":\"$path\",\"dir\":\"$dir\"}," >> "$REPO/files.js"
    done
  fi
  echo "  ]," >> "$REPO/files.js"
done

echo "};" >> "$REPO/files.js"

# Only push if there are actual changes
git add -A
if git diff --cached --quiet; then
  echo "$(date): No changes" >> "$LOG"
else
  git commit -m "Sync dashboards $(date +%Y-%m-%d\ %H:%M)"
  git push origin main
  echo "$(date): Pushed $count HTML files" >> "$LOG"
fi
