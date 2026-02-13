#!/usr/bin/env bash
set -euo pipefail

# verify-init-todo.sh — Contract checks for init/todo state shape
#
# Validates consistency across:
# - templates/STATE.md
# - commands/todo.md instructions
# - scripts/bootstrap/bootstrap-state.sh generated output

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/templates/STATE.md"
TODO_CMD="$ROOT/commands/todo.md"
BOOTSTRAP="$ROOT/scripts/bootstrap/bootstrap-state.sh"

TOTAL_PASS=0
TOTAL_FAIL=0

check() {
  local req="$1"
  local desc="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $req: $desc"
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    echo "FAIL  $req: $desc"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

echo "=== Template + Command Contracts ==="
check "INIT-01" "template has ## Todos section" grep -q '^## Todos$' "$TEMPLATE"
check "INIT-02" "template has ### Pending Todos subsection" grep -q '^### Pending Todos$' "$TEMPLATE"
check "TODO-01" "todo command anchors insertion on ## Todos" grep -q 'Find `## Todos`' "$TODO_CMD"
check "TODO-02" "todo command handles missing Pending subsection" grep -q 'create it under `## Todos`' "$TODO_CMD"

echo ""
echo "=== Bootstrap Output Contracts ==="
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vbw-init-todo.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

BOOTSTRAP_STATE="$TMP_DIR/STATE.md"
check "BOOT-01" "bootstrap script executes" bash "$BOOTSTRAP" "$BOOTSTRAP_STATE" "Test Project" "Test Milestone" 2
check "BOOT-02" "bootstrap output has ## Todos section" grep -q '^## Todos$' "$BOOTSTRAP_STATE"
check "BOOT-03" "bootstrap output has ### Pending Todos subsection" grep -q '^### Pending Todos$' "$BOOTSTRAP_STATE"
check "BOOT-04" "bootstrap output initializes empty todo placeholder" grep -q '^None\.$' "$BOOTSTRAP_STATE"

echo ""
echo "==============================="
echo "TOTAL: $TOTAL_PASS PASS, $TOTAL_FAIL FAIL"
echo "==============================="

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "All init/todo contract checks passed."
  exit 0
fi

echo "Init/todo contract checks failed."
exit 1
