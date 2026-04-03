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
  "日股/盤前"
  "日股/盤後"
  "TradingAgents"
  "TradingAgents/US"
)

count=0
for dir in "${DIRS[@]}"; do
  mkdir -p "$REPO/$dir"
  # Sync HTML files in root of directory
  if ls "$VAULT/$dir/"*.html 1>/dev/null 2>&1; then
    rsync -u "$VAULT/$dir/"*.html "$REPO/$dir/"
    n=$(ls "$REPO/$dir/"*.html 2>/dev/null | wc -l | tr -d ' ')
    count=$((count + n))
  fi
  # Sync monthly archive subfolders (e.g., 2026-03/)
  for subdir in "$VAULT/$dir"/20[0-9][0-9]-[0-9][0-9]; do
    if [ -d "$subdir" ] && ls "$subdir/"*.html 1>/dev/null 2>&1; then
      month=$(basename "$subdir")
      mkdir -p "$REPO/$dir/$month"
      rsync -u "$subdir/"*.html "$REPO/$dir/$month/"
      n=$(ls "$REPO/$dir/$month/"*.html 2>/dev/null | wc -l | tr -d ' ')
      count=$((count + n))
    fi
  done
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
  "🇯🇵 日股盤前:日股/盤前"
  "🇯🇵 日股盤後:日股/盤後"
  "📈 個股分析:TradingAgents"
  "📈 個股分析 (US):TradingAgents/US"
)

for entry in "${SECTIONS[@]}"; do
  label="${entry%%:*}"
  dir="${entry##*:}"
  echo "  \"$label\": [" >> "$REPO/files.js"
  # Current month files (root of directory)
  find "$REPO/$dir" -maxdepth 1 -name '*.html' -print0 2>/dev/null | sort -rz | while IFS= read -r -d '' f; do
    name=$(basename "$f")
    path="$dir/$name"
    echo "    {\"name\":\"$name\",\"path\":\"$path\",\"dir\":\"$dir\"}," >> "$REPO/files.js"
  done
  # Monthly archive files (subfolders like 2026-03/)
  for subdir in "$REPO/$dir"/20[0-9][0-9]-[0-9][0-9]; do
    if [ -d "$subdir" ]; then
      month=$(basename "$subdir")
      find "$subdir" -maxdepth 1 -name '*.html' -print0 2>/dev/null | sort -rz | while IFS= read -r -d '' f; do
        name=$(basename "$f")
        path="$dir/$month/$name"
        echo "    {\"name\":\"$name\",\"path\":\"$path\",\"dir\":\"$dir/$month\",\"month\":\"$month\"}," >> "$REPO/files.js"
      done
    fi
  done
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
