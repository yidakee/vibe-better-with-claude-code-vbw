#!/bin/bash
# UserPromptSubmit hook: Pre-flight validation for VBW commands
# Non-blocking warnings only (always exit 0)

PLANNING_DIR=".vbw-planning"

# Guard: only check if planning directory exists
if [ ! -d "$PLANNING_DIR" ]; then
  exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .content // ""' 2>/dev/null)

# No prompt content to check
if [ -z "$PROMPT" ]; then
  exit 0
fi

WARNING=""

# Check: /vbw:execute when no PLAN.md exists in current phase
if echo "$PROMPT" | grep -q '/vbw:execute'; then
  # Try to detect current phase from STATE.md
  CURRENT_PHASE=""
  if [ -f "$PLANNING_DIR/STATE.md" ]; then
    CURRENT_PHASE=$(grep -m1 "^## Current Phase" "$PLANNING_DIR/STATE.md" | sed 's/.*Phase[: ]*//' | tr -d ' ')
  fi

  if [ -n "$CURRENT_PHASE" ]; then
    PHASE_DIR="$PLANNING_DIR/phases/$CURRENT_PHASE"
    PLAN_COUNT=$(find "$PHASE_DIR" -name "PLAN.md" -o -name "*-PLAN.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PLAN_COUNT" -eq 0 ]; then
      WARNING="No PLAN.md found for phase $CURRENT_PHASE. Run /vbw:plan first to create execution plans."
    fi
  fi
fi

# Check: /vbw:plan when phase already has plans
if echo "$PROMPT" | grep -q '/vbw:plan'; then
  CURRENT_PHASE=""
  if [ -f "$PLANNING_DIR/STATE.md" ]; then
    CURRENT_PHASE=$(grep -m1 "^## Current Phase" "$PLANNING_DIR/STATE.md" | sed 's/.*Phase[: ]*//' | tr -d ' ')
  fi

  if [ -n "$CURRENT_PHASE" ]; then
    PHASE_DIR="$PLANNING_DIR/phases/$CURRENT_PHASE"
    PLAN_COUNT=$(find "$PHASE_DIR" -name "PLAN.md" -o -name "*-PLAN.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PLAN_COUNT" -gt 0 ]; then
      WARNING="Phase $CURRENT_PHASE already has $PLAN_COUNT plan(s). Re-planning will create additional plans."
    fi
  fi
fi

# Check: /vbw:ship when phases are incomplete
if echo "$PROMPT" | grep -q '/vbw:ship'; then
  if [ -f "$PLANNING_DIR/STATE.md" ]; then
    INCOMPLETE=$(grep -c "status:.*incomplete\|status:.*in.progress\|status:.*pending" "$PLANNING_DIR/STATE.md" 2>/dev/null || echo 0)
    if [ "$INCOMPLETE" -gt 0 ]; then
      WARNING="There appear to be $INCOMPLETE incomplete phase(s). Review STATE.md before shipping."
    fi
  fi
fi

if [ -n "$WARNING" ]; then
  jq -n --arg msg "$WARNING" '{
    "hookSpecificOutput": {
      "additionalContext": ("VBW pre-flight warning: " + $msg)
    }
  }'
fi

exit 0
