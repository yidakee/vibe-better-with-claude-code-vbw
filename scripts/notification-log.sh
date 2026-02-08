#!/bin/bash
# NotificationReceived hook: Log notification metadata
# Non-blocking, fail-open (always exit 0)

PLANNING_DIR=".vbw-planning"

# Guard: only log if planning directory exists
if [ ! -d "$PLANNING_DIR" ]; then
  exit 0
fi

INPUT=$(cat)

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SENDER=$(echo "$INPUT" | jq -r '.sender // .from // "unknown"' 2>/dev/null)
SUMMARY=$(echo "$INPUT" | jq -r '.summary // .subject // ""' 2>/dev/null)

jq -n \
  --arg ts "$TIMESTAMP" \
  --arg sender "$SENDER" \
  --arg summary "$SUMMARY" \
  '{timestamp: $ts, sender: $sender, summary: $summary}' \
  >> "$PLANNING_DIR/.notification-log.jsonl" 2>/dev/null

exit 0
