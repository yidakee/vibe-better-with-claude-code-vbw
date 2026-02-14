#!/bin/bash
set -u
# SessionStart: VBW project state detection, update checks, cache maintenance (exit 0)

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  echo '{"hookSpecificOutput":{"additionalContext":"VBW: jq not found. Install: brew install jq (macOS) / apt install jq (Linux). All 17 VBW quality gates are disabled until jq is installed -- no commit validation, no security filtering, no file guarding."}}'
  exit 0
fi

PLANNING_DIR=".vbw-planning"
# shellcheck source=resolve-claude-dir.sh
. "$(dirname "$0")/resolve-claude-dir.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# If this is a compact-triggered SessionStart, skip — post-compact.sh handles it.
# The compaction marker is set by compaction-instructions.sh (PreCompact) and cleared
# by post-compact.sh. Only skip if the marker is fresh (< 60s) to avoid stale markers
# from crashed compactions blocking normal session starts.
if [ -f "$PLANNING_DIR/.compaction-marker" ]; then
  _cm_ts=$(cat "$PLANNING_DIR/.compaction-marker" 2>/dev/null || echo 0)
  _cm_now=$(date +%s 2>/dev/null || echo 0)
  if [ $((_cm_now - _cm_ts)) -lt 60 ]; then
    exit 0
  fi
  # Stale marker from crashed compaction — clean up and continue
  rm -f "$PLANNING_DIR/.compaction-marker" 2>/dev/null
fi

# Auto-migrate config if .vbw-planning exists
# Version marker: skip flag migration when config already has all flags from this version.
# The marker is the count of expected flags — if it matches, no jq pass needed.
EXPECTED_FLAG_COUNT=23
if [ -d "$PLANNING_DIR" ] && [ -f "$PLANNING_DIR/config.json" ]; then
  if ! jq -e 'has("model_profile")' "$PLANNING_DIR/config.json" >/dev/null 2>&1; then
    TMP=$(mktemp)
    jq '. + {model_profile: "quality", model_overrides: {}}' "$PLANNING_DIR/config.json" > "$TMP" && mv "$TMP" "$PLANNING_DIR/config.json"
  fi
  if ! jq -e 'has("prefer_teams")' "$PLANNING_DIR/config.json" >/dev/null 2>&1; then
    TMP=$(mktemp)
    jq '. + {prefer_teams: "always"}' "$PLANNING_DIR/config.json" > "$TMP" && mv "$TMP" "$PLANNING_DIR/config.json"
  fi
  # Check if migration is needed: count how many of the expected flags already exist.
  # If all present, skip the jq pass entirely (H8: avoid re-evaluation every session).
  CURRENT_FLAG_COUNT=$(jq '[
    has("context_compiler"), has("v3_delta_context"), has("v3_context_cache"),
    has("v3_plan_research_persist"), has("v3_metrics"), has("v3_contract_lite"),
    has("v3_lock_lite"), has("v3_validation_gates"), has("v3_smart_routing"),
    has("v3_event_log"), has("v3_schema_validation"), has("v3_snapshot_resume"),
    has("v3_lease_locks"), has("v3_event_recovery"), has("v3_monorepo_routing"),
    has("v2_hard_contracts"), has("v2_hard_gates"), has("v2_typed_protocol"),
    has("v2_role_isolation"), has("v2_two_phase_completion"), has("v2_token_budgets"),
    has("model_overrides"), has("prefer_teams")
  ] | map(select(.)) | length' "$PLANNING_DIR/config.json" 2>/dev/null)

  if [ "${CURRENT_FLAG_COUNT:-0}" -lt "$EXPECTED_FLAG_COUNT" ]; then
    # Comprehensive feature flag migration — single pass adds all missing flags
    # Canonical flag list from config/defaults.json. All default to false for existing users.
    TMP=$(mktemp)
    if jq '
      . +
      (if has("context_compiler") then {} else {context_compiler: true} end) +
      (if has("v3_delta_context") then {} else {v3_delta_context: false} end) +
      (if has("v3_context_cache") then {} else {v3_context_cache: false} end) +
      (if has("v3_plan_research_persist") then {} else {v3_plan_research_persist: false} end) +
      (if has("v3_metrics") then {} else {v3_metrics: false} end) +
      (if has("v3_contract_lite") then {} else {v3_contract_lite: false} end) +
      (if has("v3_lock_lite") then {} else {v3_lock_lite: false} end) +
      (if has("v3_validation_gates") then {} else {v3_validation_gates: false} end) +
      (if has("v3_smart_routing") then {} else {v3_smart_routing: false} end) +
      (if has("v3_event_log") then {} else {v3_event_log: false} end) +
      (if has("v3_schema_validation") then {} else {v3_schema_validation: false} end) +
      (if has("v3_snapshot_resume") then {} else {v3_snapshot_resume: false} end) +
      (if has("v3_lease_locks") then {} else {v3_lease_locks: false} end) +
      (if has("v3_event_recovery") then {} else {v3_event_recovery: false} end) +
      (if has("v3_monorepo_routing") then {} else {v3_monorepo_routing: false} end) +
      (if has("v2_hard_contracts") then {} else {v2_hard_contracts: false} end) +
      (if has("v2_hard_gates") then {} else {v2_hard_gates: false} end) +
      (if has("v2_typed_protocol") then {} else {v2_typed_protocol: false} end) +
      (if has("v2_role_isolation") then {} else {v2_role_isolation: false} end) +
      (if has("v2_two_phase_completion") then {} else {v2_two_phase_completion: false} end) +
      (if has("v2_token_budgets") then {} else {v2_token_budgets: false} end)
    ' "$PLANNING_DIR/config.json" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$PLANNING_DIR/config.json"
    else
      echo "WARNING: Config migration failed (jq error). Config may be missing flags." >&2
      rm -f "$TMP"
    fi
  fi
