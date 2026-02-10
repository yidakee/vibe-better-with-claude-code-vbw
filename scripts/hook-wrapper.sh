#!/bin/bash
# hook-wrapper.sh — Universal VBW hook wrapper (DXP-01)
#
# Wraps every VBW hook with error logging and graceful degradation.
# No hook failure can ever break a session.
#
# Usage: hook-wrapper.sh <script-name.sh> [extra-args...]
#
# - Resolves the target script from the VBW plugin cache
# - Passes through stdin (hook JSON context) and extra arguments
# - Logs failures to .vbw-planning/.hook-errors.log
# - Always exits 0

SCRIPT="$1"; shift
[ -z "$SCRIPT" ] && exit 0

# Resolve from plugin cache (version-sorted, latest wins)
CACHE="$HOME/.claude/plugins/cache/vbw-marketplace/vbw"
TARGET=$(ls -1 "$CACHE"/*/scripts/"$SCRIPT" 2>/dev/null \
  | (sort -V 2>/dev/null || sort -t. -k1,1n -k2,2n -k3,3n) | tail -1)
[ -z "$TARGET" ] || [ ! -f "$TARGET" ] && exit 0

# Execute — stdin flows through to the target script
bash "$TARGET" "$@"
RC=$?
[ "$RC" -eq 0 ] && exit 0

# --- Failure: log and exit 0 ---
if [ -d ".vbw-planning" ]; then
  LOG=".vbw-planning/.hook-errors.log"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%s")
  printf '%s %s exit=%d\n' "$TS" "$SCRIPT" "$RC" >> "$LOG" 2>/dev/null
  # Trim to last 50 entries to prevent unbounded growth
  if [ -f "$LOG" ]; then
    LC=$(wc -l < "$LOG" 2>/dev/null | tr -d ' ')
    [ "${LC:-0}" -gt 50 ] && { tail -30 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"; } 2>/dev/null
  fi
fi

exit 0
