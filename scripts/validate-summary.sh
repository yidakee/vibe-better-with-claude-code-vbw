#!/bin/bash
set -u
# PostToolUse/SubagentStop: Validate SUMMARY.md structure (non-blocking, exit 0)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // ""')

# Only check SUMMARY.md files in .vbw-planning/
if ! echo "$FILE_PATH" | grep -qE '\.vbw-planning/.*SUMMARY\.md$'; then
  exit 0
fi

[ -f "$FILE_PATH" ] || exit 0

MISSING=""

# YAML frontmatter required (compact format relies on it)
if ! head -1 "$FILE_PATH" | grep -q '^---$'; then
  MISSING="Missing YAML frontmatter. "
fi

if ! grep -q "## What Was Built" "$FILE_PATH"; then
  MISSING="${MISSING}Missing '## What Was Built'. "
fi

if ! grep -q "## Files Modified" "$FILE_PATH"; then
  MISSING="${MISSING}Missing '## Files Modified'. "
fi

if [ -n "$MISSING" ]; then
  jq -n --arg msg "$MISSING" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("SUMMARY validation: " + $msg)
    }
  }'
fi

exit 0
