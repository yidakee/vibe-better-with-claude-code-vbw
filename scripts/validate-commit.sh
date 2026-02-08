#!/bin/bash
set -u
# PostToolUse hook: Validate git commit message format
# Non-blocking feedback only (always exit 0)

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
      "additionalContext": ("Commit message does not match format {type}({scope}): {desc}. Got: " + $msg)
    }
  }'
fi

# Version bump warning (VBW plugin development only)
if [ -f ".claude-plugin/plugin.json" ]; then
  PLUGIN_NAME=$(jq -r '.name // ""' .claude-plugin/plugin.json 2>/dev/null)
  if [ "$PLUGIN_NAME" = "vbw" ]; then
    STAGED=$(git diff --cached --name-only 2>/dev/null)
    if [ -n "$STAGED" ]; then
      HAS_NON_VERSION=false
      HAS_VERSION=false
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        case "$f" in
          VERSION|.claude-plugin/*|marketplace.json) ;;
          *) HAS_NON_VERSION=true ;;
        esac
        if [ "$f" = "VERSION" ]; then
          HAS_VERSION=true
        fi
      done <<< "$STAGED"
      if [ "$HAS_NON_VERSION" = true ] && [ "$HAS_VERSION" = false ]; then
        jq -n '{
          "hookSpecificOutput": {
            "additionalContext": "VERSION file not staged. Run scripts/bump-version.sh before committing."
          }
        }'
      fi
    fi
  fi
fi

exit 0
