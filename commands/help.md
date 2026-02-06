---
description: Display all available VBW commands with descriptions and usage examples.
argument-hint: [command-name]
allowed-tools: Read, Glob
---

# VBW Help $ARGUMENTS

## Behavior

### No arguments: Display complete command reference

Show all VBW commands grouped by lifecycle stage. Use a double-line box for the header.

Mark available commands (those with .md files in commands/ directory) with ✓.
Mark planned commands with ○ and their target phase.

### With argument: Display detailed command help

If `$ARGUMENTS` matches a command name (e.g., `init`, `config`), read that command file using the Read tool via `${CLAUDE_PLUGIN_ROOT}/commands/{name}.md` and display:
- Command name and description
- Usage examples
- Available arguments
- Related commands

If the command is not yet implemented, show its planned phase and description.

## Command Reference

### Lifecycle

| Status | Command       | Description                                             |
|--------|---------------|---------------------------------------------------------|
| ✓      | /vbw:init     | Initialize a new VBW project with .planning directory   |
| ✓      | /vbw:plan     | Plan a phase: research, decompose, self-review          |
| ✓      | /vbw:build    | Execute a planned phase through Dev agents              |
| ○      | /vbw:ship     | Complete and archive a milestone [Phase 6]              |

### Monitoring

| Status | Command       | Description                                             |
|--------|---------------|---------------------------------------------------------|
| ✓      | /vbw:status   | View progress dashboard with metrics                    |
| ○      | /vbw:qa       | Run verification on completed work [Phase 8]            |

### Supporting

| Status | Command       | Description                                             |
|--------|---------------|---------------------------------------------------------|
| ✓      | /vbw:config   | View and modify VBW settings                            |
| ✓      | /vbw:help     | This help guide                                         |
| ○      | /vbw:fix      | Quick task with commit discipline [Phase 8]             |
| ○      | /vbw:debug    | Systematic bug investigation [Phase 8]                  |
| ○      | /vbw:todo     | Add item to backlog [Phase 7]                           |
| ○      | /vbw:pause    | Save session context for later [Phase 7]                |
| ○      | /vbw:resume   | Restore previous session context [Phase 7]              |

### Advanced

| Status | Command          | Description                                          |
|--------|------------------|------------------------------------------------------|
| ✓      | /vbw:map         | Analyze existing codebase with parallel mapper agents|
| ✓      | /vbw:discuss     | Gather context before planning                       |
| ✓      | /vbw:assumptions | Surface Claude's assumptions                         |
| ✓      | /vbw:research    | Standalone research task                             |
| ○      | /vbw:milestone   | Start new milestone [Phase 6]                        |
| ○      | /vbw:switch      | Switch active milestone [Phase 6]                    |
| ○      | /vbw:audit       | Audit milestone before shipping [Phase 6]            |
| ○      | /vbw:add-phase   | Add phase to roadmap [Phase 6]                       |
| ○      | /vbw:insert-phase| Insert urgent phase into roadmap [Phase 6]           |
| ○      | /vbw:remove-phase| Remove future phase from roadmap [Phase 6]           |
| ○      | /vbw:whats-new   | View changelog and recent updates [Phase 9]          |
| ○      | /vbw:update      | Update VBW to latest version [Phase 9]               |

**Legend:** ✓ Available now | ○ Planned (see phase)

## Getting Started

New to VBW? Follow these steps:

1. `/vbw:init "My project description"` -- Set up your project
2. `/vbw:discuss 1` -- Clarify your vision for Phase 1 (optional)
3. `/vbw:plan 1` -- Plan your first phase
4. `/vbw:build 1` -- Execute the plan
5. `/vbw:qa 1` -- Verify the work [Phase 8]
6. `/vbw:ship` -- Ship the milestone [Phase 6]

Run `/vbw:help <command>` for detailed help on any command.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for visual formatting:
- Double-line box for the help header banner
- ✓ for available commands, ○ for planned commands
- ➜ for navigation prompts in Getting Started
- No ANSI color codes
