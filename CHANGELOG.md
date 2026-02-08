# Changelog

All notable changes to VBW will be documented in this file.

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
