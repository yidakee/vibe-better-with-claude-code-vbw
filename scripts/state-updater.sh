#!/bin/bash
# PostToolUse hook: Auto-update execution state when SUMMARY.md is written
# Non-blocking, fail-open (always exit 0)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only act on *-SUMMARY.md files in a phases directory
if ! echo "$FILE_PATH" | grep -qE 'phases/.*-SUMMARY\.md$'; then
  exit 0
fi

STATE_FILE=".vbw-planning/.execution-state.json"

# Guard: only act if execution state exists
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Check the SUMMARY.md file exists
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Parse frontmatter from SUMMARY.md for phase, plan, status
PHASE=""
PLAN=""
STATUS=""
IN_FRONTMATTER=0

while IFS= read -r line; do
  if [ "$line" = "---" ]; then
    if [ "$IN_FRONTMATTER" -eq 0 ]; then
      IN_FRONTMATTER=1
      continue
    else
      break
    fi
  fi
  if [ "$IN_FRONTMATTER" -eq 1 ]; then
    key=$(echo "$line" | cut -d: -f1 | tr -d ' ')
    val=$(echo "$line" | cut -d: -f2- | sed 's/^ *//')
    case "$key" in
      phase) PHASE="$val" ;;
      plan) PLAN="$val" ;;
      status) STATUS="$val" ;;
    esac
  fi
done < "$FILE_PATH"

# Need at least phase and plan to update state
if [ -z "$PHASE" ] || [ -z "$PLAN" ]; then
  exit 0
fi

# Default status to "completed" if SUMMARY exists but no status in frontmatter
STATUS="${STATUS:-completed}"

# Update execution state via jq
TEMP_FILE="${STATE_FILE}.tmp"
jq --arg phase "$PHASE" --arg plan "$PLAN" --arg status "$STATUS" '
  if .phases[$phase] and .phases[$phase][$plan] then
    .phases[$phase][$plan].status = $status
  else
    .
  end
' "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$STATE_FILE" 2>/dev/null

exit 0
