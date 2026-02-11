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

Config: Pre-injected by SessionStart hook (effort, autonomy, verification_tier). Override with --effort flag.

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

Phase state:
```
!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/phase-detect.sh 2>/dev/null || echo "phase_detect_error=true"`
```

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **Auto-detect phase (if omitted):** If no integer phase in $ARGUMENTS:
   - Phase detection is pre-computed in Context above. Use `next_phase`, `next_phase_slug`, and `next_phase_state` directly.
   - First phase where `next_phase_state` is `needs_execute` is the target.
   - Found: "Auto-detected Phase {N} ({slug}) -- planned, not yet built"
   - All built: STOP "All planned phases are built. Specify a phase to rebuild: `/vbw:execute N`"
3. **Phase not planned:** No PLAN.md in phase dir → STOP: "Phase {N} has no plans. Run /vbw:plan {N} first."
4. **Phase already complete:** All plans have SUMMARY.md:
   - cautious/standard autonomy: WARN + ask "Re-running creates new commits. Continue?"
   - confident/pure-vibe: warn but auto-continue

## Steps

### Step 1: Parse arguments

- **Phase number** (optional; auto-detected): integer matching `.vbw-planning/phases/{NN}-*`
- **--effort** (optional): thorough|balanced|fast|turbo — overrides config for this run
- **--skip-qa** (optional): skip post-build verification
- **--plan=NN** (optional): execute single plan, ignore wave grouping

Effort → agent levels:

| Profile | DEV_EFFORT | QA_EFFORT | PLAN_APPROVAL | QA_TIMING |
|---------|-----------|-----------|---------------|-----------|
| Thorough | high | high | required | per-wave |
| Balanced | medium | medium | off | per-wave |
| Fast | medium | low | off | post-build |
| Turbo | low | skip | off | skip |

Read active profile only: `${CLAUDE_PLUGIN_ROOT}/references/effort-profile-{profile}.md`

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
   - Unsatisfied → STOP: "Cross-phase dependency not met. Plan {id} depends on Phase {P}, Plan {plan} ({reason}). Status: {failed|missing|not built}. Fix: Run /vbw:implement {P}"
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
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} dev {phases_dir}`
This produces `{phase-dir}/.context-dev.md` with phase goal and conventions.
If compilation fails, proceed without it — Dev reads files directly.

For each uncompleted plan, TaskCreate:
```
subject: "Execute {NN-MM}: {plan-title}"
description: |
  Execute all tasks in {PLAN_PATH}.
  Effort: {DEV_EFFORT}. Working directory: {pwd}.
  Phase context: {phase-dir}/.context-dev.md (if compiled)
  {If resuming: "Resume from Task {N}. Tasks 1-{N-1} already committed."}
  {If autonomous: false: "This plan has checkpoints -- pause for user input."}
activeForm: "Executing {NN-MM}"
```

Wire dependencies via TaskUpdate: read `depends_on` from each plan's frontmatter, add `addBlockedBy: [task IDs of dependency plans]`. Plans with empty depends_on start immediately.

Spawn Dev teammates and assign tasks. Platform enforces execution ordering via task deps. If `--plan=NN`: single task, no dependencies.

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

### Step 4: Post-build QA (optional)

If `--skip-qa` or turbo: "○ QA verification skipped ({reason})"

**Tier resolution:** Map effort to tier: turbo=skip (already handled), fast=quick, balanced=standard, thorough=deep. Override: if >15 requirements or last phase before ship, force Deep.

**Context compilation:** If `config_context_compiler=true`, before spawning QA run:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} qa {phases_dir}`
This produces `{phase-dir}/.context-qa.md` with phase goal, success criteria, requirements to verify, and conventions.
If compilation fails, proceed without it.

**Per-wave QA (Thorough/Balanced, QA_TIMING=per-wave):** After each wave completes, spawn QA concurrently with next wave's Dev work. QA receives only completed wave's PLAN.md + SUMMARY.md + "Phase context: {phase-dir}/.context-qa.md (if compiled). Your verification tier is {tier}. Run {5-10|15-25|30+} checks per the tier definitions in your agent protocol." After final wave, spawn integration QA covering all plans + cross-plan integration. Persist to `{phase-dir}/{phase}-VERIFICATION-wave{W}.md` and `{phase}-VERIFICATION.md`.

**Post-build QA (Fast, QA_TIMING=post-build):** Spawn QA after ALL plans complete. Include in task description: "Phase context: {phase-dir}/.context-qa.md (if compiled). Your verification tier is {tier}. Run {5-10|15-25|30+} checks per the tier definitions in your agent protocol." Persist to `{phase-dir}/{phase}-VERIFICATION.md`.

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
    Plans: {completed}/{total}  Effort: {profile}  Deviations: {count}

  QA: {PASS|PARTIAL|FAIL|skipped}
```

**"What happened" (NRW-02):** If config `plain_summary` is true (default), append 2-4 plain-English sentences between QA and Next Up. No jargon. Source from SUMMARY.md files + QA result. If false, skip.

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh execute {qa-result}` and display output.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), ◆ running, ✓ complete, ✗ failed, ○ skipped, Metrics Block, Next Up Block, no ANSI color codes.
