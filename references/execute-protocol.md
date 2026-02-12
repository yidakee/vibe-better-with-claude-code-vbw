# VBW Execution Protocol

Loaded on demand by /vbw:vibe Execute mode. Not a user-facing command.

### Step 2: Load plans and detect resume state

1. Glob `*-PLAN.md` in phase dir. Read each plan's YAML frontmatter.
2. Check existing SUMMARY.md files (complete plans).
3. `git log --oneline -20` for committed tasks (crash recovery).
4. Build remaining plans list. If `--plan=NN`, filter to that plan.
5. Partially-complete plans: note resume-from task number.
6. **Crash recovery:** If `.vbw-planning/.execution-state.json` exists with `"status": "running"`, update plan statuses to match current SUMMARY.md state.
   - **V3 Event Recovery (REQ-17):** If `v3_event_recovery=true` in config, attempt event-sourced recovery first:
     `RECOVERED=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/recover-state.sh {phase} 2>/dev/null || echo "{}")`
     If non-empty and has `plans` array, use recovered state as the baseline instead of the stale execution-state.json. This provides more accurate status when execution-state.json was not written (crash before flush).
7. **Write execution state** to `.vbw-planning/.execution-state.json`:
```json
{
  "phase": N, "phase_name": "{slug}", "status": "running",
  "started_at": "{ISO 8601}", "wave": 1, "total_waves": N,
  "plans": [{"id": "NN-MM", "title": "...", "wave": W, "status": "pending|complete"}]
}
```
Set completed plans (with SUMMARY.md) to `"complete"`, others to `"pending"`.

8. **V3 Event Log (REQ-16):** If `v3_event_log=true` in config:
   - Log phase start: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh phase_start {phase} 2>/dev/null || true`

9. **V3 Snapshot Resume (REQ-18):** If `v3_snapshot_resume=true` in config:
   - On crash recovery (execution-state.json exists with `"status": "running"`): attempt restore:
     `SNAPSHOT=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-resume.sh restore {phase} 2>/dev/null || echo "")`
   - If snapshot found, log: `✓ Snapshot found: ${SNAPSHOT}` — use snapshot's `recent_commits` to cross-reference git log for more reliable resume-from detection.

10. **V3 Schema Validation (REQ-17):** If `v3_schema_validation=true` in config:
   - Validate each PLAN.md frontmatter before execution:
     `VALID=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-schema.sh plan {plan_path} 2>/dev/null || echo "valid")`
   - If `invalid`: log warning `⚠ Plan {NN-MM} schema: ${VALID}` — continue execution (advisory only).
   - Log to metrics: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh schema_check {phase} {plan} result=$VALID 2>/dev/null || true`

11. **Cross-phase deps (PWR-04):** For each plan with `cross_phase_deps`:
   - Verify referenced plan's SUMMARY.md exists with `status: complete`
   - If artifact path specified, verify file exists
   - Unsatisfied → STOP: "Cross-phase dependency not met. Plan {id} depends on Phase {P}, Plan {plan} ({reason}). Status: {failed|missing|not built}. Fix: Run /vbw:vibe {P}"
   - All satisfied: `✓ Cross-phase dependencies verified`
   - No cross_phase_deps: skip silently

### Step 3: Create Agent Team and execute

**V3 Smart Routing (REQ-15):** If `v3_smart_routing=true` in config:
- Before creating agent teams, assess each plan:
  ```bash
  RISK=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess-plan-risk.sh {plan_path} 2>/dev/null || echo "medium")
  TASK_COUNT=$(grep -c '^### Task [0-9]' {plan_path} 2>/dev/null || echo "0")
  ```
- If `RISK=low` AND `TASK_COUNT<=3` AND effort is not `thorough`: force turbo execution for this plan (no team, direct implementation). Log routing decision:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh smart_route {phase} {plan} risk=$RISK tasks=$TASK_COUNT routed=turbo 2>/dev/null || true`
- Otherwise: proceed with normal team delegation. Log:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh smart_route {phase} {plan} risk=$RISK tasks=$TASK_COUNT routed=team 2>/dev/null || true`
- On script error: fall back to configured effort level.

**Delegation directive (all except Turbo):**
You are the team LEAD. NEVER implement tasks yourself.
- Delegate ALL implementation to Dev teammates via TaskCreate
- NEVER Write/Edit files in a plan's `files_modified` — only state files: STATE.md, ROADMAP.md, .execution-state.json, SUMMARY.md
- If Dev fails: guidance via SendMessage, not takeover. If all Devs unavailable: create new Dev.
- At Turbo (or smart-routed to turbo): no team — Dev executes directly.

