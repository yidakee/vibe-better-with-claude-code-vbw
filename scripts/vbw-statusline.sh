#!/bin/bash
# VBW Status Line for Claude Code — 4/5-Line Dashboard
# Line 1: [VBW] Phase N/M │ Plans: done/total (N this phase) │ Effort: X │ QA: pass │ repo:branch Files: +2~3 Commits: ↑5 Diff: +156 -23
# Line 2: Context: ▓▓▓▓▓▓▓▓░░░░░░░░░░░░ 42% 84.0K/200K │ Tokens: 15.2K in  1.2K out │ Cache: 5.0K write  2.0K read
# Line 3: Session: ██████████████████░░  6% ~2h13m │ Weekly: ███████░░░░░░░░░░░░░ 35% ~2d 23h │ Extra: ████████████████████ 96% $578/$600
# Line 4: Model: Opus │ Time: 12m 34s (API: 23s) │ VBW 1.0.67 │ CC 1.0.11
# Line 5: Team: build-team │ researcher ◆ │ tester ○ │ dev-1 ✓ │ Tasks: 3/5  (conditional)

input=$(cat)

# Colors
C='\033[36m' G='\033[32m' Y='\033[33m' R='\033[31m'
D='\033[2m' B='\033[1m' X='\033[0m'

# --- Cached platform info ---
_UID=$(id -u)
_OS=$(uname)
_VER=$(cat "$(dirname "$0")/../VERSION" 2>/dev/null | tr -d '[:space:]')
_CACHE="/tmp/vbw-${_VER:-0}-${_UID}"

# Clean stale caches from previous versions on first run
if ! [ -f "${_CACHE}-ok" ] || ! [ -O "${_CACHE}-ok" ]; then
  rm -f /tmp/vbw-*-"${_UID}"-* /tmp/vbw-sl-cache-"${_UID}" /tmp/vbw-usage-cache-"${_UID}" /tmp/vbw-gh-cache-"${_UID}" /tmp/vbw-team-cache-"${_UID}" 2>/dev/null
  touch "${_CACHE}-ok"
fi

# --- Helpers ---

# Check if a cache file is still fresh (within TTL seconds)
cache_fresh() {
  local cf="$1" ttl="$2"
  [ ! -f "$cf" ] && return 1
  # Ownership check: only trust cache files we own
  [ ! -O "$cf" ] && rm -f "$cf" 2>/dev/null && return 1
  local mt
  if [ "$_OS" = "Darwin" ]; then
    mt=$(stat -f %m "$cf" 2>/dev/null || echo 0)
  else
    mt=$(stat -c %Y "$cf" 2>/dev/null || echo 0)
  fi
  [ $((NOW - mt)) -le "$ttl" ]
}

