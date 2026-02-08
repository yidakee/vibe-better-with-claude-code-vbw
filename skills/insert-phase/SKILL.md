---
name: insert-phase
description: Insert an urgent phase between existing phases, renumbering subsequent phases.
argument-hint: <position> <phase-name> [--goal="phase goal description"]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Insert-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing arguments:** If no position + name, STOP: "Usage: /vbw:insert-phase <position> <phase-name> [--goal=\"description\"]"
3. **Invalid position:** If out of range (1 to max+1), STOP with valid range.
4. **Completed conflict:** If inserting before a completed phase, WARN and require confirmation.

## Steps

### Step 1: Resolve milestone context

If ACTIVE exists: milestone-scoped ROADMAP_PATH, PHASES_DIR.
Otherwise: .vbw-planning/ defaults.

### Step 2: Parse arguments

- **Position**: integer (required)
- **Phase name**: text after position, before flags
- **--goal**: optional goal description
- **Slug**: lowercase, hyphenated

### Step 3: Identify phases to renumber

Parse ROADMAP.md for all existing phases. All phases >= position shift up by 1. Build renumbering map.

### Step 4: Renumber phase directories

Process in REVERSE order (highest first to avoid collisions):

For each phase from last down to position:
1. Rename directory: `{NN}-{slug}` -> `{NN+1}-{slug}`
2. Rename internal PLAN.md/SUMMARY.md files to new phase prefix
3. Update `phase:` field in YAML frontmatter
4. Update `depends_on` references pointing to renumbered phases

### Step 5: Update ROADMAP.md

1. Insert new phase entry at position in phase list
2. Insert new Phase Details section
3. Renumber all subsequent phase entries, headers, and cross-references
4. Update progress table

### Step 6: Create phase directory

`mkdir -p {PHASES_DIR}/{NN}-{slug}/`

### Step 7: Present summary

```
╔═══════════════════════════════════════════╗
║  Phase Inserted: {phase-name}             ║
║  Position: {N} of {total}   INSERTED      ║
╚═══════════════════════════════════════════╝

  Renumbered: {count} phase(s) shifted

  Phase Changes:
    Phase {old} -> Phase {new}: {name}
    NEW Phase {N}: {new-phase-name}

  ✓ Updated {ROADMAP_PATH}
  ✓ Created {PHASES_DIR}/{NN}-{slug}/
  ✓ Renumbered {count} phase directories

➜ Next Up
  /vbw:discuss {N} -- Define this urgent phase
  /vbw:plan {N} -- Plan this phase
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for insertion banner
- Metrics Block for renumbering info
- File Checklist (✓ prefix) for changes
- Next Up Block for navigation
- No ANSI color codes
