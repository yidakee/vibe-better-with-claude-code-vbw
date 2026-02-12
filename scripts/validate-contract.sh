#!/usr/bin/env bash
set -u

# validate-contract.sh <mode> <contract-path> <task-number> [modified-files...]
# Validates a task against its contract sidecar.
# mode: start (verify contract exists, task in range)
#       end   (check modified files against allowed_paths)
# Fail-open: exit 0 always. Violations are advisory and logged to metrics.

if [ $# -lt 3 ]; then
  echo "Usage: validate-contract.sh <start|end> <contract-path> <task-number> [files...]" >&2
  exit 0
fi

MODE="$1"
CONTRACT_PATH="$2"
TASK_NUM="$3"
shift 3

PLANNING_DIR=".vbw-planning"
CONFIG_PATH="${PLANNING_DIR}/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check feature flag
if [ -f "$CONFIG_PATH" ] && command -v jq &>/dev/null; then
  ENABLED=$(jq -r '.v3_contract_lite // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
  [ "$ENABLED" != "true" ] && exit 0
fi

# Validate contract file exists
if [ ! -f "$CONTRACT_PATH" ]; then
  echo "V3 contract: contract file not found: $CONTRACT_PATH" >&2
  exit 0
fi

# Read contract
TASK_COUNT=$(jq -r '.task_count // 0' "$CONTRACT_PATH" 2>/dev/null) || TASK_COUNT=0
PHASE=$(jq -r '.phase // 0' "$CONTRACT_PATH" 2>/dev/null) || PHASE=0

emit_violation() {
  local violation_type="$1"
  local detail="$2"
  if [ -f "${SCRIPT_DIR}/collect-metrics.sh" ]; then
    bash "${SCRIPT_DIR}/collect-metrics.sh" scope_violation "$PHASE" \
      "type=${violation_type}" "task=${TASK_NUM}" "detail=${detail}" 2>/dev/null || true
  fi
  echo "V3 contract violation (${violation_type}): ${detail}" >&2
}

case "$MODE" in
  start)
    # Verify task number is within plan range
    if [ "$TASK_NUM" -gt "$TASK_COUNT" ] 2>/dev/null || [ "$TASK_NUM" -lt 1 ] 2>/dev/null; then
      emit_violation "task_range" "Task ${TASK_NUM} outside contract range 1-${TASK_COUNT}"
    fi
    ;;

  end)
    # Check each modified file against allowed_paths
    ALLOWED=$(jq -r '.allowed_paths[]' "$CONTRACT_PATH" 2>/dev/null) || ALLOWED=""

    for FILE in "$@"; do
      [ -z "$FILE" ] && continue
      # Normalize: strip leading ./
      NORM_FILE="${FILE#./}"
      FOUND=false

      while IFS= read -r allowed; do
        [ -z "$allowed" ] && continue
        NORM_ALLOWED="${allowed#./}"
        if [ "$NORM_FILE" = "$NORM_ALLOWED" ]; then
          FOUND=true
          break
        fi
      done <<< "$ALLOWED"

      if [ "$FOUND" = "false" ]; then
        emit_violation "out_of_scope" "${NORM_FILE} not in allowed_paths"
      fi
    done
    ;;

  *)
    echo "Unknown mode: $MODE. Valid: start, end" >&2
    ;;
esac

exit 0
