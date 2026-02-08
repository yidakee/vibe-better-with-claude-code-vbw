---
name: milestone
disable-model-invocation: true
description: Start a new milestone cycle with isolated state and phase numbering.
argument-hint: <milestone-name> [--branch]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Milestone: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Existing milestones:
```
!`ls -d .vbw-planning/*/ 2>/dev/null || echo "No milestone directories"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing name:** If $ARGUMENTS has no milestone name, STOP: "Usage: /vbw:milestone <milestone-name> [--branch]"
3. **Already exists:** If .vbw-planning/{slug}/ exists, STOP: "Milestone '{name}' already exists. Use /vbw:switch {name}."
4. **Migration needed:** If no ACTIVE file but ROADMAP.md exists at root (single-milestone with work), migrate to "default" milestone first.

## Steps

### Step 1: Parse arguments

- **Milestone name**: first non-flag argument
- **Slug**: lowercase, spaces to hyphens, strip special chars (e.g., "v2.0 Launch" -> "v2-0-launch")
- **--branch**: enable git branch integration

### Step 2: First-milestone migration (if needed)

If Guard #4 triggered:
1. Create .vbw-planning/default/
2. Move ROADMAP.md, STATE.md, phases/ into .vbw-planning/default/
3. Write ACTIVE file with "default"
4. Display "✓ Migrated existing work to 'default' milestone"

Shared files stay at root: PROJECT.md, config.json, REQUIREMENTS.md, codebase/.

### Step 3: Create milestone directory

1. Create .vbw-planning/{slug}/
2. Write ROADMAP.md from template with milestone title
3. Write STATE.md from template with milestone header
4. Create .vbw-planning/{slug}/phases/

Add `"branch_per_milestone": true` to config.json if --branch used (persists preference for future milestones).

### Step 4: Update ACTIVE pointer

Write slug to .vbw-planning/ACTIVE.

### Step 5: Git branch integration

If `--branch` (or `branch_per_milestone` is true in config):
1. Create branch: `git checkout -b milestone/{slug}`
2. Display "✓ Created and switched to branch milestone/{slug}"

If not: display "○ Git branch skipped (use --branch to create a dedicated branch)"

### Step 6: Present summary

```
{If migration: "⚠ Migrated existing work to 'default' milestone"}

╔═══════════════════════════════════════════╗
║  Milestone Created: {milestone-name}      ║
║  Slug: {slug}                             ║
╚═══════════════════════════════════════════╝

  ✓ .vbw-planning/{slug}/ROADMAP.md
  ✓ .vbw-planning/{slug}/STATE.md
  ✓ .vbw-planning/{slug}/phases/
  ✓ .vbw-planning/ACTIVE -> {slug}
  {✓ Branch: milestone/{slug} | ○ No branch}

  Shared (project-level):
    PROJECT.md, config.json, REQUIREMENTS.md

➜ Next Up
  /vbw:add-phase {phase-name} -- Add a phase to this milestone
  /vbw:discuss 1 -- Start defining your first phase
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for creation banner
- File Checklist (✓ prefix) for created files
- Next Up Block for navigation
- No ANSI color codes
