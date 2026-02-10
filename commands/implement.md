---
name: implement
description: "The one command. Detects project state and routes to bootstrap, scoping, planning, execution, or completion."
argument-hint: "[phase-number] [--effort=thorough|balanced|fast|turbo] [--skip-qa]"
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

Evaluate phase-detect.sh output. FIRST match determines route:

| # | Condition | Route |
|---|-----------|-------|
| 1 | `planning_dir_exists=false` | Run /vbw:init first |
| 2 | `project_exists=false` | State 1: Bootstrap |
| 3 | `phase_count=0` | State 2: Scoping |
| 4 | `next_phase_state=needs_plan_and_execute` or `needs_execute` | State 3-4: Plan + Execute (use `next_phase` + `next_phase_slug`) |
| 5 | `next_phase_state=all_done` | State 5: Completion |

Phases directory already resolved by phase-detect.sh (`phases_dir`, `active_milestone`).

## State 1: Bootstrap (No Project Defined)

**Critical Rules — non-negotiable:**
- NEVER fabricate content. Only use what user explicitly states.
- If answer doesn't match question: STOP, handle their request, let them re-run.
- No silent assumptions — ask follow-ups for gaps.
- Phases come from user, not you.
- Write files directly after gathering answers (no per-file confirmation).

**Constraints:** Do NOT explore/scan codebase (that's /vbw:map). Use existing `.vbw-planning/codebase/` if present.

**Brownfield detection:** Same as init Guard #3 — git ls-files or Glob check.

**Steps:**
- **B1: PROJECT.md** — If $ARGUMENTS provided (excluding flags), use as description. Otherwise ask name + core purpose. Write immediately.
- **B1.5: Discovery Depth Resolution** — Read `discovery_questions` and `active_profile` from config. Map:

  | Profile | Depth | Questions |
  |---------|-------|-----------|
  | yolo | skip | 0 |
  | prototype | quick | 1-2 |
  | default | standard | 3-5 |
  | production | thorough | 5-8 |

  If `discovery_questions=false`: force depth=skip. Store DISCOVERY_DEPTH for B2.

- **B2: REQUIREMENTS.md (Discovery)** — Behavior depends on DISCOVERY_DEPTH:

  **If skip:** Ask 2 minimal static questions via AskUserQuestion: (1) "What are the must-have features?" (2) "Who will use this?" Populate REQUIREMENTS.md with REQ-IDs. Create `.vbw-planning/discovery.json` with `{"answered":[],"inferred":[]}`. Write immediately.

  **If quick/standard/thorough:** Read `${CLAUDE_PLUGIN_ROOT}/references/discovery-protocol.md` (deferred load, TAU-01). Follow Bootstrap Discovery flow:
  1. Analyze user's description (from B1) for domain, scale, users, complexity signals
  2. **Round 1 — Scenarios:** Generate scenario questions per protocol wording guidelines. Present as AskUserQuestion with descriptive options where each option's description explains "this means..." consequences. Number of scenarios: quick=1, standard=2, thorough=3-4
  3. **Round 2 — Checklists:** Based on Round 1 answers, generate targeted pick-many questions. Present as AskUserQuestion with `multiSelect: true`. Number of checklists: quick=1, standard=1-2, thorough=2-3
  4. **Synthesize:** Translate all answers into technical REQUIREMENTS.md with REQ-IDs. Questions are friendly, requirements are precise.
  5. **Store:** Create `.vbw-planning/discovery.json` with `answered[]` (each entry: question, answer, category, phase="bootstrap", date) and `inferred[]` (facts derived from answers). Write immediately.

  **Wording rules (all depths):** No jargon in questions. Plain language first. Concrete situations over abstract concepts. Cause and effect for every choice. Assume user is not a developer. See protocol for full guidelines and examples.
- **B3: ROADMAP.md** — Suggest 3-5 phases based on requirements. If `.vbw-planning/codebase/` exists, read INDEX.md, PATTERNS.md, ARCHITECTURE.md, CONCERNS.md. Each phase: name, goal, mapped reqs, success criteria. Write immediately. Create phase dirs.
- **B4: STATE.md** — Update: project name, Phase 1 position, today's date, empty decisions, 0%.
- **B5: Brownfield summary** — If BROWNFIELD=true AND no codebase/: count files by ext, check tests/CI/Docker/monorepo, add Codebase Profile to STATE.md.
- **B6: CLAUDE.md** — Generate and write CLAUDE.md at project root. Protocol:
  - **Structure:** `# {project-name}` + `**Core value:** {one-liner}` + sections: Active Context (phase/status/next action), Key Decisions (5-10 most impactful from STATE.md), Installed Skills (from STATE.md), Project Conventions (from conventions.json if non-empty), Learned Patterns (3-5 from patterns/PATTERNS.md if exists), VBW Commands (/vbw:status + /vbw:help).
  - **Rules:** Max 200 lines. Core value + Active Context mandatory; other sections omit if empty. Regenerate (not append) on each update. Key Decisions: newest first. No CLAUDE.md if no .vbw-planning/.
  - **Updated by:** /vbw:implement (create), /vbw:plan (phase context), /vbw:execute (decisions/patterns), /vbw:archive (archived state), /vbw:teach (conventions).
  - **Pattern learning:** After phase build, append entry to .vbw-planning/patterns/PATTERNS.md (what worked, what failed, timing, deviations).
- **B7: Transition** — Display "Bootstrap complete. Transitioning to scoping..." Re-evaluate state, route to next match.

## State 2: Scoping (No Phases)

Read `${CLAUDE_PLUGIN_ROOT}/commands/plan.md` (Scoping Mode section).
1. Load context (PROJECT.md, REQUIREMENTS.md, codebase map if available)
2. Ask "What do you want to build?" (or use $ARGUMENTS)
3. Decompose into 3-5 phases
4. Write ROADMAP.md, create phase dirs
5. Update STATE.md

Display "Scoping complete. {N} phases created. Transitioning to planning..." Re-evaluate state.

## States 3-4: Plan + Execute

**Auto-detect phase** (if no integer in $ARGUMENTS): Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md`, follow **Implement Command** dual-condition detection. Announce: "Auto-detected Phase {N} ({slug}) -- {needs plan + execute | planned, needs execute}"

**Parse arguments:** Phase number (optional), --effort (optional), --skip-qa (optional).

**Determine planning state:**
- No plans (State 3): proceed to Planning
- Plans without all SUMMARY.md (State 4): skip to Execution
- All have SUMMARY.md: cautious/standard → WARN + ask "Re-running creates new commits. Continue?"; confident/pure-vibe → warn + auto-continue

### Planning step (State 3 only)

Read `${CLAUDE_PLUGIN_ROOT}/commands/plan.md` (Phase Planning Mode section). Display `◆ Planning Phase {N}: {phase-name}  Effort: {level}`

1. Resolve context. Display: `◆ Resolving context...`
2. Turbo: direct plan generation inline. Display: `◆ Turbo mode -- generating plan inline...`
3. Other efforts: spawn Lead agent. Display: `◆ Spawning Lead agent...` → `✓ Lead agent complete`
4. Validate PLAN.md files produced. Display brief summary.

Do NOT update STATE.md to "Planned" — implement skips to "Built" after execution.
Display: `✓ Planning complete -- transitioning to execution...`

**Cautious gate (autonomy=cautious only):** STOP after planning. Display plan summary, ask "Plans ready. Execute Phase {N}?" Wait for confirmation. Other autonomy levels: auto-chain.

### Execution step

Read `${CLAUDE_PLUGIN_ROOT}/commands/execute.md` for full protocol.
1. Parse effort, load plans
2. Detect resume state from SUMMARY.md + git log
3. Create Agent Team, execute with Dev teammates
4. Post-build QA unless --skip-qa or Turbo
5. Update STATE.md: mark phase "Built"
6. Update ROADMAP.md: mark completed plans
7. Clean up execution state

### Pure-vibe phase loop (autonomy=pure-vibe only)

After execution + phase summary: if more unbuilt phases exist, display `◆ Phase {N} complete. Auto-continuing to Phase {N+1}...`, re-evaluate state, continue until State 5 or error. Other autonomy levels: STOP after phase. **Error guards NEVER affected by autonomy.**

## State 5: Completion

Display per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
```
All phases implemented.
  Completed phases:
    {each phase with plan count and status}
```
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh implement` and display. Do NOT auto-archive.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md for all output.

- **After State 1:** project-defined banner + transition
- **After State 2:** phases-created summary + transition
- **After States 3-4:** Shutdown: send shutdown to each teammate, wait for approval, re-request if rejected, then TeamDelete. Then:
```
Phase {N}: {name} -- Implemented
  {Planning section if State 3: completed plan list}
  Execution: completed/failed plan list
  Metrics: Plans: {N}/{N}  Effort: {profile}  Deviations: {count}
  QA: {PASS|PARTIAL|FAIL|skipped}
```
**"What happened" (NRW-02):** If config `plain_summary` true (default), append 2-4 plain-English sentences. No jargon. If false, skip.
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh implement {qa-result}`.
- **After State 5:** all-done summary + next action suggestions

**Rules:** Phase Banner (double-line box), ◆ running, ✓ complete, ✗ failed, ○ skipped, Metrics Block, Next Up Block, no ANSI. Next Up references /vbw:implement (not plan/execute) and /vbw:archive for completion.
