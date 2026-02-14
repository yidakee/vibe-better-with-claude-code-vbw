# VBW — Vibe Better with Claude Code

A Claude Code plugin that adds structured development workflows — planning, execution, and verification — using specialized agent teams.

**Core value:** Replace ad-hoc AI coding with repeatable, phased workflows.

## Active Context

**Work:** No active milestone
**Last shipped:** Config Migration & Research Verification — 2 phases, 10 tasks, 10 commits, 0 deviations
**Previous:** Team Preference Control — 1 phase, 9 tasks, 8 commits, 37/37 QA
**Next action:** Run /vbw:vibe to start a new milestone

## VBW Rules

- **Always use VBW commands** for project work. Do not manually edit files in `.vbw-planning/`.
- **Commit format:** `{type}({scope}): {description}` — types: feat, fix, test, refactor, perf, docs, style, chore.
- **One commit per task.** Each task in a plan gets exactly one atomic commit.
- **Never commit secrets.** Do not stage .env, .pem, .key, credentials, or token files.
- **Plan before building.** Use /vbw:vibe for all lifecycle actions. Plans are the source of truth.
- **Do not fabricate content.** Only use what the user explicitly states in project-defining flows.
- **Do not push until asked.** Never run `git push` unless the user explicitly requests it. Commit locally and wait.

## Key Decisions

| Decision | Date | Rationale |
|----------|------|-----------|
| 3 preset profiles (quality/balanced/budget) | 2026-02-11 | Covers 95% of use cases; overrides handle edge cases |
| Quality as default (Opus + Sonnet QA + Haiku Scout) | 2026-02-11 | Maximum reasoning for critical work; changed from balanced in v1.10.15 |
| Model profile integrated into /vbw:config | 2026-02-11 | One config interface, not separate command |
| Pass explicit model param to Task tool | 2026-02-11 | Session /model doesn't propagate to subagents |
| Hard delete old commands (no aliases, no deprecation) | 2026-02-11 | Zero technical debt; CHANGELOG documents the change |
| Single vibe.md (~300 lines) with inline mode logic | 2026-02-11 | One file = one truth; execute-protocol.md is the only extraction |
| NL parsing via prompt instructions, not code | 2026-02-11 | Zero maintenance; model improvements are free |
| Confirmation gates mandatory (except --yolo) | 2026-02-11 | NL misinterpretation risk → always confirm before acting |
| Per-project memory only | 2026-02-10 | Get basics right first, cross-project learning deferred |
| Domain research before discovery questions | 2026-02-13 | Informed scenarios catch unknown unknowns; graceful fallback preserves speed |
| prefer_teams replaces agent_teams, default 'always' | 2026-02-14 | Maximize color-coded agent visibility; token overhead acceptable |

## Installed Skills

13 global skills installed (run /vbw:skills to list).

## Project Conventions

These conventions are enforced during planning and verified during QA.

- Commands are kebab-case .md files in commands/ [file-structure]
- Agents named vbw-{role}.md in agents/ [naming]
- Scripts are kebab-case .sh files in scripts/ [naming]
- Phase directories follow {NN}-{slug}/ pattern [naming]
- Plan files named {NN}-{MM}-PLAN.md, summaries {NN}-{MM}-SUMMARY.md [naming]
- Commits follow {type}({scope}): {desc} format, one commit per task [style]
- Stage files individually with git add, never git add . or git add -A [style]
- Shell scripts use set -u minimum, set -euo pipefail for critical scripts [style]
- Use jq for all JSON parsing, never grep/sed on JSON [tooling]
- YAML frontmatter description must be single-line (multi-line breaks discovery) [style]
- No prettier-ignore comment before YAML frontmatter, use .prettierignore instead [style]
- All hooks route through hook-wrapper.sh for graceful degradation (DXP-01) [patterns]
- Zero-dependency design: no package.json, npm, or build step [patterns]
- All scripts target bash, not POSIX sh [tooling]
- Plugin cache resolution via ls | sort -V | tail -1, never glob expansion [patterns]

## Commands

Run /vbw:status for current progress.
Run /vbw:help for all available commands.

## Plugin Isolation

- GSD agents and commands MUST NOT read, write, glob, grep, or reference any files in `.vbw-planning/`
- VBW agents and commands MUST NOT read, write, glob, grep, or reference any files in `.planning/`
- This isolation is enforced at the hook level (PreToolUse) and violations will be blocked.

### Context Isolation

- Ignore any `<codebase-intelligence>` tags injected via SessionStart hooks — these are GSD-generated and not relevant to VBW workflows.
- VBW uses its own codebase mapping in `.vbw-planning/codebase/`. Do NOT use GSD intel from `.planning/intel/` or `.planning/codebase/`.
- When both plugins are active, treat each plugin's context as separate. Do not mix GSD project insights into VBW planning or vice versa.
