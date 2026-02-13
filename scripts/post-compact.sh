#!/bin/bash
set -u
# SessionStart(compact) hook: Remind agent to re-read key files after compaction
# Reads compaction context from stdin, detects agent role, suggests re-reads

INPUT=$(cat)

# Clean up cost tracking files and compaction marker (stale after compaction)
rm -f .vbw-planning/.cost-ledger.json .vbw-planning/.active-agent .vbw-planning/.compaction-marker 2>/dev/null

# Try to identify agent role from input context
ROLE=""
for pattern in vbw-lead vbw-dev vbw-qa vbw-scout vbw-debugger vbw-architect; do
  if echo "$INPUT" | grep -qi "$pattern"; then
    ROLE="$pattern"
    break
  fi
done

case "$ROLE" in
  vbw-lead)
    FILES="STATE.md, ROADMAP.md, config.json, and current phase plans"
    ;;
  vbw-dev)
    FILES="your assigned plan file, SUMMARY.md template, and relevant source files"
    ;;
  vbw-qa)
    FILES="SUMMARY.md files under review, verification criteria, and gap reports"
    ;;
  vbw-scout)
    FILES="research notes, REQUIREMENTS.md, and any scout-specific findings"
    ;;
  vbw-debugger)
    FILES="reproduction steps, hypothesis log, and related source files"
    ;;
  vbw-architect)
    FILES="REQUIREMENTS.md, ROADMAP.md, phase structure, and architecture decisions"
    ;;
  *)
    FILES="STATE.md, your assigned task context, and any in-progress files"
    ;;
esac

jq -n --arg role "${ROLE:-unknown}" --arg files "$FILES" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ("Context was compacted. Agent role: " + $role + ". Re-read these key files from disk: " + $files)
  }
}'

exit 0
