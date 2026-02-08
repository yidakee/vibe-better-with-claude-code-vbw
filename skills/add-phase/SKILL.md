---
name: add-phase
description: Add a new phase to the end of the active milestone's roadmap.
argument-hint: <phase-name> [--goal="phase goal description"]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Add-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing phase name:** STOP: "Usage: /vbw:add-phase <phase-name> [--goal=\"description\"]"

## Steps

### Step 1: Resolve milestone context

If ACTIVE exists: milestone-scoped ROADMAP_PATH, PHASES_DIR.
Otherwise: .vbw-planning/ defaults.

### Step 2: Parse arguments

- **Phase name**: first non-flag argument
- **--goal**: optional goal description
- **Slug**: lowercase, hyphenated (e.g., "API Layer" -> "api-layer")

### Step 3: Determine next phase number

Find highest phase number in ROADMAP.md. Next = max + 1. Zero-pad (01, 02, ...).

### Step 4: Add to roadmap

Edit ROADMAP.md:
1. Append phase list entry: `- [ ] **Phase {N}: {name}** - {goal or "To be planned"}`
2. Append Phase Details section with goal, dependencies, empty success criteria
3. Add progress table row

### Step 5: Create directory

`mkdir -p {PHASES_DIR}/{NN}-{slug}/`

### Step 6: Present summary

```
╔═══════════════════════════════════════════╗
║  Phase Added: {phase-name}                ║
║  Phase {N} of {total}                     ║
╚═══════════════════════════════════════════╝

  Milestone: {name}
  Position:  Phase {N} (appended)
  Goal:      {goal or "To be planned"}

  ✓ Updated {ROADMAP_PATH}
  ✓ Created {PHASES_DIR}/{NN}-{slug}/

➜ Next Up
  /vbw:discuss {N} -- Define this phase's scope
  /vbw:plan {N} -- Plan this phase directly
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box)
- Metrics Block for position/goal
- File Checklist (✓ prefix)
- Next Up Block
- No ANSI color codes
