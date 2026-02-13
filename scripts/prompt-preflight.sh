#!/bin/bash
set -u
# UserPromptSubmit: Pre-flight validation for VBW commands (non-blocking, exit 0)

PLANNING_DIR=".vbw-planning"
[ -d "$PLANNING_DIR" ] || exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# GSD Isolation: manage .vbw-session marker
if [ -f "$PLANNING_DIR/.gsd-isolation" ]; then
  if echo "$PROMPT" | grep -qi '^/vbw:'; then
    echo "session" > "$PLANNING_DIR/.vbw-session"
  else
    rm -f "$PLANNING_DIR/.vbw-session"
  fi
fi

WARNING=""

# Check: /vbw:vibe --execute when no PLAN.md exists
if echo "$PROMPT" | grep -q '/vbw:vibe.*--execute'; then
  CURRENT_PHASE=""
  if [ -f "$PLANNING_DIR/STATE.md" ]; then
    CURRENT_PHASE=$(grep -m1 "^## Current Phase" "$PLANNING_DIR/STATE.md" | sed 's/.*Phase[: ]*//' | tr -d ' ')
  fi

  if [ -n "$CURRENT_PHASE" ]; then
    PHASE_DIR="$PLANNING_DIR/phases/$CURRENT_PHASE"
    PLAN_COUNT=$(find "$PHASE_DIR" -name "PLAN.md" -o -name "*-PLAN.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PLAN_COUNT" -eq 0 ]; then
      WARNING="No PLAN.md for phase $CURRENT_PHASE. Run /vbw:vibe to plan first."
    fi
  fi
fi

# Check: /vbw:vibe --archive with incomplete phases
if echo "$PROMPT" | grep -q '/vbw:vibe.*--archive'; then
  if [ -f "$PLANNING_DIR/STATE.md" ]; then
    INCOMPLETE=$(grep -c "status:.*incomplete\|status:.*in.progress\|status:.*pending" "$PLANNING_DIR/STATE.md" 2>/dev/null || echo 0)
    if [ "$INCOMPLETE" -gt 0 ]; then
      WARNING="$INCOMPLETE incomplete phase(s). Review STATE.md before shipping."
    fi
  fi
fi

if [ -n "$WARNING" ]; then
  jq -n --arg msg "$WARNING" '{
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": ("VBW pre-flight warning: " + $msg)
    }
  }'
fi

exit 0
