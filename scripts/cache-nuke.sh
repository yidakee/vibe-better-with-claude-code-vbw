#!/usr/bin/env bash
# cache-nuke.sh — Wipe ALL VBW caches to prevent stale contamination.
#
# Usage:
#   cache-nuke.sh              # wipe everything
#   cache-nuke.sh --keep-latest  # keep latest cached plugin version, wipe rest
#
# Called by: /vbw:update, session-start.sh
# Output: JSON summary of what was wiped.

set -eo pipefail

KEEP_LATEST=false
if [[ "${1:-}" == "--keep-latest" ]]; then
  KEEP_LATEST=true
fi

PLUGIN_CACHE_DIR="$HOME/.claude/plugins/cache/vbw-marketplace/vbw"
GLOBAL_CMD_DIR="$HOME/.claude/commands/vbw"
UID_TAG="$(id -u)"

wiped_plugin_cache=false
wiped_global_commands=false
wiped_temp_caches=false
versions_removed=0

# --- 1. Plugin cache ---
if [[ -d "$PLUGIN_CACHE_DIR" ]]; then
  if [[ "$KEEP_LATEST" == true ]]; then
    VERSIONS=$(ls -d "$PLUGIN_CACHE_DIR"/*/ 2>/dev/null | sort -V || true)
    COUNT=$(echo "$VERSIONS" | grep -c '/' || true)
    if [[ "$COUNT" -gt 1 ]]; then
      TO_REMOVE=$(echo "$VERSIONS" | head -n $((COUNT - 1)))
      versions_removed=$((COUNT - 1))
      echo "$TO_REMOVE" | xargs rm -rf 2>/dev/null || true
      wiped_plugin_cache=true
    fi
  else
    versions_removed=$(ls -d "$PLUGIN_CACHE_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
    rm -rf "$PLUGIN_CACHE_DIR"
    wiped_plugin_cache=true
  fi
fi

# --- 2. Global commands ---
if [[ -d "$GLOBAL_CMD_DIR" ]]; then
  rm -rf "$GLOBAL_CMD_DIR"
  wiped_global_commands=true
fi

# --- 3. Temp caches (statusline + update check) ---
TEMP_FILES=$(ls /tmp/vbw-*-"${UID_TAG}"-* /tmp/vbw-*-"${UID_TAG}" /tmp/vbw-update-check-"${UID_TAG}" 2>/dev/null || true)
if [[ -n "$TEMP_FILES" ]]; then
  echo "$TEMP_FILES" | xargs rm -f 2>/dev/null || true
  wiped_temp_caches=true
fi

# --- JSON summary ---
cat <<EOF
{"wiped":{"plugin_cache":${wiped_plugin_cache},"global_commands":${wiped_global_commands},"temp_caches":${wiped_temp_caches},"versions_removed":${versions_removed}}}
EOF
