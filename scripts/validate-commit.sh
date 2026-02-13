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
# Heredoc-style commits: extract first non-blank line as commit subject
MSG=""
if echo "$COMMAND" | grep -q 'cat <<'; then
  MSG=$(printf '%s\n' "$COMMAND" | sed -n '/cat <</,$ p' | sed '1d' | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^[[:space:]]*//')
  if [ -z "$MSG" ]; then
    exit 0  # Can't parse heredoc, fail-open
  fi
fi
# Only attempt -m extraction if heredoc did not set MSG
if [ -z "$MSG" ]; then
  MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -z "$MSG" ] && MSG=$(echo "$COMMAND" | sed -n "s/.*-m[[:space:]]*'\\([^']*\\)'.*/\\1/p")
  [ -z "$MSG" ] && MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*\([^[:space:]]*\).*/\1/p')
fi

if [ -z "$MSG" ]; then
  exit 0
fi

# Validate format: {type}({scope}): {desc}
VALID_TYPES="feat|fix|test|refactor|perf|docs|style|chore"
if ! echo "$MSG" | grep -qE "^($VALID_TYPES)\(.+\): .+"; then
  jq -n --arg msg "$MSG" '{
    "hookSpecificOutput": {
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
          "additionalContext": ("Version files are out of sync. Run: bash scripts/bump-version.sh\n" + $details)
        }
      }'
    }
  fi
fi

exit 0
