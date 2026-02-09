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

Project existence:
```
!`head -20 .vbw-planning/PROJECT.md 2>/dev/null || echo "NO_PROJECT"`
```

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "NO_PHASES"`
```

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "NO_ACTIVE_MILESTONE"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

Codebase map staleness:
```
!`if [ -f .vbw-planning/codebase/META.md ]; then head -5 .vbw-planning/codebase/META.md; else echo "No codebase map"; fi`
```

Project files (brownfield detection):
```
!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No detected project files"`
```

Existing state:
```
!`ls -la .vbw-planning 2>/dev/null || echo "No .vbw-planning directory"`
```

## State Detection

Evaluate project state in this order. The FIRST matching condition determines the route.

| # | Condition | Route |
|---|-----------|-------|
| 1 | `.vbw-planning/` does not exist | Run /vbw:init first (preserve existing guard) |
| 2 | `.vbw-planning/PROJECT.md` does not exist OR contains template placeholder `{project-description}` | State 1: Bootstrap |
| 3 | No phase directories exist in the resolved phases path (empty or missing) | State 2: Scoping |
| 4 | Phase directories exist and at least one has no `*-PLAN.md` files OR has plans without matching `*-SUMMARY.md` | State 3-4: Plan + Execute (existing behavior) |
| 5 | All phase directories have all plans with matching `*-SUMMARY.md` files | State 5: Completion |

For conditions 3-5, resolve the phases directory first:
- If `.vbw-planning/ACTIVE` exists, read its contents for the milestone slug and use `.vbw-planning/{slug}/phases/`
- Otherwise use `.vbw-planning/phases/`

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

### Scoping Steps

**Step S1: Load project context**

Read `.vbw-planning/PROJECT.md` and `.vbw-planning/REQUIREMENTS.md` to understand the project. If `.vbw-planning/codebase/` exists, read INDEX.md and ARCHITECTURE.md for codebase context.

**Step S2: Gather scope**

If $ARGUMENTS provided (excluding flags like --effort), use as scope description. Otherwise ask:

"What do you want to build next? Describe the work you want to accomplish."

If REQUIREMENTS.md has uncovered requirements (not yet mapped to phases), present them as suggestions.

**Step S3: Decompose into phases**

Based on the user's answer and existing requirements:
1. Propose 3-5 phases with name, goal, and success criteria
2. Each phase should be independently plannable and executable
3. Map requirements (REQ-IDs) to phases where applicable

**Step S4: Write roadmap and create phase directories**

Update ROADMAP.md with the proposed phases. Create phase directories in the resolved phases path (`.vbw-planning/phases/{NN}-{slug}/` for each phase).

**Step S5: Update state**

Update STATE.md: set position to Phase 1, status to "Pending planning".

**Step S6: Transition**

Announce scoping complete and re-evaluate state. The project now has phases, so the state machine should route to State 3-4 (plan + execute for the first unplanned phase).

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
- **All plans have SUMMARY.md:** Phase is fully built. WARN: "Phase {N} already implemented. Re-running will create new commits. Continue?"

### Planning step (State 3 only)

> Skipped entirely if plans already exist (State 4).

Reference the full planning protocol from `@${CLAUDE_PLUGIN_ROOT}/commands/plan.md`.

Execute the planning flow:
1. Parse effort and resolve context.
2. At **Turbo** effort: use the turbo shortcut (direct plan generation).
3. At all other effort levels: spawn the Lead agent for research, decomposition, and self-review.
4. Validate that PLAN.md files were produced.
5. Display brief planning summary.

**Important:** Do NOT update STATE.md to "Planned". The implement command skips the intermediate "Planned" state and goes directly to "Built" after execution completes.

### Execution step

Reference the full execution protocol from `@${CLAUDE_PLUGIN_ROOT}/commands/execute.md`.

Execute the build flow:
1. Parse effort and load plans.
2. Detect resume state from existing SUMMARY.md files and git log.
3. Create Agent Team and execute plans with Dev teammates.
4. Run post-build QA unless `--skip-qa` or Turbo effort.
5. Update STATE.md: mark the phase as "Built".
6. Update ROADMAP.md: mark completed plans.
7. Clean up execution state.

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
- Next Up references /vbw:archive (not /vbw:ship) for completion
