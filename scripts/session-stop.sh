#!/bin/bash
set -u
# Stop hook: Log session metrics to .vbw-planning/.session-log.jsonl
# Non-blocking, fail-open (always exit 0)

PLANNING_DIR=".vbw-planning"

# Guard: only log if planning directory exists
if [ ! -d "$PLANNING_DIR" ]; then
  exit 0
fi

INPUT=$(cat)

# Extract session metrics via jq (fail-silent on missing fields)
COST=$(echo "$INPUT" | jq -r '.cost_usd // .cost // 0' 2>/dev/null)
DURATION=$(echo "$INPUT" | jq -r '.duration_ms // .duration // 0' 2>/dev/null)
TOKENS_IN=$(echo "$INPUT" | jq -r '.tokens_in // .input_tokens // 0' 2>/dev/null)
TOKENS_OUT=$(echo "$INPUT" | jq -r '.tokens_out // .output_tokens // 0' 2>/dev/null)
MODEL=$(echo "$INPUT" | jq -r '.model // "unknown"' 2>/dev/null)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Append JSON line to session log (atomic: write to temp file, then append)
TEMP_FILE="$PLANNING_DIR/.session-log.jsonl.tmp"

jq -n \
  --arg ts "$TIMESTAMP" \
  --argjson dur "${DURATION:-0}" \
  --argjson cost "${COST:-0}" \
  --argjson tin "${TOKENS_IN:-0}" \
  --argjson tout "${TOKENS_OUT:-0}" \
  --arg model "$MODEL" \
  --arg branch "$BRANCH" \
  '{timestamp: $ts, duration_ms: $dur, cost_usd: $cost, tokens_in: $tin, tokens_out: $tout, model: $model, branch: $branch}' \
  > "$TEMP_FILE" 2>/dev/null \
  && [ -O "$TEMP_FILE" ] \
  && cat "$TEMP_FILE" >> "$PLANNING_DIR/.session-log.jsonl" 2>/dev/null

rm -f "$TEMP_FILE" 2>/dev/null

exit 0
