---
name: vbw:status
description: Display project progress dashboard with phase status, velocity metrics, and next action.
argument-hint: [--verbose] [--metrics]
allowed-tools: Read, Glob, Grep, Bash
---

# VBW Status $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Roadmap:
```
!`head -50 .vbw-planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
```

Config: Pre-injected by SessionStart hook. Read .vbw-planning/config.json only if --verbose.

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- No ROADMAP.md or has template placeholders: STOP "No roadmap found. Run /vbw:vibe to set up your project."

## Steps

1. **Parse args:** --verbose shows per-plan detail within each phase
2. **Resolve milestone:** If .vbw-planning/ACTIVE exists, use milestone-scoped paths. Gather milestone list (all dirs with ROADMAP.md). Else use defaults.
3. **Read data:** (STATE.md and ROADMAP.md use compact format -- flat fields, no verbose prose)
   - STATE.md: project name, current phase (flat `Phase:`, `Plans:`, `Progress:` lines), velocity
   - ROADMAP.md: phases, status markers, plan counts (compact per-phase fields, Progress table)
   - SessionStart injection: effort, autonomy. If --verbose, read config.json
   - Phase dirs: glob `*-PLAN.md` and `*-SUMMARY.md` per phase for completion data
   - If Agent Teams build active: read shared task list for teammate status
   - Cost ledger: if `.vbw-planning/.cost-ledger.json` exists, read with jq. Extract per-agent costs. Compute total. Only display economy if total > 0.
4. **Compute progress:** Per phase: count PLANs (total) vs SUMMARYs (done). Pct = done/total * 100. Status: ✓ (100%), ◆ (1-99%), ○ (0%).
5. **Compute velocity:** Total plans done, avg duration, total time. If --verbose: per-phase breakdown.
6. **Next action:** Find first incomplete phase. Has plans but not all summaries: `/vbw:vibe` (auto-executes). Complete + next unplanned: `/vbw:vibe` (auto-plans). All complete: `/vbw:vibe --archive`. No plans anywhere: `/vbw:vibe`.

## Display

Per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:

**Header:**
```
╔═══════════════════════════════════════════╗
║  {project-name}                           ║
║  {progress-bar} {percent}%                ║
╚═══════════════════════════════════════════╝
```

**Multi-milestone** (if multiple):
```
  Milestones:
    ◆ {active-slug}    {bar} {%}  ({done}/{total} phases)
    ○ {other-slug}     {bar} {%}  ({done}/{total} phases)
```

**Phases:** `✓/◆/○ Phase N: {name}  {██░░} {%}  ({done}/{total} plans)`. If --verbose, indent per-plan detail with duration.

**Agent Teams** (if active): `◆/✓/○ {Agent}: Plan {N} ({status})`

**Velocity:**
```
  Velocity:
    Plans completed:  {N}
    Average duration: {time}
    Total time:       {time}
```

**Economy** (only if .cost-ledger.json exists AND total > $0.00): Read ledger with jq. Sort agents by cost desc. Show dollar + pct per agent. Include cache hit rate if available.
```
  Economy:
    Total cost:   ${total}
    Per agent:
      Dev          $0.82   70%
      Lead         $0.15   13%
    Cache hit rate: {percent}%
```

**Next Up:** Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh status` and display.
