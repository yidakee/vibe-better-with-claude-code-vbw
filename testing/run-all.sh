#!/usr/bin/env bash
set -euo pipefail

# run-all.sh — Single entrypoint for repo verification checks

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Running init/todo contract checks..."
bash "$ROOT/scripts/verify-init-todo.sh"

echo ""
echo "Running bash script contract checks..."
bash "$ROOT/testing/verify-bash-scripts-contract.sh"

echo ""
echo "Running command contract checks..."
bash "$ROOT/testing/verify-commands-contract.sh"

echo ""
if [ "${RUN_VIBE_VERIFY:-0}" = "1" ]; then
  echo "Running vibe consolidation checks..."
  bash "$ROOT/scripts/verify-vibe.sh"
else
  echo "Skipping scripts/verify-vibe.sh (set RUN_VIBE_VERIFY=1 to enable)."
fi

echo ""
echo "All selected checks completed."
