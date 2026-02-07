---
description: Restore context from a previous paused session.
argument-hint:
allowed-tools: Read, Bash, Glob
---

# VBW Resume

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **No resume file:** Resolve RESUME_PATH (using ACTIVE pointer per Step 1). If RESUME.md does not exist at RESUME_PATH, STOP: "No paused session found. Use /vbw:pause to save your session before taking a break."

## Steps

### Step 1: Resolve milestone context

Standard milestone resolution to find RESUME_PATH:
- If .planning/ACTIVE exists: read slug, set RESUME_PATH to .planning/{slug}/RESUME.md, set STATE_PATH to .planning/{slug}/STATE.md, set PHASES_DIR to .planning/{slug}/phases/
- If .planning/ACTIVE does not exist: set RESUME_PATH to .planning/RESUME.md, set STATE_PATH to .planning/STATE.md, set PHASES_DIR to .planning/phases/

### Step 2: Read resume file

Read RESUME_PATH and extract all sections:
- Position: phase, plan progress, last completed plan, next pending plan
- Context: phase goal, current status
- Session notes
- Resume instructions: specific next command

### Step 3: Check for state changes

Read STATE.md to check if anything has changed since the pause.

Compare the resume file's "last completed plan" against the current state of the phases directory. Use Glob to find SUMMARY.md files in PHASES_DIR:
- If new SUMMARY.md files exist that were not present at pause time, note: "Progress was made since you paused."
- If the state matches, proceed normally.

### Step 4: Present resume context

Display using brand formatting from @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:

```
╔═══════════════════════════════════════════╗
║  Session Resumed                          ║
║  Paused: {date from resume file}          ║
╚═══════════════════════════════════════════╝

  Phase:    {N} - {name}
  Progress: {completed}/{total} plans
  Status:   {current status}

  {If session notes exist:}
  Notes: {session notes}

  {If progress changed since pause:}
  ⚠ Progress changed since pause -- review /vbw:status

  Phase Goal:
    {phase goal from resume file}

➜ Continue
  {specific next command from resume instructions}
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Double-line box for the resume header (phase-level event)
- Metrics Block for position and status
- ⚠ for state-changed warning
- Next Up Block for continuation command
- No ANSI color codes
