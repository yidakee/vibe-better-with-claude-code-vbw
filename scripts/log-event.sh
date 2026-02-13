#!/usr/bin/env bash
set -u

# log-event.sh <event-type> <phase> [plan] [key=value ...]
# Appends a structured event to .vbw-planning/.events/event-log.jsonl
# Each event includes a unique event_id (UUID when uuidgen available, timestamp+random fallback).
# Exit 0 always — event logging must never block execution.
#
# V1 event types: phase_start, phase_end, plan_start, plan_end,
#                 agent_spawn, agent_shutdown, error, checkpoint
# V2 event types: phase_planned, task_created, task_claimed, task_started,
#                 artifact_written, gate_passed, gate_failed,
#                 task_completed_candidate, task_completed_confirmed,
#                 task_blocked, task_reassigned
#
# Escalation fields for task_blocked events:
#   next_action=<action>  -- e.g., "escalate_lead", "retry", "reassign", "manual_fix"
#   reason=<description>  -- Human-readable blocker description
#
# When v2_typed_protocol=true, unknown event types are rejected
# (warning to stderr, event not written). When false, all types accepted.

if [ $# -lt 2 ]; then
  exit 0
fi

PLANNING_DIR=".vbw-planning"
CONFIG_PATH="${PLANNING_DIR}/config.json"

# Check feature flag
if [ -f "$CONFIG_PATH" ] && command -v jq &>/dev/null; then
  ENABLED=$(jq -r '.v3_event_log // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
  [ "$ENABLED" != "true" ] && exit 0
fi

EVENT_TYPE="$1"
PHASE="$2"
shift 2

# Optional event type validation (REQ-02)
if [ -f "$CONFIG_PATH" ] && command -v jq &>/dev/null; then
  TYPED=$(jq -r '.v2_typed_protocol // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
  if [ "$TYPED" = "true" ]; then
    case "$EVENT_TYPE" in
      # V1 types
      phase_start|phase_end|plan_start|plan_end|agent_spawn|agent_shutdown|error|checkpoint)
        ;;
      # V2 types
      phase_planned|task_created|task_claimed|task_started|artifact_written|gate_passed|gate_failed|task_completed_candidate|task_completed_confirmed|task_blocked|task_reassigned)
        ;;
      # Additional metric/internal types
      token_overage|token_cap_escalated|file_conflict|smart_route|contract_revision|cache_hit|task_completion_rejected|snapshot_restored|state_recovered)
        ;;
      *)
        echo "[log-event] WARNING: unknown event type '${EVENT_TYPE}' rejected by v2_typed_protocol" >&2
        exit 0
        ;;
    esac
  fi
fi

PLAN=""
DATA_PAIRS=""

# Parse remaining args: first non-key=value arg is plan number
for arg in "$@"; do
  case "$arg" in
    *=*)
      KEY=$(echo "$arg" | cut -d'=' -f1)
      VALUE=$(echo "$arg" | cut -d'=' -f2-)
      if [ -n "$DATA_PAIRS" ]; then
        DATA_PAIRS="${DATA_PAIRS},\"${KEY}\":\"${VALUE}\""
      else
        DATA_PAIRS="\"${KEY}\":\"${VALUE}\""
      fi
      ;;
    *)
      if [ -z "$PLAN" ]; then
        PLAN="$arg"
      fi
      ;;
  esac
done

EVENTS_DIR="${PLANNING_DIR}/.events"
EVENTS_FILE="${EVENTS_DIR}/event-log.jsonl"

mkdir -p "$EVENTS_DIR" 2>/dev/null || exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")

# Generate unique event_id
if command -v uuidgen &>/dev/null; then
  EVENT_ID=$(uuidgen 2>/dev/null) || EVENT_ID=""
  if [ -n "$EVENT_ID" ]; then
    EVENT_ID=$(echo "$EVENT_ID" | tr '[:upper:]' '[:lower:]')
  else
    EVENT_ID="${TS}-${RANDOM}${RANDOM}"
  fi
else
  EVENT_ID="${TS}-${RANDOM}${RANDOM}"
fi

PLAN_FIELD=""
if [ -n "$PLAN" ]; then
  PLAN_FIELD=",\"plan\":${PLAN}"
fi

DATA_FIELD=""
if [ -n "$DATA_PAIRS" ]; then
  DATA_FIELD=",\"data\":{${DATA_PAIRS}}"
fi

echo "{\"ts\":\"${TS}\",\"event_id\":\"${EVENT_ID}\",\"event\":\"${EVENT_TYPE}\",\"phase\":${PHASE}${PLAN_FIELD}${DATA_FIELD}}" >> "$EVENTS_FILE" 2>/dev/null || true
