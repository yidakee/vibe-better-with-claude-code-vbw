---
name: status
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

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No roadmap:** If ROADMAP.md doesn't exist or still contains template placeholders, STOP: "No roadmap found. Run /vbw:new to define your project."

## Steps

### Step 1: Parse arguments

- **--verbose**: Show per-plan detail within each phase
- **--metrics**: Show token consumption breakdown and compaction history

### Step 2: Resolve milestone context

If .vbw-planning/ACTIVE exists: use milestone-scoped ROADMAP_PATH, PHASES_DIR. Gather milestone list (all dirs with ROADMAP.md).
Otherwise: use .vbw-planning/ defaults.

### Step 3: Read project data

**From STATE.md:** Project name, current phase, velocity metrics.
**From ROADMAP.md:** All phases with names, status markers, plan counts.
**From config.json:** Effort profile.
**From phase directories:** Glob for `*-PLAN.md` and `*-SUMMARY.md` per phase. Count for real-time completion data.

If an Agent Teams build is active, read the shared task list for live teammate status.

### Step 4: Compute phase progress

For each phase in roadmap:
1. Count PLAN.md files (total) and SUMMARY.md files (completed)
2. Calculate percentage: (completed / total) * 100
3. Status: ✓ complete (100%), ◆ in-progress (1-99%), ○ planned/not-started (0%)

### Step 5: Compute velocity

From STATE.md or SUMMARY.md files: total plans completed, average duration, total time.

If --verbose: also prepare per-phase breakdown with per-plan durations.

### Step 6: Determine next action

1. Find first incomplete phase
2. If has plans but not all summaries: `/vbw:execute {N}`
3. If complete and next has no plans: `/vbw:plan {N+1}`
4. If all complete: `/vbw:ship`
5. If no plans anywhere: `/vbw:plan`

### Step 7: Metrics (--metrics only)

Read SUMMARY.md frontmatter for tokens_consumed and compaction_count. Compute:
- Per-phase token totals and compaction counts
- Agent type estimates: Dev (from SUMMARYs), QA (~estimated from tier), Lead (~estimated from plan count)
- Cost estimate

Label estimates clearly as "~estimated".

### Step 8: Display dashboard

**Header:**
```
╔═══════════════════════════════════════════╗
║  {project-name}                           ║
║  {progress-bar} {percent}%                ║
╚═══════════════════════════════════════════╝
```

**Multi-milestone overview** (if multiple milestones):
```
  Milestones:
    ◆ {active-slug}    {bar} {%}  ({done}/{total} phases)
    ○ {other-slug}     {bar} {%}  ({done}/{total} phases)
```

**Phase list:**
```
  Phases:
    ✓ Phase 1: {name}       ██████████ 100%  (3/3 plans)
    ◆ Phase 3: {name}       ██████░░░░  60%  (2/3 plans)
    ○ Phase 4: {name}       ░░░░░░░░░░   0%  (0/3 plans)
```

**Verbose per-plan detail** (if --verbose):
```
    ✓ Phase 1: {name}       ██████████ 100%  (3/3 plans)
        ✓ Plan 01: {title}                    ~3 min
        ✓ Plan 02: {title}                    ~4 min
```

**Agent Teams status** (if build team active):
```
  Active Build:
    ◆ Dev-1: Plan 02 (in progress)
    ✓ Dev-2: Plan 01 (complete)
    ○ Dev-3: Plan 03 (pending)
```

**Velocity:**
```
  Velocity:
    Plans completed:  {N}
    Average duration: {time}
    Total time:       {time}
```

**Next Up:**
```
➜ Next: /vbw:{command} -- {description}
```

**Metrics view** (if --metrics):
```
  Token Consumption:
    Total:     {tokens}
    By Agent:
      Dev:     {tokens} ({%})
      QA:      ~{tokens} ({%}) (estimated)
      Lead:    ~{tokens} ({%}) (estimated)
    By Phase:
      Phase 1: {tokens} ({plans} plans, {avg}/plan)

  Compaction Events:
    Total:     {count} across {phases} phases
    {Phase N, Plan M: count compaction(s)}

  Cost Estimate:
    ~${amount} (based on Opus pricing)
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Status Dashboard template (double-line header box)
- Progress bars: 10 chars, █ filled, ░ empty
- Symbols: ✓ complete, ◆ in-progress, ○ pending
- Metrics Block for velocity and token sections
- Next Up Block for suggested action
- No ANSI color codes
