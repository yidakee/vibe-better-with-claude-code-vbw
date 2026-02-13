---
name: vbw:vibe
description: "The one command. Detects state, parses intent, routes to any lifecycle mode -- bootstrap, scope, plan, execute, discuss, archive, and more."
argument-hint: "[intent or flags] [--plan] [--execute] [--discuss] [--assumptions] [--scope] [--add] [--insert] [--remove] [--archive] [--yolo] [--effort=level] [--skip-qa] [--skip-audit] [--plan=NN] [N]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
disable-model-invocation: true
---

# VBW Vibe: $ARGUMENTS

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

## Input Parsing

Three input paths, evaluated in order:

### Path 1: Flag detection

Check $ARGUMENTS for flags. If any mode flag is present, go directly to that mode:
- `--plan [N]` -> Plan mode
- `--execute [N]` -> Execute mode
- `--discuss [N]` -> Discuss mode
- `--assumptions [N]` -> Assumptions mode
- `--scope` -> Scope mode
- `--add "desc"` -> Add Phase mode
- `--insert N "desc"` -> Insert Phase mode
- `--remove N` -> Remove Phase mode
- `--archive` -> Archive mode

Behavior modifiers (combinable with mode flags):
- `--effort <level>`: thorough|balanced|fast|turbo (overrides config)
- `--skip-qa`: skip post-build QA
- `--skip-audit`: skip pre-archive audit
- `--yolo`: skip all confirmation gates, auto-loop remaining phases
- `--plan=NN`: execute single plan (bypasses wave grouping)
- Bare integer `N`: targets phase N (works with any mode flag)

If flags present: skip confirmation gate (flags express explicit intent).

### Path 2: Natural language intent

If $ARGUMENTS present but no flags detected, interpret user intent:
- Discussion keywords (talk, discuss, explore, think about, what about) -> Discuss mode
- Assumption keywords (assume, assuming, what if, what are you assuming) -> Assumptions mode
- Planning keywords (plan, scope, break down, decompose, structure) -> Plan mode
- Execution keywords (build, execute, run, do it, go, make it, ship it) -> Execute mode
- Phase mutation keywords (add, insert, remove, skip, drop, new phase) -> relevant Phase Mutation mode
- Completion keywords (done, ship, archive, wrap up, finish, complete) -> Archive mode
- Ambiguous -> AskUserQuestion with 2-3 contextual options

ALWAYS confirm interpreted intent via AskUserQuestion before executing.

### Path 3: State detection (no args)

If no $ARGUMENTS, evaluate phase-detect.sh output. First match determines mode:

| Priority | Condition | Mode | Confirmation |
|---|---|---|---|
| 1 | `planning_dir_exists=false` | Init redirect | (redirect, no confirmation) |
| 2 | `project_exists=false` | Bootstrap | "No project defined. Set one up?" |
| 3 | `phase_count=0` | Scope | "Project defined but no phases. Scope the work?" |
| 4 | `next_phase_state=needs_plan_and_execute` | Plan + Execute | "Phase {N} needs planning and execution. Start?" |
| 5 | `next_phase_state=needs_execute` | Execute | "Phase {N} is planned. Execute it?" |
| 6 | `next_phase_state=all_done` | Archive | "All phases complete. Run audit and archive?" |

### Confirmation Gate

Every mode triggers confirmation via AskUserQuestion before executing, with contextual options (recommended action + alternatives).
- **Exception:** `--yolo` skips all confirmation gates. Error guards (missing roadmap, uninitialized project) still halt.
- **Exception:** Flags skip confirmation (explicit intent).

## Modes

### Mode: Init Redirect

If `planning_dir_exists=false`: display "Run /vbw:init first to set up your project." STOP.

### Mode: Bootstrap

**Guard:** `.vbw-planning/` exists but no PROJECT.md.

