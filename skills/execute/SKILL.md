---
description: Execute a planned phase through Agent Teams with parallel Dev teammates.
argument-hint: [phase-number] [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Build: $ARGUMENTS

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

2. **Auto-detect phase (if omitted):** If `$ARGUMENTS` does not contain an integer phase number (flags like `--effort` are still allowed):
   1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md` and follow the **Resolve Phases Directory** section to determine the correct phases path.
   2. Scan phase directories in numeric order. For each directory, check for `*-PLAN.md` and `*-SUMMARY.md` files. The first phase where `*-PLAN.md` files exist but at least one plan lacks a corresponding `*-SUMMARY.md` (matched by numeric prefix) is the target.
   3. If found: announce "Auto-detected Phase {N} ({slug}) -- planned, not yet built" and proceed with that phase number.
   4. If all planned phases are fully built: STOP and tell the user "All planned phases are built. Specify a phase to rebuild: `/vbw:execute N`"

3. **Phase not planned:** If no PLAN.md files in .vbw-planning/phases/{phase-dir}/, STOP: "Phase {N} has no plans. Run /vbw:plan {N} first."
4. **Phase already complete:** If ALL plans have SUMMARY.md, WARN: "Phase {N} already complete. Re-running creates new commits. Continue?"

## Steps

### Step 1: Parse arguments

- **Phase number** (optional; auto-detected if omitted): integer matching `.vbw-planning/phases/{NN}-*`
- **--effort** (optional): thorough|balanced|fast|turbo. Overrides config for this run only.
- **--skip-qa** (optional): skip post-build deep verification
- **--plan=NN** (optional): execute only one plan, ignore wave grouping

Map effort to agent levels per `${CLAUDE_PLUGIN_ROOT}/references/effort-profiles.md`:

| Profile  | DEV_EFFORT | QA_EFFORT |
|----------|------------|-----------|
| Thorough | high       | high      |
| Balanced | medium     | medium    |
| Fast     | medium     | low       |
| Turbo    | low        | skip      |

### Step 2: Load plans and detect resume state

1. Glob for `*-PLAN.md` in the phase directory. Read each plan's YAML frontmatter (plan, title, wave, depends_on, autonomous, files_modified).
2. Check for existing SUMMARY.md files -- these plans are already complete.
3. Check `git log --oneline -20` for committed tasks matching this phase (crash recovery).
4. Build list of remaining (uncompleted) plans. If `--plan=NN`, filter to that single plan.
5. For partially-complete plans (SUMMARY.md with `status: partial`, or commits in git log but no SUMMARY.md): note the resume-from task number.

### Step 3: Create Agent Team and execute

Create a build team. For each uncompleted plan, create a task in the shared task list with thin context:

```
Execute all tasks in {PLAN_PATH}.
Effort: {DEV_EFFORT}. Working directory: {pwd}.
{If resuming: "Resume from Task {N}. Tasks 1-{N-1} already committed."}
{If autonomous: false: "This plan has checkpoints -- pause for user input."}
```

Spawn Dev teammates (one per plan within a wave, or one per plan if `--plan=NN`). Use wave ordering: all plans in wave 1 first, wait for completion, then wave 2, etc.

Hooks handle continuous verification:
- PostToolUse validates SUMMARY.md structure on write
- TaskCompleted verifies atomic commit exists
- TeammateIdle runs quality gate before teammate stops

### Step 4: Post-build QA (optional)

If `--skip-qa` NOT set AND effort != turbo: spawn QA as a subagent with thin context:

```
Verify phase {N}. Tier: {QA tier from effort}.
Plans: {paths to PLAN.md files}. Summaries: {paths to SUMMARY.md files}.
Phase success criteria: {from ROADMAP.md}.
```

Persist results to `{phase-dir}/{phase}-VERIFICATION.md`.

If `--skip-qa` or turbo: display "○ QA verification skipped ({reason})".

### Step 5: Update state and present summary

**Update STATE.md:** phase position, plan completion counts, effort used.
**Update ROADMAP.md:** mark completed plans.

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md`:

```
╔═══════════════════════════════════════════════╗
║  Phase {N}: {name} -- Built                   ║
╚═══════════════════════════════════════════════╝

  Plan Results:
    ✓ Plan 01: {title}
    ✓ Plan 02: {title}
    ✗ Plan 03: {title} (failed)

  Metrics:
    Plans:      {completed}/{total}
    Effort:     {profile}
    Deviations: {count from SUMMARYs}

  QA:         {PASS|PARTIAL|FAIL|skipped}

➜ Next Up
  /vbw:plan {N+1} -- Plan the next phase
  /vbw:qa {N} -- Verify this phase (if QA skipped)
  /vbw:ship -- Complete the milestone (if last phase)
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:
- Phase Banner (double-line box) for completion
- Execution Progress symbols: ◆ running, ✓ complete, ✗ failed, ○ skipped
- Metrics Block for stats
- Next Up Block for navigation
- No ANSI color codes