fi

# --- Migrate .claude/CLAUDE.md to root CLAUDE.md (one-time, #20) ---
# Old VBW versions wrote a duplicate isolation guard to .claude/CLAUDE.md.
# Consolidate to root CLAUDE.md only. Three scenarios:
#   A) .claude/CLAUDE.md only (no root) → mv to root
#   B) Both exist → root already has isolation via bootstrap, delete guard
#   C) Root only → no-op
if [ -d "$PLANNING_DIR" ] && [ ! -f "$PLANNING_DIR/.claude-md-migrated" ]; then
  GUARD=".claude/CLAUDE.md"
  ROOT_CLAUDE="CLAUDE.md"
  if [ -f "$GUARD" ]; then
    if [ ! -f "$ROOT_CLAUDE" ]; then
      # Scenario A: guard only → move to root
      mv "$GUARD" "$ROOT_CLAUDE" 2>/dev/null || true
    else
      # Scenario B: both exist → root wins, delete guard
      rm -f "$GUARD" 2>/dev/null || true
    fi
  fi
  # Mark migration done (idempotent)
  echo "1" > "$PLANNING_DIR/.claude-md-migrated" 2>/dev/null || true
fi

# --- Session-level config cache (performance optimization, REQ-01 #9) ---
# Write commonly-read config flags to a flat file for fast sourcing.
# Invalidation: overwritten every session start. Scripts can opt-in:
#   [ -f /tmp/vbw-config-cache-$(id -u) ] && source /tmp/vbw-config-cache-$(id -u)
VBW_CONFIG_CACHE="/tmp/vbw-config-cache-$(id -u)"
if [ -d "$PLANNING_DIR" ] && [ -f "$PLANNING_DIR/config.json" ] && command -v jq &>/dev/null; then
  jq -r '
    "VBW_EFFORT=\(.effort // "balanced")",
    "VBW_AUTONOMY=\(.autonomy // "standard")",
    "VBW_CONTEXT_COMPILER=\(if .context_compiler == null then true else .context_compiler end)",
    "VBW_V3_DELTA_CONTEXT=\(.v3_delta_context // false)",
    "VBW_V3_CONTEXT_CACHE=\(.v3_context_cache // false)",
    "VBW_V3_PLAN_RESEARCH_PERSIST=\(.v3_plan_research_persist // false)",
    "VBW_V3_METRICS=\(.v3_metrics // false)",
    "VBW_V3_CONTRACT_LITE=\(.v3_contract_lite // false)",
    "VBW_V3_LOCK_LITE=\(.v3_lock_lite // false)",
    "VBW_V3_VALIDATION_GATES=\(.v3_validation_gates // false)",
    "VBW_V3_SMART_ROUTING=\(.v3_smart_routing // false)",
    "VBW_V3_EVENT_LOG=\(.v3_event_log // false)",
    "VBW_V3_SCHEMA_VALIDATION=\(.v3_schema_validation // false)",
    "VBW_V3_SNAPSHOT_RESUME=\(.v3_snapshot_resume // false)",
    "VBW_V3_LEASE_LOCKS=\(.v3_lease_locks // false)",
    "VBW_V3_EVENT_RECOVERY=\(.v3_event_recovery // false)",
    "VBW_V3_MONOREPO_ROUTING=\(.v3_monorepo_routing // false)",
    "VBW_V2_HARD_CONTRACTS=\(.v2_hard_contracts // false)",
    "VBW_V2_HARD_GATES=\(.v2_hard_gates // false)",
    "VBW_V2_TYPED_PROTOCOL=\(.v2_typed_protocol // false)",
    "VBW_V2_ROLE_ISOLATION=\(.v2_role_isolation // false)",
    "VBW_V2_TWO_PHASE_COMPLETION=\(.v2_two_phase_completion // false)",
    "VBW_V2_TOKEN_BUDGETS=\(.v2_token_budgets // false)"
  ' "$PLANNING_DIR/config.json" > "$VBW_CONFIG_CACHE" 2>/dev/null || true
