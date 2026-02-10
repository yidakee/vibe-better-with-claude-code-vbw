---
name: add-phase
disable-model-invocation: true
description: Add a new phase to the end of the active milestone's roadmap.
argument-hint: <phase-name> [--goal="phase goal description"]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Add-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **Missing name:** STOP: "Usage: /vbw:add-phase <phase-name> [--goal=\"description\"]"

## Steps

1. **Resolve context:** ACTIVE → milestone-scoped paths. Otherwise → defaults.
2. **Parse args:** Phase name (first non-flag arg), --goal (optional), slug (lowercase hyphenated).
3. **Next number:** Highest in ROADMAP.md + 1, zero-padded.
4. **Update ROADMAP.md:** Append phase list entry, append Phase Details section, add progress row.
5. **Create dir:** `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
6. **Present:** Phase Banner with milestone, position, goal. ✓ for roadmap update + dir creation. Next Up: /vbw:discuss or /vbw:plan.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), Metrics, ✓ checklist, Next Up, no ANSI.
