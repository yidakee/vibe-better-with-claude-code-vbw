---
name: fix
description: Apply a quick fix or small change with commit discipline. Turbo mode -- no planning ceremony.
argument-hint: "<description of what to fix or change>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Fix: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing description:** If $ARGUMENTS is empty, STOP: "Usage: /vbw:fix \"description of what to fix\""

## Steps

### Step 1: Parse fix description

The entire $ARGUMENTS string (minus flags) is the fix description.

### Step 2: Resolve milestone context

If .vbw-planning/ACTIVE exists: use milestone-scoped STATE_PATH.
Otherwise: use .vbw-planning/STATE.md.

### Step 3: Spawn Dev agent

Spawn vbw-dev as a subagent via the Task tool with thin context:

```
Quick fix (Turbo mode). Effort: low.
Task: {fix description}.
Implement directly. One atomic commit: fix(quick): {brief description}.
No SUMMARY.md or PLAN.md needed.
If ambiguous or requires architectural decisions, STOP and report back.
```

### Step 4: Verify and present

Check `git log --oneline -1` for the new commit.

If committed:
```
✓ Fix applied

  {commit hash} {commit message}
  Files: {changed files}

➜ Next: /vbw:status -- View project status
```

If Dev stopped without committing:
```
⚠ Fix could not be applied automatically

  {reason from Dev agent}

➜ Try: /vbw:debug "{issue}" -- Investigate further
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- ✓ for success, ⚠ for inability to fix
- Next Up Block for navigation
- No ANSI color codes
