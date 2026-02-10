---
name: insert-phase
disable-model-invocation: true
description: Insert an urgent phase between existing phases, renumbering subsequent phases.
argument-hint: <position> <phase-name> [--goal="phase goal description"]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Insert-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **Missing args:** STOP: "Usage: /vbw:insert-phase <position> <phase-name> [--goal=\"description\"]"
3. **Invalid position:** Out of range (1 to max+1) → STOP with valid range.
4. **Completed conflict:** Inserting before completed phase → WARN + confirm.

## Steps

1. **Resolve context:** ACTIVE → milestone-scoped paths. Otherwise → defaults.
2. **Parse args:** position (int), phase name (text before flags), --goal (optional), slug (lowercase hyphenated).
3. **Identify renumbering:** Parse ROADMAP.md phases. All >= position shift up by 1.
4. **Renumber dirs (REVERSE order):** For each phase from last to position: rename dir {NN}-{slug} → {NN+1}-{slug}, rename internal PLAN/SUMMARY files, update `phase:` frontmatter, update `depends_on` references.
5. **Update ROADMAP.md:** Insert new phase entry + details section at position, renumber subsequent entries/headers/cross-refs, update progress table.
6. **Create dir:** `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
7. **Present:** Phase Banner with renumber count, phase changes, file checklist, Next Up (/vbw:discuss or /vbw:plan).

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), Metrics, ✓ checklist, Next Up, no ANSI.
