#!/bin/bash
# TaskCompleted hook: Verify a recent git commit exists for the completed task
# Exit 2 = block completion, Exit 0 = allow
# Exit 0 on ANY error (fail-open: never block legitimate work)

# Read stdin to get task context
INPUT=$(cat 2>/dev/null) || exit 0

# Extract task subject/description from TaskCompleted event JSON
TASK_SUBJECT=""
if [ -n "$INPUT" ]; then
  TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // .task.subject // ""' 2>/dev/null) || true
  if [ -z "$TASK_SUBJECT" ]; then
    TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_description // .task.description // ""' 2>/dev/null) || true
  fi
fi

# Get recent commits (last 20, within 2 hours)
NOW=$(date +%s 2>/dev/null) || exit 0
TWO_HOURS=7200
RECENT_COMMITS=$(git log --oneline -20 --format="%ct %s" 2>/dev/null) || exit 0

if [ -z "$RECENT_COMMITS" ]; then
  echo "No commits found in repository" >&2
  exit 2
fi

# Filter to commits within last 2 hours
RECENT_MESSAGES=""
while IFS= read -r line; do
  COMMIT_TS=$(echo "$line" | cut -d' ' -f1)
  COMMIT_MSG=$(echo "$line" | cut -d' ' -f2-)
  if [ -n "$COMMIT_TS" ] && [ "$COMMIT_TS" -gt 0 ] 2>/dev/null; then
    AGE=$(( NOW - COMMIT_TS ))
    if [ "$AGE" -le "$TWO_HOURS" ]; then
      RECENT_MESSAGES="${RECENT_MESSAGES}${COMMIT_MSG}
"
    fi
  fi
done <<< "$RECENT_COMMITS"

if [ -z "$RECENT_MESSAGES" ]; then
  echo "No recent commits found (last commit is over 2 hours old)" >&2
  exit 2
fi

# If no task context available, fall back to original behavior (any recent commit = pass)
if [ -z "$TASK_SUBJECT" ]; then
  exit 0
fi

# Extract keywords from task subject (words > 3 chars, lowercased, max 8)
KEYWORDS=$(echo "$TASK_SUBJECT" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | while read -r word; do
  if [ ${#word} -gt 3 ]; then
    echo "$word"
  fi
done | head -8)

if [ -z "$KEYWORDS" ]; then
  # No usable keywords extracted, allow (fail-open)
  exit 0
fi

# Count total keywords
KEYWORD_COUNT=$(echo "$KEYWORDS" | wc -l | tr -d ' ')

# Determine minimum match threshold
MIN_MATCHES=2
if [ "$KEYWORD_COUNT" -le 2 ]; then
  MIN_MATCHES=1
fi

# Count how many keywords appear in recent commit messages
MATCH_COUNT=0
LOWER_MESSAGES=$(echo "$RECENT_MESSAGES" | tr '[:upper:]' '[:lower:]')

while IFS= read -r keyword; do
  [ -z "$keyword" ] && continue
  if echo "$LOWER_MESSAGES" | grep -q "$keyword"; then
    MATCH_COUNT=$(( MATCH_COUNT + 1 ))
  fi
done <<< "$KEYWORDS"

if [ "$MATCH_COUNT" -ge "$MIN_MATCHES" ]; then
  exit 0
fi

echo "No recent commit found matching task: '$TASK_SUBJECT' (matched $MATCH_COUNT/$KEYWORD_COUNT keywords, needed $MIN_MATCHES)" >&2
exit 2