fi

# --- Flag dependency validation (REQ-01) ---
FLAG_WARNINGS=""
if [ -d "$PLANNING_DIR" ] && [ -f "$PLANNING_DIR/config.json" ]; then
  _v2_hard_gates=$(jq -r '.v2_hard_gates // false' "$PLANNING_DIR/config.json" 2>/dev/null)
  _v2_hard_contracts=$(jq -r '.v2_hard_contracts // false' "$PLANNING_DIR/config.json" 2>/dev/null)
  _v3_event_recovery=$(jq -r '.v3_event_recovery // false' "$PLANNING_DIR/config.json" 2>/dev/null)
  _v3_event_log=$(jq -r '.v3_event_log // false' "$PLANNING_DIR/config.json" 2>/dev/null)
  _v2_two_phase=$(jq -r '.v2_two_phase_completion // false' "$PLANNING_DIR/config.json" 2>/dev/null)

  if [ "$_v2_hard_gates" = "true" ] && [ "$_v2_hard_contracts" != "true" ]; then
    FLAG_WARNINGS="${FLAG_WARNINGS} WARNING: v2_hard_gates requires v2_hard_contracts -- enable v2_hard_contracts first or contract_compliance gate will fail."
  fi
  if [ "$_v3_event_recovery" = "true" ] && [ "$_v3_event_log" != "true" ]; then
    FLAG_WARNINGS="${FLAG_WARNINGS} WARNING: v3_event_recovery requires v3_event_log -- enable v3_event_log first or event recovery will find no events."
  fi
  if [ "$_v2_two_phase" = "true" ] && [ "$_v3_event_log" != "true" ]; then
    FLAG_WARNINGS="${FLAG_WARNINGS} WARNING: v2_two_phase_completion requires v3_event_log -- enable v3_event_log first or completion events will be lost."
  fi
fi

# Compaction marker cleanup moved to the early-exit check above and to post-compact.sh

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
        git merge --ff-only origin/main --quiet 2>/dev/null
      else
        echo "VBW: marketplace checkout has local modifications — skipping reset" >&2
      fi) &
  fi
  # Content staleness: compare command counts
  if [ -d "$MKT_DIR/commands" ] && [ -d "$CACHE_DIR" ]; then
    LATEST_VER=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V | tail -1)
    if [ -n "$LATEST_VER" ] && [ -d "${LATEST_VER}commands" ]; then
      # zsh compat: bare globs error before ls runs in zsh (nomatch). Use ls dir | grep.
      # shellcheck disable=SC2010
      MKT_CMD_COUNT=$(ls -1 "$MKT_DIR/commands/" 2>/dev/null | grep '\.md$' | wc -l | tr -d ' ')
      # shellcheck disable=SC2010
      CACHE_CMD_COUNT=$(ls -1 "${LATEST_VER}commands/" 2>/dev/null | grep '\.md$' | wc -l | tr -d ' ')
      if [ "${MKT_CMD_COUNT:-0}" -ne "${CACHE_CMD_COUNT:-0}" ]; then
        echo "VBW cache stale — marketplace has ${MKT_CMD_COUNT} commands, cache has ${CACHE_CMD_COUNT}" >&2
        rm -rf "$CACHE_DIR"
      fi
    fi
  fi
