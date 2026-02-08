---
name: discuss
description: Gather phase context through structured questions before planning.
argument-hint: [phase-number]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Discuss: $ARGUMENTS

## Context

Working directory: `!`pwd``

Roadmap:
```
!`head -50 .vbw-planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
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
3. If all phases have plans: STOP and tell the user "All phases are planned. Specify a phase to re-discuss: `/vbw:discuss N`"

If `$ARGUMENTS` contains an explicit phase number, use it directly:

2. **Phase not in roadmap:** STOP: "Phase {N} not found."

## Purpose

Structured conversation to surface the user's vision, priorities, and constraints BEFORE the Lead agent plans. Output is a CONTEXT.md file that /vbw:plan reads as locked input. This is requirements clarification, not brainstorming.

## Steps

### Step 1: Load phase details

From ROADMAP.md: goal, requirements, success criteria, dependencies.

### Step 2: Structured questioning

Ask 3-5 phase-specific questions across:
- **Essential features:** Which requirements are most critical?
- **Technical preferences:** Implementation approach preferences?
- **Boundaries:** What to avoid?
- **Dependencies:** Influence from prior phases?
- **Acceptance:** What makes this phase "done" beyond roadmap criteria?

Adapt to phase type (agent/UI/integration/infrastructure).

### Step 3: Synthesize CONTEXT.md

Write to `.vbw-planning/phases/{phase-dir}/{phase}-CONTEXT.md`:

```markdown
# Phase {N} Context

## User Vision
{What the user wants, in their words}

## Essential Features
{Prioritized list}

## Technical Preferences
{Specific implementation preferences}

## Boundaries
{Constraints and things to avoid}

## Acceptance Criteria (User)
{Beyond roadmap criteria}

## Decisions Made
{Decisions locked during discussion}
```

### Step 4: Confirm and next step

Show summary. Ask for corrections.

```
➜ Next Up
  /vbw:plan {N} -- Plan this phase with your context locked in
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- ✓ for captured answers
- Next Up Block
- No ANSI color codes
