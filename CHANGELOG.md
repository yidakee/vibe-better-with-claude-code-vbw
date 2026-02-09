# Changelog

All notable changes to VBW will be documented in this file.

## [Unreleased]

### Added

- **Frontmatter description validation hook** — new `validate-frontmatter.sh` PostToolUse hook catches multi-line and empty `description` fields in markdown frontmatter at write time, preventing silent breakage of plugin command/skill discovery. Non-blocking (warning only).

### Fixed

- **jq dependency detection at all entry points** — `session-start.sh` now warns that all 17 quality gates are disabled when jq is missing. `detect-stack.sh` exits with a JSON error before any jq-dependent logic. `/vbw:init` has a pre-flight check with platform-specific install instructions (brew/apt).
- **Version sync enforcement at commit and push time** — `validate-commit.sh` now runs `bump-version.sh --verify` and warns (non-blocking) when the 4 version files diverge. `pre-push-hook.sh` runs the same check but blocks the push (exit 1) when files are out of sync.
- **jq guard in validate-commit.sh** — hook exits 0 silently when jq is missing instead of producing confusing error output.

## [1.0.69] - 2026-02-09

### Changed

- **Adaptive map sizing** — `/vbw:map` now sizes the mapping strategy to the codebase: solo (< 200 files, no Agent Team), duo (200–1000 files, 2 scouts), quad (1000+ files, 4 scouts). Previously always spawned 4 Scout teammates regardless of project size, causing 6+ minutes of overhead for small codebases.
- **`--tier=solo|duo|quad` override** — force a specific mapping tier via argument, bypassing auto-detection.
- **Solo mode maps inline** — orchestrator analyzes all 4 domains sequentially and writes documents directly, skipping TeamCreate/SendMessage/shutdown overhead entirely.
- **Agent Teams guard in map** — forces solo mode with `⚠` note when Agent Teams is not enabled.
- **`mapping_tier` in META.md** — map output now records which tier was used, displayed in the completion banner.
- **Init flow reorder** — `/vbw:init` no longer shows skill suggestions before codebase mapping completes. Detect-stack results are saved silently (only stack summary shown), mapping runs, then curated + registry suggestions are combined into a single unified prompt.
- **Adaptive mapping in init** — small codebases (< 200 files) run map inline synchronously (~30s), larger codebases launch map in background. Greenfield projects skip mapping entirely.
- **Unified skill prompt** — curated and registry skill suggestions now appear in one AskUserQuestion with `(curated)` / `(registry)` tags, instead of showing curated suggestions early and registry results later.
- **Continuous progress output** — both map and init now display progress per-document (solo) or per-scout (duo/quad) with no silent gaps.

## [1.0.67] - 2026-02-09

### Fixed

- **Brownfield detection is now language-agnostic** — removed hardcoded extension list (`*.ts, *.js, *.py, *.go, *.rs, *.java, *.rb`) from both `init.md` and `new.md`. Detection now cascades: `git ls-files` first, then broad Glob fallback for non-git projects. Shell scripts, C++, CSS, HTML, and any other file type all count.
- **Codebase mapping always runs during init** — removed `(brownfield only)` gate from the Map track. The map command handles empty projects via its own guard, so init no longer needs to pre-filter.

### Changed

- **Removed per-file confirmation gates from `/vbw:new`** — the flow no longer prompts "Does this look right?" for each file (PROJECT.md, REQUIREMENTS.md, ROADMAP.md). Files are written immediately after gathering answers, with a single summary at the end. Users can re-run with `--re-scope` to redefine.

## [1.0.60] - 2026-02-08

### Fixed

