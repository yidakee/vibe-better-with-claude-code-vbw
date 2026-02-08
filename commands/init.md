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

### Step 2: Brownfield detection + parallel discovery

**2a. Brownfield detection (quick):**

If BROWNFIELD=true:
1. Count source files by extension (Glob)
2. Check for test files, CI/CD, Docker, monorepo indicators
3. Add Codebase Profile section to STATE.md

**2b. Parallel launch — run ALL of the following concurrently (use parallel tool calls):**

Launch these tasks in the SAME message so they execute in parallel:

| Track | What | How |
|-------|------|-----|
| **Map** (brownfield only) | Codebase mapping | Launch `/vbw:map` by following `@${CLAUDE_PLUGIN_ROOT}/commands/map.md`. Runs as a background operation with Scout teammates. |
| **Detect** | Stack detection | Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh "$(pwd)"` |

If greenfield (BROWNFIELD=false), skip the Map track — only run Detect.

**2c. Process detect-stack.sh results (immediately after Detect completes):**

The Detect track returns JSON with: `detected_stack[]`, `installed.global[]`, `installed.project[]`, `recommended_skills[]`, `suggestions[]`, `find_skills_available`.

Display the detected stack and installed skills.

Display curated suggestions from `suggestions[]`. For each suggestion, show the install command: `npx skills add <skill-name> -g -y`.

**2d. find-skills bootstrap** — check `find_skills_available` from the JSON result:

- If `true`: display "✓ Skills.sh registry — available" and proceed to Step 3.
- If `false`: ask the user with AskUserQuestion:
```
○ Skills.sh Registry

VBW can search the Skills.sh registry (~2000 community skills) to find
skills matching your project. This requires the find-skills meta-skill.
Install it now?
```
Options: "Install (Recommended)" / "Skip"

If approved: run `npx skills add vercel-labs/skills --skill find-skills -g -y` and display the result.
If declined: display "○ Skipped. Run /vbw:skills later to search the registry."

### Step 3: Convergence — augment and search

This step waits for codebase mapping to finish (if brownfield) before proceeding.

**3a. Augment with map data (brownfield only):**

If BROWNFIELD=true and `.vbw-planning/codebase/STACK.md` exists, read it to extract additional stack components that `detect-stack.sh` may have missed (e.g., frameworks detected through code analysis rather than manifest files). Merge these into `detected_stack[]`.

Display:
```
  ✓ Codebase mapped ({file-count} source files)
```

**3b. Parallel registry search** — if find-skills is available (either was already installed or just installed in 2d):

- If `detected_stack[]` is non-empty (including any augmented items from 3a): run `npx skills find "<stack-item>"` for ALL detected stack items **in parallel** (use multiple concurrent Bash tool calls in the SAME message). Collect and deduplicate results against already-installed skills.
- If `detected_stack[]` is empty: run a general search based on the project type (e.g., if there are .sh files, search "shell scripting"; if .md files dominate, search "documentation").
- Display registry results with `(registry)` attribution.

**3c. Offer to install** — if there are any suggestions (curated from 2c + registry from 3b combined), ask the user with AskUserQuestion using multiSelect which ones to install. Max 4 options. Include "Skip" as an option. For selected skills, run `npx skills add <skill> -g -y`.

**3d. Write Skills section to STATE.md** — using the format from `${CLAUDE_PLUGIN_ROOT}/references/skill-discovery.md` (SKIL-05).

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

  {include Codebase block only if BROWNFIELD}
  ✓ Codebase mapped ({document-count} documents)

  {include Skills block only if skills were discovered in Step 3}
  Skills:
    Installed: {count} ({names})
    Stack:     {detected, including map-augmented items}
  {✓ Skills.sh registry (available) — if find-skills is installed}
  {○ Skills.sh registry (skipped) — if find-skills was declined or unavailable}
```

Then auto-launch `/vbw:new` by following `@${CLAUDE_PLUGIN_ROOT}/commands/new.md`.

If greenfield:
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
