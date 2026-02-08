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

# --- Cache integrity check (nuke if critical files missing) ---
if [ -d "$CACHE_DIR" ]; then
  LATEST_CACHE=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V | tail -1)
  if [ -n "$LATEST_CACHE" ]; then
    INTEGRITY_OK=true
    for f in commands/init.md .claude-plugin/plugin.json VERSION config/defaults.json; do
      if [ ! -f "$LATEST_CACHE$f" ]; then
        INTEGRITY_OK=false
        break
      fi
    done
    if [ "$INTEGRITY_OK" = false ]; then
      echo "VBW cache integrity check failed — nuking stale cache" >&2
      rm -rf "$CACHE_DIR"
    fi
  fi
fi

# --- Auto-sync stale marketplace checkout ---
# The marketplace is a git clone that can fall behind the cached plugin.
# If stale, pull it silently so the next /vbw:update works correctly.
MKT_DIR="$HOME/.claude/plugins/marketplaces/vbw-marketplace"
if [ -d "$MKT_DIR/.git" ] && [ -d "$CACHE_DIR" ]; then
  MKT_VER=$(jq -r '.version // "0"' "$MKT_DIR/.claude-plugin/plugin.json" 2>/dev/null)
  CACHE_VER=$(jq -r '.version // "0"' "$(ls -d "$CACHE_DIR"/*/.claude-plugin/plugin.json 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
  if [ "$MKT_VER" != "$CACHE_VER" ] && [ -n "$CACHE_VER" ] && [ "$CACHE_VER" != "0" ]; then
    (cd "$MKT_DIR" && git fetch origin --quiet 2>/dev/null && git reset --hard origin/main --quiet 2>/dev/null) &
  fi
  # Content staleness: compare command counts between marketplace and cache
  # Only compare commands/ dir (both locations have the same structure for this dir)
  if [ -d "$MKT_DIR/commands" ] && [ -d "$CACHE_DIR" ]; then
    LATEST_VER=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V | tail -1)
    if [ -n "$LATEST_VER" ] && [ -d "${LATEST_VER}commands" ]; then
      MKT_CMD_COUNT=$(ls "$MKT_DIR/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
      CACHE_CMD_COUNT=$(ls "${LATEST_VER}commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
      if [ "${MKT_CMD_COUNT:-0}" -ne "${CACHE_CMD_COUNT:-0}" ]; then
        echo "VBW cache stale — marketplace has ${MKT_CMD_COUNT} commands, cache has ${CACHE_CMD_COUNT}" >&2
        rm -rf "$CACHE_DIR"
      fi
    fi
  fi
fi

# --- Sync commands to ~/.claude/commands/vbw/ for /vbw:* autocomplete prefix ---
# Plugin commands/ may not show the namespace prefix in all environments.
# Global commands in a subdirectory (e.g. ~/.claude/commands/vbw/) reliably
# get the subdirectory name as prefix, matching the pattern GSD uses.
VBW_CACHE_CMD=$(ls -d "$HOME"/.claude/plugins/cache/vbw-marketplace/vbw/*/commands 2>/dev/null | sort -V | tail -1)
VBW_GLOBAL_CMD="$HOME/.claude/commands/vbw"
if [ -d "$VBW_CACHE_CMD" ]; then
  mkdir -p "$VBW_GLOBAL_CMD"
  rm -f "$VBW_GLOBAL_CMD"/*.md 2>/dev/null
  cp "$VBW_CACHE_CMD"/*.md "$VBW_GLOBAL_CMD/" 2>/dev/null
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