- **`eval` removed from statusline** — replaced `eval "$(jq ...)"` with safe `IFS='|' read` parsing for Anthropic usage API response, eliminating shell injection risk (S1)
- **Security filter now fail-closed** — `security-filter.sh` exits 2 (block) on jq failures, empty stdin, or malformed data instead of silently allowing access (S2)
- **Unquoted variables fixed** — replaced unsafe `xargs rm -rf` with `while read` loops in session-start.sh, cache-nuke.sh; quoted `$PROJECT_ROOT` in file-guard.sh; fixed word-splitting in validate-commit.sh (S3)
- **Safe `git reset --hard`** — session-start.sh now checks `git diff --quiet` before resetting marketplace checkout, skips with warning if dirty (S5)
- **Temp file ownership checks** — statusline cache reads now verify file ownership with `[ -O "$file" ]` before trusting cached data (S6)
- **Settings mutation backup** — session-start.sh creates `.bak` before modifying `~/.claude/settings.json`, restores on jq failure (P4)
- **Cache cleanup race condition** — mkdir-based lock prevents concurrent session-start scripts from racing on cache cleanup (R2)
- **`set -u` strict mode** — added to all 13 hook scripts to catch undefined variable typos, with proper `${VAR:-}` defaults (R1)

### Added

- **`sort -V` fallback in hooks** — all 17 hook entries now use `(sort -V 2>/dev/null || sort -t. -k1,1n -k2,2n -k3,3n)` for systems without GNU sort version sorting (P3)
- **`_note` key in hooks.json** — documents the hard-coded cache path coupling and why it cannot be abstracted (M2)
- **`--verify` flag for bump-version.sh** — checks all 4 version files are in sync without bumping, exits 1 with diff report on mismatch (P1)
- **Offline version bump fallback** — bump-version.sh falls back to local VERSION when remote fetch fails instead of hard-exiting (M4)
- **jq availability check** — session-start.sh warns users if jq is missing with install instructions (M3)
- **Version management docs** — CONTRIBUTING.md now documents the 4-file sync, bump-version.sh workflow, and --verify flag (D3)

### Changed

- **Marketplace.json schemas aligned** — root and plugin marketplace.json now share consistent owner, metadata, and license fields (D1)
- **Owner name encoding consistent** — all manifest files use "Tiago Serôdio" with circumflex accent (D2)
- **`.claude/settings.local.json` gitignored** — user-specific permission settings no longer tracked in git (I3)

## [1.0.59] - 2026-02-08

### Fixed

- **Installation instructions cause paste error** — both install commands were in a single code block, so users who copy-pasted got them concatenated into one command with a malformed URL. Split into separate code blocks with explicit Step 1/Step 2 labels and a warning not to paste together.

## [1.0.58] - 2026-02-08

### Changed

- **Init reordering: map before skills** — for brownfield projects, `/vbw:init` now runs codebase mapping (Step 2) before skill discovery (Step 3). Previously, skills were suggested blind, then map ran at the end. Now map output (`STACK.md`) augments `detect-stack.sh` results, so skill suggestions are based on actual codebase analysis rather than just manifest file detection.
- **New Step 3a+: map-augmented stack detection** — after `detect-stack.sh` runs, init reads `.vbw-planning/codebase/STACK.md` to extract additional stack components found through deep code analysis (e.g., frameworks detected in imports, not just in `package.json`). These are merged into `detected_stack[]` for registry search.
- **README flow chart and tutorial updated** — brownfield path now shows map → skills → new sequence. Command table and tutorial text reflect that skill discovery is informed by map data.

## [1.0.56] - 2026-02-08

### Changed

- **Brownfield init auto-chains** — `/vbw:init` now auto-chains to `/vbw:map` then `/vbw:new` when an existing codebase is detected. Previously init stopped at "Next Up: /vbw:new" and the user had to run each command separately.
- **`/vbw:new` Next Up offers discuss and implement** — after project definition, the Next Up block now suggests `/vbw:discuss` and `/vbw:implement` instead of `/vbw:plan`. Reflects the actual user flow: gather context or jump straight to building.
- **Removed brownfield auto-map from `/vbw:new`** — codebase mapping for brownfield projects is now handled by init's auto-chain (init → map → new), eliminating the duplicate brownfield detection in new's Step 6.
- **README flow chart updated** — shows the greenfield/brownfield split at init, with brownfield auto-chaining through map and new. Tutorial and command table updated to match.

