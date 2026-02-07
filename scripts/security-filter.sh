#!/bin/bash
# PreToolUse hook: Block access to sensitive files
# Exit 2 = block tool call, Exit 0 = allow

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // ""')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Sensitive file patterns
BLOCKED_PATTERNS=(
  '\.env$'
  '\.env\.'
  '\.pem$'
  '\.key$'
  '\.cert$'
  '\.p12$'
  '\.pfx$'
  'credentials\.json$'
  'secrets\.json$'
  'service-account.*\.json$'
  'node_modules/'
  '\.git/'
  'dist/'
  'build/'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -qE "$pattern"; then
    echo "Blocked: sensitive file ($FILE_PATH matches $pattern)" >&2
    exit 2
  fi
done

exit 0
