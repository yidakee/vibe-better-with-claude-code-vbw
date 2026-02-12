# VBW Execution Protocol

Loaded on demand by /vbw:vibe Execute mode. Not a user-facing command.

### Step 2: Load plans and detect resume state

1. Glob `*-PLAN.md` in phase dir. Read each plan's YAML frontmatter.
2. Check existing SUMMARY.md files (complete plans).
3. `git log --oneline -20` for committed tasks (crash recovery).
4. Build remaining plans list. If `--plan=NN`, filter to that plan.
5. Partially-complete plans: note resume-from task number.
6. **Crash recovery:** If `.vbw-planning/.execution-state.json` exists with `"status": "running"`, update plan statuses to match current SUMMARY.md state.
7. **Write execution state** to `.vbw-planning/.execution-state.json`:
```json
{
  "phase": N, "phase_name": "{slug}", "status": "running",
  "started_at": "{ISO 8601}", "wave": 1, "total_waves": N,
  "plans": [{"id": "NN-MM", "title": "...", "wave": W, "status": "pending|complete"}]
}
```
Set completed plans (with SUMMARY.md) to `"complete"`, others to `"pending"`.

8. **Cross-phase deps (PWR-04):** For each plan with `cross_phase_deps`:
   - Verify referenced plan's SUMMARY.md exists with `status: complete`
   - If artifact path specified, verify file exists
   - Unsatisfied → STOP: "Cross-phase dependency not met. Plan {id} depends on Phase {P}, Plan {plan} ({reason}). Status: {failed|missing|not built}. Fix: Run /vbw:vibe {P}"
   - All satisfied: `✓ Cross-phase dependencies verified`
   - No cross_phase_deps: skip silently

### Step 3: Create Agent Team and execute

**Delegation directive (all except Turbo):**
You are the team LEAD. NEVER implement tasks yourself.
- Delegate ALL implementation to Dev teammates via TaskCreate
- NEVER Write/Edit files in a plan's `files_modified` — only state files: STATE.md, ROADMAP.md, .execution-state.json, SUMMARY.md
- If Dev fails: guidance via SendMessage, not takeover. If all Devs unavailable: create new Dev.
- At Turbo: no team — Dev executes directly.

**Context compilation (REQ-11):** If `config_context_compiler=true` from Context block above, before creating Dev tasks run:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} dev {phases_dir} {plan_path}`
This produces `{phase-dir}/.context-dev.md` with phase goal and conventions.
The plan_path argument enables skill bundling: compile-context.sh reads skills_used from the plan's frontmatter and bundles referenced SKILL.md content into .context-dev.md. If the plan has no skills_used, this is a no-op.
If compilation fails, proceed without it — Dev reads files directly.

**Model resolution:** Resolve models for Dev and QA agents:
```bash
DEV_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh dev .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
if [ $? -ne 0 ]; then echo "$DEV_MODEL" >&2; exit 1; fi

QA_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh qa .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
if [ $? -ne 0 ]; then echo "$QA_MODEL" >&2; exit 1; fi
```

For each uncompleted plan, TaskCreate:
```
subject: "Execute {NN-MM}: {plan-title}"
description: |
  Execute all tasks in {PLAN_PATH}.
  Effort: {DEV_EFFORT}. Working directory: {pwd}.
  Model: ${DEV_MODEL}
  Phase context: {phase-dir}/.context-dev.md (if compiled)
  {If resuming: "Resume from Task {N}. Tasks 1-{N-1} already committed."}
  {If autonomous: false: "This plan has checkpoints -- pause for user input."}
activeForm: "Executing {NN-MM}"
```

Display: `◆ Spawning Dev teammate (${DEV_MODEL})...`

**CRITICAL:** Pass `model: "${DEV_MODEL}"` parameter to the Task tool invocation when spawning Dev teammates.

Wire dependencies via TaskUpdate: read `depends_on` from each plan's frontmatter, add `addBlockedBy: [task IDs of dependency plans]`. Plans with empty depends_on start immediately.

Spawn Dev teammates and assign tasks. Platform enforces execution ordering via task deps. If `--plan=NN`: single task, no dependencies.

**Blocked agent notification (mandatory):** When a Dev teammate completes a plan (task marked completed + SUMMARY.md verified), check if any other tasks have `blockedBy` containing that completed task's ID. For each newly-unblocked task, send its assigned Dev a message: "Blocking task {id} complete. Your task is now unblocked — proceed with execution." This ensures blocked agents resume without manual intervention.

**Plan approval gate (effort-gated, autonomy-gated):**

| Autonomy | Approval active at |
|----------|-------------------|
| cautious | Thorough + Balanced |
| standard | Thorough only |
| confident/pure-vibe | OFF |

When active: spawn Devs with `plan_mode_required`. Dev reads PLAN.md, proposes approach, waits for lead approval. Lead approves/rejects via plan_approval_response.
When off: Devs begin immediately.

**Teammate communication (effort-gated):** Schema ref: `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`

| Effort | Messages sent |
|--------|--------------|
| Thorough | blockers (dev_blocker), cross-cutting findings, progress (dev_progress), design debates to lead |
| Balanced | blockers (dev_blocker), cross-cutting findings |
| Fast | blockers only (dev_blocker) |
| Turbo | N/A (no team) |

Use targeted `message` not `broadcast`. Reserve broadcast for critical blocking issues only.

**Execution state updates:**
- Task completion: update plan status in .execution-state.json (`"complete"` or `"failed"`)
- Wave transition: update `"wave"` when first wave N+1 task starts
- Use `jq` for atomic updates

Hooks handle continuous verification: PostToolUse validates SUMMARY.md, TaskCompleted verifies commits, TeammateIdle runs quality gate.

**V3 Metrics instrumentation (REQ-09):** If `v3_metrics=true` in config:
- At phase start: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_phase_start {phase} plan_count={N} effort={effort}`
- At each plan completion: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_plan_complete {phase} {plan} task_count={N} commit_count={N}`
- At phase end: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_phase_complete {phase} plans_completed={N} total_tasks={N} total_commits={N} deviations={N}`
All metrics calls should be `2>/dev/null || true` — never block execution.

