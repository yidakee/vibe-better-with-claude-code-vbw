---
name: remove-phase
disable-model-invocation: true
description: Remove a future phase from the active milestone's roadmap and renumber subsequent phases.
argument-hint: <phase-number>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Remove-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **Missing number:** STOP: "Usage: /vbw:remove-phase <phase-number>"
3. **Not found:** STOP: "Phase {N} not found in roadmap."
4. **Has work:** PLAN.md or SUMMARY.md in phase dir → STOP: "Phase {N} has artifacts. Remove plans first."
5. **Complete:** Marked [x] in roadmap → STOP: "Cannot remove completed Phase {N}."

## Steps

1. **Resolve context:** ACTIVE → milestone-scoped paths. Otherwise → defaults.
2. **Parse args:** Extract phase number, validate, look up name/slug.
3. **Confirm:** Display phase details, ask confirmation. Not confirmed → STOP.
4. **Remove dir:** `rm -rf {PHASES_DIR}/{NN}-{slug}/`
5. **Renumber (FORWARD order):** For each phase > removed: rename dir {NN} → {NN-1}, rename internal files, update frontmatter, update depends_on.
6. **Update ROADMAP.md:** Remove phase entry + details, renumber subsequent, update deps, update progress table.
7. **Present:** Phase Banner with renumber count, phase changes, file checklist, Next Up (/vbw:status).

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), Metrics, ✓ checklist, Next Up, no ANSI.
