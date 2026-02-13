#!/bin/bash
set -u
# PreToolUse hook: Block access to sensitive files
# Exit 2 = block tool call, Exit 0 = allow
# Fail-CLOSED: exit 2 on any parse error (never allow unvalidated input through)

# Verify jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq not available, cannot validate file path" >&2
  exit 2
fi

INPUT=$(cat 2>/dev/null) || exit 2
[ -z "$INPUT" ] && exit 2

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // ""' 2>/dev/null) || exit 2

if [ -z "$FILE_PATH" ]; then
  exit 2
fi

# Sensitive file patterns
if echo "$FILE_PATH" | grep -qE '\.env$|\.env\.|\.pem$|\.key$|\.cert$|\.p12$|\.pfx$|credentials\.json$|secrets\.json$|service-account.*\.json$|node_modules/|\.git/|dist/|build/'; then
  echo "Blocked: sensitive file ($FILE_PATH)" >&2
  exit 2
fi

# Block GSD's .planning/ directory when VBW is actively running.
# Only enforce when VBW markers are present (session or agent), so GSD can
# still write to its own directory when VBW is not the active caller.
# Stale marker protection: ignore markers older than 24h to avoid false positives
# from crashed sessions that didn't clean up.
is_marker_fresh() {
  local marker="$1"
  [ ! -f "$marker" ] && return 1
  local now marker_mtime age
  now=$(date +%s)
  if [ "$(uname)" = "Darwin" ]; then
    marker_mtime=$(stat -f %m "$marker" 2>/dev/null || echo 0)
  else
    marker_mtime=$(stat -c %Y "$marker" 2>/dev/null || echo 0)
  fi
  age=$((now - marker_mtime))
  [ "$age" -lt 86400 ]
}

if echo "$FILE_PATH" | grep -qF '.planning/' && ! echo "$FILE_PATH" | grep -qF '.vbw-planning/'; then
  if is_marker_fresh ".vbw-planning/.active-agent" || is_marker_fresh ".vbw-planning/.vbw-session"; then
    echo "Blocked: .planning/ is managed by GSD, not VBW ($FILE_PATH)" >&2
    exit 2
  fi
fi

# Block .vbw-planning/ when GSD isolation is enabled and no VBW markers present.
# .gsd-isolation = opt-in flag created during /vbw:init consent flow.
# .active-agent = VBW subagent is running (managed by agent-start.sh / agent-stop.sh).
# .vbw-session = VBW command is active (managed by prompt-preflight.sh / session-stop.sh).
if echo "$FILE_PATH" | grep -qF '.vbw-planning/'; then
  if [ -f ".vbw-planning/.gsd-isolation" ]; then
    if [ ! -f ".vbw-planning/.active-agent" ] && [ ! -f ".vbw-planning/.vbw-session" ]; then
      echo "Blocked: .vbw-planning/ is isolated from non-VBW access ($FILE_PATH)" >&2
      exit 2
    fi
  fi
fi

exit 0
