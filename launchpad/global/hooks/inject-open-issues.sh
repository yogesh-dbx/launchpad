#!/bin/bash
# UserPromptSubmit hook — injects open GitHub issues into context
# Runs on every user prompt so Claude always knows what's open
set -euo pipefail

# Only run in git repos with a GitHub remote
git rev-parse --is-inside-work-tree &>/dev/null || exit 0
git remote get-url origin 2>/dev/null | grep -q github || exit 0

# Rate-limit: cache for 60 seconds per repo
if command -v md5sum &>/dev/null; then
  REPO_HASH=$(git rev-parse --show-toplevel 2>/dev/null | md5sum | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
  REPO_HASH=$(git rev-parse --show-toplevel 2>/dev/null | md5 -r | cut -d' ' -f1)
else
  REPO_HASH="default"
fi
CACHE_FILE="/tmp/.claude-issues-${REPO_HASH}"
NOW=$(date +%s)

if [ -f "$CACHE_FILE" ]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    FILE_MOD=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  else
    FILE_MOD=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  fi
  CACHE_AGE=$(( NOW - FILE_MOD ))
  if [ "$CACHE_AGE" -lt 60 ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Fetch open issues (compact format)
ISSUES=$(gh issue list --state open --limit 20 --json number,title,labels --jq '
  .[] | "#\(.number) \(.title) [\(.labels | map(.name) | join(", "))]"
' 2>/dev/null || echo "")

if [ -z "$ISSUES" ]; then
  exit 0
fi

OUTPUT="Open issues:
${ISSUES}"

echo "$OUTPUT" | tee "$CACHE_FILE"
exit 0
