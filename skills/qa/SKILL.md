---
description: Run deep verification on completed phase work using the QA agent.
argument-hint: [phase-number] [--tier=quick|standard|deep] [--effort=thorough|balanced|fast|turbo]
allowed-tools: Read, Write, Bash, Glob, Grep
---

# VBW QA: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

## Guard

1. **Not initialized:** If .vbw-planning/ doesn't exist, STOP: "Run /vbw:init first."

2. **Auto-detect phase (if no explicit phase number):** If `$ARGUMENTS` does not contain an integer phase number (flags like `--tier` are still allowed):
   1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md`
   2. Resolve the phases directory: if `.vbw-planning/ACTIVE` exists, read it for the milestone slug and use `.vbw-planning/{milestone-slug}/phases/`; otherwise use `.vbw-planning/phases/`
   3. Scan phase directories in numeric order (`01-*`, `02-*`, ...). Find the first phase where `*-SUMMARY.md` files exist but no `*-VERIFICATION.md` exists
   4. If found: announce "Auto-detected Phase {N} ({slug}) -- built, not yet verified" and proceed with that phase number
   5. If all built phases are verified: STOP and tell user "All phases verified. Specify a phase to re-verify: `/vbw:qa N`"

3. **Phase not built:** If no SUMMARY.md files in phase directory, STOP: "Phase {N} has no completed plans. Run /vbw:execute {N} first."

Note: Continuous verification is handled by hooks (PostToolUse, TaskCompleted, TeammateIdle). This command is for deep, on-demand verification only.

## Steps

### Step 1: Resolve tier

Priority order:
1. `--tier` flag (explicit override)
2. `--effort` flag mapped via effort-profiles.md:

| Effort   | QA Tier  |
|----------|----------|
| Turbo    | Skip (exit: "QA skipped in turbo mode") |
| Fast     | Quick    |
| Balanced | Standard |
| Thorough | Deep     |

3. Config default mapped via same table. If no config: Standard.

**Context overrides:** If >15 requirements or last phase before ship: override to Deep.

### Step 2: Resolve milestone context

If .vbw-planning/ACTIVE exists: use milestone-scoped paths.
Otherwise: use default .vbw-planning/ paths.

### Step 3: Spawn QA agent

Spawn vbw-qa as a subagent via the Task tool with thin context:

```
Verify phase {N}. Tier: {ACTIVE_TIER}.
Plans: {paths to PLAN.md files}
Summaries: {paths to SUMMARY.md files}
Phase success criteria: {section from ROADMAP.md}
Convention baseline: .vbw-planning/codebase/CONVENTIONS.md (if exists)
Verification protocol: ${CLAUDE_PLUGIN_ROOT}/references/verification-protocol.md
Return findings as structured text. Do not write files.
```

The QA agent reads all referenced files itself.

### Step 4: Persist results

Parse QA output for result (PASS/FAIL/PARTIAL) and check counts.

Write VERIFICATION.md to `{phase-dir}/{phase}-VERIFICATION.md`:
```yaml
---
phase: {phase-id}
tier: {ACTIVE_TIER}
result: {PASS|FAIL|PARTIAL}
passed: {N}
failed: {N}
total: {N}
date: {YYYY-MM-DD}
---
```

Body: QA output text.

### Step 5: Present summary

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md`:

```
┌──────────────────────────────────────────┐
│  Phase {N}: {name} -- Verified           │
└──────────────────────────────────────────┘

  Tier:     {quick|standard|deep}
  Result:   {✓ PASS | ✗ FAIL | ◆ PARTIAL}
  Checks:   {passed}/{total}
  Failed:   {list or "None"}

  Report:   {path to VERIFICATION.md}

➜ Next Up
  /vbw:execute {N+1} -- Build next phase (if PASS)
  /vbw:fix "{issue}" -- Fix a failing check (if FAIL/PARTIAL)
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:
- Single-line box for verification banner
- Metrics Block for tier/result/checks
- Semantic symbols: ✓ PASS, ✗ FAIL, ◆ PARTIAL
- Next Up Block for navigation
- No ANSI color codes
