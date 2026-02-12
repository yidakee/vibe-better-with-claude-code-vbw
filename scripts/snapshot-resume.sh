#!/usr/bin/env bash
set -u

# snapshot-resume.sh <save|restore> <phase> [execution-state-path]
# Save: snapshot execution state + git context for crash recovery.
# Restore: find latest snapshot for a phase.
# Snapshots: .vbw-planning/.snapshots/{phase}-{timestamp}.json
# Max 10 per phase (prunes oldest). Fail-open: exit 0 always.

if [ $# -lt 2 ]; then
  exit 0
fi

ACTION="$1"
PHASE="$2"
STATE_PATH="${3:-.vbw-planning/.execution-state.json}"

PLANNING_DIR=".vbw-planning"
CONFIG_PATH="${PLANNING_DIR}/config.json"
SNAPSHOTS_DIR="${PLANNING_DIR}/.snapshots"

# Check feature flag
if [ -f "$CONFIG_PATH" ] && command -v jq &>/dev/null; then
  ENABLED=$(jq -r '.v3_snapshot_resume // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
  [ "$ENABLED" != "true" ] && exit 0
fi

case "$ACTION" in
  save)
    mkdir -p "$SNAPSHOTS_DIR" 2>/dev/null || exit 0
    [ ! -f "$STATE_PATH" ] && exit 0

    TS=$(date -u +"%Y%m%dT%H%M%S" 2>/dev/null || echo "unknown")
    SNAPSHOT_FILE="${SNAPSHOTS_DIR}/${PHASE}-${TS}.json"

    # Build snapshot: execution state + git log + timestamp
    GIT_LOG=$(git log --oneline -5 2>/dev/null || echo "no git")
    GIT_LOG_JSON=$(echo "$GIT_LOG" | jq -R '.' | jq -s '.' 2>/dev/null) || GIT_LOG_JSON="[]"

    EXEC_STATE=$(cat "$STATE_PATH" 2>/dev/null) || EXEC_STATE="{}"

    jq -n \
      --arg snapshot_ts "$TS" \
      --argjson phase "$PHASE" \
      --argjson execution_state "$EXEC_STATE" \
      --argjson recent_commits "$GIT_LOG_JSON" \
      '{snapshot_ts: $snapshot_ts, phase: $phase, execution_state: $execution_state, recent_commits: $recent_commits}' \
      > "$SNAPSHOT_FILE" 2>/dev/null || exit 0

    # Prune: keep max 10 snapshots per phase
    SNAP_COUNT=$(ls -1 "${SNAPSHOTS_DIR}/${PHASE}-"*.json 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SNAP_COUNT" -gt 10 ] 2>/dev/null; then
      PRUNE_COUNT=$((SNAP_COUNT - 10))
      ls -1t "${SNAPSHOTS_DIR}/${PHASE}-"*.json 2>/dev/null | tail -n "$PRUNE_COUNT" | while IFS= read -r old; do
        rm -f "$old" 2>/dev/null || true
      done
    fi

    echo "$SNAPSHOT_FILE"
    ;;

  restore)
    [ ! -d "$SNAPSHOTS_DIR" ] && exit 0

    # Find latest snapshot for this phase
    LATEST=$(ls -1t "${SNAPSHOTS_DIR}/${PHASE}-"*.json 2>/dev/null | head -1)
    if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
      echo "$LATEST"
    fi
    ;;

  *)
    echo "Unknown action: $ACTION. Valid: save, restore" >&2
    ;;
esac

exit 0