**V3 Monorepo Routing (REQ-17):** If `v3_monorepo_routing=true` in config:
- Before context compilation, detect relevant package paths:
  `PACKAGES=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/route-monorepo.sh {phase_dir} 2>/dev/null || echo "[]")`
- If non-empty array (not `[]`): pass package paths to context compilation for scoped file inclusion.
  Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh monorepo_route {phase} packages=$PACKAGES 2>/dev/null || true`
- If empty or error: proceed with default (full repo) context compilation.

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

**V3 Validation Gates (REQ-13, REQ-14):** If `v3_validation_gates=true` in config:
- **Per plan:** Assess risk and resolve gate policy:
  ```bash
  RISK=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/assess-plan-risk.sh {plan_path} 2>/dev/null || echo "medium")
  GATE_POLICY=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-gate-policy.sh {effort} $RISK {autonomy} 2>/dev/null || echo '{}')
  ```
- Extract policy fields: `qa_tier`, `approval_required`, `communication_level`, `two_phase`
- Use these to override the static tables below for this plan
- Log to metrics: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh gate_policy {phase} {plan} risk=$RISK qa_tier=$QA_TIER approval=$APPROVAL 2>/dev/null || true`
- On script error: fall back to static tables below

**Plan approval gate (effort-gated, autonomy-gated):**
When `v3_validation_gates=true`: use `approval_required` from gate policy above.
When `v3_validation_gates=false` (default): use static table:

| Autonomy | Approval active at |
|----------|-------------------|
| cautious | Thorough + Balanced |
| standard | Thorough only |
| confident/pure-vibe | OFF |

When active: spawn Devs with `plan_mode_required`. Dev reads PLAN.md, proposes approach, waits for lead approval. Lead approves/rejects via plan_approval_response.
When off: Devs begin immediately.

**Teammate communication (effort-gated):**
When `v3_validation_gates=true`: use `communication_level` from gate policy (none/blockers/blockers_findings/full).
When `v3_validation_gates=false` (default): use static table:

Schema ref: `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`

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

**V3 Event Log — plan lifecycle (REQ-16):** If `v3_event_log=true` in config:
- At plan start: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh plan_start {phase} {plan} 2>/dev/null || true`
- At agent spawn: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh agent_spawn {phase} {plan} role=dev model=$DEV_MODEL 2>/dev/null || true`
- At agent shutdown: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh agent_shutdown {phase} {plan} role=dev 2>/dev/null || true`
- At plan complete: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh plan_end {phase} {plan} status=complete 2>/dev/null || true`
- At plan failure: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh plan_end {phase} {plan} status=failed 2>/dev/null || true`
- On error: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh error {phase} {plan} message={error_summary} 2>/dev/null || true`

**V3 Snapshot — per-plan checkpoint (REQ-18):** If `v3_snapshot_resume=true` in config:
- After each plan completes (SUMMARY.md verified):
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/snapshot-resume.sh save {phase} 2>/dev/null || true`
- This captures execution state + recent git context for crash recovery.

**V3 Metrics instrumentation (REQ-09):** If `v3_metrics=true` in config:
- At phase start: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_phase_start {phase} plan_count={N} effort={effort}`
- At each plan completion: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_plan_complete {phase} {plan} task_count={N} commit_count={N}`
- At phase end: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-metrics.sh execute_phase_complete {phase} plans_completed={N} total_tasks={N} total_commits={N} deviations={N}`
All metrics calls should be `2>/dev/null || true` — never block execution.