## [1.0.55] - 2026-02-08

### Changed

- **Skill wiring through plans** — Lead now reads relevant SKILL.md files during research and wires them into each PLAN.md via `@` references in `<context>` + `skills_used` frontmatter. Dev and QA consume skills through the existing `@` read path instead of separate STATE.md lookups.
- **Lead self-review validates skill wiring** — Stage 3 checklist now enforces that every `skills_used` entry has a matching `@` reference in the plan's context section.
- **QA reads `@`-referenced context** — QA now reads all `@`-referenced files from the plan (including skills), closing the gap where it previously only noted skills from STATE.md.
- **Init summary cleanup** — removed "Suggested: {count}" line from Step 4 summary (redundant after skill installation completes).

## [1.0.54] - 2026-02-08

### Added

- **find-skills bootstrap in `/vbw:init`** — init now offers to install the find-skills meta-skill and searches the Skills.sh registry (~2000 community skills) for matches. Previously init silently skipped registry search with no explanation when curated mappings had no match.
- **`~/.agents/skills/` path support** — `detect-stack.sh` now scans all three skill locations: `~/.claude/skills/`, `.claude/skills/`, and `~/.agents/skills/` (where the skills CLI installs). New `installed.agents` array in JSON output.
- **find-skills bootstrap in `/vbw:skills`** — the skills command now offers to install find-skills when missing instead of silently skipping registry search.
- **Proactive registry search in `/vbw:skills`** — when find-skills is available and detected stack items have no curated mapping, the command automatically searches the registry without requiring `--search`.
- **Better empty state in `/vbw:skills`** — when no stack is detected, shows example search queries instead of a dead end.

### Changed

- **Removed "do NOT mention find-skills during init" restriction** — init now proactively bootstraps find-skills and runs dynamic registry search (Steps 3c-3e)
- **`references/skill-discovery.md` SKIL-06** — find-skills bootstrap now runs during both `/vbw:init` and `/vbw:plan` (was plan-only)
- **`references/skill-discovery.md` SKIL-07** — dynamic discovery triggers during both `/vbw:init` and `/vbw:plan` (was plan-only)
- **`detect-stack.sh` find-skills detection** — checks both `~/.claude/skills/find-skills` and `~/.agents/skills/find-skills`

## [1.0.53] - 2026-02-08

### Fixed

- **Nuclear cache wipe during updates** — /vbw:update now completely wipes ALL cached versions before installing the new one, preventing stale file contamination. Previously, the cache directory could retain old files if the version number matched.
- **Cache integrity verification on session start** — session-start.sh now verifies critical files exist in the cache and nukes it if any are missing. This catches scenarios where files were added in a new version but the cache was already populated.
- **Always-sync global commands** — Global commands at ~/.claude/commands/vbw/ are now unconditionally synced from cache on every session start, not just when file counts differ. This prevents content-level staleness.
- **New scripts/cache-nuke.sh utility** — Standalone cache wipe script that removes plugin cache, global commands, and temp files. Used by /vbw:update and available for manual recovery.

## [1.0.52] - 2026-02-08

### Added

- `/vbw:skills` command: standalone skill discovery and installation from skills.sh — detects tech stack, suggests curated skills, searches the registry, and installs with one command
- `scripts/detect-stack.sh`: helper script that detects project tech stack, cross-references installed skills, and outputs suggestions as JSON — replaces 50+ inline LLM tool calls with one bash call

### Fixed

