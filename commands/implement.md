---
name: implement
description: "The one command. Detects project state and routes to bootstrap, scoping, planning, execution, or completion."
argument-hint: "[phase-number] [--effort turbo|fast|balanced|thorough] [--skip-qa]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
disable-model-invocation: true
---

# VBW Implement: $ARGUMENTS

## Context

Working directory: `!`pwd``

Pre-computed state (via phase-detect.sh):
```
!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/phase-detect.sh 2>/dev/null || echo "phase_detect_error=true"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

## State Detection

Evaluate project state using the phase-detect.sh output keys. The FIRST matching condition determines the route.

| # | Condition (from phase-detect.sh output) | Route |
|---|----------------------------------------|-------|
| 1 | `planning_dir_exists=false` | Run /vbw:init first (preserve existing guard) |
| 2 | `project_exists=false` | State 1: Bootstrap |
| 3 | `phase_count=0` | State 2: Scoping |
| 4 | `next_phase_state=needs_plan_and_execute` or `next_phase_state=needs_execute` | State 3-4: Plan + Execute (use `next_phase` and `next_phase_slug` for target phase) |
| 5 | `next_phase_state=all_done` | State 5: Completion |

The phases directory is already resolved by phase-detect.sh (see `phases_dir` and `active_milestone` keys). No manual directory resolution needed.

## State 1: Bootstrap (No Project Defined)

> Triggered when `.vbw-planning/PROJECT.md` does not exist or contains template placeholder.

### Critical Rules

**NEVER FABRICATE CONTENT.** These rules are non-negotiable:

1. **Only use what the user explicitly states.** Do not infer, embellish, or generate requirements, phases, or roadmap content that the user did not articulate.
2. **If the user's answer does not match the question, STOP.** Acknowledge their request, explain that bootstrap is paused, and handle what they actually asked for.
3. **No silent assumptions.** If the user's answers leave gaps, ask a follow-up question. Do not fill gaps with your own assumptions.
4. **Phases come from the user, not from you.** Propose phases based strictly on the requirements the user provided.
5. **Write files directly after gathering answers.** Do NOT prompt for per-file confirmation.

### Constraints

**Do NOT explore or scan the codebase.** Codebase analysis is `/vbw:map`'s job. If a codebase map exists at `.vbw-planning/codebase/`, use it. Do not go looking for more.

### Brownfield Detection

Check if the project already has source files:
- **Git repo:** Run `git ls-files --error-unmatch . 2>/dev/null | head -5`. If it returns any files, BROWNFIELD=true.
- **No git / not initialized:** Use Glob to check for any files (`**/*.*`) excluding `.vbw-planning/`, `.claude/`, `node_modules/`, and `.git/`. If matches exist, BROWNFIELD=true.

### Bootstrap Steps

**Step B1: Fill PROJECT.md**

If $ARGUMENTS provided (excluding flags), use as project description. Otherwise ask:
- "What is the name of your project?"
- "Describe your project's core purpose in 1-2 sentences."

Write PROJECT.md immediately.

**Step B2: Gather requirements**

Ask 3-5 focused questions:
1. Must-have features for first release?
2. Primary users/audience?
3. Technical constraints (language, framework, hosting)?
4. Integrations or external services?
5. What is out of scope?

Populate REQUIREMENTS.md with REQ-ID format. Use ONLY what the user stated. Write REQUIREMENTS.md immediately.

**Step B3: Create roadmap**

Suggest 3-5 phases based on requirements. If `.vbw-planning/codebase/` exists, read INDEX.md, PATTERNS.md, ARCHITECTURE.md, CONCERNS.md and factor findings into the roadmap.

Each phase: name, goal, mapped requirements, success criteria. Write ROADMAP.md immediately. Create phase directories in `.vbw-planning/phases/`.

**Step B4: Initialize state**

Update STATE.md: project name, Phase 1 position, today's date, empty decisions, 0% progress.

**Step B5: Brownfield codebase summary**

If BROWNFIELD=true AND `.vbw-planning/codebase/` does NOT exist:
1. Count source files by extension (Glob)
2. Check for test files, CI/CD, Docker, monorepo indicators
3. Add Codebase Profile section to STATE.md

**Step B6: Generate CLAUDE.md**

Follow `${CLAUDE_PLUGIN_ROOT}/references/memory-protocol.md`. Write CLAUDE.md at project root.

**Step B7: Transition**

After bootstrap completes, announce:
```
Bootstrap complete. Transitioning to scoping...
```

Re-evaluate state. The project now has PROJECT.md but may have no phases (if the roadmap created phases, skip to State 3-4). Route to the next matching state.

## State 2: Scoping (No Phases Defined)

> Triggered when PROJECT.md exists but no phase directories exist in the resolved phases path.

Read `${CLAUDE_PLUGIN_ROOT}/commands/plan.md` for the full scoping protocol (Scoping Mode section).

Execute the scoping flow:
1. Load project context (PROJECT.md, REQUIREMENTS.md, codebase map if available).
2. Ask "What do you want to build?" (or use $ARGUMENTS as scope description).
3. Decompose into 3-5 phases with names, goals, and success criteria.
4. Write ROADMAP.md and create phase directories.
5. Update STATE.md.

After scoping completes, re-evaluate state. The project now has phases, so the state machine should route to State 3-4.

```
Scoping complete. {N} phases created. Transitioning to planning...
```

## States 3-4: Plan + Execute (Existing Phases)

> State 3: Triggered when phase directories exist and at least one has no `*-PLAN.md` files (needs planning + execution).
> State 4: Triggered when phase directories exist and at least one has plans without matching `*-SUMMARY.md` (needs execution only).

### Auto-detect target phase

If `$ARGUMENTS` does not contain an integer phase number:
1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md` and follow the **Implement Command** dual-condition detection.
2. Announce: "Auto-detected Phase {N} ({slug}) -- {needs plan + execute | planned, needs execute}"

If `$ARGUMENTS` contains an integer, validate that the phase directory exists.

### Parse arguments

- **Phase number** (optional; auto-detected if omitted): integer matching phase directory
- **--effort** (optional): thorough|balanced|fast|turbo. Overrides config for this run only.
- **--skip-qa** (optional): skip post-build verification

### Determine planning state

Check the target phase directory for existing `*-PLAN.md` files.

- **No plans exist (State 3):** Phase needs both planning and execution. Proceed to Planning step.
- **Plans exist but not all have SUMMARY.md (State 4):** Phase is already planned. Skip to Execution step.
- **All plans have SUMMARY.md:** Phase is fully built.
  - At `cautious` or `standard` autonomy: WARN and ask: "Phase {N} already implemented. Re-running will create new commits. Continue?"
  - At `confident` or `dangerously-vibe` autonomy: display warning but auto-continue without asking.

### Planning step (State 3 only)

> Skipped entirely if plans already exist (State 4).

Read `${CLAUDE_PLUGIN_ROOT}/commands/plan.md` for the full planning protocol (Phase Planning Mode section).

Display:
```
◆ Planning Phase {N}: {phase-name}
  Effort: {level}
```

Execute the planning flow:
1. Parse effort and resolve context. Display: `  ◆ Resolving context...`
2. At **Turbo** effort: use the turbo shortcut (direct plan generation). Display: `  ◆ Turbo mode -- generating plan inline...`
3. At all other effort levels: spawn the Lead agent for research, decomposition, and self-review. Display: `  ◆ Spawning Lead agent...`
4. After Lead returns, display: `  ✓ Lead agent complete`
5. Validate that PLAN.md files were produced. Display: `  ◆ Validating plan artifacts...`
6. Display brief planning summary with plan count and wave structure.

**Important:** Do NOT update STATE.md to "Planned". The implement command skips the intermediate "Planned" state and goes directly to "Built" after execution completes.

Display: `✓ Planning complete -- transitioning to execution...`

**Cautious gate (autonomy=cautious only):**

If autonomy is `cautious`, STOP after planning and before execution:
1. Display the plan summary (plan count, wave structure, key tasks)
2. Ask: "Plans ready. Execute Phase {N}?" and wait for confirmation
3. Only proceed to execution if the user confirms

At all other autonomy levels (`standard`, `confident`, `dangerously-vibe`): auto-chain directly to execution as currently.

### Execution step

Read `${CLAUDE_PLUGIN_ROOT}/commands/execute.md` for the full execution protocol.

Execute the build flow:
1. Parse effort and load plans.
2. Detect resume state from existing SUMMARY.md files and git log.
3. Create Agent Team and execute plans with Dev teammates.
4. Run post-build QA unless `--skip-qa` or Turbo effort.
5. Update STATE.md: mark the phase as "Built".
6. Update ROADMAP.md: mark completed plans.
7. Clean up execution state.

### Dangerously-vibe phase loop (autonomy=dangerously-vibe only)

After the execution step completes and the phase summary is displayed:
- If autonomy is `dangerously-vibe` AND more unbuilt phases exist:
  1. Display: `◆ Phase {N} complete. Auto-continuing to Phase {N+1}...`
  2. Re-evaluate state (loop back to State Detection)
  3. Continue until State 5 (all phases complete) or an error guard halts execution
- At all other autonomy levels (`cautious`, `standard`, `confident`): STOP after the phase as currently.

**Error guards are NEVER affected by autonomy.** Missing roadmap, uninitialized project, and other hard stops always halt regardless of autonomy level.

## State 5: Completion (All Phases Done)

> Triggered when all phase directories have all plans with matching SUMMARY.md files.

All planned work is complete. Present the completion summary.

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md`:

```
All phases implemented.

  Completed phases:
    {list each phase with its plan count and status}

Next steps:
  /vbw:archive -- Archive this work and start fresh
  /vbw:add-phase {name} -- Add more phases to continue building
  /vbw:qa -- Run verification on completed phases
```

Do NOT auto-archive. Let the user decide their next action.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md for all output.

### After State 1 (Bootstrap)

Display the project-defined banner then transition message.

### After State 2 (Scoping)

Display the phases-created summary then transition message.

### After States 3-4 (Plan + Execute)

Follow the Agent Teams Shutdown Protocol in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md` before presenting results.

Display:
```
Phase {N}: {name} -- Implemented

  {Planning section if State 3:}
  Planning:
    completed plan list

  Execution:
    completed/failed plan list

  Metrics:
    Plans:      {completed}/{total}
    Effort:     {profile}
    Deviations: {count from SUMMARYs}

  QA:         {PASS|PARTIAL|FAIL|skipped}

Next Up
  /vbw:implement -- Continue to next phase
  /vbw:qa {N} -- Verify this phase (if QA skipped)
  /vbw:archive -- Complete the work (if last phase)
```

### After State 5 (Completion)

Display the all-done summary with next action suggestions.

### Rules
- Phase Banner (double-line box) for phase-level completions
- Execution Progress symbols: ◆ running, ✓ complete, ✗ failed, ○ skipped
- Metrics Block for stats
- Next Up Block for navigation
- No ANSI color codes
- Next Up references /vbw:implement (not /vbw:plan or /vbw:execute) as the primary next action
- Next Up references /vbw:archive for completion
