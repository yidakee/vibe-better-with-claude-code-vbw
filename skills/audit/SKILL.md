---
name: audit
description: Audit the active milestone for shipping readiness -- checks completion, execution, and verification status.
argument-hint: [--fix]
allowed-tools: Read, Glob, Grep, Bash
---

# VBW Audit $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No roadmap:** If neither ACTIVE nor ROADMAP.md exists, STOP: "No milestones configured. Run /vbw:new or /vbw:milestone first."

## Steps

### Step 1: Resolve milestone context

If ACTIVE exists: milestone-scoped paths (ROADMAP, PHASES_DIR, STATE).
Otherwise: .vbw-planning/ root paths. MILESTONE_NAME = slug or "default".

### Step 2: Run audit checks

**Check 1 -- Roadmap completeness:** Every phase has a real goal (not "TBD" or empty).
**Check 2 -- Phase planning:** Every phase has at least one PLAN.md.
**Check 3 -- Plan execution:** Every PLAN.md has a corresponding SUMMARY.md.
**Check 4 -- Execution status:** Every SUMMARY.md has `status: complete`.
**Check 5 -- Verification:** VERIFICATION.md files exist and show PASS. Missing = WARN, failed = FAIL.
**Check 6 -- Requirements coverage:** Requirement IDs in roadmap exist in REQUIREMENTS.md.

### Step 3: Compute result

- **PASS:** All checks pass (ship-ready)
- **WARN:** No FAILs but WARNs (non-critical issues)
- **FAIL:** Any check failed (critical issues)

### Step 4: --fix suggestions

If `--fix` present and issues found, suggest commands:
- Missing verifications: `/vbw:qa {N}`
- Incomplete plans: `/vbw:execute {N}`
- Placeholder goals: edit roadmap manually
- Failed executions: re-run `/vbw:execute {N}`

### Step 5: Present report

```
╔═══════════════════════════════════════════╗
║  Milestone Audit: {MILESTONE_NAME}        ║
║  Result: {PASS|WARN|FAIL}                 ║
╚═══════════════════════════════════════════╝

  Checks:
    {✓|⚠|✗} Roadmap completeness    {evidence}
    {✓|⚠|✗} Phase planning          {N}/{N} phases
    {✓|⚠|✗} Plan execution          {N}/{N} plans
    {✓|⚠|✗} Execution status        {N}/{N} complete
    {✓|⚠|✗} Verification coverage   {N}/{M} verified
    {✓|⚠|✗} Requirements coverage   {N} mapped

  {If PASS:}
  ➜ Next Up
    /vbw:ship -- Ship this milestone

  {If FAIL:}
  ✗ Milestone not ready to ship
    /vbw:execute {N} -- Complete Phase {N}
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Double-line box for audit header
- ✓ PASS, ⚠ WARN, ✗ FAIL
- Metrics Block for check results
- Next Up Block for navigation
- No ANSI color codes
