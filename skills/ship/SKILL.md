---
name: ship
disable-model-invocation: true
description: Complete and archive the active milestone -- archive state, tag repository, clear milestone workspace.
argument-hint: [--tag=vN.N.N] [--no-tag] [--force]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Ship $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .vbw-planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Git status:
```
!`git status --short 2>/dev/null || echo "Not a git repository"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No milestones or roadmap:** If neither ACTIVE nor ROADMAP.md exists, STOP: "No milestones configured. Run /vbw:new or /vbw:milestone first."
3. **Audit not passed:** If `--force` not present, run audit checks (same as /vbw:audit). If FAIL, STOP: "Audit failed. Run /vbw:audit for details, or --force to ship anyway."
4. **No completed work:** If no SUMMARY.md files exist, STOP: "Nothing to ship."

## Steps

### Step 1: Resolve milestone context

If ACTIVE exists: SLUG from file, milestone-scoped paths.
If not: SLUG = "default", root .vbw-planning/ paths.

Read ROADMAP to get milestone name.

### Step 2: Parse arguments

- **--tag=vN.N.N**: Custom git tag
- **--no-tag**: Skip tagging
- **--force**: Skip audit requirement

### Step 3: Compute milestone summary

From ROADMAP: total phases.
From SUMMARY.md files (Glob): phases completed, tasks, commits, deviations.
From REQUIREMENTS.md: total requirements, requirements satisfied.

### Step 4: Archive milestone

1. `mkdir -p .vbw-planning/milestones/`
2. Multi-milestone: `mv .vbw-planning/{SLUG}/ .vbw-planning/milestones/{SLUG}/`
3. Single-milestone: move ROADMAP.md, STATE.md, phases/ to `.vbw-planning/milestones/{SLUG}/`. Keep shared files (PROJECT.md, config.json, REQUIREMENTS.md, codebase/).
4. Write SHIPPED.md to archived directory.
5. Delete stale RESUME.md if present.

### Step 4.5: Git branch merge

If a `milestone/{SLUG}` branch exists:
1. Check for uncommitted changes: `git status --porcelain`. If dirty, WARN: "Uncommitted changes detected. Commit or stash before merging."
2. Get base branch: `git log --oneline --decorate -1 milestone/{SLUG}` to determine the branch point, or use `main`/`master` as default.
3. Attempt merge: `git checkout {base} && git merge milestone/{SLUG} --no-ff -m "ship: merge milestone/{SLUG}"`
4. If merge conflict: `git merge --abort`, display "⚠ Merge conflict detected. Resolve manually." Do NOT block shipping -- archive already happened.
5. If merge succeeded: display "✓ Merged milestone/{SLUG} into {base}"

If no milestone branch exists: skip silently.

### Step 5: Git tagging

If `--no-tag` NOT set:
- Tag name: `--tag` value, or default `milestone/{SLUG}`
- `git tag -a {tag} -m "Shipped milestone: {name}"`
- Display "✓ Tagged: {tag}"

If `--no-tag`: display "○ Git tag skipped"

### Step 6: Update ACTIVE pointer

Check for remaining milestones. If others exist: set ACTIVE to first remaining. If none: remove ACTIVE file, restore single-milestone mode.

### Step 7: Update memory

Regenerate CLAUDE.md if it exists (update Active Context, remove shipped milestone refs, keep patterns). Preserve .vbw-planning/patterns/PATTERNS.md (project-scoped).

### Step 8: Present confirmation

```
╔═══════════════════════════════════════════╗
║  Shipped: {milestone-name}                ║
╚═══════════════════════════════════════════╝

  Phases:       {completed}/{total}
  Tasks:        {count}
  Commits:      {count}
  Requirements: {satisfied}/{total}
  Deviations:   {count}

  Archive: .vbw-planning/milestones/{SLUG}/
  Tag:     {tag or "none"}
  Branch:  {merged to {base} | "no branch" | "conflict -- merge manually"}

  Memory:
    ✓ Patterns preserved
    ✓ CLAUDE.md updated
    ✓ Session resume cleared

➜ Next Up
  /vbw:milestone <name> -- Start a new milestone
  /vbw:status -- View project overview
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Ship Confirmation template (double-line box)
- Metrics Block for statistics
- Next Up Block for navigation
- No ANSI color codes
