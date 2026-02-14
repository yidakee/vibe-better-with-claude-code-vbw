#!/usr/bin/env bash
set -euo pipefail

# bootstrap-project.sh — Generate PROJECT.md for a VBW project
#
# Usage: bootstrap-project.sh OUTPUT_PATH NAME DESCRIPTION [CORE_VALUE]
#   OUTPUT_PATH   Path to write PROJECT.md
#   NAME          Project name
#   DESCRIPTION   One-line project description
#   CORE_VALUE    (Optional) Core value statement; defaults to DESCRIPTION

if [[ $# -lt 3 ]]; then
  echo "Usage: bootstrap-project.sh OUTPUT_PATH NAME DESCRIPTION [CORE_VALUE]" >&2
  exit 1
fi

OUTPUT_PATH="$1"
NAME="$2"
DESCRIPTION="$3"
CORE_VALUE="${4:-$DESCRIPTION}"

# Ensure parent directory exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<EOF
# ${NAME}

${DESCRIPTION}

**Core value:** ${CORE_VALUE}

## Requirements

### Validated

### Active

### Out of Scope

## Constraints
- **Zero dependencies**: No package.json, npm, or build step
- **Bash + Markdown only**: All logic in shell scripts and markdown commands

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
EOF

exit 0