### Step 3b: SUMMARY.md verification gate (mandatory)

**This is a hard gate. Do NOT proceed to QA or mark a plan as complete in .execution-state.json without verifying its SUMMARY.md.**

When a Dev teammate reports plan completion (task marked completed):
1. **Check:** Verify `{phase_dir}/{plan_id}-SUMMARY.md` exists and contains commit hashes, task statuses, and files modified.
2. **If missing or incomplete:** Send the Dev a message: "Write {plan_id}-SUMMARY.md using the template at templates/SUMMARY.md. Include commit hashes, tasks completed, files modified, and any deviations." Wait for confirmation before proceeding.
3. **If Dev is unavailable:** Write it yourself from `git log --oneline` and the PLAN.md.
4. **Only after SUMMARY.md is verified:** Update plan status to `"complete"` in .execution-state.json and proceed.

### Step 4: Post-build QA (optional)

If `--skip-qa` or turbo: "○ QA verification skipped ({reason})"

**Tier resolution:** Map effort to tier: turbo=skip (already handled), fast=quick, balanced=standard, thorough=deep. Override: if >15 requirements or last phase before ship, force Deep.

**Context compilation:** If `config_context_compiler=true`, before spawning QA run:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} qa {phases_dir}`
This produces `{phase-dir}/.context-qa.md` with phase goal, success criteria, requirements to verify, and conventions.
If compilation fails, proceed without it.

Display: `◆ Spawning QA agent (${QA_MODEL})...`

**Per-wave QA (Thorough/Balanced, QA_TIMING=per-wave):** After each wave completes, spawn QA concurrently with next wave's Dev work. QA receives only completed wave's PLAN.md + SUMMARY.md + "Phase context: {phase-dir}/.context-qa.md (if compiled). Model: ${QA_MODEL}. Your verification tier is {tier}. Run {5-10|15-25|30+} checks per the tier definitions in your agent protocol." After final wave, spawn integration QA covering all plans + cross-plan integration. Persist to `{phase-dir}/{phase}-VERIFICATION-wave{W}.md` and `{phase}-VERIFICATION.md`.

**Post-build QA (Fast, QA_TIMING=post-build):** Spawn QA after ALL plans complete. Include in task description: "Phase context: {phase-dir}/.context-qa.md (if compiled). Model: ${QA_MODEL}. Your verification tier is {tier}. Run {5-10|15-25|30+} checks per the tier definitions in your agent protocol." Persist to `{phase-dir}/{phase}-VERIFICATION.md`.

**CRITICAL:** Pass `model: "${QA_MODEL}"` parameter to the Task tool invocation when spawning QA agents.

### Step 5: Update state and present summary

**Shutdown:** Send shutdown to each teammate, wait for approval, re-request if rejected, then TeamDelete. Wait for TeamDelete before state updates.

**Mark complete:** Set .execution-state.json `"status"` to `"complete"` (statusline auto-deletes on next refresh).
**Update STATE.md:** phase position, plan completion counts, effort used.
**Update ROADMAP.md:** mark completed plans.

Display per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
```
╔═══════════════════════════════════════════════╗
║  Phase {N}: {name} -- Built                   ║
╚═══════════════════════════════════════════════╝

  Plan Results:
    ✓ Plan 01: {title}  /  ✗ Plan 03: {title} (failed)

  Metrics:
    Plans: {completed}/{total}  Effort: {profile}  Model Profile: {profile}  Deviations: {count}

  QA: {PASS|PARTIAL|FAIL|skipped}
```

**"What happened" (NRW-02):** If config `plain_summary` is true (default), append 2-4 plain-English sentences between QA and Next Up. No jargon. Source from SUMMARY.md files + QA result. If false, skip.

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh execute {qa-result}` and display output.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), ◆ running, ✓ complete, ✗ failed, ○ skipped, Metrics Block, Next Up Block, no ANSI color codes.