**Critical Rules (non-negotiable):**
- NEVER fabricate content. Only use what the user explicitly states.
- If answer doesn't match question: STOP, handle their request, let them re-run.
- No silent assumptions -- ask follow-ups for gaps.
- Phases come from the user, not you.

**Constraints:** Do NOT explore/scan codebase (that's /vbw:map). Use existing `.vbw-planning/codebase/` if present.

**Brownfield detection:** `git ls-files` or Glob check for existing code.

**Steps:**
- **B1: PROJECT.md** -- If $ARGUMENTS provided (excluding flags), use as description. Otherwise ask name + core purpose. Then call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-project.sh .vbw-planning/PROJECT.md "$NAME" "$DESCRIPTION"
  ```
- **B1.5: Discovery Depth** -- Read `discovery_questions` and `active_profile` from config. Map profile to depth:

  | Profile | Depth | Questions |
  |---------|-------|-----------|
  | yolo | skip | 0 |
  | prototype | quick | 1-2 |
  | default | standard | 3-5 |
  | production | thorough | 5-8 |

  If `discovery_questions=false`: force depth=skip. Store DISCOVERY_DEPTH for B2.

- **B2: REQUIREMENTS.md (Discovery)** -- Behavior depends on DISCOVERY_DEPTH:
  - **If skip:** Ask 2 minimal static questions via AskUserQuestion: (1) "What are the must-have features?" (2) "Who will use this?" Create `.vbw-planning/discovery.json` with `{"answered":[],"inferred":[]}`.
  - **If quick/standard/thorough:** Read `${CLAUDE_PLUGIN_ROOT}/references/discovery-protocol.md`. Follow Bootstrap Discovery flow:
    1. Analyze user's description for domain, scale, users, complexity signals
    2. Round 1 -- Scenarios: Generate scenario questions per protocol. Present as AskUserQuestion with descriptive options. Count: quick=1, standard=2, thorough=3-4
    3. Round 2 -- Checklists: Based on Round 1 answers, generate targeted pick-many questions with `multiSelect: true`. Count: quick=1, standard=1-2, thorough=2-3
    4. Synthesize answers into `.vbw-planning/discovery.json` with `answered[]` and `inferred[]` (questions=friendly, requirements=precise)
  - **Wording rules (all depths):** No jargon. Plain language. Concrete situations. Cause and effect. Assume user is not a developer.
  - **After discovery (all depths):** Call:
    ```
    bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-requirements.sh .vbw-planning/REQUIREMENTS.md .vbw-planning/discovery.json
    ```

- **B3: ROADMAP.md** -- Suggest 3-5 phases from requirements. If `.vbw-planning/codebase/` exists, read INDEX.md, PATTERNS.md, ARCHITECTURE.md, CONCERNS.md. Each phase: name, goal, mapped reqs, success criteria. Write phases JSON to temp file, then call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-roadmap.sh .vbw-planning/ROADMAP.md "$PROJECT_NAME" /tmp/vbw-phases.json
  ```
  Script handles ROADMAP.md generation and phase directory creation.
- **B4: STATE.md** -- Extract project name, milestone name, and phase count from earlier steps. Call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-state.sh .vbw-planning/STATE.md "$PROJECT_NAME" "$MILESTONE_NAME" "$PHASE_COUNT"
  ```
  Script handles today's date, Phase 1 status, empty decisions, and 0% progress.
- **B5: Brownfield summary** -- If BROWNFIELD=true AND no codebase/: count files by ext, check tests/CI/Docker/monorepo, add Codebase Profile to STATE.md.
- **B6: CLAUDE.md** -- Extract project name and core value from PROJECT.md. If root CLAUDE.md exists, pass it as EXISTING_PATH for section preservation. Call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-claude.sh CLAUDE.md "$PROJECT_NAME" "$CORE_VALUE" [CLAUDE.md]
  ```
  Script handles: new file generation (heading + core value + VBW sections), existing file preservation (replaces only VBW-managed sections: Active Context, VBW Rules, Key Decisions, Installed Skills, Project Conventions, Commands, Plugin Isolation; preserves all other content). Omit the fourth argument if no existing CLAUDE.md. Max 200 lines.
- **B7: Transition** -- Display "Bootstrap complete. Transitioning to scoping..." Re-evaluate state, route to next match.

### Mode: Scope

**Guard:** PROJECT.md exists but `phase_count=0`.

**Steps:**
1. Load context: PROJECT.md, REQUIREMENTS.md. If `.vbw-planning/codebase/` exists, read INDEX.md + ARCHITECTURE.md.
2. If $ARGUMENTS (excl. flags) provided, use as scope. Else ask: "What do you want to build?" Show uncovered requirements as suggestions.
3. Decompose into 3-5 phases (name, goal, success criteria). Each independently plannable. Map REQ-IDs.
4. Write ROADMAP.md. Create `.vbw-planning/phases/{NN}-{slug}/` dirs.
5. Update STATE.md: Phase 1, status "Pending planning".
6. Display "Scoping complete. {N} phases created." STOP -- do not auto-continue to planning.

### Mode: Discuss

**Guard:** Initialized, phase exists in roadmap.
**Phase auto-detection:** First phase without `*-PLAN.md`. All planned: STOP "All phases planned. Specify: `/vbw:vibe --discuss N`"

**Steps:**
1. Load phase goal, requirements, success criteria, dependencies from ROADMAP.md.
2. Ask 3-5 phase-specific questions across: essential features, technical preferences, boundaries, dependencies, acceptance criteria.
3. Write `.vbw-planning/phases/{phase-dir}/{phase}-CONTEXT.md` with sections: User Vision, Essential Features, Technical Preferences, Boundaries, Acceptance Criteria, Decisions Made.
4. Update `.vbw-planning/discovery.json`: append each question+answer to `answered[]` (category, phase, date), extract inferences to `inferred[]`.
5. Show summary, ask for corrections. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Mode: Assumptions

**Guard:** Initialized, phase exists in roadmap.
**Phase auto-detection:** Same as Discuss mode.

**Steps:**
1. Load context: ROADMAP.md, REQUIREMENTS.md, PROJECT.md, STATE.md, CONTEXT.md (if exists), codebase signals.
2. Generate 5-10 assumptions by impact: scope (included/excluded), technical (implied approaches), ordering (sequencing), dependency (prior phases), user preference (defaults without stated preference).
3. Gather feedback per assumption: "Confirm, correct, or expand?" Confirm=proceed, Correct=user provides answer, Expand=user adds nuance.
4. Present grouped by status (confirmed/corrected/expanded). This mode does NOT write files. For persistence: "Run `/vbw:vibe --discuss {N}` to capture as CONTEXT.md." Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Mode: Plan

**Guard:** Initialized, roadmap exists, phase exists.
**Phase auto-detection:** First phase without PLAN.md. All planned: STOP "All phases planned. Specify phase: `/vbw:vibe --plan N`"

**Steps:**
1. **Parse args:** Phase number (optional, auto-detected), --effort (optional, falls back to config).
2. **Phase Discovery (if applicable):** Skip if already planned, phase dir has `{phase}-CONTEXT.md`, or DISCOVERY_DEPTH=skip. Otherwise: read `${CLAUDE_PLUGIN_ROOT}/references/discovery-protocol.md` Phase Discovery mode. Generate phase-scoped questions (quick=1, standard=1-2, thorough=2-3). Skip categories already in `discovery.json.answered[]`. Present via AskUserQuestion. Append to `discovery.json`. Write `{phase}-CONTEXT.md`.
3. **Context compilation:** If `config_context_compiler=true`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} lead {phases_dir}`. Include `.context-lead.md` in Lead agent context if produced.
4. **Turbo shortcut:** If effort=turbo, skip Lead. Read phase reqs from ROADMAP.md, create single lightweight PLAN.md inline.
5. **Other efforts:**
   - Resolve Lead model:
     ```bash
     LEAD_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh lead .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
     if [ $? -ne 0 ]; then
       echo "$LEAD_MODEL" >&2
       exit 1
     fi
     ```
   - Spawn vbw-lead as subagent via Task tool with compiled context (or full file list as fallback).
   - **CRITICAL:** Add `model: "${LEAD_MODEL}"` parameter to the Task tool invocation.
   - Display `◆ Spawning Lead agent...` -> `✓ Lead agent complete`.
6. **Validate output:** Verify PLAN.md has valid frontmatter (phase, plan, title, wave, depends_on, must_haves) and tasks. Check wave deps acyclic.
7. **Present:** Update STATE.md (phase position, plan count, status=Planned). Resolve model profile:
   ```bash
   MODEL_PROFILE=$(jq -r '.model_profile // "balanced"' .vbw-planning/config.json)
   ```
   Display Phase Banner with plan list, effort level, and model profile:
   ```
   Phase {N}: {name}
   Plans: {N}
     {plan}: {title} (wave {W}, {N} tasks)
   Effort: {effort}
   Model Profile: {profile}
   ```
8. **Cautious gate (autonomy=cautious only):** STOP after planning. Ask "Plans ready. Execute Phase {N}?" Other levels: auto-chain.

### Mode: Execute

Read `${CLAUDE_PLUGIN_ROOT}/references/execute-protocol.md` and follow its instructions.

This mode delegates entirely to the protocol file. Before reading:
1. **Parse arguments:** Phase number (auto-detect if omitted), --effort, --skip-qa, --plan=NN.
2. **Run execute guards:**
   - Not initialized: STOP "Run /vbw:init first."
   - No PLAN.md in phase dir: STOP "Phase {N} has no plans. Run `/vbw:vibe --plan {N}` first."
   - All plans have SUMMARY.md: cautious/standard -> WARN + confirm; confident/pure-vibe -> warn + auto-continue.
3. **Compile context:** If `config_context_compiler=true`, run:
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} dev {phases_dir} {plan_path}`
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} qa {phases_dir}`
   Include compiled context paths in Dev and QA task descriptions.

Then Read the protocol file and execute Steps 2-5 as written.

### Mode: Add Phase

**Guard:** Initialized. Requires phase name in $ARGUMENTS.
Missing name: STOP "Usage: `/vbw:vibe --add <phase-name>`"

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: phase name (first non-flag arg), --goal (optional), slug (lowercase hyphenated).
3. Next number: highest in ROADMAP.md + 1, zero-padded.
4. Update ROADMAP.md: append phase list entry, append Phase Details section, add progress row.
5. Create dir: `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
6. Present: Phase Banner with milestone, position, goal. Checklist for roadmap update + dir creation. Next Up: `/vbw:vibe --discuss` or `/vbw:vibe --plan`.

