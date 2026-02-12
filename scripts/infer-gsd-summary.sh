#!/usr/bin/env bash
set -euo pipefail

# infer-gsd-summary.sh — Extract recent work context from archived GSD planning data
#
# Usage: infer-gsd-summary.sh GSD_ARCHIVE_DIR
#   GSD_ARCHIVE_DIR   Path to .vbw-planning/gsd-archive/ directory
#
# Output: JSON to stdout with latest milestone, recent phases, key decisions,
#         and current work status. Focused on recent context (last 2-3 phases).
#
# Exit: Always exits 0. Missing directory/files produce minimal JSON, not errors.

EMPTY_JSON='{"latest_milestone":null,"recent_phases":[],"key_decisions":[],"current_work":null}'

if [[ $# -lt 1 ]]; then
  echo "$EMPTY_JSON" | jq .
  exit 0
fi

GSD_ARCHIVE_DIR="$1"

# If archive directory doesn't exist, output minimal JSON
if [[ ! -d "$GSD_ARCHIVE_DIR" ]]; then
  echo "$EMPTY_JSON" | jq .
  exit 0
fi

# --- Extract latest milestone from INDEX.json ---
LATEST_MILESTONE="null"
INDEX_FILE="$GSD_ARCHIVE_DIR/INDEX.json"

if [[ -f "$INDEX_FILE" ]]; then
  milestone_name=$(jq -r '.milestones[-1] // empty' "$INDEX_FILE" 2>/dev/null || true)
  if [[ -n "$milestone_name" ]]; then
    phases_total=$(jq -r '.phases_total // 0' "$INDEX_FILE" 2>/dev/null || echo "0")
    phases_complete=$(jq -r '.phases_complete // 0' "$INDEX_FILE" 2>/dev/null || echo "0")
    if [[ "$phases_complete" -eq "$phases_total" ]] && [[ "$phases_total" -gt 0 ]]; then
      milestone_status="complete"
    else
      milestone_status="in_progress"
    fi
    LATEST_MILESTONE=$(jq -n \
      --arg name "$milestone_name" \
      --argjson phase_count "$phases_total" \
      --arg status "$milestone_status" \
      '{"name": $name, "phase_count": $phase_count, "status": $status}')
  fi
fi

# --- Build output ---
jq -n \
  --argjson latest_milestone "$LATEST_MILESTONE" \
  '{
    "latest_milestone": $latest_milestone,
    "recent_phases": [],
    "key_decisions": [],
    "current_work": null
  }'
