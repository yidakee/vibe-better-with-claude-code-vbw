---
name: assumptions
description: Surface Claude's implicit assumptions about a phase before planning begins.
argument-hint: [phase-number]
allowed-tools: Read, Glob, Grep, Bash
---

# VBW Assumptions: $ARGUMENTS

## Context

Working directory: `!`pwd``

Roadmap:
```
!`head -50 .vbw-planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
```

Codebase signals:
```
!`ls package.json pyproject.toml Cargo.toml go.mod 2>/dev/null || echo "No detected project files"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.

### Phase Resolution

If `$ARGUMENTS` does not contain an integer phase number:

1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md` and follow the **Planning Commands** algorithm:
   - Resolve the phases directory (check `.vbw-planning/ACTIVE` for milestone context)
   - Scan phase directories in numeric order (`01-*`, `02-*`, ...)
   - Find the first phase directory containing NO `*-PLAN.md` files
2. If found: announce "Auto-detected Phase {N} ({slug}) -- next phase to plan" and proceed using that phase number
3. If all phases have plans: STOP and tell the user "All phases are planned. Specify a phase to re-analyze: `/vbw:assumptions N`"

If `$ARGUMENTS` contains an explicit phase number, use it directly:

2. **Phase not in roadmap:** STOP: "Phase {N} not found."

## Purpose

Before planning, Claude makes invisible assumptions about scope, approach, and preferences. This command makes them explicit so the user can confirm, correct, or expand before /vbw:plan runs.

## Steps

### Step 1: Load phase context

Read: ROADMAP.md, REQUIREMENTS.md, PROJECT.md, STATE.md, CONTEXT.md (if exists), codebase signals.

### Step 2: Generate 5-10 assumptions

Categories (prioritized by impact):
- **Scope:** What's included/excluded beyond requirements
- **Technical:** Implementation approaches implied but unspecified
- **Ordering:** Task sequencing assumptions
- **Dependency:** What must exist from prior phases
- **User preference:** Defaults chosen without stated preference

### Step 3: Gather feedback

For each assumption: "Confirm, correct, or expand?"
- **Confirm**: correct, proceed
- **Correct**: user provides right answer
- **Expand**: partially correct, user adds nuance

### Step 4: Present summary

Group by status: confirmed, corrected, expanded.

This command does NOT write files. For persistence: "Run /vbw:discuss {N} to capture preferences as CONTEXT.md."

```
➜ Next Up
  /vbw:discuss {N} -- Persist preferences as CONTEXT.md
  /vbw:plan {N} -- Plan with assumptions clarified
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Numbered list (order = priority)
- ✓ confirmed, ✗ corrected, ○ expanded
- Next Up Block
- No ANSI color codes