**V3 Contract-Lite (REQ-10):** If `v3_contract_lite=true` in config:
- **Once per plan (before first task):** Generate contract sidecar:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-contract.sh {plan_path} 2>/dev/null || true`
  This produces `.vbw-planning/.contracts/{phase}-{plan}.json` with allowed_paths and must_haves.
- **Before each task:** Validate task start:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-contract.sh start {contract_path} {task_number} 2>/dev/null || true`
- **After each task:** Validate modified files against contract:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-contract.sh end {contract_path} {task_number} {modified_files...} 2>/dev/null || true`
  Where `{modified_files}` comes from `git diff --name-only HEAD~1` after the task's commit.
- Violations are advisory only (logged to metrics, not blocking).

**V2 Hard Gates (REQ-02, REQ-03):** If `v2_hard_gates=true` in config:
- **Pre-task gate sequence (before each task starts):**
  1. `contract_compliance` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh contract_compliance {phase} {plan} {task} {contract_path}`
  2. `protected_file` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh protected_file {phase} {plan} {task} {contract_path}`
  - If any gate fails (exit 2): attempt auto-repair:
    `REPAIR=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-repair.sh {gate_type} {phase} {plan} {task} {contract_path})`
  - If `repaired=true`: re-run the failed gate to confirm, then proceed.
  - If `repaired=false`: emit blocker, halt task execution. Send Lead a message with the failure evidence and next action from the blocker event.
- **Post-task gate sequence (after each task commit):**
  1. `required_checks` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh required_checks {phase} {plan} {task} {contract_path}`
  2. `commit_hygiene` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh commit_hygiene {phase} {plan} {task} {contract_path}`
  - Gate failures trigger auto-repair with same flow as pre-task.
- **Post-plan gate (after all tasks complete, before marking plan done):**
  1. `artifact_persistence` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh artifact_persistence {phase} {plan} {task} {contract_path}`
  2. `verification_threshold` gate: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hard-gate.sh verification_threshold {phase} {plan} {task} {contract_path}`
  - These gates fire AFTER SUMMARY.md verification but BEFORE updating execution-state.json to "complete".
- **YOLO mode:** Hard gates ALWAYS fire regardless of autonomy level. YOLO only skips confirmation prompts.
- **Fallback:** If hard-gate.sh or auto-repair.sh errors (not a gate fail, but a script error), log to metrics and continue (fail-open on script errors, hard-stop only on gate verdicts).

**V3 Lock-Lite (REQ-11):** If `v3_lock_lite=true` in config:
- **Before each task:** Acquire lock with claimed files:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lock-lite.sh acquire {task_id} {claimed_files...} 2>/dev/null || true`
  Where `{task_id}` is `{phase}-{plan}-T{N}` and `{claimed_files}` from the task's **Files:** list.
- **After each task (or on failure):** Release lock:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lock-lite.sh release {task_id} 2>/dev/null || true`
- Conflicts are advisory only (logged to metrics, not blocking).
- Lock cleanup: at phase end, `rm -f .vbw-planning/.locks/*.lock 2>/dev/null || true`.

**V3 Lease Locks (REQ-17):** If `v3_lease_locks=true` in config:
- Use `lease-lock.sh` instead of `lock-lite.sh` for all lock operations above:
  - Acquire: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lease-lock.sh acquire {task_id} --ttl=300 {claimed_files...} 2>/dev/null || true`
  - Release: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lease-lock.sh release {task_id} 2>/dev/null || true`
- **During long-running tasks** (>2 minutes estimated): renew lease periodically:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lease-lock.sh renew {task_id} 2>/dev/null || true`
- Check for expired leases before acquiring: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lease-lock.sh check {task_id} {claimed_files...} 2>/dev/null || true`
- If both `v3_lease_locks` and `v3_lock_lite` are true, lease-lock takes precedence.

### Step 3b: SUMMARY.md verification gate (mandatory)

**This is a hard gate. Do NOT proceed to QA or mark a plan as complete in .execution-state.json without verifying its SUMMARY.md.**

When a Dev teammate reports plan completion (task marked completed):
1. **Check:** Verify `{phase_dir}/{plan_id}-SUMMARY.md` exists and contains commit hashes, task statuses, and files modified.
2. **If missing or incomplete:** Send the Dev a message: "Write {plan_id}-SUMMARY.md using the template at templates/SUMMARY.md. Include commit hashes, tasks completed, files modified, and any deviations." Wait for confirmation before proceeding.
3. **If Dev is unavailable:** Write it yourself from `git log --oneline` and the PLAN.md.
4. **V3 Schema Validation — SUMMARY.md (REQ-17):** If `v3_schema_validation=true` in config:
   - Validate SUMMARY.md frontmatter: `VALID=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-schema.sh summary {summary_path} 2>/dev/null || echo "valid")`
   - If `invalid`: log warning `⚠ Summary {plan_id} schema: ${VALID}` — advisory only.
5. **Only after SUMMARY.md is verified:** Update plan status to `"complete"` in .execution-state.json and proceed.

### Step 4: Post-build QA (optional)

If `--skip-qa` or turbo: "○ QA verification skipped ({reason})"

**Tier resolution:** When `v3_validation_gates=true`: use `qa_tier` from gate policy resolved in Step 3.
When `v3_validation_gates=false` (default): map effort to tier: turbo=skip (already handled), fast=quick, balanced=standard, thorough=deep. Override: if >15 requirements or last phase before ship, force Deep.

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

**V3 Event Log — phase end (REQ-16):** If `v3_event_log=true` in config:
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/log-event.sh phase_end {phase} plans_completed={N} total_tasks={N} 2>/dev/null || true`

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
