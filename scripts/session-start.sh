#!/bin/bash
set -u
# SessionStart: VBW project state detection, update checks, cache maintenance (exit 0)

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  echo '{"hookSpecificOutput":{"additionalContext":"VBW: jq not found. Install: brew install jq (macOS) / apt install jq (Linux). All 17 VBW quality gates are disabled until jq is installed -- no commit validation, no security filtering, no file guarding."}}'
  exit 0
fi

PLANNING_DIR=".vbw-planning"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Auto-migrate config if .vbw-planning exists
if [ -d "$PLANNING_DIR" ] && [ -f "$PLANNING_DIR/config.json" ]; then
  if ! jq -e '.model_profile' "$PLANNING_DIR/config.json" >/dev/null 2>&1; then
    TMP=$(mktemp)
    jq '. + {model_profile: "quality", model_overrides: {}}' "$PLANNING_DIR/config.json" > "$TMP" && mv "$TMP" "$PLANNING_DIR/config.json"
  fi
fi

# Auto-migrate .claude/CLAUDE.md to root CLAUDE.md (VBW projects only)
if [ -d "$PLANNING_DIR" ] && [ ! -f "$PLANNING_DIR/.claude-md-migrated" ]; then
  CLAUDE_MIGRATE_OK=true
  if [ -f ".claude/CLAUDE.md" ]; then
    if [ ! -f "CLAUDE.md" ]; then
      # Scenario A: .claude/CLAUDE.md only → move to root
      mv ".claude/CLAUDE.md" "CLAUDE.md" || CLAUDE_MIGRATE_OK=false
    else
      # Scenario B: both exist — extract non-VBW content from guard
      EXTRACTED=$(awk '
        BEGIN { skip = 0 }
        /^## (Active Context|VBW Rules|Key Decisions|Installed Skills|Project Conventions|Commands|Plugin Isolation)$/ { skip = 1; next }
        /^## / { skip = 0 }
        /^# / && !/^## / { next }
        /^\*\*Core value:\*\*/ { next }
        !skip { print }
      ' ".claude/CLAUDE.md")
      if echo "$EXTRACTED" | grep -q '[^[:space:]]'; then
        # Has user content — merge into root before VBW sections
        FIRST_VBW=$(grep -nE '^## (Active Context|VBW Rules|Key Decisions|Installed Skills|Project Conventions|Commands|Plugin Isolation)$' "CLAUDE.md" | head -1 | cut -d: -f1)
        TMP=$(mktemp)
        if [ -n "${FIRST_VBW:-}" ]; then
          head -n $((FIRST_VBW - 1)) "CLAUDE.md" > "$TMP"
          echo "$EXTRACTED" >> "$TMP"
          echo "" >> "$TMP"
          tail -n +"$FIRST_VBW" "CLAUDE.md" >> "$TMP"
        else
          cat "CLAUDE.md" > "$TMP"
          echo "" >> "$TMP"
          echo "$EXTRACTED" >> "$TMP"
        fi
        mv "$TMP" "CLAUDE.md" || CLAUDE_MIGRATE_OK=false
      fi
      if [ "$CLAUDE_MIGRATE_OK" = true ]; then
        rm ".claude/CLAUDE.md" || CLAUDE_MIGRATE_OK=false
      fi
    fi
  fi
  if [ "$CLAUDE_MIGRATE_OK" = true ]; then
    touch "$PLANNING_DIR/.claude-md-migrated"
  fi
fi

# Clean compaction marker at session start (fresh-session guarantee, REQ-15)
rm -f "$PLANNING_DIR/.compaction-marker" 2>/dev/null

UPDATE_MSG=""

# --- First-run welcome (DXP-03) ---
VBW_MARKER="$CLAUDE_DIR/.vbw-welcomed"
WELCOME_MSG=""
if [ ! -f "$VBW_MARKER" ]; then
  mkdir -p "$CLAUDE_DIR" 2>/dev/null
  touch "$VBW_MARKER" 2>/dev/null
  WELCOME_MSG="FIRST RUN -- Display this welcome to the user verbatim: Welcome to VBW -- Vibe Better with Claude Code. You're not an engineer anymore. You're a prompt jockey with commit access. At least do it properly. Quick start: /vbw:vibe -- describe your project and VBW handles the rest. Type /vbw:help for the full story. --- "
fi

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
  LOCAL_VER="" REMOTE_VER=""
  IFS='|' read -r LOCAL_VER REMOTE_VER < "$CACHE" 2>/dev/null || true
  if [ -n "${REMOTE_VER:-}" ] && [ "${REMOTE_VER:-}" != "0.0.0" ] && [ "${REMOTE_VER:-}" != "${LOCAL_VER:-}" ]; then
    UPDATE_MSG=" UPDATE AVAILABLE: v${LOCAL_VER:-0.0.0} -> v${REMOTE_VER:-0.0.0}. Run /vbw:update to upgrade."
  fi
fi

# --- Migrate statusLine if using old for-loop pattern ---
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  SL_CMD=$(jq -r '.statusLine.command // .statusLine // ""' "$SETTINGS_FILE" 2>/dev/null)
  if echo "$SL_CMD" | grep -q 'for f in' && echo "$SL_CMD" | grep -q 'vbw-statusline'; then
    CORRECT_CMD="bash -c 'f=\$(ls -1 \"\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}\"/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"\$f\" ] && exec bash \"\$f\"'"
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    if ! jq --arg cmd "$CORRECT_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"; then
      cp "${SETTINGS_FILE}.bak" "$SETTINGS_FILE"
      rm -f "${SETTINGS_FILE}.tmp"
    else
      mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    fi
    rm -f "${SETTINGS_FILE}.bak"
  fi
fi

# --- Clean old cache versions (keep only latest) ---
CACHE_DIR="$CLAUDE_DIR/plugins/cache/vbw-marketplace/vbw"
VBW_CLEANUP_LOCK="/tmp/vbw-cache-cleanup-lock"
if [ -d "$CACHE_DIR" ] && mkdir "$VBW_CLEANUP_LOCK" 2>/dev/null; then
  VERSIONS=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V)
  COUNT=$(echo "$VERSIONS" | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 1 ]; then
    echo "$VERSIONS" | head -n $((COUNT - 1)) | while IFS= read -r dir; do rm -rf "$dir"; done
  fi
  rmdir "$VBW_CLEANUP_LOCK" 2>/dev/null
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
MKT_DIR="$CLAUDE_DIR/plugins/marketplaces/vbw-marketplace"
if [ -d "$MKT_DIR/.git" ] && [ -d "$CACHE_DIR" ]; then
  MKT_VER=$(jq -r '.version // "0"' "$MKT_DIR/.claude-plugin/plugin.json" 2>/dev/null)
  CACHE_VER=$(jq -r '.version // "0"' "$(ls -d "$CACHE_DIR"/*/.claude-plugin/plugin.json 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
  if [ "$MKT_VER" != "$CACHE_VER" ] && [ -n "$CACHE_VER" ] && [ "$CACHE_VER" != "0" ]; then
    (cd "$MKT_DIR" && git fetch origin --quiet 2>/dev/null && \
      if git diff --quiet 2>/dev/null; then
        git reset --hard origin/main --quiet 2>/dev/null
      else
        echo "VBW: marketplace checkout has local modifications — skipping reset" >&2
      fi) &
  fi
  # Content staleness: compare command counts
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

# --- Auto-install git hooks if missing ---
PROJECT_GIT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) || PROJECT_GIT_DIR=""
if [ -n "$PROJECT_GIT_DIR" ] && [ ! -f "$PROJECT_GIT_DIR/.git/hooks/pre-push" ] && [ -f "$SCRIPT_DIR/install-hooks.sh" ]; then
  (bash "$SCRIPT_DIR/install-hooks.sh" 2>/dev/null) || true
