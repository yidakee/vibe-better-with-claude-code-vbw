#!/bin/bash
# VBW Status Line for Claude Code — 3-Line Dashboard
# Line 1: [VBW] Phase N/M │ plans done/total (phase) │ effort │ QA │ 🌿 branch
# Line 2: ▓▓▓▓░░░░░░ 42% │ 15.2K in  1.2K out │ cache: 5.0K w  2.0K r │ 58% free
# Line 3: Opus │ $1.42 │ 12m 34s (api 23s) │ +156 -23 │ CC 1.0.80

input=$(cat)

# Colors
C='\033[36m' G='\033[32m' Y='\033[33m' R='\033[31m'
D='\033[2m' B='\033[1m' X='\033[0m'

# --- Helpers ---

# Tokens to human-readable: 850 / 15.2K / 1.2M
fmt_tok() {
  awk "BEGIN {
    v=$1+0
    if (v >= 1000000)      printf \"%.1fM\", v/1000000
    else if (v >= 1000)    printf \"%.1fK\", v/1000
    else                   printf \"%d\", v
  }"
}

# Smart cost: $0.42 / $1.42 / $142
fmt_cost() {
  awk "BEGIN {
    v=$1+0
    if (v >= 100)       printf \"\$%.0f\", v
    else if (v >= 10)   printf \"\$%.1f\", v
    else                printf \"\$%.2f\", v
  }"
}

# Duration ms to smart format: 45s / 12m 34s / 1h 23m
fmt_dur() {
  awk "BEGIN {
    s=int($1/1000)
    if (s >= 3600) { h=int(s/3600); m=int((s%3600)/60); printf \"%dh %dm\", h, m }
    else if (s >= 60) { m=int(s/60); r=s%60; printf \"%dm %ds\", m, r }
    else printf \"%ds\", s
  }"
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

# --- VBW state (cached 5s) ---

CF="/tmp/vbw-sl-cache-$(id -u)"
NOW=$(date +%s)
if [ "$(uname)" = "Darwin" ]; then
  MT=$(stat -f %m "$CF" 2>/dev/null || echo 0)
else
  MT=$(stat -c %Y "$CF" 2>/dev/null || echo 0)
fi

if [ ! -f "$CF" ] || [ $((NOW - MT)) -gt 5 ]; then
  PH=""; TT=""; ST=""; EF="balanced"; BR=""
  PD=0; PT=0; PPD=0; QA="--"
  if [ -f ".vbw-planning/STATE.md" ]; then
    PH=$(grep -m1 "^Phase:" .vbw-planning/STATE.md | grep -oE '[0-9]+' | head -1)
    TT=$(grep -m1 "^Phase:" .vbw-planning/STATE.md | grep -oE '[0-9]+' | tail -1)
    ST=$(grep -m1 "^Status:" .vbw-planning/STATE.md | sed 's/^Status: *//')
  fi
  [ -f ".vbw-planning/config.json" ] && \
    EF=$(jq -r '.effort // "balanced"' .vbw-planning/config.json 2>/dev/null)
  git rev-parse --git-dir >/dev/null 2>&1 && BR=$(git branch --show-current 2>/dev/null)

  # Plan counting
  if [ -d ".vbw-planning/phases" ]; then
    PT=$(find .vbw-planning/phases -name '*-PLAN.md' 2>/dev/null | wc -l | tr -d ' ')
    PD=$(find .vbw-planning/phases -name '*-SUMMARY.md' 2>/dev/null | wc -l | tr -d ' ')
    # Current phase plans done
    if [ -n "$PH" ] && [ "$PH" != "0" ]; then
      PDIR=$(find .vbw-planning/phases -maxdepth 1 -type d -name "$(printf '%02d' "$PH")-*" 2>/dev/null | head -1)
      [ -n "$PDIR" ] && PPD=$(find "$PDIR" -name '*-SUMMARY.md' 2>/dev/null | wc -l | tr -d ' ')
      [ -n "$PDIR" ] && [ -n "$(find "$PDIR" -name '*VERIFICATION.md' 2>/dev/null | head -1)" ] && QA="pass"
    fi
  fi

  printf '%s\n' "${PH:-0}|${TT:-0}|${ST}|${EF}|${BR}|${PD}|${PT}|${PPD}|${QA}" > "$CF"
fi

IFS='|' read -r PH TT ST EF BR PD PT PPD QA < "$CF"

# --- Context bar ---

[ "$PCT" -ge 90 ] && BC="$R" || { [ "$PCT" -ge 70 ] && BC="$Y" || BC="$G"; }
FL=$((PCT * 10 / 100)); EM=$((10 - FL))
BAR=""; [ "$FL" -gt 0 ] && BAR=$(printf "%${FL}s" | tr ' ' '▓')
[ "$EM" -gt 0 ] && BAR="${BAR}$(printf "%${EM}s" | tr ' ' '░')"

# --- Line 1: VBW project state ---

if [ -d ".vbw-planning" ]; then
  L1="${C}${B}[VBW]${X}"
  [ "$TT" -gt 0 ] 2>/dev/null && L1="$L1 Phase ${PH}/${TT}" || L1="$L1 Phase ${PH:-?}"
  [ "$PT" -gt 0 ] 2>/dev/null && L1="$L1 ${D}│${X} ${PD}/${PT} plans (${PPD} this phase)"
  L1="$L1 ${D}│${X} $EF"
  if [ "$QA" = "pass" ]; then
    L1="$L1 ${D}│${X} ${G}QA:pass${X}"
  else
    L1="$L1 ${D}│${X} ${D}QA:--${X}"
  fi
else
  L1="${C}${B}[VBW]${X} ${D}no project${X}"
fi
[ -n "$BR" ] && L1="$L1 ${D}│${X} 🌿 $BR"

# --- Line 2: context window deep metrics ---

L2="${BC}${BAR}${X} ${PCT}%"
L2="$L2 ${D}│${X} $(fmt_tok "$IN_TOK") in  $(fmt_tok "$OUT_TOK") out"
L2="$L2 ${D}│${X} cache: $(fmt_tok "$CACHE_W") w  $(fmt_tok "$CACHE_R") r"
L2="$L2 ${D}│${X} ${REM}% free"

# --- Line 3: session economy ---

L3="${D}${MODEL}${X}"
L3="$L3 ${D}│${X} ${Y}$(fmt_cost "$COST")${X}"
L3="$L3 ${D}│${X} $(fmt_dur "$DUR_MS") (api $(fmt_dur "$API_MS"))"
L3="$L3 ${D}│${X} ${G}+${ADDED}${X} ${R}-${REMOVED}${X}"
L3="$L3 ${D}│${X} ${D}CC ${VER}${X}"

echo -e "$L1"
echo -e "$L2"
echo -e "$L3"
