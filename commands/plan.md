---
name: plan
description: "Scope new work or plan a specific phase. No args with no phases starts scoping; otherwise plans the next unplanned phase."
argument-hint: [phase-number] [--effort=thorough|balanced|fast|turbo]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Plan: $ARGUMENTS

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

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "NO_ACTIVE_MILESTONE"`
```

Codebase map staleness:
```
!`bash -c 'f=$(ls -1 "$HOME"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/map-staleness.sh 2>/dev/null | sort -V | tail -1); [ -f "$f" ] && exec bash "$f" || echo "status: no_script"'`
```

## Mode Detection

Resolve phases dir: if `.vbw-planning/ACTIVE` exists, use `.vbw-planning/{milestone-slug}/phases/`; else `.vbw-planning/phases/`.

First match wins:

| Condition | Mode |
|-----------|------|
| $ARGUMENTS has integer phase number | Phase Planning (that number) |
| No phase dirs exist | Scoping |
| Phase dirs exist | Phase Planning (auto-detect) |

## Scoping Mode

Guard:
- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- No PROJECT.md or contains `{project-description}`: STOP "No project defined. Run /vbw:implement to set up your project."

Steps:
- **S1:** Read PROJECT.md, REQUIREMENTS.md. If `.vbw-planning/codebase/` exists, read INDEX.md + ARCHITECTURE.md.
- **S2:** If $ARGUMENTS (excl. flags) provided, use as scope. Else ask: "What do you want to build next?" Show uncovered requirements from REQUIREMENTS.md as suggestions.
- **S3:** Propose 3-5 phases (name, goal, success criteria). Each independently plannable. Map REQ-IDs to phases.
- **S4:** Update ROADMAP.md. Create `.vbw-planning/phases/{NN}-{slug}/` dirs.
- **S5:** Update STATE.md: Phase 1, status "Pending planning".
- **S6:** Announce "Scoping complete. {N} phases created." Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh plan` and display. STOP -- do not auto-continue.

## Phase Planning Mode

### Phase Auto-Detection

If $ARGUMENTS has no integer phase number:
1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md`
2. Resolve phases dir (check .vbw-planning/ACTIVE for milestone)
3. Scan dirs numerically. Find first with NO `*-PLAN.md` files
4. Found: announce "Auto-detected Phase {N} ({slug})" and proceed
5. All planned: STOP "All phases are planned. Specify a phase to re-plan: `/vbw:plan N`"

### Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- No ROADMAP.md or has template placeholders: STOP "No roadmap found. Run /vbw:implement to set up your project."
- Phase {N} not in roadmap: STOP "Phase {N} not found in roadmap."
- Already has PLAN.md + SUMMARY.md: WARN "Phase {N} already completed. Re-planning preserves existing plans as .bak."

### Staleness Check

From Context block above (advisory only, never block):
- `stale`: print `⚠ Codebase map is {staleness} stale ({changed} files changed). Consider /vbw:map before planning.`
- `no_map`: print `○ No codebase map. Run /vbw:map for better planning context.`
- `fresh`: print `✓ Codebase map is fresh ({staleness} changed)`
- `no_git`/`no_script`: skip silently

### Steps

1. **Parse args:** phase number (optional, auto-detected), --effort (optional, falls back to config)
2. **Turbo shortcut:** If effort=turbo, skip Lead. Read phase reqs from ROADMAP.md. Create single lightweight PLAN.md. Skip to step 5.
3. **Spawn Lead:** Display `◆ Planning Phase {N}: {phase-name} / Effort: {level} / Spawning Lead agent...`

Spawn vbw-lead as subagent via Task tool:
```
Plan phase {N}: {phase-name}.
Roadmap: .vbw-planning/ROADMAP.md
Requirements: .vbw-planning/REQUIREMENTS.md
State: .vbw-planning/STATE.md
Project: .vbw-planning/PROJECT.md
Patterns: .vbw-planning/patterns/PATTERNS.md (if exists)
Codebase map: .vbw-planning/codebase/ (if exists)
  Read INDEX.md, ARCHITECTURE.md, CONCERNS.md for codebase context.
Effort: {level}
Output: Write PLAN.md files to .vbw-planning/phases/{phase-dir}/
```
Lead reads all files itself. Display `✓ Lead agent complete` after return.

4. **Validate output:** Verify each PLAN.md has valid frontmatter (phase, plan, title, wave, depends_on, must_haves) and tasks (name, files, action, verify, done). Check wave deps acyclic. Check cross_phase_deps reference lower phases. Report failures.
5. **Update + present:** Update STATE.md (phase position, plan count, status=Planned). Display per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
```
╔═══════════════════════════════════════════╗
║  Phase {N}: {name} -- Planned             ║
╚═══════════════════════════════════════════╝

  Plans:
    ○ Plan 01: {title}  (wave {W}, {task-count} tasks)
    ○ Plan 02: {title}  (wave {W}, {task-count} tasks)

  Effort: {profile}

```
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh plan` and display.
