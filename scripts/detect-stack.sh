#!/bin/bash
# detect-stack.sh — Detect project tech stack and recommend skills
# Called by /vbw:init Step 3 and /vbw:skills to avoid 50+ inline tool calls.
# Reads stack-mappings.json, checks project files, outputs JSON.
#
# Usage: bash detect-stack.sh [project-dir]
# Output: JSON object with detected stack, installed skills, and suggestions.

set -eo pipefail

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
if [ -d "$HOME/.claude/skills" ]; then
  INSTALLED_GLOBAL=$(ls -1 "$HOME/.claude/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  INSTALLED_PROJECT=$(ls -1 "$PROJECT_DIR/.claude/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
if [ -d "$HOME/.agents/skills" ]; then
  INSTALLED_AGENTS=$(ls -1 "$HOME/.agents/skills/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
fi
ALL_INSTALLED="$INSTALLED_GLOBAL,$INSTALLED_PROJECT,$INSTALLED_AGENTS"

# --- Read manifest files once ---
PKG_JSON=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  PKG_JSON=$(cat "$PROJECT_DIR/package.json" 2>/dev/null)
fi

REQUIREMENTS_TXT=""
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  REQUIREMENTS_TXT=$(cat "$PROJECT_DIR/requirements.txt" 2>/dev/null)
fi

PYPROJECT_TOML=""
if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  PYPROJECT_TOML=$(cat "$PROJECT_DIR/pyproject.toml" 2>/dev/null)
fi

GEMFILE=""
if [ -f "$PROJECT_DIR/Gemfile" ]; then
  GEMFILE=$(cat "$PROJECT_DIR/Gemfile" 2>/dev/null)
fi

CARGO_TOML=""
if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  CARGO_TOML=$(cat "$PROJECT_DIR/Cargo.toml" 2>/dev/null)
fi

GO_MOD=""
if [ -f "$PROJECT_DIR/go.mod" ]; then
  GO_MOD=$(cat "$PROJECT_DIR/go.mod" 2>/dev/null)
fi

# --- Check a single detect pattern ---
# Returns 0 (true) if pattern matches, 1 (false) if not.
check_pattern() {
  local pattern="$1"

  if echo "$pattern" | grep -qF ':'; then
    # Dependency pattern: "file:dependency"
    local file dep content
    file=$(echo "$pattern" | cut -d: -f1)
    dep=$(echo "$pattern" | cut -d: -f2-)

    case "$file" in
      package.json)   content="$PKG_JSON" ;;
      requirements.txt) content="$REQUIREMENTS_TXT" ;;
      pyproject.toml) content="$PYPROJECT_TOML" ;;
      Gemfile)        content="$GEMFILE" ;;
      Cargo.toml)     content="$CARGO_TOML" ;;
      go.mod)         content="$GO_MOD" ;;
      *)              content="" ;;
    esac

    if [ -n "$content" ] && echo "$content" | grep -qF "\"$dep\""; then
      return 0
    fi
    # Also check without quotes (requirements.txt, go.mod, etc.)
    if [ -n "$content" ] && echo "$content" | grep -qiw "$dep"; then
      return 0
    fi
    return 1
  else
    # File/directory pattern
    if [ -e "$PROJECT_DIR/$pattern" ]; then
      return 0
    fi
    return 1
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
if [ -d "$HOME/.claude/skills/find-skills" ] || [ -d "$HOME/.agents/skills/find-skills" ]; then
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
