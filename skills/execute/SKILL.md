---
name: execute
disable-model-invocation: true
description: Execute a planned phase through Agent Teams with parallel Dev teammates.
argument-hint: [phase-number] [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Build: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
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

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.

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

| Profile  | DEV_EFFORT | QA_EFFORT | PLAN_APPROVAL | QA_TIMING  |
|----------|------------|-----------|---------------|------------|
| Thorough | high       | high      | required      | per-wave   |
| Balanced | medium     | medium    | off           | per-wave   |
| Fast     | medium     | low       | off           | post-build |
| Turbo    | low        | skip      | off           | skip       |

### Step 2: Load plans and detect resume state

1. Glob for `*-PLAN.md` in the phase directory. Read each plan's YAML frontmatter (plan, title, wave, depends_on, autonomous, files_modified).
2. Check for existing SUMMARY.md files -- these plans are already complete.
3. Check `git log --oneline -20` for committed tasks matching this phase (crash recovery).
4. Build list of remaining (uncompleted) plans. If `--plan=NN`, filter to that single plan.
5. For partially-complete plans (SUMMARY.md with `status: partial`, or commits in git log but no SUMMARY.md): note the resume-from task number.
6. **Crash recovery check:** If `.vbw-planning/.execution-state.json` exists with `"status": "running"`, a previous run crashed. Update its plan statuses to match current SUMMARY.md state before proceeding.
7. **Write initial execution state** to `.vbw-planning/.execution-state.json`:

```json
{
  "phase": {N},
  "phase_name": "{slug}",
  "status": "running",
  "started_at": "{ISO 8601 timestamp}",
  "wave": 1,
  "total_waves": {max wave number from plans},
  "plans": [
    {"id": "{NN-MM}", "title": "{plan title}", "wave": {W}, "status": "pending|complete"}
  ]
}
```

Set already-completed plans (those with SUMMARY.md) to `"complete"`, all others to `"pending"`.

### Step 3: Create Agent Team and execute

Create a build team.

**Delegation directive (all effort levels except Turbo):**

You are the team LEAD, not a developer. Your role is to orchestrate, not implement.

- NEVER implement plan tasks yourself -- delegate ALL implementation to Dev teammates via TaskCreate and task assignment
- NEVER use Write or Edit to modify source code files, test files, or configuration files that are part of a plan's `files_modified` list
- Your Write/Edit usage is LIMITED to state tracking files only: `.vbw-planning/STATE.md`, `.vbw-planning/ROADMAP.md`, `.vbw-planning/.execution-state.json`, and SUMMARY.md files
- If a Dev teammate fails or gets stuck, help by providing guidance via SendMessage -- do not take over implementation
- If all Dev teammates are unavailable, create a new Dev teammate rather than implementing yourself

This is instruction-enforced (not platform-enforced). The platform cannot prevent the lead from using Write/Edit on source files. This directive exists as a defensive guardrail to maintain the separation between orchestration and implementation roles.

Note: Anthropic's `delegate` permissionMode cannot be applied here because the lead is the main session, not a spawned agent. Skill frontmatter cannot change the main session's permissionMode at runtime.

At Turbo effort, no team is created -- Dev executes directly without a lead.

For each uncompleted plan, use TaskCreate to create a task with thin context:

```
For each uncompleted plan, use TaskCreate:

TaskCreate:
  subject: "Execute {NN-MM}: {plan-title}"
  description: |
    Execute all tasks in {PLAN_PATH}.
    Effort: {DEV_EFFORT}. Working directory: {pwd}.
    {If resuming: "Resume from Task {N}. Tasks 1-{N-1} already committed."}
    {If autonomous: false: "This plan has checkpoints -- pause for user input."}
  activeForm: "Executing {NN-MM}"

After creating all tasks, wire dependencies using TaskUpdate:
  - Read the `depends_on` field from each plan's YAML frontmatter
  - For each plan with `depends_on` entries, find the task IDs of those dependency plans and wire them:
    TaskUpdate(taskId, addBlockedBy: [task IDs of plans listed in depends_on])
  - Plans with no `depends_on` (or empty list) start immediately with no blockedBy

Example for 3 plans:
  Task A (plan 04-01, depends_on: []) -- no blockedBy
  Task B (plan 04-02, depends_on: []) -- no blockedBy
  Task C (plan 04-03, depends_on: [04-01]) -- blockedBy: [Task A ID]
```

Spawn Dev teammates and assign tasks. The platform enforces execution ordering via task dependencies:
- Tasks are blockedBy their specific dependencies from the plan's `depends_on` frontmatter field
- Plans with no `depends_on` start immediately when teammates are spawned
- Plans with `depends_on` entries are held until those specific dependency tasks complete
- Teammates are spawned for all plans, but dependent teammates will idle until their tasks unblock
- Wave tracking in `.execution-state.json` is informational (for display/logging), not controlling
- If `--plan=NN`: create a single task with no dependencies (ignore dependency wiring)

**Plan approval gate (effort-gated):**
When PLAN_APPROVAL is `required` (Thorough effort only):
- Spawn Dev teammates with `plan_mode_required` set
- Each Dev enters read-only plan mode: it reads the PLAN.md, proposes its implementation approach, and waits for lead approval before writing any code
- The lead reviews each Dev's proposed approach and approves (plan_approval_response with approve: true) or rejects with feedback (approve: false with content describing what to change)
- This adds a platform-enforced review gate -- the Dev literally cannot make changes until approved

When PLAN_APPROVAL is `off` (Balanced, Fast, Turbo):
- Spawn Dev teammates without plan_mode_required
- Devs begin implementation immediately upon receiving their task (existing behavior)

**Teammate communication protocol (effort-gated):**

Instruct Dev teammates to use SendMessage for coordination based on the active effort level:

- At **Thorough** or **Balanced** effort:
  - **Blockers:** If a task is blocked by a dependency not yet available (e.g., a prior wave's output hasn't landed), message the lead with the blocker description so the lead can prioritize or reassign.
  - **Cross-cutting findings:** If implementing a task reveals something that affects another teammate's work (e.g., a shared interface changed, a dependency version conflict, a schema migration ordering issue), message the affected teammate directly.
- At **Thorough** effort only, additionally:
  - **Progress updates:** After completing each task, message the lead with a brief status update (task name, commit hash, any concerns).
  - **Design debates:** If a task's approach has architectural implications that could affect other plans, message the lead to discuss before implementing.
- At **Fast** effort: instruct teammates to report blockers only via SendMessage. No cross-cutting findings, progress updates, or design debates.
- At **Turbo** effort: no Agent Team exists, so no messaging directives apply.

Use targeted `message` (not `broadcast`) for most communication. Reserve `broadcast` only for critical blocking issues affecting all teammates (e.g., a shared dependency is broken and all work should pause).

**Update execution state at task and wave completions:**
- **Task completion:** When a teammate completes (or fails), update the plan's status in `.vbw-planning/.execution-state.json` to "complete" (or "failed").
- **Wave transition:** Wave transitions happen automatically -- when all wave N tasks complete, their wave N+1 dependents unblock. Update "wave" in the execution state JSON when you observe the first wave N+1 task starting.

Use `jq` for atomic updates, e.g.: `jq '(.plans[] | select(.id == "03-01")).status = "complete"' .vbw-planning/.execution-state.json > tmp && mv tmp .vbw-planning/.execution-state.json`

Hooks handle continuous verification:
- PostToolUse validates SUMMARY.md structure on write
- TaskCompleted verifies atomic commit exists
- TeammateIdle runs quality gate before teammate stops

### Step 4: Post-build QA (optional)

If `--skip-qa` or turbo: display "○ QA verification skipped ({reason})".

**Per-wave QA (Thorough and Balanced effort, QA_TIMING = per-wave):**

After each wave's plans complete, spawn a QA subagent concurrently with the next wave's Dev work:

```
Verify completed wave {W} plans for phase {N}. Tier: {QA tier from effort}.
Plans: {paths to completed wave's PLAN.md files}.
Summaries: {paths to completed wave's SUMMARY.md files}.
```

- QA receives only the completed plans' PLAN.md + SUMMARY.md files, not the entire phase
- QA runs concurrently with Dev teammates executing the next wave's plans
- After the final wave completes, spawn a final QA pass covering cross-wave integration:

```
Final integration verification for phase {N}. Tier: {QA tier from effort}.
Plans: {paths to ALL PLAN.md files}. Summaries: {paths to ALL SUMMARY.md files}.
Phase success criteria: {from ROADMAP.md}.
Focus on cross-plan integration, shared interfaces, and overall phase coherence.
```

Persist per-wave results to `{phase-dir}/{phase}-VERIFICATION-wave{W}.md`.
Persist final integration results to `{phase-dir}/{phase}-VERIFICATION.md`.

**Post-build QA (Fast effort, QA_TIMING = post-build):**

Spawn QA as a subagent after ALL plans complete:

```
Verify phase {N}. Tier: {QA tier from effort}.
Plans: {paths to PLAN.md files}. Summaries: {paths to SUMMARY.md files}.
Phase success criteria: {from ROADMAP.md}.
```

Persist results to `{phase-dir}/{phase}-VERIFICATION.md`.

### Step 5: Update state and present summary

**Shutdown and cleanup (all effort levels except Turbo):**

After all teammates have completed their tasks (or after all waves have finished), follow the Agent Teams Shutdown Protocol in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.

Do not proceed to state updates until TeamDelete has succeeded.

**Mark execution complete:** Update `.vbw-planning/.execution-state.json` — set `"status"` to `"complete"`. The statusline will auto-delete the file on next refresh, returning to normal display.

**Update STATE.md:** phase position, plan completion counts, effort used.
**Update ROADMAP.md:** mark completed plans.

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md`:

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

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for completion
- Execution Progress symbols: ◆ running, ✓ complete, ✗ failed, ○ skipped
- Metrics Block for stats
- Next Up Block for navigation
- No ANSI color codes
