#!/bin/bash
# PostToolUse hook — warns when context window usage is high
# Reads context % from bridge file written by statusline.sh
set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

BRIDGE_FILE="$HOME/.claude/.context-pct-$SESSION_ID"

# No bridge file yet (statusline hasn't run) — skip silently
[ ! -f "$BRIDGE_FILE" ] && exit 0

PCT=$(cat "$BRIDGE_FILE" 2>/dev/null || echo 0)

# Warn at 60% — suggest being concise
if [ "$PCT" -ge 60 ] && [ "$PCT" -lt 80 ]; then
  WARN_FILE="$HOME/.claude/.context-warned-60-$SESSION_ID"
  if [ ! -f "$WARN_FILE" ]; then
    touch "$WARN_FILE"
    echo "⚠️  Context window at ${PCT}%. Be concise — avoid verbose outputs and unnecessary file reads."
  fi
fi

# Warn at 80% — suggest pause-work
if [ "$PCT" -ge 80 ]; then
  WARN_FILE="$HOME/.claude/.context-warned-80-$SESSION_ID"
  if [ ! -f "$WARN_FILE" ]; then
    touch "$WARN_FILE"
    echo "🔴 Context window at ${PCT}%. Consider running /pause-work to save state before compaction hits."
  fi
fi

exit 0