fi

# --- Reconcile orphaned execution state ---
EXEC_STATE="$PLANNING_DIR/.execution-state.json"
if [ -f "$EXEC_STATE" ]; then
  EXEC_STATUS=$(jq -r '.status // ""' "$EXEC_STATE" 2>/dev/null)
  if [ "$EXEC_STATUS" = "running" ]; then
    PHASE_NAME=$(jq -r '.phase_name // ""' "$EXEC_STATE" 2>/dev/null)
    PHASE_NUM=$(jq -r '.phase // ""' "$EXEC_STATE" 2>/dev/null)
    PHASE_DIR=""
    if [ -n "$PHASE_NUM" ]; then
      PHASE_DIR=$(ls -d "$PLANNING_DIR/phases/${PHASE_NUM}-"* 2>/dev/null | head -1)
    fi
    if [ -n "$PHASE_DIR" ] && [ -d "$PHASE_DIR" ]; then
      PLAN_COUNT=$(jq -r '.plans | length' "$EXEC_STATE" 2>/dev/null)
      SUMMARY_COUNT=$(ls "$PHASE_DIR"/*-SUMMARY.md 2>/dev/null | wc -l | tr -d ' ')
      if [ "${SUMMARY_COUNT:-0}" -ge "${PLAN_COUNT:-1}" ] && [ "${PLAN_COUNT:-0}" -gt 0 ]; then
        # All plans have SUMMARY.md — build finished after crash
        jq '.status = "complete"' "$EXEC_STATE" > "$PLANNING_DIR/.execution-state.json.tmp" && mv "$PLANNING_DIR/.execution-state.json.tmp" "$EXEC_STATE"
        BUILD_STATE="complete (recovered)"
      else
        BUILD_STATE="interrupted (${SUMMARY_COUNT:-0}/${PLAN_COUNT:-0} plans)"
      fi
      UPDATE_MSG="${UPDATE_MSG} Build state: ${BUILD_STATE}."
    fi
  fi
fi

# --- Project state ---

if [ ! -d "$PLANNING_DIR" ]; then
  jq -n --arg update "$UPDATE_MSG" --arg welcome "$WELCOME_MSG" '{
    "hookSpecificOutput": {
      "additionalContext": ($welcome + "No .vbw-planning/ directory found. Run /vbw:init to set up the project." + $update)
    }
  }'
  exit 0
fi

# --- Resolve ACTIVE milestone ---
MILESTONE_SLUG="none"
if [ -f "$PLANNING_DIR/ACTIVE" ]; then
  MILESTONE_SLUG=$(cat "$PLANNING_DIR/ACTIVE" 2>/dev/null | tr -d '[:space:]')
  MILESTONE_DIR="$PLANNING_DIR/milestones/$MILESTONE_SLUG"
  if [ ! -d "$MILESTONE_DIR" ]; then
    # ACTIVE points to nonexistent directory — fall back
    MILESTONE_SLUG="none"
    MILESTONE_DIR="$PLANNING_DIR"
    PHASES_DIR="$PLANNING_DIR/phases"
  else
    PHASES_DIR="$MILESTONE_DIR/phases"
  fi
else
  MILESTONE_DIR="$PLANNING_DIR"
  PHASES_DIR="$PLANNING_DIR/phases"
fi

# --- Parse config ---
CONFIG_FILE="$PLANNING_DIR/config.json"
config_effort="balanced"
config_autonomy="standard"
config_auto_commit="true"
config_verification="standard"
config_agent_teams="true"
config_max_tasks="5"
if [ -f "$CONFIG_FILE" ]; then
  config_effort=$(jq -r '.effort // "balanced"' "$CONFIG_FILE" 2>/dev/null)
  config_autonomy=$(jq -r '.autonomy // "standard"' "$CONFIG_FILE" 2>/dev/null)
  config_auto_commit=$(jq -r '.auto_commit // true' "$CONFIG_FILE" 2>/dev/null)
  config_verification=$(jq -r '.verification_tier // "standard"' "$CONFIG_FILE" 2>/dev/null)
  config_agent_teams=$(jq -r '.agent_teams // true' "$CONFIG_FILE" 2>/dev/null)
  config_max_tasks=$(jq -r '.max_tasks_per_plan // 5' "$CONFIG_FILE" 2>/dev/null)
fi

# --- Parse STATE.md ---
STATE_FILE="$MILESTONE_DIR/STATE.md"
phase_pos="unknown"
phase_total="unknown"
phase_name="unknown"
phase_status="unknown"
progress_pct="0"
if [ -f "$STATE_FILE" ]; then
  # Extract "Phase: N of M (name)" from "Phase: 1 of 3 (Context Diet)"
  phase_line=$(grep -m1 "^Phase:" "$STATE_FILE" 2>/dev/null || true)
  if [ -n "$phase_line" ]; then
    phase_pos=$(echo "$phase_line" | sed 's/Phase: *\([0-9]*\).*/\1/')
    phase_total=$(echo "$phase_line" | sed 's/.*of *\([0-9]*\).*/\1/')
    phase_name=$(echo "$phase_line" | sed -n 's/.*(\(.*\))/\1/p')
  fi
  # Extract status line
  status_line=$(grep -m1 "^Status:" "$STATE_FILE" 2>/dev/null || true)
  if [ -n "$status_line" ]; then
    phase_status=$(echo "$status_line" | sed 's/Status: *//')
  fi
  # Extract progress percentage
  progress_line=$(grep -m1 "^Progress:" "$STATE_FILE" 2>/dev/null || true)
  if [ -n "$progress_line" ]; then
    progress_pct=$(echo "$progress_line" | grep -o '[0-9]*%' | tr -d '%')
  fi
fi
: "${phase_pos:=unknown}"
: "${phase_total:=unknown}"
: "${phase_name:=unknown}"
: "${phase_status:=unknown}"
: "${progress_pct:=0}"

# --- Determine next action ---
NEXT_ACTION=""
if [ ! -f "$PLANNING_DIR/PROJECT.md" ]; then
  NEXT_ACTION="/vbw:init"
elif [ ! -d "$PHASES_DIR" ] || [ -z "$(ls -d "$PHASES_DIR"/*/ 2>/dev/null)" ]; then
  NEXT_ACTION="/vbw:vibe (needs scoping)"
else
  # Check execution state for interrupted builds
  EXEC_STATE="$PLANNING_DIR/.execution-state.json"
  MILESTONE_EXEC_STATE="$MILESTONE_DIR/.execution-state.json"
  exec_running=false
  for es in "$EXEC_STATE" "$MILESTONE_EXEC_STATE"; do
    if [ -f "$es" ]; then
      es_status=$(jq -r '.status // ""' "$es" 2>/dev/null)
      if [ "$es_status" = "running" ]; then
        exec_running=true
        break
      fi
    fi
  done

  if [ "$exec_running" = true ]; then
    NEXT_ACTION="/vbw:vibe (build interrupted, will resume)"
  else
    # Find next phase needing work
    all_done=true
    next_phase=""
    for pdir in $(ls -d "$PHASES_DIR"/*/ 2>/dev/null | sort); do
      pname=$(basename "$pdir")
      plan_count=$(ls "$pdir"/*-PLAN.md 2>/dev/null | wc -l | tr -d ' ')
      summary_count=$(ls "$pdir"/*-SUMMARY.md 2>/dev/null | wc -l | tr -d ' ')
      if [ "${plan_count:-0}" -eq 0 ]; then
        # Phase has no plans yet — needs planning
        pnum=$(echo "$pname" | sed 's/-.*//')
        NEXT_ACTION="/vbw:vibe (Phase $pnum needs planning)"
        all_done=false
        break
      elif [ "${summary_count:-0}" -lt "${plan_count:-0}" ]; then
        # Phase has plans but not all executed
        pnum=$(echo "$pname" | sed 's/-.*//')
        NEXT_ACTION="/vbw:vibe (Phase $pnum planned, needs execution)"
        all_done=false
        break
      fi
    done
    if [ "$all_done" = true ]; then
      NEXT_ACTION="/vbw:vibe --archive"
    fi
  fi
fi

# --- Build additionalContext ---
CTX="VBW project detected."
CTX="$CTX Milestone: ${MILESTONE_SLUG}."
CTX="$CTX Phase: ${phase_pos}/${phase_total} (${phase_name}) -- ${phase_status}."
CTX="$CTX Progress: ${progress_pct}%."
CTX="$CTX Config: effort=${config_effort}, autonomy=${config_autonomy}, auto_commit=${config_auto_commit}, verification=${config_verification}, agent_teams=${config_agent_teams}, max_tasks=${config_max_tasks}."
CTX="$CTX Next: ${NEXT_ACTION}."

jq -n --arg ctx "$CTX" --arg update "$UPDATE_MSG" --arg welcome "$WELCOME_MSG" '{
  "hookSpecificOutput": {
    "additionalContext": ($welcome + $ctx + $update)
  }
}'

exit 0
