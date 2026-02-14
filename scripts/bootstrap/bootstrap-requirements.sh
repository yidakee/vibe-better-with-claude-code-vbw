#!/usr/bin/env bash
set -euo pipefail

# bootstrap-requirements.sh — Generate REQUIREMENTS.md from discovery data
#
# Usage: bootstrap-requirements.sh OUTPUT_PATH DISCOVERY_JSON_PATH [RESEARCH_FILE]
#   OUTPUT_PATH          Path to write REQUIREMENTS.md
#   DISCOVERY_JSON_PATH  Path to discovery.json with answered[] and inferred[]
#   RESEARCH_FILE        Optional path to domain-research.md with research findings

if [[ $# -lt 2 ]]; then
  echo "Usage: bootstrap-requirements.sh OUTPUT_PATH DISCOVERY_JSON_PATH [RESEARCH_FILE]" >&2
  exit 1
fi

OUTPUT_PATH="$1"
DISCOVERY_JSON="$2"
RESEARCH_FILE="${3:-}"  # Optional third argument

if [[ ! -f "$DISCOVERY_JSON" ]]; then
  echo "Error: Discovery file not found: $DISCOVERY_JSON" >&2
  exit 1
fi

# Validate JSON
if ! jq empty "$DISCOVERY_JSON" 2>/dev/null; then
  echo "Error: Invalid JSON in $DISCOVERY_JSON" >&2
  exit 1
fi

# Load research if available
RESEARCH_AVAILABLE=false
TABLE_STAKES=""
PITFALLS=""
PATTERNS=""

if [ -n "$RESEARCH_FILE" ] && [ -f "$RESEARCH_FILE" ]; then
  RESEARCH_AVAILABLE=true
  # Extract sections using awk (bash-only, no jq needed for markdown)
  # Use sed to remove last line instead of head -n -1 (macOS compatibility)
  TABLE_STAKES=$(awk '/## Table Stakes/,/^## / {if (!/^## / || /## Table Stakes/) print}' "$RESEARCH_FILE" | tail -n +2 | sed '$d')
  PITFALLS=$(awk '/## Common Pitfalls/,/^## / {if (!/^## / || /## Common Pitfalls/) print}' "$RESEARCH_FILE" | tail -n +2 | sed '$d')
  PATTERNS=$(awk '/## Architecture Patterns/,/^## / {if (!/^## / || /## Architecture Patterns/) print}' "$RESEARCH_FILE" | tail -n +2 | sed '$d')
fi

CREATED=$(date +%Y-%m-%d)

# Ensure parent directory exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Extract data from discovery.json
INFERRED_COUNT=$(jq '.inferred | length' "$DISCOVERY_JSON")

# Start building the file
{
  echo "# Requirements"
  echo ""
  echo "Defined: ${CREATED}"
  echo ""
  echo "## Problem Statement"
  echo ""
  echo "_(To be defined during discovery)_"
  echo ""
  echo "## Requirements"
  echo ""

  # Generate requirements from inferred data
  # Research findings integrated where relevant — requirement descriptions include domain context.
  if [[ "$INFERRED_COUNT" -gt 0 ]]; then
    REQ_NUM=1
    for i in $(seq 0 $((INFERRED_COUNT - 1))); do
      REQ_ID=$(printf "REQ-%02d" "$REQ_NUM")
      REQ_TEXT=$(jq -r ".inferred[$i].text // .inferred[$i]" "$DISCOVERY_JSON")
      REQ_PRIORITY=$(jq -r ".inferred[$i].priority // \"Must-have\"" "$DISCOVERY_JSON")

      # Extract tier if present, default to "differentiators" for backward compat
      REQ_TIER=$(jq -r ".inferred[$i].tier // \"differentiators\"" "$DISCOVERY_JSON")

      # Map tier to priority and annotation
      case "$REQ_TIER" in
        table_stakes)
          REQ_PRIORITY="Must-have"
          REQ_ANNOTATION=" (domain standard)"
          ;;
        differentiators)
          REQ_PRIORITY="Must-have"
          REQ_ANNOTATION=" (competitive advantage)"
          ;;
        anti_features)
          # Skip anti-features — they go to Out of Scope section
          continue
          ;;
        *)
          REQ_ANNOTATION=""
          ;;
      esac

      # Integrate research findings if available (legacy annotation logic)
      if [ "$RESEARCH_AVAILABLE" = true ] && [ -z "$REQ_ANNOTATION" ]; then
        ANNOTATION=""

        # Check if requirement relates to table stakes (domain standard)
        if echo "$TABLE_STAKES" | grep -qi "$(echo "$REQ_TEXT" | awk '{print tolower($1) " " tolower($2) " " tolower($3)}' | head -c 20)" 2>/dev/null; then
          RELEVANT_STAKE=$(echo "$TABLE_STAKES" | grep -i "$(echo "$REQ_TEXT" | awk '{print $2}' | head -c 15)" | head -1 | sed 's/^[*-] //' | cut -c1-60)
          if [ -n "$RELEVANT_STAKE" ]; then
            ANNOTATION=" (domain standard)"
          fi
        fi

        # Check if requirement addresses a common pitfall
        if [ -z "$ANNOTATION" ] && echo "$PITFALLS" | grep -qi "$(echo "$REQ_TEXT" | awk '{print tolower($1) " " tolower($2)}' | head -c 15)" 2>/dev/null; then
          RELEVANT_PITFALL=$(echo "$PITFALLS" | grep -i "$(echo "$REQ_TEXT" | awk '{print $2}' | head -c 15)" | head -1 | sed 's/^[*-] //' | cut -c1-80)
          if [ -n "$RELEVANT_PITFALL" ]; then
            ANNOTATION=" (addresses common pitfall: ${RELEVANT_PITFALL})"
          fi
        fi

        # Check if requirement aligns with architecture pattern
        if [ -z "$ANNOTATION" ] && echo "$PATTERNS" | grep -qi "$(echo "$REQ_TEXT" | awk '{print tolower($1) " " tolower($2)}' | head -c 15)" 2>/dev/null; then
          RELEVANT_PATTERN=$(echo "$PATTERNS" | grep -i "$(echo "$REQ_TEXT" | awk '{print $2}' | head -c 15)" | head -1 | sed 's/^[*-] //' | cut -c1-60)
          if [ -n "$RELEVANT_PATTERN" ]; then
            ANNOTATION=" (typical approach: ${RELEVANT_PATTERN})"
          fi
        fi

        REQ_ANNOTATION="${ANNOTATION}"
      fi

      echo "### ${REQ_ID}: ${REQ_TEXT}${REQ_ANNOTATION}"
      echo "**${REQ_PRIORITY}**"
      echo ""
      REQ_NUM=$((REQ_NUM + 1))
    done
  else
    echo "_(No requirements defined yet)_"
    echo ""
  fi

  # Generate Out of Scope section from anti-features
  ANTI_FEATURES=$(jq -r '.inferred[] | select(.tier == "anti_features") | .text' "$DISCOVERY_JSON" 2>/dev/null || echo "")
  echo "## Out of Scope"
  echo ""
  if [ -n "$ANTI_FEATURES" ]; then
    echo "$ANTI_FEATURES" | while IFS= read -r feature; do
      if [ -n "$feature" ]; then
        echo "- $feature (deliberately excluded)"
      fi
    done
  else
    echo "_(To be defined)_"
  fi
  echo ""
} > "$OUTPUT_PATH"

# Update discovery.json with research metadata
if [ "$RESEARCH_AVAILABLE" = true ]; then
  DOMAIN=$(jq -r '.answered[] | select(.category=="scope") | .answer' "$DISCOVERY_JSON" | head -1 | awk '{print $1}')
  DATE=$(date +%Y-%m-%d)
  jq --arg domain "$DOMAIN" --arg date "$DATE" \
     '.research_summary = {available: true, domain: $domain, date: $date, key_findings: []}' \
     "$DISCOVERY_JSON" > "$DISCOVERY_JSON.tmp" && mv "$DISCOVERY_JSON.tmp" "$DISCOVERY_JSON"
else
  jq '.research_summary = {available: false}' "$DISCOVERY_JSON" > "$DISCOVERY_JSON.tmp" && mv "$DISCOVERY_JSON.tmp" "$DISCOVERY_JSON"
fi

exit 0
