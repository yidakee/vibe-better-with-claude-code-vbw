#!/usr/bin/env bash
# Checks codebase map staleness by diffing META.md git_hash against HEAD.
# Output: key-value pairs on stdout. Exit 0 always.
set -euo pipefail

META=".vbw-planning/codebase/META.md"

# No map
if [[ ! -f "$META" ]]; then
  echo "status: no_map"
  exit 0
fi

# No git
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "status: no_git"
  exit 0
fi

# Parse META.md
git_hash=$(grep '^git_hash:' "$META" | awk '{print $2}')
file_count=$(grep '^file_count:' "$META" | awk '{print $2}')
mapped_at=$(grep '^mapped_at:' "$META" | awk '{print $2}')

# Validate parsed values
if [[ -z "$git_hash" || -z "$file_count" || "$file_count" -eq 0 ]]; then
  echo "status: no_map"
  exit 0
fi

# Verify the stored hash exists in this repo
if ! git cat-file -e "$git_hash" 2>/dev/null; then
  echo "status: stale"
  echo "staleness: 100%"
  echo "changed: unknown"
  echo "total: $file_count"
  echo "since: $mapped_at"
  if ! [ -t 1 ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Codebase map is stale (100% files changed). Run /vbw:map --incremental to refresh.\"}}"
  fi
  exit 0
fi

# Count changed files since map was created
changed=$(git diff --name-only "$git_hash"..HEAD 2>/dev/null | wc -l | tr -d ' ')

# Calculate staleness percentage
staleness=$(( changed * 100 / file_count ))

if [[ "$staleness" -gt 30 ]]; then
  status="stale"
else
  status="fresh"
fi

echo "status: $status"
echo "staleness: ${staleness}%"
echo "changed: $changed"
echo "total: $file_count"
echo "since: $mapped_at"

# When called as a SessionStart hook (stdout is not a terminal), output hookSpecificOutput
if [[ "$status" == "stale" ]] && ! [ -t 1 ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Codebase map is stale (${staleness}% files changed). Run /vbw:map --incremental to refresh.\"}}"
fi