fi

# --- Sync global commands mirror for vbw: prefix in autocomplete ---
VBW_GLOBAL_CMD="$CLAUDE_DIR/commands/vbw"
CACHED_VER=$(ls -d "$CACHE_DIR"/*/ 2>/dev/null | sort -V | tail -1)
if [ -n "$CACHED_VER" ] && [ -d "${CACHED_VER}commands" ]; then
  mkdir -p "$VBW_GLOBAL_CMD"
  # Remove stale commands not in cache, then copy fresh
  if [ -d "$VBW_GLOBAL_CMD" ]; then
    for f in "$VBW_GLOBAL_CMD"/*.md; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      [ -f "${CACHED_VER}commands/$base" ] || rm -f "$f"
    done
  fi
  cp "${CACHED_VER}commands/"*.md "$VBW_GLOBAL_CMD/" 2>/dev/null
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
    PHASE_NUM=$(jq -r '.phase // ""' "$EXEC_STATE" 2>/dev/null)
    PHASE_DIR=""
    if [ -n "$PHASE_NUM" ]; then
      PHASE_DIR=$(ls -d "$PLANNING_DIR/phases/${PHASE_NUM}-"* 2>/dev/null | head -1)
    fi
    if [ -n "$PHASE_DIR" ] && [ -d "$PHASE_DIR" ]; then
      PLAN_COUNT=$(jq -r '.plans | length' "$EXEC_STATE" 2>/dev/null)
      # zsh compat: use ls dir | grep to avoid bare glob expansion errors
      # shellcheck disable=SC2010
      SUMMARY_COUNT=$(ls -1 "$PHASE_DIR" 2>/dev/null | grep '\-SUMMARY\.md$' | wc -l | tr -d ' ')
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
config_prefer_teams="always"
config_max_tasks="5"
if [ -f "$CONFIG_FILE" ]; then
  config_effort=$(jq -r '.effort // "balanced"' "$CONFIG_FILE" 2>/dev/null)
  config_autonomy=$(jq -r '.autonomy // "standard"' "$CONFIG_FILE" 2>/dev/null)
  config_auto_commit=$(jq -r 'if .auto_commit == null then true else .auto_commit end' "$CONFIG_FILE" 2>/dev/null)
  config_verification=$(jq -r '.verification_tier // "standard"' "$CONFIG_FILE" 2>/dev/null)
  config_prefer_teams=$(jq -r '.prefer_teams // "always"' "$CONFIG_FILE" 2>/dev/null)
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
    for pdir in $(ls -d "$PHASES_DIR"/*/ 2>/dev/null | sort); do
      pname=$(basename "$pdir")
      # zsh compat: use ls dir | grep to avoid bare glob expansion errors
      # shellcheck disable=SC2010
      plan_count=$(ls -1 "$pdir" 2>/dev/null | grep '\-PLAN\.md$' | wc -l | tr -d ' ')
      # shellcheck disable=SC2010
      summary_count=$(ls -1 "$pdir" 2>/dev/null | grep '\-SUMMARY\.md$' | wc -l | tr -d ' ')
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
CTX="$CTX Config: effort=${config_effort}, autonomy=${config_autonomy}, auto_commit=${config_auto_commit}, verification=${config_verification}, prefer_teams=${config_prefer_teams}, max_tasks=${config_max_tasks}."
CTX="$CTX Next: ${NEXT_ACTION}."

jq -n --arg ctx "$CTX" --arg update "$UPDATE_MSG" --arg welcome "$WELCOME_MSG" --arg flags "${FLAG_WARNINGS:-}" '{
  "hookSpecificOutput": {
    "additionalContext": ($welcome + $ctx + $update + $flags)
  }
}'

exit 0
