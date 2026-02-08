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

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing phase number:** STOP: "Usage: /vbw:remove-phase <phase-number>"
3. **Phase not found:** STOP: "Phase {N} not found in roadmap."
4. **Phase has work:** If PLAN.md or SUMMARY.md exist in phase dir, STOP: "Phase {N} has artifacts. Remove plans first."
5. **Phase is complete:** If marked `[x]` in roadmap, STOP: "Cannot remove completed Phase {N}."

## Steps

### Step 1: Resolve milestone context

If ACTIVE exists: milestone-scoped ROADMAP_PATH, PHASES_DIR.
Otherwise: .vbw-planning/ defaults.

### Step 2: Parse arguments

Extract phase number. Validate against roadmap. Look up name and slug.

### Step 3: Confirm removal

Display phase details (name, goal, status, directory) and ask user to confirm. If not confirmed, STOP: "Removal cancelled."

### Step 4: Remove phase directory

`rm -rf {PHASES_DIR}/{NN}-{slug}/`

### Step 5: Renumber subsequent phases

Process in FORWARD order (lowest first to avoid collisions when decrementing):

For each phase with number > removed:
1. Rename directory: `{NN}-{slug}` -> `{NN-1}-{slug}`
2. Rename internal PLAN.md/SUMMARY.md files to new phase prefix
3. Update `phase:` field in YAML frontmatter
4. Update `depends_on` references pointing to renumbered phases

### Step 6: Update ROADMAP.md

1. Remove phase entry from phase list
2. Remove Phase Details section
3. Renumber subsequent entries, headers, cross-references
4. Update dependency references (phase after removed one points to phase before)
5. Update progress table

### Step 7: Present summary

```
╔═══════════════════════════════════════════╗
║  Phase Removed: {phase-name}              ║
║  {total} phases remaining                 ║
╚═══════════════════════════════════════════╝

  Renumbered: {count} phase(s) shifted

  Phase Changes:
    REMOVED Phase {N}: {name}
    Phase {old} -> Phase {new}: {name}

  ✓ Removed {PHASES_DIR}/{NN}-{slug}/
  ✓ Updated {ROADMAP_PATH}
  ✓ Renumbered {count} subsequent phases

➜ Next Up
  /vbw:status -- View updated roadmap
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for removal banner
- Metrics Block for renumbering info
- File Checklist (✓ prefix) for changes
- Next Up Block for navigation
- No ANSI color codes
