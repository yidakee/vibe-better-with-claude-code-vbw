# VBW Phase Auto-Detection Protocol

Single source of truth for detecting the target phase when the user omits the phase number from a command. Referenced by `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/execute/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/qa/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/discuss/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/assumptions/SKILL.md`.

## Overview

When `$ARGUMENTS` contains no explicit phase number, commands use this protocol to infer the correct phase from the current planning state. Detection logic varies by command type because each command targets a different stage of the phase lifecycle.

## Resolve Phases Directory

Before scanning, determine the correct phases path:

1. If `.vbw-planning/ACTIVE` exists, read its contents to get the milestone slug
2. Use `.vbw-planning/{milestone-slug}/phases/` as the phases directory
3. If ACTIVE does not exist, use `.vbw-planning/phases/`

All directory scanning below uses the resolved phases directory.

## Detection by Command Type

### Planning Commands (`/vbw:plan`, `/vbw:discuss`, `/vbw:assumptions`)

**Goal:** Find the next phase that needs planning.

**Algorithm:**
1. List phase directories in numeric order (`01-*`, `02-*`, ...)
2. For each directory, check for `*-PLAN.md` files
3. The first phase directory containing NO `*-PLAN.md` files is the target
4. If found: use that phase
5. If all phases have plans: report "All phases are planned. Specify a phase to re-plan: `/vbw:plan N`" and STOP

### Build Command (`/vbw:execute`)

**Goal:** Find the next phase that is planned but not yet built.

**Algorithm:**
1. List phase directories in numeric order
2. For each directory, check for `*-PLAN.md` and `*-SUMMARY.md` files
3. The first phase where `*-PLAN.md` files exist but at least one plan lacks a corresponding `*-SUMMARY.md` is the target
4. If found: use that phase
5. If all planned phases are fully built: report "All planned phases are built. Specify a phase to rebuild: `/vbw:execute N`" and STOP

**Matching logic:** Plan file `NN-PLAN.md` corresponds to summary file `NN-SUMMARY.md` (same numeric prefix).

### QA Command (`/vbw:qa`)

**Goal:** Find the next phase that is built but not yet verified.

**Algorithm:**
1. List phase directories in numeric order
2. For each directory, check for `*-SUMMARY.md` and `*-VERIFICATION.md` files
3. The first phase where `*-SUMMARY.md` files exist but no `*-VERIFICATION.md` exists is the target
4. If found: use that phase
5. If all built phases are verified: report "All phases verified. Specify a phase to re-verify: `/vbw:qa N`" and STOP

## Announcement

Always announce the auto-detected phase before proceeding. Format:

```
Auto-detected Phase {N} ({slug}) -- {reason}
```

Reasons by command type:
- Planning: "next phase to plan"
- Build: "planned, not yet built"
- QA: "built, not yet verified"

Then continue with the rest of the command as if the user had typed that phase number.
