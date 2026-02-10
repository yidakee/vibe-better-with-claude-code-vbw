---
name: archive
disable-model-invocation: true
description: Archive completed work -- save state, tag repository, clean up workspace.
argument-hint: [--tag=vN.N.N] [--no-tag] [--force]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Archive $ARGUMENTS

## Context

Working directory: `!`pwd``
Active milestone: `!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"``
Git status:
```
!`git status --short 2>/dev/null || echo "Not a git repository"`
```

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **No roadmap:** Neither ACTIVE nor ROADMAP.md → STOP: "No milestones configured. Run /vbw:implement."
3. **Audit not passed:** Without --force, run audit checks. FAIL → STOP: "Audit failed. Run /vbw:audit or --force."
4. **No work:** No SUMMARY.md files → STOP: "Nothing to ship."

## Steps

1. **Resolve context:** ACTIVE → milestone-scoped paths. No ACTIVE → SLUG="default", root paths.
2. **Parse args:** --tag=vN.N.N (custom tag), --no-tag (skip), --force (skip audit).
3. **Compute summary:** From ROADMAP (total phases), SUMMARY.md files (completed phases/tasks/commits/deviations), REQUIREMENTS.md (satisfied count).
4. **Archive:** `mkdir -p .vbw-planning/milestones/`. Multi-milestone: mv entire dir. Single: mv ROADMAP.md, STATE.md, phases/ to milestones/{SLUG}/. Keep shared files. Write SHIPPED.md. Delete stale RESUME.md.
5. **Git branch merge:** If `milestone/{SLUG}` branch exists: check dirty, merge --no-ff. Conflict → abort, warn (don't block archive). No branch → skip.
6. **Git tag:** Unless --no-tag: `git tag -a {tag} -m "Shipped milestone: {name}"`. Default tag: `milestone/{SLUG}`.
7. **Update ACTIVE:** Remaining milestones → set ACTIVE to first. None → remove ACTIVE, single-milestone mode.
8. **Update memory:** Regenerate CLAUDE.md (update Active Context, remove shipped refs). Preserve patterns.
9. **Present:** Phase Banner with metrics (phases, tasks, commits, requirements, deviations), archive path, tag, branch status, memory status. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh archive`.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), Metrics Block, Next Up, no ANSI.
