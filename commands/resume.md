---
name: vbw:resume
disable-model-invocation: true
description: Restore project context from .vbw-planning/ state.
argument-hint:
allowed-tools: Read, Bash, Glob
---

# VBW Resume

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **No roadmap:** ROADMAP.md missing → STOP: "No roadmap found. Run /vbw:vibe."

## Steps

1. **Resolve paths:** ACTIVE → milestone-scoped. Otherwise → .vbw-planning/ defaults.
2. **Read ground truth:** PROJECT.md (name, core value), STATE.md (decisions, todos, blockers), ROADMAP.md (phases), Glob *-PLAN.md + *-SUMMARY.md (plan/completion counts), .execution-state.json (interrupted builds), most recent SUMMARY.md (last work), RESUME.md (session notes). Skip missing files.
3. **Compute progress:** Per phase: count PLANs vs SUMMARYs → not started | planned | in progress | complete. Current phase = first incomplete.
4. **Detect interrupted builds:** If .execution-state.json status="running": all SUMMARYs present = completed since last session; some missing = interrupted.
5. **Present dashboard:** Phase Banner "Context Restored / {project name}" with: core value, phase/progress, overall progress bar, key decisions, todos, blockers (⚠), last completed, build status (✓ completed / ⚠ interrupted), session notes. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh resume`.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — double-line box, Metrics Block, ⚠ warnings, ✓ completions, ➜ Next Up, no ANSI.
