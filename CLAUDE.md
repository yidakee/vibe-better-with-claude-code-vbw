# VBW — Vibe Better with Claude Code

A Claude Code plugin that adds structured development workflows — planning, execution, and verification — using specialized agent teams.

**Core value:** Replace ad-hoc AI coding with repeatable, phased workflows.

## Active Context

**Work:** Performance Optimization — token savings, script automation, agent cost controls
**Phase:** 2 of 3 (Script Offloading) — not started
**Completed:** Phase 1 (Context Diet) — 4 plans, 6 commits, 0 deviations
**Next action:** /vbw:implement to plan and execute Phase 2

## VBW Rules

- **Always use VBW commands** for project work. Do not manually edit files in `.vbw-planning/`.
- **Commit format:** `{type}({scope}): {description}` — types: feat, fix, test, refactor, perf, docs, style, chore.
- **One commit per task.** Each task in a plan gets exactly one atomic commit.
- **Never commit secrets.** Do not stage .env, .pem, .key, credentials, or token files.
- **Plan before building.** Use /vbw:plan before /vbw:execute. Plans are the source of truth.
- **Do not fabricate content.** Only use what the user explicitly states in project-defining flows.
- **Do not bump version or push until asked.** Never run `scripts/bump-version.sh` or `git push` unless the user explicitly requests it. Commit locally and wait.

## Key Decisions

| Decision | Date | Rationale |
|----------|------|-----------|
| Ship current feature set as v1 | 2026-02-09 | All core workflows functional |
| Target solo developers | 2026-02-09 | Primary Claude Code user base |
| 3-phase roadmap: failures → polish → docs | 2026-02-09 | Risk-ordered, concerns-first |
| `/vbw:implement` as single primary command | 2026-02-09 | Users confused by command overlap |
| Milestones become internal concept | 2026-02-09 | Solo devs don't need the abstraction |
| `/vbw:ship` → `/vbw:archive` | 2026-02-09 | Clearer verb for wrapping up work |
| Remove `/vbw:new`, `/vbw:milestone`, `/vbw:switch` | 2026-02-09 | Absorbed into implement/plan |
| Performance optimization: 3 phases | 2026-02-09 | Context diet → script offloading → agent cost controls |
| Every optimization must have measured impact | 2026-02-09 | No changes for the sake of changes |

## Installed Skills

- audit-website (global)
- bash-pro (global)
- find-skills (global)
- frontend-design (global)
- plugin-settings (global)
- plugin-structure (global)
- posix-shell-pro (global)
- remotion-best-practices (global)
- seo-audit (global)
- skill-development (global)
- vercel-react-best-practices (global)
- web-design-guidelines (global)
- agent-sdk-development (global)

## Learned Patterns

- Plan 03-03 (validation) found zero discrepancies — Plans 01+02 across all phases were implemented accurately
- Hook count grew from 17 to 18 during Phase 1 (frontmatter validation added)
- Version sync enforcement at push time prevents mismatched releases

## Compact Instructions

When compacting context, follow these priorities:

**Always preserve:**
- Active plan file content (current task number, remaining tasks, file paths)
- Commit hashes and messages from this session's work
- Deviation decisions and their rationale
- Current phase number, name, and status
- File paths that were modified (exact paths, not summaries)
- Any error messages or test failures being debugged

**Safe to discard:**
- Tool output details (file contents already read, grep results already processed)
- Planning exploration that led to the current plan (keep only the final plan)
- Verbose git diff output (keep only the summary of what changed)
- Reference file contents that can be re-read from disk (ROADMAP.md, REQUIREMENTS.md, shared-patterns.md)
- Previous phase summaries (already written to disk as SUMMARY.md files)

**After compaction:** Re-read your assigned plan file and STATE.md from disk to restore working context.

## State

- Planning directory: `.vbw-planning/`
- Codebase map: `.vbw-planning/codebase/` (9 documents)

## Commands

Run /vbw:status for current progress.
Run /vbw:help for all available commands.
