---
name: vbw:qa
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

Phase state:
```
!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/phase-detect.sh 2>/dev/null || echo "phase_detect_error=true"`
```

## Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- **Auto-detect phase** (no explicit number): Phase detection is pre-computed in Context above. Use `next_phase` and `next_phase_slug` for the target phase. To find the first phase needing QA: scan phase dirs for first with `*-SUMMARY.md` but no `*-VERIFICATION.md` (phase-detect.sh provides the base phase state; QA-specific detection requires this additional check). Found: announce "Auto-detected Phase {N} ({slug})". All verified: STOP "All phases verified. Specify: `/vbw:qa N`"
- Phase not built (no SUMMARYs): STOP "Phase {N} has no completed plans. Run /vbw:vibe first."

Note: Continuous verification handled by hooks. This command is for deep, on-demand verification only.

## Steps

1. **Resolve tier:** Priority: --tier flag > --effort flag > config default > Standard. Effort mapping: turbo=skip (exit "QA skipped in turbo mode"), fast=quick, balanced=standard, thorough=deep. Read `${CLAUDE_PLUGIN_ROOT}/references/effort-profile-{profile}.md`. Context overrides: >15 requirements or last phase before ship → Deep.
2. **Resolve milestone:** If .vbw-planning/ACTIVE exists, use milestone-scoped paths.
3. **Spawn QA:**
   - Resolve QA model:
     ```bash
     QA_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh qa .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
     if [ $? -ne 0 ]; then echo "$QA_MODEL" >&2; exit 1; fi
     ```
   - Display: `◆ Spawning QA agent (${QA_MODEL})...`
   - Spawn vbw-qa as subagent via Task tool. **Add `model: "${QA_MODEL}"` parameter.**
```
Verify phase {N}. Tier: {ACTIVE_TIER}.
Plans: {paths to PLAN.md files}
Summaries: {paths to SUMMARY.md files}
Phase success criteria: {section from ROADMAP.md}
Convention baseline: .vbw-planning/codebase/CONVENTIONS.md (if exists)
Verification protocol: ${CLAUDE_PLUGIN_ROOT}/references/verification-protocol.md
Return findings using the qa_result schema (see ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md).
```
   - QA agent reads all files itself.

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