# Build a progress bar: progress_bar <percent> <width>
progress_bar() {
  local pct="$1" width="$2"
  local filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled="$width"
  # Guarantee at least 1 block for any non-zero percentage
  [ "$pct" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
  local empty=$((width - filled))
  local color
  if [ "$pct" -ge 80 ]; then color="$R"
  elif [ "$pct" -ge 50 ]; then color="$Y"
  else color="$G"
  fi
  local bar=""
  [ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
  [ "$empty" -gt 0 ] && bar="${bar}$(printf "%${empty}s" | tr ' ' '░')"
  printf '%b%s%b' "$color" "$bar" "$X"
}

# Format token count: 1500000 -> "1.5M", 15000 -> "15.0K", 500 -> "500"
fmt_tok() {
  local v=$1
  if [ "$v" -ge 1000000 ]; then
    printf "%d.%dM" $((v / 1000000)) $(( (v % 1000000) / 100000 ))
  elif [ "$v" -ge 1000 ]; then
    printf "%d.%dK" $((v / 1000)) $(( (v % 1000) / 100 ))
  else
    printf "%d" "$v"
  fi
}

# Format cost: 0.53 -> "$0.53", 12.40 -> "$12.4", 150.00 -> "$150"
fmt_cost() {
  local whole="${1%%.*}" frac="${1#*.}"
  local cents="${frac:0:2}"
  cents=$((10#${cents:-0}))
  whole=$((10#${whole:-0}))
  local total_cents=$(( whole * 100 + cents ))
  if [ "$total_cents" -ge 10000 ]; then printf "\$%d" "$whole"
  elif [ "$total_cents" -ge 1000 ]; then printf "\$%d.%d" "$whole" $((cents / 10))
  else printf "\$%d.%02d" "$whole" "$cents"
  fi
}

# Format duration from ms: 125000 -> "2m 5s", 3700000 -> "1h 1m"
fmt_dur() {
  local s=$(($1 / 1000))
  if [ "$s" -ge 3600 ]; then
    printf "%dh %dm" $((s / 3600)) $(( (s % 3600) / 60 ))
  elif [ "$s" -ge 60 ]; then
    printf "%dm %ds" $((s / 60)) $((s % 60))
  else
    printf "%ds" "$s"
  fi
}

# --- Session data: single jq call ---

IFS='|' read -r PCT REM IN_TOK OUT_TOK CACHE_W CACHE_R CTX_SIZE \
               COST DUR_MS API_MS ADDED REMOVED MODEL VER <<< \
  "$(echo "$input" | jq -r '[
    (.context_window.used_percentage // 0 | floor),
    (.context_window.remaining_percentage // 100 | floor),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0),
    (.context_window.current_usage.cache_creation_input_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.context_window.context_window_size // 200000),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_api_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.model.display_name // "Claude"),
    (.version // "?")
  ] | join("|")' 2>/dev/null)"

# Defaults on jq failure
PCT=${PCT:-0}; REM=${REM:-100}; IN_TOK=${IN_TOK:-0}; OUT_TOK=${OUT_TOK:-0}
CACHE_W=${CACHE_W:-0}; CACHE_R=${CACHE_R:-0}; COST=${COST:-0}
DUR_MS=${DUR_MS:-0}; API_MS=${API_MS:-0}; ADDED=${ADDED:-0}; REMOVED=${REMOVED:-0}
MODEL=${MODEL:-Claude}; VER=${VER:-?}

NOW=$(date +%s)

# Used tokens = input + cache_write + cache_read (per official docs)
CTX_USED=$((IN_TOK + CACHE_W + CACHE_R))

# --- Format all values with shell builtins ---
CTX_USED_FMT=$(fmt_tok "$CTX_USED")
CTX_SIZE_FMT=$(fmt_tok "$CTX_SIZE")
IN_TOK_FMT=$(fmt_tok "$IN_TOK")
OUT_TOK_FMT=$(fmt_tok "$OUT_TOK")
CACHE_W_FMT=$(fmt_tok "$CACHE_W")
CACHE_R_FMT=$(fmt_tok "$CACHE_R")
COST_FMT=$(fmt_cost "$COST")
DUR_FMT=$(fmt_dur "$DUR_MS")
API_DUR_FMT=$(fmt_dur "$API_MS")

# --- Fast cache: VBW state + execution + agents (5s TTL) ---

FAST_CF="${_CACHE}-fast"

if ! cache_fresh "$FAST_CF" 5; then
  # --- VBW state ---
  PH=""; TT=""; EF="balanced"; BR=""
  PD=0; PT=0; PPD=0; QA="--"; GH_URL=""
  if [ -f ".vbw-planning/STATE.md" ]; then
    PH=$(grep -m1 "^Phase:" .vbw-planning/STATE.md | grep -oE '[0-9]+' | head -1)
    TT=$(grep -m1 "^Phase:" .vbw-planning/STATE.md | grep -oE '[0-9]+' | tail -1)
  fi
  [ -f ".vbw-planning/config.json" ] && \
    EF=$(jq -r '.effort // "balanced"' .vbw-planning/config.json 2>/dev/null)
  if git rev-parse --git-dir >/dev/null 2>&1; then
    BR=$(git branch --show-current 2>/dev/null)
    GH_URL=$(git remote get-url origin 2>/dev/null | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$||' | sed 's|https://[^@]*@|https://|')
    GIT_STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    GIT_MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    GIT_AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
  fi
  # Plan counting
  if [ -d ".vbw-planning/phases" ]; then
    PT=$(find .vbw-planning/phases -name '*-PLAN.md' 2>/dev/null | wc -l | tr -d ' ')
    PD=$(find .vbw-planning/phases -name '*-SUMMARY.md' 2>/dev/null | wc -l | tr -d ' ')
    if [ -n "$PH" ] && [ "$PH" != "0" ]; then
      PDIR=$(find .vbw-planning/phases -maxdepth 1 -type d -name "$(printf '%02d' "$PH")-*" 2>/dev/null | head -1)
      [ -n "$PDIR" ] && PPD=$(find "$PDIR" -name '*-SUMMARY.md' 2>/dev/null | wc -l | tr -d ' ')
      [ -n "$PDIR" ] && [ -n "$(find "$PDIR" -name '*VERIFICATION.md' 2>/dev/null | head -1)" ] && QA="pass"
    fi
  fi

  # --- Execution progress ---
  EXEC_STATUS=""; EXEC_WAVE=0; EXEC_TWAVES=0; EXEC_DONE=0; EXEC_TOTAL=0; EXEC_CURRENT=""
  if [ -f ".vbw-planning/.execution-state.json" ]; then
    IFS='|' read -r EXEC_STATUS EXEC_WAVE EXEC_TWAVES EXEC_DONE EXEC_TOTAL EXEC_CURRENT <<< \
      "$(jq -r '[
        (.status // ""),
        (.wave // 0),
        (.total_waves // 0),
        ([.plans[] | select(.status == "complete")] | length),
        (.plans | length),
        ([.plans[] | select(.status == "running")][0].title // "")
      ] | join("|")' .vbw-planning/.execution-state.json 2>/dev/null)"
  fi

  # --- Agent count ---
  AGENT_DATA=""
  AGENT_N=$(( $(pgrep -u "$_UID" -cf "claude" 2>/dev/null || echo 1) - 1 ))
  if [ "$AGENT_N" -gt 0 ] 2>/dev/null; then
    AGENT_DATA="${AGENT_N}"
  fi

  printf '%s\n' "${PH:-0}|${TT:-0}|${EF}|${BR}|${PD}|${PT}|${PPD}|${QA}|${GH_URL}|${GIT_STAGED:-0}|${GIT_MODIFIED:-0}|${GIT_AHEAD:-0}|${EXEC_STATUS:-}|${EXEC_WAVE:-0}|${EXEC_TWAVES:-0}|${EXEC_DONE:-0}|${EXEC_TOTAL:-0}|${EXEC_CURRENT:-}|${AGENT_DATA:-0}" > "$FAST_CF" 2>/dev/null
fi

if [ -O "$FAST_CF" ]; then
  IFS='|' read -r PH TT EF BR PD PT PPD QA GH_URL GIT_STAGED GIT_MODIFIED GIT_AHEAD \
                  EXEC_STATUS EXEC_WAVE EXEC_TWAVES EXEC_DONE EXEC_TOTAL EXEC_CURRENT \
                  AGENT_N < "$FAST_CF"
fi

# Reconstruct agent display line from count
AGENT_LINE=""
if [ "${AGENT_N:-0}" -gt 0 ] 2>/dev/null; then
  AGENT_LINE="${C}◆${X} ${AGENT_N} agent$([ "$AGENT_N" -gt 1 ] && echo s) working"
fi

# --- Slow cache: usage limits + update check (60s TTL) ---

SLOW_CF="${_CACHE}-slow"

if ! cache_fresh "$SLOW_CF" 60; then
  # --- Usage limits ---
  OAUTH_TOKEN=""
  if [ "$_OS" = "Darwin" ]; then
    CRED_JSON=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$CRED_JSON" ]; then
      OAUTH_TOKEN=$(echo "$CRED_JSON" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
  fi

  FIVE_PCT=0; FIVE_EPOCH=0; WEEK_PCT=0; WEEK_EPOCH=0; SONNET_PCT=-1
  EXTRA_ENABLED=0; EXTRA_PCT=-1; EXTRA_USED_C=0; EXTRA_LIMIT_C=0; FETCH_OK="noauth"

  if [ -n "$OAUTH_TOKEN" ]; then
    USAGE_RAW=$(curl -s --max-time 3 \
      -H "Authorization: Bearer ${OAUTH_TOKEN}" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$USAGE_RAW" ] && echo "$USAGE_RAW" | jq -e '.five_hour' >/dev/null 2>&1; then
      IFS='|' read -r FIVE_PCT FIVE_EPOCH WEEK_PCT WEEK_EPOCH SONNET_PCT \
                      EXTRA_ENABLED EXTRA_PCT EXTRA_USED_C EXTRA_LIMIT_C <<< \
        "$(echo "$USAGE_RAW" | jq -r '
          def pct: floor;
          def epoch: gsub("\\.[0-9]+"; "") | gsub("Z$"; "+00:00") | split("+")[0] + "Z" | fromdate;
          [
            ((.five_hour.utilization // 0) | pct),
            ((.five_hour.resets_at // "") | if . == "" or . == null then 0 else epoch end),
            ((.seven_day.utilization // 0) | pct),
            ((.seven_day.resets_at // "") | if . == "" or . == null then 0 else epoch end),
            ((.seven_day_sonnet.utilization // -1) | pct),
            (if .extra_usage.is_enabled == true then 1 else 0 end),
            ((.extra_usage.utilization // -1) | pct),
            ((.extra_usage.used_credits // 0) | floor),
            ((.extra_usage.monthly_limit // 0) | floor)
          ] | join("|")
        ' 2>/dev/null)"
      FETCH_OK="ok"
    else
      FETCH_OK="fail"
    fi
  fi

  # --- Update check ---
  UPDATE_AVAIL=""
  REMOTE_VER=$(curl -sf --max-time 3 "https://raw.githubusercontent.com/yidakee/vibe-better-with-claude-code-vbw/main/VERSION" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$REMOTE_VER" ] && [ -n "$_VER" ] && [ "$REMOTE_VER" != "$_VER" ]; then
    NEWEST=$(printf '%s\n%s\n' "$_VER" "$REMOTE_VER" | (sort -V 2>/dev/null || sort -t. -k1,1n -k2,2n -k3,3n) | tail -1)
    [ "$NEWEST" = "$REMOTE_VER" ] && UPDATE_AVAIL="$REMOTE_VER"
  fi

  printf '%s\n' "${FIVE_PCT:-0}|${FIVE_EPOCH:-0}|${WEEK_PCT:-0}|${WEEK_EPOCH:-0}|${SONNET_PCT:--1}|${EXTRA_ENABLED:-0}|${EXTRA_PCT:--1}|${EXTRA_USED_C:-0}|${EXTRA_LIMIT_C:-0}|${FETCH_OK}|${UPDATE_AVAIL:-}" > "$SLOW_CF" 2>/dev/null
fi

if [ -O "$SLOW_CF" ]; then
  IFS='|' read -r FIVE_PCT FIVE_EPOCH WEEK_PCT WEEK_EPOCH SONNET_PCT \
                  EXTRA_ENABLED EXTRA_PCT EXTRA_USED_C EXTRA_LIMIT_C \
                  FETCH_OK UPDATE_AVAIL < "$SLOW_CF"
fi

# --- Cost cache: previous snapshot for delta tracking ---

COST_CF="${_CACHE}-cost"
PREV_COST=""
[ -O "$COST_CF" ] && PREV_COST=$(cat "$COST_CF" 2>/dev/null)
printf '%s\n' "${COST}" > "$COST_CF" 2>/dev/null

# --- Usage rendering ---

USAGE_LINE=""
if [ "$FETCH_OK" = "ok" ]; then
  # Countdown helper
  countdown() {
    local epoch="$1"
    if [ "${epoch:-0}" -gt 0 ] 2>/dev/null; then
      local diff=$((epoch - NOW))
      if [ "$diff" -gt 0 ]; then
        if [ "$diff" -ge 86400 ]; then
          local dd=$((diff / 86400)) hh=$(( (diff % 86400) / 3600 ))
          echo "~${dd}d ${hh}h"
        else
          local hh=$((diff / 3600)) mm=$(( (diff % 3600) / 60 ))
          echo "~${hh}h${mm}m"
        fi
      else
        echo "now"
      fi
    fi
  }

  FIVE_REM=$(countdown "$FIVE_EPOCH")
  WEEK_REM=$(countdown "$WEEK_EPOCH")

  USAGE_LINE="Session: $(progress_bar "${FIVE_PCT:-0}" 20) ${FIVE_PCT:-0}%"
  [ -n "$FIVE_REM" ] && USAGE_LINE="$USAGE_LINE $FIVE_REM"
  USAGE_LINE="$USAGE_LINE ${D}│${X} Weekly: $(progress_bar "${WEEK_PCT:-0}" 20) ${WEEK_PCT:-0}%"
  [ -n "$WEEK_REM" ] && USAGE_LINE="$USAGE_LINE $WEEK_REM"
  if [ "${SONNET_PCT:--1}" -ge 0 ] 2>/dev/null; then
    USAGE_LINE="$USAGE_LINE ${D}│${X} Sonnet: $(progress_bar "${SONNET_PCT}" 20) ${SONNET_PCT}%"
  fi
  if [ "${EXTRA_ENABLED:-0}" = "1" ] && [ "${EXTRA_PCT:--1}" -ge 0 ] 2>/dev/null; then
    EXTRA_USED_D="$((EXTRA_USED_C / 100)).$( printf '%02d' $((EXTRA_USED_C % 100)) )"
    EXTRA_LIMIT_D="$((EXTRA_LIMIT_C / 100)).$( printf '%02d' $((EXTRA_LIMIT_C % 100)) )"
    USAGE_LINE="$USAGE_LINE ${D}│${X} Extra: $(progress_bar "${EXTRA_PCT}" 20) ${EXTRA_PCT}% \$${EXTRA_USED_D}/\$${EXTRA_LIMIT_D}"
  fi
elif [ "$FETCH_OK" = "fail" ]; then
  USAGE_LINE="${D}Limits: fetch failed (retry in 60s)${X}"
else
  USAGE_LINE="${D}Limits: N/A (using API key)${X}"
fi

# --- GitHub link (from VBW state cache) ---
# OSC 8 clickable link: \e]8;;URL\a TEXT \e]8;;\a
# Links to current branch tree when branch is available

GH_LINK=""
if [ -n "$GH_URL" ]; then
  GH_NAME=$(basename "$GH_URL")
  if [ -n "$BR" ]; then
    GH_BRANCH_URL="${GH_URL}/tree/${BR}"
    GH_LINK="\033]8;;${GH_BRANCH_URL}\a${GH_NAME}:${BR}\033]8;;\a"
  else
    GH_LINK="\033]8;;${GH_URL}\a${GH_NAME}\033]8;;\a"
  fi
fi

# --- Context bar (20 chars wide) ---

[ "$PCT" -ge 90 ] && BC="$R" || { [ "$PCT" -ge 70 ] && BC="$Y" || BC="$G"; }
FL=$((PCT * 20 / 100)); EM=$((20 - FL))
CTX_BAR=""; [ "$FL" -gt 0 ] && CTX_BAR=$(printf "%${FL}s" | tr ' ' '▓')
[ "$EM" -gt 0 ] && CTX_BAR="${CTX_BAR}$(printf "%${EM}s" | tr ' ' '░')"

# --- Line 1: VBW project state ---

if [ "$EXEC_STATUS" = "running" ] && [ "${EXEC_TOTAL:-0}" -gt 0 ] 2>/dev/null; then
  # Build progress mode
  EXEC_PCT=$((EXEC_DONE * 100 / EXEC_TOTAL))
  L1="${C}${B}[VBW]${X} Build: $(progress_bar "$EXEC_PCT" 8) ${EXEC_DONE}/${EXEC_TOTAL} plans"
  [ "${EXEC_TWAVES:-0}" -gt 1 ] 2>/dev/null && L1="$L1 ${D}│${X} Wave ${EXEC_WAVE}/${EXEC_TWAVES}"
  [ -n "$EXEC_CURRENT" ] && L1="$L1 ${D}│${X} ${C}◆${X} ${EXEC_CURRENT}"
elif [ "$EXEC_STATUS" = "complete" ]; then
  # Auto-cleanup: remove finished execution state
  rm -f .vbw-planning/.execution-state.json "$FAST_CF" 2>/dev/null
  EXEC_STATUS=""
  # Fall through to normal display
  L1="${C}${B}[VBW]${X}"
  [ "$TT" -gt 0 ] 2>/dev/null && L1="$L1 Phase ${PH}/${TT}" || L1="$L1 Phase ${PH:-?}"
  [ "$PT" -gt 0 ] 2>/dev/null && L1="$L1 ${D}│${X} Plans: ${PD}/${PT} (${PPD} this phase)"
  L1="$L1 ${D}│${X} Effort: $EF"
  if [ "$QA" = "pass" ]; then L1="$L1 ${D}│${X} ${G}QA: pass${X}"
  else L1="$L1 ${D}│${X} ${D}QA: --${X}"; fi
elif [ -d ".vbw-planning" ]; then
  L1="${C}${B}[VBW]${X}"
  [ "$TT" -gt 0 ] 2>/dev/null && L1="$L1 Phase ${PH}/${TT}" || L1="$L1 Phase ${PH:-?}"
  [ "$PT" -gt 0 ] 2>/dev/null && L1="$L1 ${D}│${X} Plans: ${PD}/${PT} (${PPD} this phase)"
  L1="$L1 ${D}│${X} Effort: $EF"
  if [ "$QA" = "pass" ]; then
    L1="$L1 ${D}│${X} ${G}QA: pass${X}"
  else
    L1="$L1 ${D}│${X} ${D}QA: --${X}"
  fi
else
  L1="${C}${B}[VBW]${X} ${D}no project${X}"
fi
if [ -n "$BR" ]; then
  if [ -n "$GH_LINK" ]; then
    L1="$L1 ${D}│${X} ${GH_LINK}"
  else
    L1="$L1 ${D}│${X} $BR"
  fi
  GIT_IND=""
  [ "${GIT_STAGED:-0}" -gt 0 ] 2>/dev/null && GIT_IND="${G}+${GIT_STAGED}${X}"
  [ "${GIT_MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_IND="${GIT_IND}${Y}~${GIT_MODIFIED}${X}"
  [ -n "$GIT_IND" ] && L1="$L1 ${D}Files:${X} $GIT_IND"
  [ "${GIT_AHEAD:-0}" -gt 0 ] 2>/dev/null && L1="$L1 ${D}Commits:${X} ${C}↑${GIT_AHEAD}${X}"
  L1="$L1 ${D}Diff:${X} ${G}+${ADDED}${X} ${R}-${REMOVED}${X}"
fi

# --- Line 2: context window ---

L2="Context: ${BC}${CTX_BAR}${X} ${BC}${PCT}%${X} ${CTX_USED_FMT}/${CTX_SIZE_FMT}"
L2="$L2 ${D}│${X} Tokens: ${IN_TOK_FMT} in  ${OUT_TOK_FMT} out"
L2="$L2 ${D}│${X} Cache: ${CACHE_W_FMT} write  ${CACHE_R_FMT} read"

# --- Line 3: usage limits ---

L3="$USAGE_LINE"

# --- Line 4: session economy + GitHub ---

L4="Model: ${D}${MODEL}${X}"
L4="$L4 ${D}│${X} Time: ${DUR_FMT} (API: ${API_DUR_FMT})"
[ -n "$AGENT_LINE" ] && L4="$L4 ${D}│${X} ${AGENT_LINE}"
if [ -n "$UPDATE_AVAIL" ]; then
  L4="$L4 ${D}│${X} ${Y}${B}VBW ${_VER:-?} → ${UPDATE_AVAIL}${X} ${Y}/vbw:update${X} ${D}│${X} ${D}CC ${VER}${X}"
else
  L4="$L4 ${D}│${X} ${D}VBW ${_VER:-?}${X} ${D}│${X} ${D}CC ${VER}${X}"
fi

# --- Output ---

printf '%b\n' "$L1"
printf '%b\n' "$L2"
printf '%b\n' "$L3"
printf '%b\n' "$L4"

exit 0