- `/vbw:init` Step 3 skill discovery never suggested skills on brownfield projects — root cause: SKIL-02 protocol was too complex for inline LLM execution (27 entries x multiple detect patterns). Now uses `detect-stack.sh` for reliable detection
- Wrong install command in `references/skill-discovery.md`: `npx @anthropic-ai/claude-code skills add` does not exist — replaced with correct `npx skills add <name> -g -y`
- Wrong `find-skills` install note in SKIL-06: replaced with correct `npx skills add vercel-labs/skills --skill find-skills -g -y`
- Both `marketplace.json` files said "27 commands" when there were already 28 — updated to 29

### Changed

- Command count: 28 to 29 across README, help, and both marketplace.json files
- `/vbw:init` Step 3 now calls `detect-stack.sh` directly instead of delegating to the 180-line skill-discovery.md protocol

## [1.0.51] - 2026-02-08

### Changed

- Updated statusline screenshot in `assets/statusline.png`

## [1.0.50] - 2026-02-08

### Added

- Security filter blocks `.planning/` directory (GSD's workspace) to prevent cross-tool contamination — `.vbw-planning/` is unaffected

## [1.0.49] - 2026-02-08

### Fixed

- `/vbw:*` prefix missing in autocomplete — root cause: marketplace checkout stuck at v1.0.9 (pre-migration `skills/` structure) while plugin cache had v1.0.48 (`commands/`). Claude Code read commands from the stale marketplace, not the cache
- `/vbw:update` now always runs `marketplace update` before `plugin update` to prevent marketplace staleness
- `session-start.sh` auto-syncs stale marketplace checkout when version mismatch detected

### Added

- Belt-and-suspenders: `session-start.sh` copies commands to `~/.claude/commands/vbw/` (global commands subdirectory pattern, same as GSD) — guarantees `/vbw:*` prefix regardless of plugin system behavior
- `/vbw:uninstall` now cleans up `~/.claude/commands/vbw/` directory

## [1.0.47] - 2026-02-08

### Changed

- Migrated all 28 slash commands from `skills/*/SKILL.md` to `commands/*.md` — autocomplete now shows `/vbw:help` instead of `/help (vbw)`
- Updated `@` references in implement, new, and help commands to point to `commands/` paths
- Updated path references in `references/verification-protocol.md`, `references/phase-detection.md`, and `references/skill-discovery.md`
- Updated project structure in README.md and CONTRIBUTING.md

### Removed

- `skills/` directory (replaced by `commands/`)

## [1.0.46] - 2026-02-08

### Fixed

- Existing users' `statusLine` in `~/.claude/settings.json` not updating after plugin update — users who installed with the old `for f in` glob pattern were stuck on the oldest cached version forever
- `session-start.sh` now auto-migrates the statusLine command to the correct `sort -V | tail -1` pattern on every session start (idempotent, no-op if already correct)

## [1.0.45] - 2026-02-08

### Fixed

- All 17 hook commands and statusline resolved the **oldest** cached version instead of the latest — glob `for f in ...` expands alphabetically (`1.0.27` < `1.0.44`), so hooks always ran stale code after updates
- Same stale-version bug in `skill-hook-dispatch.sh` internal glob loop, `/vbw:plan` map-staleness inline execution, and `/vbw:init` statusline template
- `/vbw:update` Step 5 cache cleanup now verifies removal succeeded and retries if old versions persist

## [1.0.41] - 2026-02-08

### Added

- `/vbw:implement` command: unified plan+execute in one step with dual-condition phase auto-detection (needs plan+execute vs execute-only)
- `references/handoff-schemas.md`: 5 structured JSON schemas for agent-to-agent SendMessage communication (`scout_findings`, `dev_progress`, `dev_blocker`, `qa_result`, `debugger_report`)
- Version bump warning in `validate-commit.sh`: warns when non-version files are staged but VERSION is not (VBW plugin development only, guarded by `name = "vbw"`)
- Implement Command section in `references/phase-detection.md` with dual-condition detection algorithm
- Schema-based Output Format in Scout agent: structured JSON for teammate mode, plain markdown for standalone subagent mode
- Communication sections in Dev, QA, and Debugger agents referencing handoff schemas
- 5 new automation hook scripts: `map-staleness.sh`, `notification-log.sh`, `post-compact.sh`, `prompt-preflight.sh`, `session-stop.sh`, `state-updater.sh`
- `references/shared-patterns.md`: consolidated Initialization Guard and Agent Teams Shutdown Protocol
- Plan self-review step in Lead agent
- Per-plan dependency wiring in `/vbw:execute` (replaces wave-level blocking)
- Per-wave QA overlap with later-wave Dev execution at Thorough/Balanced effort
- Scout model inheritance: Opus at Thorough/Balanced, Haiku at Fast/Turbo (was always inherited)
- REQ-ID tracing and must_haves testability instructions for Lead agent
- `references/vbw-brand-essentials.md`: extracted brand vocabulary as standalone reference

### Changed

- Command count: 27 → 28 across README and help (added `/vbw:implement`)
- 4 agent definitions (scout, dev, qa, debugger) now reference structured handoff schemas
- 4 skills (map, execute, debug, qa) now use structured schema communication with JSON parsing fallback
- `/vbw:execute` teammate communication protocol uses `dev_progress` and `dev_blocker` schemas
- `/vbw:map` Scout task descriptions specify `scout_findings` schema with domain field
- `/vbw:qa` spawn instructions and result parsing reference `qa_result` schema
- `/vbw:debug` competing hypotheses instructions reference `debugger_report` schema
- `/vbw:help` Getting Started now highlights `/vbw:implement` as the quick path
- README hook counts: 12 hooks/7 events → 17 hooks/11 events with expanded descriptions
- Statusline caching: batch formatting, 10s agent TTL, merged GitHub cache
- SUMMARY.md frontmatter simplified; STATE.md performance metrics removed
- REQUIREMENTS.md traceability consolidated to ROADMAP.md
- Init guard and shutdown protocol consolidated across 21 skills via shared-patterns.md
- Security filter regex consolidated; `.planning/` references fixed to `.vbw-planning/`
- Agent meta-justification instructions trimmed for token reduction

### Fixed

- 3 scripts referenced `.planning/` instead of `.vbw-planning/`
- GNU-only `grep -oP` replaced with POSIX-compatible patterns
- STATE/ROADMAP context injections now capped (`head -40`) to prevent token bloat

## [1.0.35] - 2026-02-08

### Added

- `name` field in YAML frontmatter for all 27 skills (was missing from all)
- `disable-model-invocation: true` for 8 lifecycle skills: execute, ship, uninstall, milestone, new, init, switch, remove-phase
- Step 3.5 in `/vbw:map`: lead writes 7 mapping documents from Scout SendMessage reports (Scouts no longer write files)
- Delegate permissionMode explanation note in `/vbw:execute` delegation directive
- VBW-scoped matcher on SubagentStop hook: only triggers for vbw-lead, vbw-dev, vbw-qa, vbw-scout, vbw-debugger, vbw-architect

### Changed

- `/vbw:map` Scout task descriptions: Scouts analyze and send findings via SendMessage instead of writing files directly (preserves platform-enforced read-only guarantee)
- `/vbw:map` Step 3 now uses explicit TaskCreate language matching execute skill convention
- Lead agent tools list: removed Task (was inconsistent with "Never spawns subagents" constraint)
- plugin.json author field: split into separate `name` and `url` fields
- Both marketplace.json files: aligned description ("27 commands"), keywords (6 terms), and category ("development")
- README.md: command count updated from 26 to 27 across all mentions; Lead agent table and permission model updated to remove Task

### Fixed

- PreToolUse hook: consolidated two duplicate security-filter entries (Read|Glob|Grep + Write|Edit) into one combined matcher (4 entries → 3)

## [1.0.34] - 2026-02-08

### Added

- Competing hypotheses for `/vbw:debug`: at Thorough effort + ambiguous bugs, spawns 3 parallel debugger teammates via Agent Teams instead of a single serial investigation
- Teammate mode for debugger agent: SendMessage-based structured reporting (hypothesis, evidence, confidence, fix recommendation)
- Delegation directive in `/vbw:execute`: defensive prose preventing team lead from implementing tasks itself (instruction-enforced guardrail)
- Model cost evaluation reference document: analysis of all 6 agent roles confirming current Opus/Sonnet/Haiku split is optimal
- Skill-hook dispatcher (`skill-hook-dispatch.sh`): runtime skill-hook wiring from config.json
- File-guard hook (`file-guard.sh`): blocks writes to files not declared in active plan's `files_modified`
- Plan approval gate: Dev teammates at Thorough effort spawned with `plan_mode_required` (platform-enforced review)
- TaskCreate blockedBy dependencies: wave execution now uses platform-enforced task ordering instead of prose instructions

### Changed

- Agent table in README expanded to 5 columns: Agent, Role, Tools, Denied, Mode
- Hook diagram in README expanded from 4 to 7 event types (added SubagentStop, SessionStart, PreCompact), grouped by purpose (Verification/Security/Lifecycle)
- Permission Model diagram in README: ungrouped Scout and QA (different capabilities), clarified Architect enforcement tiers
- Hook count corrected from "8 hook events" to "12 hooks across 7 event types" across all README mentions
- Architect agent: Bash removed from tools, added to disallowedTools (platform-enforced)
- QA agent description updated from "Read-only" to "Can run commands but cannot write files"
- `task-verify.sh` rewritten: reads stdin for task context, verifies task-specific commits via keyword matching (2+ threshold)
- `qa-gate.sh` rewritten: uses structural verification (SUMMARY.md existence OR conventional commit format) instead of keyword heuristics
- `security-filter.sh` routing expanded: now covers Write|Edit operations on sensitive files (was Read-only)
- Limitations section: "VBW solves them" softened to "VBW addresses all of them", shutdown attributed to platform, file conflicts mention runtime enforcement

### Fixed

- Lead agent missing Bash and WebFetch in README agent table
- README overstatement: "validates writes and commits continuously" replaced with accurate per-script descriptions
- README overstatement: "QA gate before teammate goes idle" replaced with "structural completion gate"
- README overstatement: "Verifies atomic commit exists" replaced with "verifies task-related commit via keyword matching"
- README overstatement: "VBW's team lead handles graceful shutdown sequencing" replaced with platform attribution
- Architect "Not code. Ever." claim now clarifies Edit/Bash are platform-denied while Write-to-plans is instruction-enforced

## [1.0.26] - 2026-02-07

### Added

- `/vbw:new` command: project definition flow (name, requirements, roadmap, CLAUDE.md) extracted from init
- Windows/WSL disclaimer in README "What Is This" section

### Changed

- `/vbw:init` is now technical setup only: environment config (Agent Teams, statusline), directory scaffold, stack detection, skill discovery. No longer asks project questions — points to `/vbw:new` as next step
- Guard clauses in `/vbw:plan`, `/vbw:status`, `/vbw:audit`, `/vbw:ship` updated to point to `/vbw:new` for missing roadmap
- `/vbw:resume` now detects unfilled templates and suggests `/vbw:new` instead of re-running init
- `/vbw:help` lifecycle flow updated: init -> new -> plan -> build -> ship
- README flow diagram, tutorial, and commands table updated for two-step setup

### Fixed

- All hook commands in hooks.json used `${CLAUDE_PLUGIN_ROOT}` which is not available as an env var in hook execution — replaced with glob-based path discovery pattern. This fixes "PreToolUse:Read hook error" on every Read/Glob/Grep call

## [1.0.25] - 2026-02-07

### Changed

- `/vbw:config` now offers interactive selection for common settings (effort, verification tier, max tasks, agent teams) when called without arguments. Direct `<setting> <value>` syntax still works for power users.

## [1.0.24] - 2026-02-07

### Fixed

- `/vbw:whats-new` now shows the current version's changelog when called without arguments (was showing nothing because it looked for entries newer than current)
- Agent activity indicator moved to Line 4 inline before GitHub link

## [1.0.23] - 2026-02-07

### Added

- Agent activity indicator in statusline Line 5: shows "N agents working" when background agents are active (process-based detection, 3s cache)
- Brownfield auto-map: `/vbw:init` now auto-triggers `/vbw:map` when existing codebase detected instead of just suggesting it

### Fixed

- Statusline "Branch: Phase complete}" corruption: removed unused `Status` field from STATE.md parsing that broke pipe-delimited cache format
- Security filter hook errors: fail-open on malformed input, missing jq, or empty stdin instead of crashing
- Sandbox permission errors in `/vbw:whats-new` and `/vbw:update`: removed `cat ${CLAUDE_PLUGIN_ROOT}/VERSION` from context blocks (plugin root is outside working directory sandbox)
- Stale version in `/vbw:update` whats-new suggestion: removed version argument entirely

## [1.0.20] - 2026-02-07

### Added

- Real-time statusline dashboard: context window bar, API usage limits (session/weekly/sonnet/extra), cost tracking, clickable GitHub link, agent team status
- Manifesto section and Discord invite in README
- Statusline screenshot showcase in README Features section

### Changed

- Renamed `/vbw:build` to `/vbw:execute` to avoid security filter collision with `build/` pattern
- Moved directory scaffold into Step 0 of `/vbw:init` so all setup completes before user questions
- Versioned cache filenames in statusline -- auto-clears stale caches on plugin update
- Simplified `/vbw:whats-new` to read directly from plugin root instead of cache paths (fixes sandbox permission errors)
- Improved `/vbw:update` messaging to clarify "since" version in whats-new suggestion

### Fixed

- Security filter no longer blocks `skills/build/SKILL.md` (resolved by rename to `skills/execute/`)
- Usage limits API: added required `anthropic-beta: oauth-2025-04-20` header
- Extra usage credits display: correctly converts cents to dollars
- Statusline `utilization` field: removed erroneous x100 (API returns 0-100, not 0-1)
- Weekly countdown now shows days when >= 24 hours
- Removed hardcoded `/vbw:plan 1` references (auto-detection handles phase selection)

## [1.0.0] - 2026-02-07

### Added

- Complete agent system: Scout, Architect, Lead, Dev, QA, Debugger with tool permissions and effort profiles
- Full command suite: 25 commands covering lifecycle, monitoring, supporting, and advanced operations
- Codebase mapping with parallel mapper agents, synthesis (INDEX.md, PATTERNS.md), and incremental refresh
- Branded visual output: Unicode box-drawing, semantic symbols, progress bars, graceful degradation
- Skills integration: stack detection, skill discovery, auto-install suggestions, agent skill awareness
- Concurrent milestones with isolated state, switching, shipping, and phase management
- Persistent memory: CLAUDE.md generation, pattern learning, session pause/resume
- Resilience: three-tier verification pipeline, failure recovery, intra-plan resume, observability
- Version management: /vbw:whats-new changelog viewer, /vbw:update plugin updater
- Effort profiles: Thorough, Balanced, Fast, Turbo controlling agent behavior
- Deviation handling: auto-fix minor, auto-add critical, auto-resolve blocking, checkpoint architectural

### Changed

- Expanded from 3 foundational commands to 25 complete commands
- VERSION bumped from 0.1.0 to 1.0.0

## [0.1.0] - 2026-02-06

### Added

- Initial plugin structure with plugin.json and marketplace.json
- Directory layout (skills/, agents/, references/, templates/, config/)
- Foundational commands: /vbw:init, /vbw:config, /vbw:help
- Artifact templates for PLAN.md, SUMMARY.md, VERIFICATION.md, PROJECT.md, STATE.md, REQUIREMENTS.md, ROADMAP.md
- Agent definition stubs for 6 agents
