#!/usr/bin/env bash
set -euo pipefail
# Git pre-push hook: enforce version file consistency before push
# Delegated from .git/hooks/pre-push wrapper installed by install-hooks.sh
# Bypass:  git push --no-verify
#
# This hook only checks that the 4 version files are in sync with each other.
# Version bumping is handled at merge time by a GitHub Action.

# Use git to find the repo root — works regardless of how this script is invoked
# (symlink, direct call, or delegated from the hook wrapper).
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=""
if [ -z "$ROOT" ]; then
  echo "WARNING: pre-push hook could not determine repo root — skipping version check" >&2
  exit 0
fi

# This hook is VBW-specific. Skip entirely if bump-version.sh is absent.
# Note: checking VERSION alone is insufficient — many non-VBW repos have VERSION files.
if [ ! -f "$ROOT/scripts/bump-version.sh" ]; then
  exit 0
fi

VERIFY_OUTPUT=$(bash "$ROOT/scripts/bump-version.sh" --verify 2>&1) || {
  echo ""
  echo "ERROR: Push blocked -- version files are out of sync."
  echo ""
  echo "$VERIFY_OUTPUT" | grep -A 10 "MISMATCH"
  echo ""
  echo "  Run: bash scripts/bump-version.sh --verify"
  echo "  to see details, then manually sync the 4 version files."
  echo ""
  exit 1
}

exit 0
