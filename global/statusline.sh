#!/usr/bin/env bash
# Claude Code statusline — shows model, git branch, Databricks profile, context usage, cost
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')

# Bridge: write context % for PostToolUse hook to read
echo "$PCT" > "$HOME/.claude/.context-pct-$SESSION_ID" 2>/dev/null
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Git branch
BRANCH=""
if cd "$DIR" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
fi

# Databricks profile from env or .databrickscfg
PROFILE="${DATABRICKS_CONFIG_PROFILE:-DEFAULT}"

# Context bar: green < 50%, yellow 50-75%, red > 75%
if [ "$PCT" -lt 50 ]; then
  CTX_COLOR="\033[32m"
elif [ "$PCT" -lt 75 ]; then
  CTX_COLOR="\033[33m"
else
  CTX_COLOR="\033[31m"
fi
RESET="\033[0m"

# Format cost
COST_FMT=$(printf '$%.2f' "$COST")

echo -e "${MODEL} | ${BRANCH:-detached} | db:${PROFILE} | ${CTX_COLOR}${PCT}%${RESET} ctx | ${COST_FMT} | +${ADDED}/-${REMOVED}"
