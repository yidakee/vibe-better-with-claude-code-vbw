#!/bin/bash
set -u
# PostToolUse hook: Validate YAML frontmatter in markdown files
# Non-blocking feedback only (always exit 0)

if ! command -v jq &>/dev/null; then
  exit 0
fi

# Hook scripts receive JSON on stdin. If run directly in an interactive shell,
# stdin is a TTY and `cat` would block waiting for input.
if [ -t 0 ]; then
  exit 0
fi

INPUT=$(cat 2>/dev/null) || exit 0
[ -z "$INPUT" ] && exit 0
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0

# Only check .md files
case "$FILE_PATH" in
  *.md) ;;
  *) exit 0 ;;
esac

[ ! -f "$FILE_PATH" ] && exit 0
HEAD=$(head -1 "$FILE_PATH" 2>/dev/null)
[ "$HEAD" != "---" ] && exit 0

# Extract frontmatter block between --- delimiters
FRONTMATTER=$(awk '
  BEGIN { count=0 }
  /^---$/ { count++; if (count==2) exit; next }
  count==1 { print }
' "$FILE_PATH" 2>/dev/null)

[ -z "$FRONTMATTER" ] && exit 0

# Check if description field exists in frontmatter
if ! echo "$FRONTMATTER" | grep -q "^description:"; then
  exit 0
fi

# Extract the description line
DESC_LINE=$(echo "$FRONTMATTER" | grep "^description:")
DESC_VALUE=$(echo "$DESC_LINE" | sed 's/^description:[[:space:]]*//')

# Check for block scalar indicators (| or >)
case "$DESC_VALUE" in
  "|"*|">"*)
    jq -n --arg file "$FILE_PATH" '{
      "hookSpecificOutput": {
        "additionalContext": ("Frontmatter warning: description field in " + $file + " must be a single line. Multi-line descriptions break plugin command/skill discovery. Fix: collapse to one line.")
      }
    }'
    exit 0
    ;;
esac

# Check for empty description
if [ -z "$DESC_VALUE" ]; then
  # Check if next line is indented (multi-line folded style without indicator)
  AFTER_DESC=$(echo "$FRONTMATTER" | awk '/^description:/{found=1; next} found && /^[[:space:]]/{print; next} found{exit}')
  if [ -n "$AFTER_DESC" ]; then
    jq -n --arg file "$FILE_PATH" '{
      "hookSpecificOutput": {
        "additionalContext": ("Frontmatter warning: description field in " + $file + " must be a single line. Multi-line descriptions break plugin command/skill discovery. Fix: collapse to one line.")
      }
    }'
  else
    jq -n --arg file "$FILE_PATH" '{
      "hookSpecificOutput": {
        "additionalContext": ("Frontmatter warning: description field in " + $file + " is empty. Empty descriptions break plugin command/skill discovery. Fix: add a single-line description.")
      }
    }'
  fi
  exit 0
fi

# Check for multi-line description (indented continuation lines after description)
AFTER_DESC=$(echo "$FRONTMATTER" | awk '/^description:/{found=1; next} found && /^[[:space:]]/{print; next} found{exit}')
if [ -n "$AFTER_DESC" ]; then
  jq -n --arg file "$FILE_PATH" '{
    "hookSpecificOutput": {
      "additionalContext": ("Frontmatter warning: description field in " + $file + " must be a single line. Multi-line descriptions break plugin command/skill discovery. Fix: collapse to one line.")
    }
  }'
fi

exit 0
