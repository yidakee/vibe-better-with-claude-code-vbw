---
name: qa
description: Run deep verification on completed phase work using the QA agent.
argument-hint: [phase-number] [--tier=quick|standard|deep] [--effort=thorough|balanced|fast|turbo]
allowed-tools: Read, Write, Bash, Glob, Grep
---

# VBW QA: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Config: Pre-injected by SessionStart hook. Override with --effort flag.

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

## Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- **Auto-detect phase** (no explicit number): Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md`. Resolve phases dir (check .vbw-planning/ACTIVE). Scan numerically for first phase with `*-SUMMARY.md` but no `*-VERIFICATION.md`. Found: announce "Auto-detected Phase {N} ({slug})". All verified: STOP "All phases verified. Specify: `/vbw:qa N`"
- Phase not built (no SUMMARYs): STOP "Phase {N} has no completed plans. Run /vbw:execute {N} first."

Note: Continuous verification handled by hooks. This command is for deep, on-demand verification only.

## Steps

1. **Resolve tier:** Priority: --tier flag > --effort flag > config default > Standard. Effort mapping: turbo=skip (exit "QA skipped in turbo mode"), fast=quick, balanced=standard, thorough=deep. Read `${CLAUDE_PLUGIN_ROOT}/references/effort-profile-{profile}.md`. Context overrides: >15 requirements or last phase before ship → Deep.
2. **Resolve milestone:** If .vbw-planning/ACTIVE exists, use milestone-scoped paths.
3. **Spawn QA:** Spawn vbw-qa as subagent via Task tool:
```
Verify phase {N}. Tier: {ACTIVE_TIER}.
Plans: {paths to PLAN.md files}
Summaries: {paths to SUMMARY.md files}
Phase success criteria: {section from ROADMAP.md}
Convention baseline: .vbw-planning/codebase/CONVENTIONS.md (if exists)
Verification protocol: ${CLAUDE_PLUGIN_ROOT}/references/verification-protocol.md
Return findings using the qa_result schema (see ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md).
```
QA agent reads all files itself.

4. **Persist:** Parse QA output as JSON (qa_result schema). Fallback: extract from markdown. Write `{phase-dir}/{phase}-VERIFICATION.md` with frontmatter: phase, tier, result (PASS|FAIL|PARTIAL), passed, failed, total, date. Body: QA output.
5. **Present:** Per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
```
┌──────────────────────────────────────────┐
│  Phase {N}: {name} -- Verified           │
└──────────────────────────────────────────┘

  Tier:     {quick|standard|deep}
  Result:   {✓ PASS | ✗ FAIL | ◆ PARTIAL}
  Checks:   {passed}/{total}
  Failed:   {list or "None"}

  Report:   {path to VERIFICATION.md}

```
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh qa {result}` and display.
