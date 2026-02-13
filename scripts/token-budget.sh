#!/usr/bin/env bash
set -u

# token-budget.sh <role> [file] [contract-path] [task-number]
# Enforces token/line budgets on context content.
#
# Budget resolution order (v2_token_budgets=true):
#   1. Per-task: contract metadata -> complexity score -> tier multiplier -> role base * multiplier
#   2. Per-role: token-budgets.json .budgets[role].max_lines
#   3. No budget (pass through): role not in budgets or max_lines=0
#
# Input: file path as arg, or stdin if no file.
# Output: truncated content within budget (stdout).
# Logs overage to metrics when v3_metrics=true.
# Exit: 0 always (budget enforcement must never block).

PLANNING_DIR=".vbw-planning"
CONFIG_PATH="${PLANNING_DIR}/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUDGETS_PATH="${SCRIPT_DIR}/../config/token-budgets.json"

# Check feature flag
ENABLED=false
if [ -f "$CONFIG_PATH" ] && command -v jq &>/dev/null; then
  ENABLED=$(jq -r '.v2_token_budgets // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
fi

if [ $# -lt 1 ]; then
  # No role — pass through
  cat 2>/dev/null
  exit 0
fi

ROLE="$1"
shift

# Read content from file arg or stdin
CONTENT=""
if [ $# -ge 1 ] && [ -f "$1" ]; then
  CONTENT=$(cat "$1" 2>/dev/null) || CONTENT=""
  shift
else
  CONTENT=$(cat 2>/dev/null) || CONTENT=""
fi

# Optional contract metadata for per-task budgets
CONTRACT_PATH="${1:-}"
TASK_NUMBER="${2:-}"

# If flag disabled, pass through
if [ "$ENABLED" != "true" ]; then
  echo "$CONTENT"
  exit 0
fi

# Compute per-task budget from contract metadata and complexity tiers
compute_task_budget() {
  local contract_path="$1"
  local role="$2"
  local budgets_path="$3"

  # Check per_task_budget_enabled
  local enabled
  enabled=$(jq -r '.task_complexity.per_task_budget_enabled // false' "$budgets_path" 2>/dev/null) || enabled="false"
  [ "$enabled" != "true" ] && return 1

  # Read contract metadata
  [ ! -f "$contract_path" ] && return 1
  local must_haves_count allowed_paths_count depends_on_count
  must_haves_count=$(jq '.must_haves | length' "$contract_path" 2>/dev/null) || must_haves_count=0
  allowed_paths_count=$(jq '.allowed_paths | length' "$contract_path" 2>/dev/null) || allowed_paths_count=0
  depends_on_count=$(jq '.depends_on | length' "$contract_path" 2>/dev/null) || depends_on_count=0

  # Read weights
  local mh_w files_w dep_w
  mh_w=$(jq -r '.task_complexity.must_haves_weight // 1' "$budgets_path" 2>/dev/null) || mh_w=1
  files_w=$(jq -r '.task_complexity.files_weight // 2' "$budgets_path" 2>/dev/null) || files_w=2
  dep_w=$(jq -r '.task_complexity.dependency_weight // 3' "$budgets_path" 2>/dev/null) || dep_w=3

  # Compute complexity score
  local score
  score=$(( (must_haves_count * mh_w) + (allowed_paths_count * files_w) + (depends_on_count * dep_w) ))

  # Find matching tier
  local multiplier
  multiplier=$(jq -r --argjson s "$score" '
    .task_complexity.tiers
    | map(select(.min_score <= $s and .max_score >= $s))
    | .[0].multiplier // 1.0
  ' "$budgets_path" 2>/dev/null) || multiplier="1.0"

  # Get base role budget
  local base_budget
  base_budget=$(jq -r --arg r "$role" '.budgets[$r].max_lines // 0' "$budgets_path" 2>/dev/null) || base_budget=0
  [ "$base_budget" -eq 0 ] 2>/dev/null && return 1

  # Compute task budget (integer arithmetic via awk for float multiply)
  local task_budget
  task_budget=$(awk "BEGIN {printf \"%.0f\", $base_budget * $multiplier}") || return 1

  echo "$task_budget"
  return 0
}

# Load budget: per-task from contract, or per-role fallback
MAX_LINES=0
BUDGET_SOURCE="role"
if [ -n "$CONTRACT_PATH" ] && [ -f "$CONTRACT_PATH" ] && [ -f "$BUDGETS_PATH" ]; then
  TASK_BUDGET=$(compute_task_budget "$CONTRACT_PATH" "$ROLE" "$BUDGETS_PATH" 2>/dev/null) || TASK_BUDGET=""
  if [ -n "$TASK_BUDGET" ] && [ "$TASK_BUDGET" -gt 0 ] 2>/dev/null; then
    MAX_LINES="$TASK_BUDGET"
    BUDGET_SOURCE="task"
  fi
fi

# Fallback to per-role budget
if [ "$MAX_LINES" -eq 0 ] && [ -f "$BUDGETS_PATH" ]; then
  MAX_LINES=$(jq -r --arg r "$ROLE" '.budgets[$r].max_lines // 0' "$BUDGETS_PATH" 2>/dev/null || echo "0")
fi

# No budget defined — pass through
if [ "$MAX_LINES" -eq 0 ] || [ "$MAX_LINES" = "0" ]; then
  echo "$CONTENT"
  exit 0
fi

# Extract phase/plan numbers from contract path for escalation tracking
PHASE_NUM="0"
PLAN_NUM="0"
if [ -n "$CONTRACT_PATH" ]; then
  # Parse from filename pattern: {phase}-{plan}.json
  CONTRACT_BASENAME=$(basename "$CONTRACT_PATH" .json 2>/dev/null) || CONTRACT_BASENAME=""
  if [[ "$CONTRACT_BASENAME" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    PHASE_NUM="${BASH_REMATCH[1]}"
    PLAN_NUM="${BASH_REMATCH[2]}"
  else
    # Try reading from contract JSON
    PHASE_NUM=$(jq -r '.phase // 0' "$CONTRACT_PATH" 2>/dev/null) || PHASE_NUM="0"
    PLAN_NUM=$(jq -r '.plan // 0' "$CONTRACT_PATH" 2>/dev/null) || PLAN_NUM="0"
  fi
fi

# Apply accumulated budget reduction from prior overages in this plan
TOKEN_STATE_DIR="${PLANNING_DIR}/.token-state"
TOKEN_STATE_FILE="${TOKEN_STATE_DIR}/${PHASE_NUM}-${PLAN_NUM}.json"
if [ "$ENABLED" = "true" ] && [ -n "$CONTRACT_PATH" ] && [ -f "$TOKEN_STATE_FILE" ]; then
  REMAINING_PCT=$(jq -r '.remaining_budget_pct // 100' "$TOKEN_STATE_FILE" 2>/dev/null) || REMAINING_PCT=100
  if [ "$REMAINING_PCT" -lt 100 ] 2>/dev/null; then
    MIN_FLOOR=$(jq -r '.escalation.min_budget_floor // 100' "$BUDGETS_PATH" 2>/dev/null) || MIN_FLOOR=100
    REDUCED_MAX=$(awk "BEGIN {printf \"%.0f\", $MAX_LINES * $REMAINING_PCT / 100}") || REDUCED_MAX="$MAX_LINES"
    if [ "$REDUCED_MAX" -lt "$MIN_FLOOR" ] 2>/dev/null; then
      REDUCED_MAX="$MIN_FLOOR"
    fi
    MAX_LINES="$REDUCED_MAX"
  fi
fi

# Count lines
LINE_COUNT=$(echo "$CONTENT" | wc -l | tr -d ' ')

if [ "$LINE_COUNT" -le "$MAX_LINES" ]; then
  # Within budget
  echo "$CONTENT"
  exit 0
fi

# Truncate (tail strategy: keep last N lines for most recent context)
STRATEGY=$(jq -r '.truncation_strategy // "tail"' "$BUDGETS_PATH" 2>/dev/null || echo "tail")
OVERAGE=$((LINE_COUNT - MAX_LINES))

case "$STRATEGY" in
  tail)
    echo "$CONTENT" | tail -n "$MAX_LINES"
    ;;
  head)
    echo "$CONTENT" | head -n "$MAX_LINES"
    ;;
  *)
    echo "$CONTENT" | tail -n "$MAX_LINES"
    ;;
esac

# Log overage to metrics
METRICS_ENABLED=false
if [ -f "$CONFIG_PATH" ]; then
  METRICS_ENABLED=$(jq -r '.v3_metrics // false' "$CONFIG_PATH" 2>/dev/null || echo "false")
fi

if [ "$METRICS_ENABLED" = "true" ] && [ -f "${SCRIPT_DIR}/collect-metrics.sh" ]; then
  bash "${SCRIPT_DIR}/collect-metrics.sh" token_overage 0 \
    "role=${ROLE}" "lines_total=${LINE_COUNT}" "lines_max=${MAX_LINES}" \
    "lines_truncated=${OVERAGE}" "budget_source=${BUDGET_SOURCE}" 2>/dev/null || true
fi

# Escalation: advisory budget reduction and event emission on overage
if [ "$ENABLED" = "true" ]; then
  # Read escalation config
  REDUCTION_PCT=$(jq -r '.escalation.reduction_percent // 15' "$BUDGETS_PATH" 2>/dev/null) || REDUCTION_PCT=15
  MIN_BUDGET_FLOOR=$(jq -r '.escalation.min_budget_floor // 100' "$BUDGETS_PATH" 2>/dev/null) || MIN_BUDGET_FLOOR=100

  # Compute new remaining budget percentage
  OLD_REMAINING_PCT=100
  OLD_OVERAGES=0
  if [ -n "$CONTRACT_PATH" ] && [ -f "$TOKEN_STATE_FILE" ]; then
    OLD_REMAINING_PCT=$(jq -r '.remaining_budget_pct // 100' "$TOKEN_STATE_FILE" 2>/dev/null) || OLD_REMAINING_PCT=100
    OLD_OVERAGES=$(jq -r '.overages // 0' "$TOKEN_STATE_FILE" 2>/dev/null) || OLD_OVERAGES=0
  fi
  NEW_PCT=$((OLD_REMAINING_PCT - REDUCTION_PCT))
  [ "$NEW_PCT" -lt 0 ] 2>/dev/null && NEW_PCT=0
  NEW_OVERAGES=$((OLD_OVERAGES + 1))

  # Emit stderr warning (enhanced from truncation notice)
  echo "[token-budget] ESCALATION: ${ROLE} exceeded budget by ${OVERAGE} lines (${LINE_COUNT} -> ${MAX_LINES}). Remaining budget reduced to ${NEW_PCT}% for subsequent tasks." >&2

  # Write/update budget reduction sidecar (only when contract path is provided — per-role mode skips state tracking)
  if [ -n "$CONTRACT_PATH" ]; then
    mkdir -p "$TOKEN_STATE_DIR" 2>/dev/null || true
    jq -n \
      --argjson phase "$PHASE_NUM" \
      --argjson plan "$PLAN_NUM" \
      --argjson overages "$NEW_OVERAGES" \
      --argjson remaining "$NEW_PCT" \
      --arg role "$ROLE" \
      --argjson overage "$OVERAGE" \
      '{phase: $phase, plan: $plan, overages: $overages, remaining_budget_pct: $remaining, last_role: $role, last_overage: $overage}' \
      > "$TOKEN_STATE_FILE" 2>/dev/null || true
  fi

  # Emit token_cap_escalated event via log-event.sh
  if [ -f "${SCRIPT_DIR}/log-event.sh" ]; then
    bash "${SCRIPT_DIR}/log-event.sh" token_cap_escalated "${PHASE_NUM}" "${PLAN_NUM}" \
      "role=${ROLE}" "overage=${OVERAGE}" "remaining_pct=${NEW_PCT}" "budget_source=${BUDGET_SOURCE}" 2>/dev/null || true
  fi
fi

# Output truncation notice to stderr (basic notice for non-escalation logging)
echo "[token-budget] ${ROLE}: truncated ${OVERAGE} lines (${LINE_COUNT} -> ${MAX_LINES})" >&2
