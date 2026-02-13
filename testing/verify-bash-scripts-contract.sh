#!/usr/bin/env bash
set -euo pipefail

# verify-bash-scripts-contract.sh — Repo-wide checks for shell scripts
#
# Checks all .sh files under scripts/ and testing/ for:
# - executable bit
# - bash shebang
# - valid Bash syntax (bash -n)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

pass() {
  echo "PASS  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL  $1"
  FAIL=$((FAIL + 1))
}

echo "=== Bash Script Contract Verification ==="

while IFS= read -r file; do
  rel="${file#$ROOT/}"

  if [ -x "$file" ]; then
    pass "$rel: executable"
  else
    fail "$rel: not executable"
  fi

  SHEBANG="$(head -1 "$file" 2>/dev/null || true)"
  case "$SHEBANG" in
    '#!/usr/bin/env bash'|'#!/bin/bash')
      pass "$rel: bash shebang"
      ;;
    *)
      fail "$rel: invalid shebang ($SHEBANG)"
      ;;
  esac

  if bash -n "$file" >/dev/null 2>&1; then
    pass "$rel: syntax valid"
  else
    fail "$rel: syntax invalid"
  fi
done < <(find "$ROOT/scripts" "$ROOT/testing" -type f -name '*.sh' | sort)

echo ""
echo "==============================="
echo "TOTAL: $PASS PASS, $FAIL FAIL"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo "All bash script contract checks passed."
exit 0
