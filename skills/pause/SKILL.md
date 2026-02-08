---
name: pause
description: Save current session context for later resumption.
argument-hint: [notes]
allowed-tools: Read, Write, Glob, Grep
---

# VBW Pause: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.

## Steps

### Step 1: Resolve paths

If .vbw-planning/ACTIVE exists: use milestone-scoped RESUME_PATH, STATE_PATH, PHASES_DIR.
Otherwise: use .vbw-planning/ defaults.

### Step 2: Gather session context

1. From STATE.md: current phase, plan progress, status
2. From ROADMAP.md: current phase goal
3. From phase directory: last completed SUMMARY.md, next pending PLAN.md
4. From $ARGUMENTS: session notes (if provided)
5. Current timestamp

### Step 3: Write RESUME.md

Write to RESUME_PATH:

```markdown
# Session Resume

**Paused:** {YYYY-MM-DD HH:MM}
**Milestone:** {slug or "default"}

## Position

**Phase:** {N} - {name}
**Plan progress:** {completed}/{total} plans
**Last completed:** Plan {NN}: {title}
**Next pending:** Plan {NN}: {title}

## Context

**Phase goal:** {from ROADMAP.md}
**Current status:** {from STATE.md}

## Session Notes

{User notes or "No notes."}

## Resume Instructions

1. Run `/vbw:resume` to restore this context
2. {Specific next command}
```

Note: Agent Teams sessions are not resumable. On resume, a NEW team is created from saved state. Completed work is detected via SUMMARY.md files and git log.

### Step 4: Update STATE.md

Update Session Continuity section: last session date, stopped-at description, resume file path.

### Step 5: Present confirmation

```
╔═══════════════════════════════════════════╗
║  Session Paused                           ║
╚═══════════════════════════════════════════╝

  Phase:    {N} - {name}
  Progress: {completed}/{total} plans
  Saved to: {RESUME_PATH}

  {If notes: "Notes: {abbreviated}"}

➜ Next Up
  /vbw:resume -- Restore this session
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Double-line box for pause confirmation
- Metrics Block for position
- Next Up Block for resume hint
- No ANSI color codes
