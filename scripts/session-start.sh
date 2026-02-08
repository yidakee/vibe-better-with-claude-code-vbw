#!/bin/bash
# SessionStart hook: Detect VBW project state and check for updates

PLANNING_DIR=".vbw-planning"
UPDATE_MSG=""

# --- Update check (once per day, fail-silent) ---

CACHE="/tmp/vbw-update-check-$(id -u)"
NOW=$(date +%s)
if [ "$(uname)" = "Darwin" ]; then
  MT=$(stat -f %m "$CACHE" 2>/dev/null || echo 0)
else
  MT=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
fi

if [ ! -f "$CACHE" ] || [ $((NOW - MT)) -gt 86400 ]; then
  # Get installed version from plugin.json next to this script
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  LOCAL_VER=$(jq -r '.version // "0.0.0"' "$SCRIPT_DIR/../.claude-plugin/plugin.json" 2>/dev/null)

  # Fetch latest version from GitHub (3s timeout)
  REMOTE_VER=$(curl -sf --max-time 3 \
    "https://raw.githubusercontent.com/yidakee/vibe-better-with-claude-code-vbw/main/.claude-plugin/plugin.json" \
    2>/dev/null | jq -r '.version // "0.0.0"' 2>/dev/null)

  # Cache the result regardless
  echo "${LOCAL_VER:-0.0.0}|${REMOTE_VER:-0.0.0}" > "$CACHE" 2>/dev/null

  if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "0.0.0" ] && [ "$REMOTE_VER" != "$LOCAL_VER" ]; then
    UPDATE_MSG=" UPDATE AVAILABLE: v${LOCAL_VER} -> v${REMOTE_VER}. Run /vbw:update to upgrade."
  fi
else
  # Read cached result
  IFS='|' read -r LOCAL_VER REMOTE_VER < "$CACHE" 2>/dev/null
  if [ -n "$REMOTE_VER" ] && [ "$REMOTE_VER" != "0.0.0" ] && [ "$REMOTE_VER" != "$LOCAL_VER" ]; then
    UPDATE_MSG=" UPDATE AVAILABLE: v${LOCAL_VER} -> v${REMOTE_VER}. Run /vbw:update to upgrade."
  fi
fi

# --- Migrate statusLine if using old for-loop pattern ---
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  SL_CMD=$(jq -r '.statusLine.command // .statusLine // ""' "$SETTINGS_FILE" 2>/dev/null)
  if echo "$SL_CMD" | grep -q 'for f in' && echo "$SL_CMD" | grep -q 'vbw-statusline'; then
    CORRECT_CMD="bash -c 'f=\$(ls -1 \"\$HOME\"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"\$f\" ] && exec bash \"\$f\"'"
    jq --arg cmd "$CORRECT_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  fi
fi

# --- Clean old cache versions (keep only latest) ---
CACHE_DIR="$HOME/.claude/plugins/cache/vbw-marketplace/vbw"
if [ -d "$CACHE_DIR" ]; then
  VERSIONS=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V)
  COUNT=$(echo "$VERSIONS" | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 1 ]; then
    echo "$VERSIONS" | head -n $((COUNT - 1)) | xargs rm -rf 2>/dev/null
  fi
fi

# --- Project state ---

if [ ! -d "$PLANNING_DIR" ]; then
  jq -n --arg update "$UPDATE_MSG" '{
    "hookSpecificOutput": {
      "additionalContext": ("No .vbw-planning/ directory found. Run /vbw:init to set up the project." + $update)
    }
  }'
  exit 0
fi

CONFIG_FILE="$PLANNING_DIR/config.json"
EFFORT="balanced"
if [ -f "$CONFIG_FILE" ]; then
  EFFORT=$(jq -r '.effort // "balanced"' "$CONFIG_FILE")
fi

STATE_FILE="$PLANNING_DIR/STATE.md"
STATE_INFO="no STATE.md found"
if [ -f "$STATE_FILE" ]; then
  PHASE=$(grep -m1 "^## Current Phase" "$STATE_FILE" | sed 's/## Current Phase: *//')
  STATE_INFO="current phase: ${PHASE:-unknown}"
fi

jq -n --arg effort "$EFFORT" --arg state "$STATE_INFO" --arg update "$UPDATE_MSG" '{
  "hookSpecificOutput": {
    "additionalContext": ("VBW project detected. Effort: " + $effort + ". State: " + $state + "." + $update)
  }
}'

exit 0
