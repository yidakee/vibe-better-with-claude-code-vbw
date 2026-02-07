---
description: Save current session context for later resumption.
argument-hint: [notes]
allowed-tools: Read, Write, Glob, Grep
---

# VBW Pause: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Current state:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No state found"`
```

Roadmap:
```
!`cat .planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."

## Steps

### Step 1: Resolve milestone context

Standard milestone resolution:
- If .planning/ACTIVE exists: read slug, set RESUME_PATH to .planning/{slug}/RESUME.md, set STATE_PATH to .planning/{slug}/STATE.md, set PHASES_DIR to .planning/{slug}/phases/
- If .planning/ACTIVE does not exist: set RESUME_PATH to .planning/RESUME.md, set STATE_PATH to .planning/STATE.md, set PHASES_DIR to .planning/phases/

### Step 2: Gather session context

Read and extract:

1. **From STATE.md:** Current phase number and name, plan progress (X of Y), status.
2. **From ROADMAP.md:** Current phase goal and success criteria.
3. **From phase directory:** Use Glob to find the most recent SUMMARY.md and PLAN.md files. Determine:
   - Last completed plan (most recent SUMMARY.md)
   - Next pending plan (PLAN.md without corresponding SUMMARY.md)
4. **From $ARGUMENTS:** If the user provided notes, include them as session notes.
5. **Timestamp:** Current date and time.

### Step 3: Write RESUME.md

Write the resume file to RESUME_PATH with this structure:

```markdown
# Session Resume

**Paused:** {YYYY-MM-DD HH:MM}
**Milestone:** {slug or "default"}

## Position

**Phase:** {N} - {phase-name}
**Plan progress:** {completed}/{total} plans
**Last completed:** Plan {NN}: {title}
**Next pending:** Plan {NN}: {title} (or "Phase complete, ready for next phase")

## Context

**Phase goal:** {from ROADMAP.md}
**Current status:** {from STATE.md}

## Session Notes

{User-provided notes from $ARGUMENTS, or "No notes."}

## Resume Instructions

To continue from where you left off:
1. Run `/vbw:resume` to restore this context
2. {Specific next command based on position, e.g., "/vbw:build 3 --plan=02"}
```

### Step 4: Update STATE.md

Update the Session Continuity section of STATE.md using the Edit tool:
- Last session: {today's date}
- Stopped at: {brief description of position}
- Resume file: {RESUME_PATH}

### Step 5: Present confirmation

Display using brand formatting from @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:

```
╔═══════════════════════════════════════════╗
║  Session Paused                           ║
╚═══════════════════════════════════════════╝

  Phase:    {N} - {name}
  Progress: {completed}/{total} plans
  Saved to: {RESUME_PATH}

  {If notes provided:}
  Notes: {abbreviated notes}

➜ Resume later: /vbw:resume
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Double-line box for the pause confirmation (phase-level event)
- Metrics Block for position info
- Next Up Block for resume hint
- No ANSI color codes
