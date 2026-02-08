#!/bin/bash
set -u
# file-guard.sh — PreToolUse guard for undeclared file modifications
# Blocks Write/Edit to files not declared in active plan's files_modified
# Fail-open design: exit 0 on any error, exit 2 only on definitive violations

INPUT=$(cat 2>/dev/null) || exit 0
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
[ -z "$FILE_PATH" ] && exit 0

# Exempt planning artifacts — these are always allowed
case "$FILE_PATH" in
  *.vbw-planning/*|*SUMMARY.md|*VERIFICATION.md|*STATE.md|*CLAUDE.md|*.execution-state.json)
    exit 0
    ;;
esac

# Find project root by walking up from $PWD
find_project_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.vbw-planning/phases" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root) || exit 0
PHASES_DIR="$PROJECT_ROOT/.vbw-planning/phases"
[ ! -d "$PHASES_DIR" ] && exit 0

# Find active plan: first PLAN.md without a corresponding SUMMARY.md
ACTIVE_PLAN=""
for PLAN_FILE in "$PHASES_DIR"/*/*-PLAN.md; do
  [ ! -f "$PLAN_FILE" ] && continue
  # Derive expected SUMMARY.md path: 03-01-PLAN.md -> 03-01-SUMMARY.md
  SUMMARY_FILE="${PLAN_FILE%-PLAN.md}-SUMMARY.md"
  if [ ! -f "$SUMMARY_FILE" ]; then
    ACTIVE_PLAN="$PLAN_FILE"
    break
  fi
done

# No active plan found — fail-open
[ -z "$ACTIVE_PLAN" ] && exit 0

# Extract files_modified from YAML frontmatter using awk
# Frontmatter is between --- delimiters at the top of the file
DECLARED_FILES=$(awk '
  BEGIN { in_front=0; in_files=0 }
  /^---$/ {
    if (in_front == 0) { in_front=1; next }
    else { exit }
  }
  in_front && /^files_modified:/ { in_files=1; next }
  in_front && in_files && /^[[:space:]]+- / {
    sub(/^[[:space:]]+- /, "")
    # Remove quotes if present
    gsub(/["'"'"']/, "")
    print
    next
  }
  in_front && in_files && /^[^[:space:]]/ { in_files=0 }
' "$ACTIVE_PLAN" 2>/dev/null) || exit 0

# No files_modified declared — fail-open
[ -z "$DECLARED_FILES" ] && exit 0

# Normalize the target file path: strip ./ prefix, convert absolute to relative
normalize_path() {
  local p="$1"
  # Convert absolute to relative (strip project root prefix)
  if [ -n "$PROJECT_ROOT" ]; then
    p="${p#"$PROJECT_ROOT"/}"
  fi
  # Strip leading ./
  p="${p#./}"
  echo "$p"
}

NORM_TARGET=$(normalize_path "$FILE_PATH")

# Check if target file is in declared files
while IFS= read -r declared; do
  [ -z "$declared" ] && continue
  NORM_DECLARED=$(normalize_path "$declared")
  if [ "$NORM_TARGET" = "$NORM_DECLARED" ]; then
    exit 0
  fi
done <<< "$DECLARED_FILES"

# File not declared — block the write
echo "Blocked: $NORM_TARGET is not in active plan's files_modified ($ACTIVE_PLAN)" >&2
exit 2