### Mode: Insert Phase

**Guard:** Initialized. Requires position + name.
Missing args: STOP "Usage: `/vbw:vibe --insert <position> <phase-name>`"
Invalid position (out of range 1 to max+1): STOP with valid range.
Inserting before completed phase: WARN + confirm.

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: position (int), phase name, --goal (optional), slug (lowercase hyphenated).
3. Identify renumbering: all phases >= position shift up by 1.
4. Renumber dirs in REVERSE order: rename dir {NN}-{slug} -> {NN+1}-{slug}, rename internal PLAN/SUMMARY files, update `phase:` frontmatter, update `depends_on` references.
5. Update ROADMAP.md: insert new phase entry + details at position, renumber subsequent entries/headers/cross-refs, update progress table.
6. Create dir: `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
7. Present: Phase Banner with renumber count, phase changes, file checklist, Next Up.

### Mode: Remove Phase

**Guard:** Initialized. Requires phase number.
Missing number: STOP "Usage: `/vbw:vibe --remove <phase-number>`"
Not found: STOP "Phase {N} not found."
Has work (PLAN.md or SUMMARY.md): STOP "Phase {N} has artifacts. Remove plans first."
Completed ([x] in roadmap): STOP "Cannot remove completed Phase {N}."

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: extract phase number, validate, look up name/slug.
3. Confirm: display phase details, ask confirmation. Not confirmed -> STOP.
4. Remove dir: `rm -rf {PHASES_DIR}/{NN}-{slug}/`
5. Renumber FORWARD: for each phase > removed: rename dir {NN} -> {NN-1}, rename internal files, update frontmatter, update depends_on.
6. Update ROADMAP.md: remove phase entry + details, renumber subsequent, update deps, update progress table.
7. Present: Phase Banner with renumber count, phase changes, file checklist, Next Up.

### Mode: Archive

**Guard:** Initialized, roadmap exists.
No roadmap: STOP "No milestones configured. Run `/vbw:vibe` to bootstrap."
No work (no SUMMARY.md files): STOP "Nothing to ship."

**Pre-gate audit (unless --skip-audit or --force):**
Run 6-point audit matrix:
1. Roadmap completeness: every phase has real goal (not TBD/empty)
2. Phase planning: every phase has >= 1 PLAN.md
3. Plan execution: every PLAN.md has SUMMARY.md
4. Execution status: every SUMMARY.md has `status: complete`
5. Verification: VERIFICATION.md files exist + PASS. Missing=WARN, failed=FAIL
6. Requirements coverage: req IDs in roadmap exist in REQUIREMENTS.md
FAIL -> STOP with remediation suggestions. WARN -> proceed with warnings.

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths. No ACTIVE -> SLUG="default", root paths.
2. Parse args: --tag=vN.N.N (custom tag), --no-tag (skip), --force (skip audit).
3. Compute summary: from ROADMAP (phases), SUMMARY.md files (tasks/commits/deviations), REQUIREMENTS.md (satisfied count).
4. Archive: `mkdir -p .vbw-planning/milestones/`. Move roadmap, state, phases to milestones/{SLUG}/. Write SHIPPED.md. Delete stale RESUME.md.
5. Git branch merge: if `milestone/{SLUG}` branch exists, merge --no-ff. Conflict -> abort, warn. No branch -> skip.
6. Git tag: unless --no-tag, `git tag -a {tag} -m "Shipped milestone: {name}"`. Default: `milestone/{SLUG}`.
7. Update ACTIVE: remaining milestones -> set ACTIVE to first. None -> remove ACTIVE.
8. Regenerate CLAUDE.md: update Active Context, remove shipped refs. Preserve non-VBW content — only replace VBW-managed sections, keep user's own sections intact.
9. Present: Phase Banner with metrics (phases, tasks, commits, requirements, deviations), archive path, tag, branch status, memory status. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Pure-Vibe Phase Loop

After Execute mode completes (autonomy=pure-vibe only): if more unbuilt phases exist, auto-continue to next phase (Plan + Execute). Loop until `next_phase_state=all_done` or error. Other autonomy levels: STOP after phase.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md for all output.

Per-mode output:
- **Bootstrap:** project-defined banner + transition to scoping
- **Scope:** phases-created summary + STOP
- **Discuss:** ✓ for captured answers, Next Up Block
- **Assumptions:** numbered list, ✓ confirmed, ✗ corrected, ○ expanded, Next Up
- **Plan:** Phase Banner (double-line box), plan list with waves/tasks, Effort, Next Up
- **Execute:** Phase Banner, plan results (✓/✗), Metrics (plans, effort, deviations), QA result, "What happened" (NRW-02), Next Up
- **Add/Insert/Remove Phase:** Phase Banner, ✓ checklist, Next Up
- **Archive:** Phase Banner, Metrics (phases, tasks, commits, reqs, deviations), archive path, tag, branch, memory status, Next Up

Rules: Phase Banner (double-line box), ◆ running, ✓ complete, ✗ failed, ○ skipped, Metrics Block, Next Up Block, no ANSI color codes.

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe {result}` for Next Up suggestions.
