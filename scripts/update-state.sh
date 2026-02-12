#!/bin/bash
set -euo pipefail
# Atomic state file updater with mkdir-based locking (portable: macOS + Linux)
#
# Usage patterns:
#   update-state.sh <file> append "<line>"         -- append line to file
#   update-state.sh <file> replace "<old>" "<new>" -- sed replacement
#   update-state.sh <file> json "<jq-expr>"        -- jq on JSON file

if [ $# -lt 3 ]; then
  echo "Usage: update-state.sh <file> <operation> <args...>" >&2
  exit 1
fi

STATE_FILE="$1"
OPERATION="$2"
shift 2

LOCK_DIR="${STATE_FILE}.lock"
MAX_WAIT=10
WAITED=0

# Acquire lock via mkdir (atomic on all filesystems)
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  WAITED=$((WAITED + 1))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "Could not acquire lock on $STATE_FILE after ${MAX_WAIT}s" >&2
    # Force-remove stale lock (older than 30s)
    if [ -d "$LOCK_DIR" ]; then
      LOCK_AGE=0
      if [ "$(uname)" = "Darwin" ]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
      else
        LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0) ))
      fi
      if [ "$LOCK_AGE" -gt 30 ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
        continue
      fi
    fi
    exit 1
  fi
  sleep 1
done

# Ensure lock is released on exit
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

case "$OPERATION" in
  append)
    echo "$1" >> "$STATE_FILE"
    ;;
  replace)
    OLD="$1"
    NEW="$2"
    TMP=$(mktemp)
    sed "s|$OLD|$NEW|g" "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
    ;;
  json)
    JQ_EXPR="$1"
    TMP=$(mktemp)
    jq "$JQ_EXPR" "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
    ;;
  *)
    echo "Unknown operation: $OPERATION. Valid: append, replace, json" >&2
    exit 1
    ;;
esac
