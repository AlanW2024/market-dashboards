#!/bin/bash
# sync-dashboards.sh — Copy HTML dashboards from Obsidian vault to GitHub Pages repo
# Usage: ./sync-dashboards.sh
# Run after generating market reports to update the mobile-viewable site.

set -e

VAULT="/Users/yeehowong/Documents/GitHub/obsidian_vault/01-市場日報"
REPO="/Users/yeehowong/Documents/GitHub/market-dashboards"

cd "$REPO"

# Source → Destination mapping
declare -a PAIRS=(
  "美股/盤前"
  "美股/盤後"
  "港股/盤前"
  "港股/盤後"
  "TradingAgents"
  "TradingAgents/US"
)

count=0
for dir in "${PAIRS[@]}"; do
  mkdir -p "$REPO/$dir"
  if ls "$VAULT/$dir/"*.html 1>/dev/null 2>&1; then
    cp "$VAULT/$dir/"*.html "$REPO/$dir/"
    n=$(ls "$REPO/$dir/"*.html 2>/dev/null | wc -l | tr -d ' ')
    count=$((count + n))
  fi
done

echo "Copied $count HTML files"

# Generate files.js for index.html
echo "const FILES = {" > "$REPO/files.js"

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
echo "Generated files.js"

# Git commit and push
git add -A
if git diff --cached --quiet; then
  echo "No changes to push."
else
  git commit -m "Sync dashboards $(date +%Y-%m-%d\ %H:%M)"
  git push origin main
  echo "✅ Pushed to GitHub Pages"
fi
