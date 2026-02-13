---
name: vbw:help
disable-model-invocation: true
description: Display all available VBW commands with descriptions and usage examples.
argument-hint: [command-name]
allowed-tools: Read, Glob
---

# VBW Help $ARGUMENTS

## Behavior

**No args:** Show all commands grouped by stage (mark all ✓).
**With arg:** Read `${CLAUDE_PLUGIN_ROOT}/commands/{name}.md`, display: name, description, usage, args, related.

## Commands

**Lifecycle:** ✓ init (scaffold) · ✓ vibe (smart router -- plan, execute, discuss, archive, and more)
**Monitoring:** ✓ status (dashboard) · ✓ qa (deep verify)
**Quick Actions:** ✓ fix (quick fix) · ✓ debug (investigation) · ✓ todo (backlog)
**Session:** ✓ pause (save notes) · ✓ resume (restore context)
**Codebase:** ✓ map (Scout analysis) · ✓ research (standalone)
**Config:** ✓ skills (community skills) · ✓ config (settings, model profiles) · ✓ help (this) · ✓ whats-new (changelog) · ✓ update (version) · ✓ uninstall (removal)

## Architecture

- /vbw:vibe --execute creates Dev team for parallel plans. /vbw:map creates Scout team. Session IS the lead.
- Continuous verification via PostToolUse, TaskCompleted, TeammateIdle hooks. /vbw:qa is on-demand.
- /vbw:config maps skills to hook events (skill-hook wiring).

## Model Profiles

Control which Claude model each agent uses (cost optimization):
- `/vbw:config model_profile quality` -- Opus for Lead/Dev/Debugger/Architect, Sonnet for QA, Haiku for Scout (~$2.80/phase)
- `/vbw:config model_profile balanced` -- Sonnet for most, Haiku for Scout (~$1.40/phase, default)
- `/vbw:config model_profile budget` -- Sonnet for critical agents, Haiku for QA/Scout (~$0.70/phase)
- `/vbw:config model_override dev opus` -- Override single agent without changing profile
- Interactive mode: Select "Model Profile" → "Configure each agent individually" to set models per-agent (6 questions across 2 rounds). Status display marks overridden agents with asterisk (*).

See: @references/model-profiles.md for full preset definitions and cost comparison.

## Getting Started

➜ /vbw:init -> /vbw:vibe -> /vbw:vibe --archive
Optional: /vbw:config model_profile <quality|balanced|budget> to optimize cost
`/vbw:help <command>` for details.

## GSD Import

Migrating from GSD? VBW automatically detects existing GSD projects during initialization.

**During /vbw:init:**
- Detects `.planning/` directory (GSD's planning folder)
- Prompts: "GSD project detected. Import work history?"
- If approved: copies `.planning/` to `.vbw-planning/gsd-archive/` (original preserved)
- Generates INDEX.json with phase metadata, milestones, and quick paths
- Continues with normal VBW initialization

**What's archived:**
- All GSD planning files (ROADMAP, PROJECT, phases, summaries, plans)
- Lightweight JSON index for fast agent reference
- Original `.planning/` remains untouched (continues working with GSD if needed)

**After import:**
- VBW agents can reference archived GSD files when needed
- Index provides quick lookup: phases completed, milestones, key file paths
- GSD isolation can be enabled to prevent cross-contamination

See: /vbw:init for the import flow, docs/migration-gsd-to-vbw.md for detailed migration guide.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — double-line box, ✓ available, ➜ Getting Started, no ANSI.
