---
name: resume
description: Restore context from a previous paused session.
argument-hint:
allowed-tools: Read, Bash, Glob
---

# VBW Resume

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No resume file:** If RESUME.md doesn't exist at resolved path, STOP: "No paused session found. Use /vbw:pause to save your session first."

## Steps

### Step 1: Resolve paths

If .vbw-planning/ACTIVE exists: use milestone-scoped RESUME_PATH, STATE_PATH, PHASES_DIR.
Otherwise: use .vbw-planning/ defaults.

### Step 2: Read resume file

Read RESUME_PATH. Extract: position (phase, plan progress, next pending), context (goal, status), session notes, resume instructions.

### Step 3: Check for state changes

Read STATE.md. Compare resume file's last completed plan against current SUMMARY.md files in PHASES_DIR. If new completions exist since pause: note "Progress was made since you paused."

Agent Teams awareness: previous team sessions are not resumable. Resume creates a NEW team from saved state. Completed tasks are detected via SUMMARY.md + `git log`, and only remaining tasks are assigned.

### Step 4: Check for unfilled templates

If PROJECT.md contains the template placeholder `{project-description}`, the project was initialized but never defined. In this case, suggest `/vbw:new` as the next action instead of the resume file's instructions.

### Step 5: Present resume context

```
╔═══════════════════════════════════════════╗
║  Session Resumed                          ║
║  Paused: {date}                           ║
╚═══════════════════════════════════════════╝

  Phase:    {N} - {name}
  Progress: {completed}/{total} plans
  Status:   {current status}

  {If notes: "Notes: {session notes}"}

  {If progress changed: "⚠ Progress changed since pause -- review /vbw:status"}

  {If templates unfilled: "⚠ Project not yet defined -- templates still contain placeholders"}

  Phase Goal:
    {goal from resume file}

➜ Next Up
  {If templates unfilled: "/vbw:new -- Define your project (name, requirements, roadmap)"}
  {Otherwise: specific next command from resume instructions}
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Double-line box for resume header
- Metrics Block for position and status
- ⚠ for state-changed warning
- Next Up Block for continuation
- No ANSI color codes
