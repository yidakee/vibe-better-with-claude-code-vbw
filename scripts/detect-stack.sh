#!/bin/bash
# detect-stack.sh — Detect project tech stack and recommend skills
# Called by /vbw:init Step 3 and /vbw:skills to avoid 50+ inline tool calls.
# Reads stack-mappings.json, checks project files, outputs JSON.
#
# Usage: bash detect-stack.sh [project-dir]
# Output: JSON object with detected stack, installed skills, and suggestions.

set -euo pipefail

# --- jq dependency check ---
if ! command -v jq &>/dev/null; then
  echo '{"error":"jq is required but not installed. Install: brew install jq (macOS) / apt install jq (Linux)"}' >&2
  exit 1
fi

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAPPINGS="$SCRIPT_DIR/../config/stack-mappings.json"

if [ ! -f "$MAPPINGS" ]; then
  echo '{"error":"stack-mappings.json not found"}' >&2
  exit 1
fi

# --- Collect installed skills ---
INSTALLED_GLOBAL=""
INSTALLED_PROJECT=""
INSTALLED_AGENTS=""
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [ -d "$CLAUDE_DIR/skills" ]; then
  INSTALLED_GLOBAL=$(ls -1 "$CLAUDE_DIR/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  INSTALLED_PROJECT=$(ls -1 "$PROJECT_DIR/.claude/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
if [ -d "$HOME/.agents/skills" ]; then
  INSTALLED_AGENTS=$(ls -1 "$HOME/.agents/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
ALL_INSTALLED="$INSTALLED_GLOBAL,$INSTALLED_PROJECT,$INSTALLED_AGENTS"

# --- Shared find helper (exclude generated/vendor trees) ---
project_find() {
  find "$PROJECT_DIR" \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.vbw-planning/*" \
    -not -path "*/.planning/*" \
    -not -path "*/vendor/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/target/*" \
    -not -path "*/.next/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.venv/*" \
    "$@" 2>/dev/null
}

has_glob_chars() {
  case "$1" in
    *"*"*|*"?"*|*"["*) return 0 ;;
    *) return 1 ;;
  esac
}

file_has_dependency() {
  local file="$1"
  local dep="$2"
  local basename
  basename=$(basename "$file")

  if [ "$basename" = "package.json" ]; then
    if jq -e --arg dep "$dep" '
      ((.dependencies // {}) | has($dep)) or
      ((.devDependencies // {}) | has($dep)) or
      ((.peerDependencies // {}) | has($dep)) or
      ((.optionalDependencies // {}) | has($dep))
    ' "$file" >/dev/null 2>&1; then
      return 0
    fi
  fi

  if grep -qF "$dep" "$file" 2>/dev/null; then
    return 0
  fi

  return 1
}

check_dependency_pattern() {
  local file_pattern="$1"
  local dep="$2"
  local candidate
  local root_file

  # Exact relative path (e.g. backend/functions/package.json:express)
  if [[ "$file_pattern" == */* ]] && [[ "$file_pattern" != \*\*/* ]] && ! has_glob_chars "$file_pattern"; then
    candidate="$PROJECT_DIR/$file_pattern"
    if [ -f "$candidate" ] && file_has_dependency "$candidate" "$dep"; then
      return 0
    fi
    return 1
  fi

  # Explicit recursive path pattern (e.g. **/package.json:firebase)
  if [[ "$file_pattern" == \*\*/* ]]; then
    local suffix="${file_pattern#**/}"
    while IFS= read -r candidate; do
      if file_has_dependency "$candidate" "$dep"; then
        return 0
      fi
    done < <(project_find -type f -path "*/$suffix")
    return 1
  fi

  # Glob filename pattern (e.g. *.json:foo)
  if has_glob_chars "$file_pattern"; then
    while IFS= read -r candidate; do
      if file_has_dependency "$candidate" "$dep"; then
        return 0
      fi
    done < <(project_find -type f -name "$file_pattern")
    return 1
  fi

  # Plain filename: check root + nested manifests (excluding vendor/generated dirs)
  root_file="$PROJECT_DIR/$file_pattern"
  if [ -f "$root_file" ] && file_has_dependency "$root_file" "$dep"; then
    return 0
  fi

  while IFS= read -r candidate; do
    if [ "$candidate" = "$root_file" ]; then
      continue
    fi
    if file_has_dependency "$candidate" "$dep"; then
      return 0
    fi
  done < <(project_find -type f -name "$file_pattern")

  return 1
}

check_path_pattern() {
  local pattern="$1"

  # Exact relative path first
  if [ -e "$PROJECT_DIR/$pattern" ]; then
    return 0
  fi

  # Explicit recursive path pattern (e.g. **/firebase.json)
  if [[ "$pattern" == \*\*/* ]]; then
    local suffix="${pattern#**/}"
    if project_find -path "*/$suffix" -print -quit | grep -q .; then
      return 0
    fi
    return 1
  fi

  # Glob patterns should match both files and dirs recursively (e.g. *.xcodeproj)
  if has_glob_chars "$pattern"; then
    if project_find -name "$pattern" -print -quit | grep -q .; then
      return 0
    fi
    return 1
  fi

  # Plain filename/dirname fallback: search nested paths too
  if [[ "$pattern" != */* ]] && project_find -name "$pattern" -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

# --- Check a single detect pattern ---
# Returns 0 (true) if pattern matches, 1 (false) if not.
check_pattern() {
  local pattern="$1"

  if echo "$pattern" | grep -qF ':'; then
    # Dependency pattern: "file:dependency"
    local file dep
    file=$(echo "$pattern" | cut -d: -f1)
    dep=$(echo "$pattern" | cut -d: -f2-)
    check_dependency_pattern "$file" "$dep"
    return $?
  else
    check_path_pattern "$pattern"
    return $?
  fi
}

# --- Iterate stack-mappings.json and check all entries ---
# Uses jq to extract entries, then checks each detect pattern in bash.
DETECTED=""
RECOMMENDED_SKILLS=""

# Extract all entries as flat lines: category|name|description|skills_csv|detect_csv
ENTRIES=$(jq -r '
  to_entries[] |
  select(.key | startswith("_") | not) |
  .key as $cat |
  .value | to_entries[] |
  [$cat, .key, (.value.description // .key), (.value.skills | join(";")), (.value.detect | join(";"))] |
  join("|")
' "$MAPPINGS" 2>/dev/null)

while IFS='|' read -r category name description skills_csv detect_csv; do
  [ -z "$name" ] && continue

  # Check each detect pattern
  matched=false
  IFS=';' read -ra patterns <<< "$detect_csv"
  for pattern in "${patterns[@]}"; do
    if check_pattern "$pattern"; then
      matched=true
      break
    fi
  done

  if [ "$matched" = true ]; then
    # Add to detected list
    if [ -n "$DETECTED" ]; then
      DETECTED="$DETECTED,$name"
    else
      DETECTED="$name"
    fi

    # Add recommended skills
    IFS=';' read -ra skill_list <<< "$skills_csv"
    for skill in "${skill_list[@]}"; do
      if ! echo ",$RECOMMENDED_SKILLS," | grep -qF ",$skill,"; then
        if [ -n "$RECOMMENDED_SKILLS" ]; then
          RECOMMENDED_SKILLS="$RECOMMENDED_SKILLS,$skill"
        else
          RECOMMENDED_SKILLS="$skill"
        fi
      fi
    done
  fi
done <<< "$ENTRIES"

# --- Compute suggestions (recommended but not installed) ---
SUGGESTIONS=""
IFS=',' read -ra rec_arr <<< "$RECOMMENDED_SKILLS"
for skill in "${rec_arr[@]}"; do
  [ -z "$skill" ] && continue
  if ! echo ",$ALL_INSTALLED," | grep -qF ",$skill,"; then
    if [ -n "$SUGGESTIONS" ]; then
      SUGGESTIONS="$SUGGESTIONS,$skill"
    else
      SUGGESTIONS="$skill"
    fi
  fi
done

# --- Check find-skills availability ---
FIND_SKILLS="false"
if [ -d "$CLAUDE_DIR/skills/find-skills" ] || [ -d "$HOME/.agents/skills/find-skills" ]; then
  FIND_SKILLS="true"
fi

# --- Output JSON ---
jq -n \
  --arg detected "$DETECTED" \
  --arg installed_global "$INSTALLED_GLOBAL" \
  --arg installed_project "$INSTALLED_PROJECT" \
  --arg installed_agents "$INSTALLED_AGENTS" \
  --arg recommended "$RECOMMENDED_SKILLS" \
  --arg suggestions "$SUGGESTIONS" \
  --argjson find_skills "$FIND_SKILLS" \
  '{
    detected_stack: ($detected | split(",") | map(select(. != ""))),
    installed: {
      global: ($installed_global | split(",") | map(select(. != ""))),
      project: ($installed_project | split(",") | map(select(. != ""))),
      agents: ($installed_agents | split(",") | map(select(. != "")))
    },
    recommended_skills: ($recommended | split(",") | map(select(. != ""))),
    suggestions: ($suggestions | split(",") | map(select(. != ""))),
    find_skills_available: $find_skills
  }'
