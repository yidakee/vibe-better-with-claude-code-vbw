---
name: init
disable-model-invocation: true
description: Set up environment and scaffold .vbw-planning directory with templates and config.
argument-hint:
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Init

## Context

Working directory: `!`pwd``

Existing state:
```
!`ls -la .vbw-planning 2>/dev/null || echo "No .vbw-planning directory"`
```

Project files:
```
!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No detected project files"`
```

Installed skills:
```
!`ls ~/.claude/skills/ 2>/dev/null || echo "No global skills"`
```

```
!`ls .claude/skills/ 2>/dev/null || echo "No project skills"`
```

## Guard

1. **Already initialized:** If .vbw-planning/config.json exists, STOP: "VBW is already initialized. Use /vbw:config to modify settings or /vbw:new to define your project."
2. **Brownfield detection:** If project files AND source files (*.ts, *.js, *.py, *.go, *.rs, *.java, *.rb) exist, set BROWNFIELD=true.

## Steps

### Step 0: Environment setup (settings.json)

**CRITICAL: Complete this ENTIRE step — including writing settings.json — BEFORE moving to Step 1. Do NOT scaffold anything until Step 0 is fully resolved. Use AskUserQuestion to ask about Agent Teams and statusline. Wait for answers. Write settings.json. Only then proceed.**

Read `~/.claude/settings.json` once (create `{}` if missing).

**0a. Agent Teams check:**

Check if `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is `"1"`. If already enabled, display "✓ Agent Teams — enabled" and move to 0b.

If NOT enabled, ask the user (use AskUserQuestion):
```
⚠ Agent Teams is not enabled

VBW uses Agent Teams for parallel builds and codebase mapping.
Enable it now?
```

If approved: set `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to `"1"`.
If declined: display "○ Skipped."

**0b. Statusline check:**

Check the `statusLine` field. It may be a string or an object with a `command` field. Handle both.

Classify:
- **HAS_VBW**: The value (string or object's `command`) contains `vbw-statusline` → display "✓ Statusline — installed" and skip to 0c
- **HAS_OTHER**: Non-empty value that does NOT contain `vbw-statusline`
- **EMPTY**: Field is missing, null, or empty

If HAS_OTHER or EMPTY, ask the user (use AskUserQuestion):
```
○ VBW includes a custom status line showing phase progress, context usage,
  cost, duration, and more — updated after every response. Install it?
```
(If HAS_OTHER, mention that a different statusline is currently configured and VBW's would replace it.)

If approved, set `statusLine` to:
```json
{"type": "command", "command": "bash -c 'f=$(ls -1 \"$HOME\"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"$f\" ] && exec bash \"$f\"'"}
```
The object format with `type` and `command` is **required** by the settings schema; a plain string will fail validation silently.

If declined: display "○ Skipped. Run /vbw:config to install it later."

**0c. Write settings.json** if any changes were made (Agent Teams and/or statusline). Write all changes in a single file write.

Display a summary of what was configured:
```
Environment setup complete:
  {✓ or ○} Agent Teams
  {✓ or ○} Statusline {add "(restart to activate)" if newly installed}
```

### Step 1: Scaffold directory

Read each template from `${CLAUDE_PLUGIN_ROOT}/templates/` and write to .vbw-planning/:

| Target                        | Source                                            |
|-------------------------------|---------------------------------------------------|
| .vbw-planning/PROJECT.md      | ${CLAUDE_PLUGIN_ROOT}/templates/PROJECT.md        |
| .vbw-planning/REQUIREMENTS.md | ${CLAUDE_PLUGIN_ROOT}/templates/REQUIREMENTS.md   |
| .vbw-planning/ROADMAP.md      | ${CLAUDE_PLUGIN_ROOT}/templates/ROADMAP.md        |
| .vbw-planning/STATE.md        | ${CLAUDE_PLUGIN_ROOT}/templates/STATE.md          |
| .vbw-planning/config.json     | ${CLAUDE_PLUGIN_ROOT}/config/defaults.json        |

Create `.vbw-planning/phases/` directory.

Ensure config.json includes `"agent_teams": true`.

### Step 2: Brownfield detection summary

If BROWNFIELD=true:
1. Count source files by extension (Glob)
2. Check for test files, CI/CD, Docker, monorepo indicators
3. Add Codebase Profile section to STATE.md

### Step 3: Skill discovery

Follow `${CLAUDE_PLUGIN_ROOT}/references/skill-discovery.md`:
1. Scan installed skills (global, project, MCP)
2. Detect stack via `${CLAUDE_PLUGIN_ROOT}/config/stack-mappings.json`
3. Suggest uninstalled skills (if skill_suggestions enabled in config)
4. Write Skills section to STATE.md

**IMPORTANT:** Do NOT mention `find-skills` to the user during init. The find-skills meta-skill is only used during `/vbw:plan` for dynamic registry lookups. During init, curated stack mappings are sufficient. If find-skills is not installed, proceed silently — do not report it as missing or suggest installing it.

### Step 4: Present summary

```
╔══════════════════════════════════════════╗
║  VBW Environment Initialized             ║
╚══════════════════════════════════════════╝

  ✓ .vbw-planning/PROJECT.md      (template)
  ✓ .vbw-planning/REQUIREMENTS.md (template)
  ✓ .vbw-planning/ROADMAP.md      (template)
  ✓ .vbw-planning/STATE.md        (template)
  ✓ .vbw-planning/config.json
  ✓ .vbw-planning/phases/
  {include next line only if statusline was installed during Step 0b}
  ✓ Statusline (restart to activate)

  {include Skills block only if skills were discovered in Step 3}
  Skills:
    Installed: {count} ({names})
    Suggested: {count} ({names})
    Stack:     {detected}
```

If BROWNFIELD:
```
  ⚠ Existing codebase detected ({file-count} source files)
```

```
➜ Next Up
  /vbw:new -- Define your project (name, requirements, roadmap)
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for init completion
- File Checklist (✓ prefix) for created files
- ○ for pending items
- Next Up Block for navigation
- No ANSI color codes
