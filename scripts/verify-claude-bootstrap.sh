#!/usr/bin/env bash
set -euo pipefail

# verify-claude-bootstrap.sh — Regression checks for bootstrap-claude.sh
#
# Usage: bash scripts/verify-claude-bootstrap.sh
# Exit: 0 if all pass, 1 if any fail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOTSTRAP="$ROOT/scripts/bootstrap/bootstrap-claude.sh"

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  fi
}

check_absent() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  FAIL  $label"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  fi
}

echo "=== verify-claude-bootstrap ==="

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OUT="$TMP_DIR/CLAUDE.md"

# 1) Greenfield generation
bash "$BOOTSTRAP" "$OUT" "Demo Project" "Demo core value"
check "greenfield creates output" test -f "$OUT"
check "greenfield has project title" grep -q '^# Demo Project$' "$OUT"
check "greenfield has core value" grep -q '^\*\*Core value:\*\* Demo core value$' "$OUT"
check "greenfield has Active Context" grep -q '^## Active Context$' "$OUT"
check "greenfield has Project Conventions" grep -q '^## Project Conventions$' "$OUT"
check "greenfield has Plugin Isolation" grep -q '^## Plugin Isolation$' "$OUT"

# 3) Brownfield preservation + managed section replacement
cat > "$TMP_DIR/existing.md" <<'EOF'
# Legacy Project

**Core value:** Legacy value

## Custom Notes
Keep this section.

## VBW Rules
OLD MANAGED CONTENT SHOULD BE REPLACED

## Codebase Intelligence
OLD GSD CONTENT SHOULD BE STRIPPED

## Project Reference
OLD GSD PROJECT REFERENCE

## GSD Rules
OLD GSD RULES

## GSD Context
OLD GSD CONTEXT

## What This Is
OLD GSD WHAT THIS IS

## Core Value
OLD GSD CORE VALUE HEADER

## Context
OLD GSD CONTEXT HEADER

## Constraints
OLD GSD CONSTRAINTS HEADER

## Team Notes
Keep this too.
EOF

bash "$BOOTSTRAP" "$OUT" "Demo Project" "Demo core value" "$TMP_DIR/existing.md"
check "brownfield preserves custom section" grep -q '^## Custom Notes$' "$OUT"
check "brownfield preserves team section" grep -q '^## Team Notes$' "$OUT"
check_absent "brownfield strips old managed VBW content" grep -q 'OLD MANAGED CONTENT SHOULD BE REPLACED' "$OUT"
check_absent "brownfield strips old managed GSD section" grep -q '^## Codebase Intelligence$' "$OUT"

for header in \
  "## Codebase Intelligence" \
  "## Project Reference" \
  "## GSD Rules" \
  "## GSD Context" \
  "## What This Is" \
  "## Core Value" \
  "## Context" \
  "## Constraints"; do
  check_absent "brownfield strips fingerprinted $header" grep -q "^${header}$" "$OUT"
done

VBW_RULES_COUNT="$(grep -c '^## VBW Rules$' "$OUT")"
if [ "$VBW_RULES_COUNT" -eq 1 ]; then
  echo "  PASS  brownfield has one VBW Rules section"
  PASS=$((PASS + 1))
else
  echo "  FAIL  brownfield has one VBW Rules section (found $VBW_RULES_COUNT)"
  FAIL=$((FAIL + 1))
fi

# 4) Idempotency: regenerate from generated file should be stable
cp "$OUT" "$TMP_DIR/before.md"
bash "$BOOTSTRAP" "$OUT" "Demo Project" "Demo core value" "$OUT"
if cmp -s "$TMP_DIR/before.md" "$OUT"; then
  echo "  PASS  idempotent regeneration"
  PASS=$((PASS + 1))
else
  echo "  FAIL  idempotent regeneration"
  FAIL=$((FAIL + 1))
fi

# 5) Preserve generic custom Context/Constraints without strong GSD fingerprint
cat > "$TMP_DIR/custom-generic.md" <<'EOF'
# Team Project

**Core value:** Team core value

## Context
This is team-specific context and should be preserved.

## Constraints
These are team-specific constraints and should be preserved.
EOF

bash "$BOOTSTRAP" "$OUT" "Team Project" "Team core value" "$TMP_DIR/custom-generic.md"
check "preserve custom generic Context section" grep -q '^## Context$' "$OUT"
check "preserve custom generic Constraints section" grep -q '^## Constraints$' "$OUT"
check "preserve custom generic Context content" grep -q 'team-specific context' "$OUT"
check "preserve custom generic Constraints content" grep -q 'team-specific constraints' "$OUT"

# 5) Edge case: empty PROJECT_NAME and CORE_VALUE should be rejected
check_absent "rejects empty PROJECT_NAME" bash "$BOOTSTRAP" "$OUT" "" "Some value"
check_absent "rejects empty CORE_VALUE" bash "$BOOTSTRAP" "$OUT" "Some Name" ""

echo ""
echo "TOTAL: $PASS PASS, $FAIL FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo "All checks passed."
  exit 0
fi

echo "Some checks failed."
exit 1
