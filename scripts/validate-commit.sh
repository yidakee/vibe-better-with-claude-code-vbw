#!/bin/bash
set -u
# PostToolUse hook: Validate git commit message format
# Non-blocking feedback only (always exit 0)

# Require jq for JSON output — fail-silent if missing (non-blocking hook)
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git commit commands
if ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0
fi

# Extract commit message from -m flag (POSIX-compatible, no GNU-only flags)
# Heredoc-style commits can't be parsed from a single line — skip validation
if echo "$COMMAND" | grep -q 'cat <<'; then
  exit 0
fi
MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
[ -z "$MSG" ] && MSG=$(echo "$COMMAND" | sed -n "s/.*-m[[:space:]]*'\\([^']*\\)'.*/\\1/p")
[ -z "$MSG" ] && MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*\([^[:space:]]*\).*/\1/p')

if [ -z "$MSG" ]; then
  exit 0
fi

# Validate format: {type}({scope}): {desc}
VALID_TYPES="feat|fix|test|refactor|perf|docs|style|chore"
if ! echo "$MSG" | grep -qE "^($VALID_TYPES)\(.+\): .+"; then
  jq -n --arg msg "$MSG" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("Commit message does not match format {type}({scope}): {desc}. Got: " + $msg)
    }
  }'
fi

# Version sync warning (VBW plugin development only)
if [ -f ".claude-plugin/plugin.json" ] && [ -f "./scripts/bump-version.sh" ]; then
  PLUGIN_NAME=$(jq -r '.name // ""' .claude-plugin/plugin.json 2>/dev/null)
  if [ "$PLUGIN_NAME" = "vbw" ]; then
    VERIFY_OUTPUT=$(bash ./scripts/bump-version.sh --verify 2>&1) || {
      DETAILS=$(echo "$VERIFY_OUTPUT" | grep -A 10 "MISMATCH")
      jq -n --arg details "$DETAILS" '{
        "hookSpecificOutput": {
          "hookEventName": "PostToolUse",
          "additionalContext": ("Version files are out of sync. Run: bash scripts/bump-version.sh\n" + $details)
        }
      }'
    }
  fi
fi

exit 0
