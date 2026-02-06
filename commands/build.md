---
description: Execute a planned phase through Dev agents with wave grouping, parallel execution, and optional QA verification.
argument-hint: <phase-number> [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Build: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No state found"`
```

Current effort setting:
```
!`cat .planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directory contents:
```
!`ls .planning/phases/ 2>/dev/null || echo "No phases directory"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **Missing phase number:** If $ARGUMENTS doesn't include a phase number (integer), STOP: "Usage: /vbw:build <phase-number> [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]"
3. **Phase not planned:** If no PLAN.md files exist in .planning/phases/{phase-dir}/, STOP: "Phase {N} has no plans. Run /vbw:plan {N} first."
4. **Phase already complete:** If ALL PLAN.md files have corresponding SUMMARY.md files, WARN: "Phase {N} already has completed plans. Re-running will create new commits. Continue?" The user can respond or cancel.

## Steps

### Step 1: Parse arguments

Extract arguments from $ARGUMENTS:

- **Phase number** (required): integer identifying which phase to build (e.g., `3` matches `.planning/phases/03-*`)
- **--effort** (optional): one of `thorough`, `balanced`, `fast`, `turbo`. Overrides the default from `.planning/config.json` for this invocation only. Does not modify the stored default.
- **--skip-qa** (optional): if present, skip the QA verification step after all plans complete
- **--plan=NN** (optional): execute only the specified plan number instead of the full phase. Ignores wave grouping -- just runs that one plan.

Map the active effort profile to agent effort levels using `${CLAUDE_PLUGIN_ROOT}/references/effort-profiles.md`:

| Profile  | Dev    | QA     |
|----------|--------|--------|
| Thorough | high   | high   |
| Balanced | medium | medium |
| Fast     | medium | low    |
| Turbo    | low    | skip   |

Store `DEV_EFFORT` and `QA_EFFORT` for use in agent spawning.

### Step 2: Load and analyze plans

Read all PLAN.md files in `.planning/phases/{phase-dir}/`:

1. Use Glob to find files matching `.planning/phases/{phase-dir}/*-PLAN.md`
2. For each PLAN.md, read the YAML frontmatter and extract:
   - `plan`: plan number
   - `title`: plan title
   - `wave`: wave number (determines execution order group)
   - `depends_on`: list of plan numbers this plan requires to complete first
   - `autonomous`: true or false (whether the plan has checkpoints)
   - `files_modified`: list of files this plan will create or modify
3. Build wave groups: group plans by their `wave` field value
4. Identify already-completed plans: check for corresponding SUMMARY.md files (e.g., `03-01-SUMMARY.md` for `03-01-PLAN.md`)
5. If `--plan=NN` was specified: filter to only that plan, ignore wave grouping

### Step 3: Validate execution order

Before executing, verify the plan dependency graph is sound:

1. **No circular dependencies:** Walk the `depends_on` chains for each plan. If a cycle is detected (plan A depends on B which depends on A), report: "Circular dependency detected: {chain}. Fix the PLAN.md depends_on fields." STOP.
2. **Valid references:** Every entry in `depends_on` must reference a plan number that exists in this phase. If a reference is invalid, report: "Plan {N} depends on plan {M} which does not exist." STOP.
3. **No file conflicts within a wave:** For each wave group, collect all `files_modified` lists. If any two plans in the same wave modify the same file, report: "File conflict in wave {W}: {file} is modified by both plan {A} and plan {B}. Move one to a different wave." STOP.

If all validation passes, proceed to execution.

### Step 4: Execute waves sequentially

Execute each wave in numeric order. Within a wave, all plans run in parallel.

**For each wave** (sorted by wave number ascending):

Display wave banner using single-line box:

```
┌──────────────────────────────────────────┐
│  Wave {N}: {count} plan(s)               │
│  {plan-01-title}, {plan-02-title}, ...   │
└──────────────────────────────────────────┘
```

**For each plan in the wave:**

1. **Skip if already complete:** If a SUMMARY.md exists for this plan, display "✓ Plan {NN}: {title} -- already complete (skipping)" and move to the next plan. This provides resume support.

2. **Note checkpoint plans:** If the plan has `autonomous: false`, display: "⚠ Plan {NN} has checkpoints -- will pause for user input during execution."

3. **Spawn a Dev agent** using the Task tool spawning protocol:
   a. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-dev.md` using the Read tool
   b. Extract the body content (everything after the closing `---` of the YAML frontmatter)
   c. Use the **Task tool** to spawn the subagent:
      - `prompt`: The extracted body content of vbw-dev.md (this becomes the subagent's system prompt)
      - `description`: Include the following in the task description:
        - The full path to the PLAN.md file to execute
        - Instruction: "Execute all tasks in this plan sequentially. Create one atomic commit per task. Produce a SUMMARY.md when complete."
        - The effort level for this Dev agent: "Effort level: {DEV_EFFORT}"
        - The working directory path

**Parallel execution within a wave:** Spawn ALL Dev agents for a wave's plans using multiple Task tool calls in the SAME message. This executes them in parallel. Wait for all to complete before advancing to the next wave.

**After each plan completes:**

1. Verify the Dev agent created a SUMMARY.md file for the plan
2. Read the SUMMARY.md frontmatter to check the `status` field:
   - `complete`: Display "✓ Plan {NN}: {title} -- complete"
   - `partial`: Display "⚠ Plan {NN}: {title} -- partial (some tasks incomplete)"
   - `failed`: Display "✗ Plan {NN}: {title} -- failed"
3. If status is "failed" or "partial": Report the issue to the user and ask: "Continue to next wave, or stop here?"
4. Collect metrics from SUMMARY.md: deviations count, duration

### Step 5: Post-execution QA verification (optional)

After all waves complete (or the single plan completes if `--plan=NN` was used):

**If `--skip-qa` is NOT set AND effort is NOT turbo (turbo skips QA per EFRT-04):**

1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-qa.md` using the Read tool
2. Extract the body content (everything after the closing `---` of the YAML frontmatter)
3. Use the **Task tool** to spawn the QA agent:
   - `prompt`: The extracted body content of vbw-qa.md
   - `description`: Include:
     - Instruction: "Verify the completed work for phase {N} against its success criteria."
     - Paths to all PLAN.md files in this phase
     - Paths to all SUMMARY.md files produced
     - The phase section from ROADMAP.md (success criteria)
     - Effort level: "QA effort: {QA_EFFORT}"
4. QA returns structured text findings. Persist these to:
   `.planning/phases/{phase-dir}/{phase}-VERIFICATION.md`
   using the Write tool.

**If `--skip-qa` IS set or effort is turbo:**
Display: "○ QA verification skipped" (with reason: --skip-qa flag or turbo mode)

### Step 6: Update state and present summary

**Update .planning/STATE.md:**
- Current position: Phase {N} complete (or "partially complete" if some plans failed)
- Plan count: completed plans / total plans
- Log the effort profile used
- Update progress bar

**Update .planning/ROADMAP.md:**
- Check off completed plan entries in the phase's plan list (if the roadmap uses checkboxes or status markers)

**Display completion summary** using double-line box (vbw-brand.md phase-level formatting):

```
╔═══════════════════════════════════════════════╗
║  Phase {N}: {name} -- Built                   ║
║  (or "Partially Built" if some plans failed)  ║
╚═══════════════════════════════════════════════╝

  Plan Results:
    ✓ Plan 01: {title}
    ✓ Plan 02: {title}
    ✗ Plan 03: {title} (failed)

  Metrics:
    Plans:      {completed}/{total}
    Effort:     {profile}
    Deviations: {total collected from SUMMARY.md files}

  QA Verification:
    {PASS | PARTIAL | FAIL | skipped}
    Checks: {passed}/{total}

  ➜ Next Up:
    {Suggest next action based on context:}
    - If more phases remain: "/vbw:plan {N+1} to plan the next phase"
    - If QA was skipped: "/vbw:qa {N} to verify this phase"
    - If this was the last phase: "/vbw:ship to complete the milestone"
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Double-line box for phase-level completion banner
- Single-line box for wave banners
- ✓ for completed plans, ✗ for failed plans, ○ for skipped steps
- ⚠ for warnings (checkpoint plans, partial completions)
- ◆ for currently executing plans
- ➜ for Next Up navigation
- No ANSI color codes
