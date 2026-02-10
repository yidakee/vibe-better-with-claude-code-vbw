---
name: audit
disable-model-invocation: true
description: Audit completion readiness -- checks completion, execution, and verification status.
argument-hint: [--fix]
allowed-tools: Read, Glob, Grep, Bash
---

# VBW Audit $ARGUMENTS

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **No roadmap:** Neither ACTIVE nor ROADMAP.md → STOP: "No roadmap found. Run /vbw:implement."

## Steps

1. **Resolve context:** ACTIVE → milestone-scoped paths. Otherwise → root paths.
2. **Run checks:**
   - Roadmap completeness: every phase has real goal (not TBD/empty)
   - Phase planning: every phase has >=1 PLAN.md
   - Plan execution: every PLAN.md has SUMMARY.md
   - Execution status: every SUMMARY.md has `status: complete`
   - Verification: VERIFICATION.md files exist + PASS. Missing=WARN, failed=FAIL
   - Requirements coverage: req IDs in roadmap exist in REQUIREMENTS.md
3. **Compute result:** PASS (all pass) | WARN (no FAILs but WARNs) | FAIL (any fail)
4. **--fix suggestions:** Missing verifications → `/vbw:qa {N}`. Incomplete plans → `/vbw:execute {N}`. Placeholder goals → edit roadmap. Failed executions → re-run.
5. **Present:** Phase Banner "Milestone Audit: {name} / Result: {PASS|WARN|FAIL}" with check results (✓/⚠/✗ per check). PASS → Next Up /vbw:archive. FAIL → remediation suggestions.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — double-line box, ✓ PASS, ⚠ WARN, ✗ FAIL, Metrics, Next Up, no ANSI.
