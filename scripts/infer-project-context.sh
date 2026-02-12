#!/usr/bin/env bash
set -euo pipefail

# infer-project-context.sh — Extract project context from codebase mapping files
#
# Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]
#   CODEBASE_DIR  Path to .vbw-planning/codebase/ mapping files
#   REPO_ROOT     Optional, defaults to current directory (for git repo name extraction)
#
# Output: Structured JSON to stdout with source attribution per field
# Exit: 0 on success, non-zero only on critical errors (missing CODEBASE_DIR)

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]"
  echo ""
  echo "Extract project context from codebase mapping files."
  echo ""
  echo "  CODEBASE_DIR  Path to .vbw-planning/codebase/ mapping files"
  echo "  REPO_ROOT     Optional, defaults to current directory"
  echo ""
  echo "Outputs structured JSON to stdout with source attribution per field."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "Error: CODEBASE_DIR is required" >&2
  echo "Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]" >&2
  exit 1
fi

CODEBASE_DIR="$1"
REPO_ROOT="${2:-$(pwd)}"

if [[ ! -d "$CODEBASE_DIR" ]]; then
  echo "Error: CODEBASE_DIR does not exist: $CODEBASE_DIR" >&2
  exit 1
fi

# --- Project name extraction (priority: git repo > plugin.json > directory) ---
NAME_VALUE=""
NAME_SOURCE=""

# Try git repo name
if [[ -z "$NAME_VALUE" ]]; then
  repo_url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)
  if [[ -n "$repo_url" ]]; then
    repo_name=$(echo "$repo_url" | sed 's/.*\///' | sed 's/\.git$//')
    if [[ -n "$repo_name" ]]; then
      NAME_VALUE="$repo_name"
      NAME_SOURCE="repo"
    fi
  fi
fi

# Try plugin.json name
if [[ -z "$NAME_VALUE" ]]; then
  plugin_json="$REPO_ROOT/.claude-plugin/plugin.json"
  if [[ -f "$plugin_json" ]]; then
    pname=$(jq -r '.name // empty' "$plugin_json" 2>/dev/null || true)
    if [[ -n "$pname" ]]; then
      NAME_VALUE="$pname"
      NAME_SOURCE="plugin.json"
    fi
  fi
fi

# Fallback to directory name
if [[ -z "$NAME_VALUE" ]]; then
  NAME_VALUE=$(basename "$REPO_ROOT")
  NAME_SOURCE="directory"
fi

# Build name JSON
NAME_JSON=$(jq -n --arg v "$NAME_VALUE" --arg s "$NAME_SOURCE" \
  '{value: $v, source: $s}')

exit 0
