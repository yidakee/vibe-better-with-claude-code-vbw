---
name: vbw:debug
description: Investigate a bug using the Debugger agent's scientific method protocol.
argument-hint: "<bug description or error message>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Debug: $ARGUMENTS

## Context

Working directory: `!`pwd``

Recent commits:
```
!`git log --oneline -10 2>/dev/null || echo "No git history"`
```

## Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- No $ARGUMENTS: STOP "Usage: /vbw:debug \"description of the bug or error message\""

## Steps

1. **Parse + effort:** Entire $ARGUMENTS = bug description. Map effort: thorough=high, balanced/fast=medium, turbo=low. Read `${CLAUDE_PLUGIN_ROOT}/references/effort-profile-{profile}.md`.

2. **Classify ambiguity:** 2+ signals = ambiguous: "intermittent/sometimes/random/unclear/inconsistent/flaky/sporadic/nondeterministic" keywords, multiple root cause areas, generic/missing error, previous reverted fixes in git log. Overrides: `--competing`/`--parallel` = always ambiguous; `--serial` = never.

3. **Spawn investigation:**

**Path A: Competing Hypotheses** (effort=high AND ambiguous):
- Generate 3 hypotheses (cause, codebase area, confirming evidence)
- Resolve Debugger model:
  ```bash
  DEBUGGER_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh debugger .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
  if [ $? -ne 0 ]; then echo "$DEBUGGER_MODEL" >&2; exit 1; fi
  ```
- Display: `◆ Spawning Debugger (${DEBUGGER_MODEL})...`
- Create Agent Team "debug-{timestamp}" via TeamCreate
- Create 3 tasks via TaskCreate, each with: bug report, ONE hypothesis only (no cross-contamination), working dir, instruction to report via `debugger_report` schema (see `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`)
- Spawn 3 vbw-debugger teammates, one task each. **Add `model: "${DEBUGGER_MODEL}"` parameter to each Task spawn.**
- Wait for completion. Synthesize: strongest evidence + highest confidence wins. Multiple confirmed = contributing factors.
- Winning hypothesis with fix: apply + commit `fix({scope}): {description}`
- Shutdown: send shutdown to each teammate, wait for approval, re-request if rejected, then TeamDelete.

**Path B: Standard** (all other cases):
- Resolve Debugger model:
  ```bash
  DEBUGGER_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh debugger .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
  if [ $? -ne 0 ]; then echo "$DEBUGGER_MODEL" >&2; exit 1; fi
  ```
- Display: `◆ Spawning Debugger (${DEBUGGER_MODEL})...`
- Spawn vbw-debugger as subagent via Task tool. **Add `model: "${DEBUGGER_MODEL}"` parameter.**
```
Bug investigation. Effort: {DEBUGGER_EFFORT}.
Bug report: {description}.
Working directory: {pwd}.
Follow protocol: reproduce, hypothesize, gather evidence, diagnose, fix, verify, document.
If you apply a fix, commit with: fix({scope}): {description}.
```

4. **Present:** Per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
```
┌──────────────────────────────────────────┐
│  Bug Investigation Complete              │
└──────────────────────────────────────────┘

  Mode:       {Path A: "Competing Hypotheses (3 parallel)" + hypothesis outcomes | Path B: "Standard (single debugger)"}
  Issue:      {one-line summary}
  Root Cause: {from report}
  Fix:        {commit hash + message, or "No fix applied"}

  Files Modified: {list}

➜ Next: /vbw:status -- View project status
```
