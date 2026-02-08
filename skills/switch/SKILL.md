---
name: switch
disable-model-invocation: true
description: Switch the active milestone context for all subsequent VBW commands.
argument-hint: <milestone-name>
allowed-tools: Read, Write, Bash, Glob, Grep
---

# VBW Switch: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone"`
```

Available milestones:
```
!`ls -d .vbw-planning/*/ROADMAP.md 2>/dev/null || echo "No milestone directories"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No milestones:** If ACTIVE doesn't exist, STOP: "No milestones configured. Use /vbw:milestone <name>."
3. **Missing name:** If $ARGUMENTS empty, list milestones (◆ active, ○ others) and STOP.
4. **Invalid milestone:** If .vbw-planning/{slug}/ doesn't exist, STOP with available list.

## Steps

### Step 1: Parse and validate

Normalize name to slug. Verify .vbw-planning/{slug}/ROADMAP.md exists. If target = current active, display "Already on '{name}'." and STOP.

### Step 2: Check for uncommitted changes

Run `git status --porcelain`. If output is non-empty:
- WARN: "⚠ Uncommitted changes detected. Commit or stash before switching to avoid losing work."
- List the dirty files
- Ask: "Continue anyway?"

### Step 3: Update ACTIVE pointer

Write slug to .vbw-planning/ACTIVE.

### Step 4: Git branch switch

Check if `milestone/{slug}` branch exists (`git branch --list milestone/{slug}`).
If exists: `git checkout milestone/{slug}` and display "✓ Switched to branch milestone/{slug}"
If not: skip silently.

### Step 5: Read target state

Read .vbw-planning/{slug}/STATE.md for phase, progress, percentage.

### Step 6: Present summary

```
╔═══════════════════════════════════════════╗
║  Switched to: {milestone-name}            ║
╚═══════════════════════════════════════════╝

  Previous: {old-slug}
  Active:   {new-slug}
  {If branch: "Branch: milestone/{slug}"}

  Milestone State:
    Phase:    {current}/{total}
    Progress: {bar} {percent}%

➜ Next Up
  /vbw:status -- View milestone progress
  /vbw:plan {N} -- Plan the next phase
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for switch confirmation
- Metrics Block for state display
- Progress bar: 10 chars, █ filled, ░ empty
- Next Up Block for navigation
- No ANSI color codes
