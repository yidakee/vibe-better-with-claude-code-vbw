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

1. **Already initialized:** If .vbw-planning/config.json exists, STOP: "VBW is already initialized. Use /vbw:config to modify settings or /vbw:implement to start building."
2. **jq required:** Run `command -v jq` via Bash. If jq is not found, STOP with:
   "VBW requires jq for its hook system. Install it:
   - macOS: `brew install jq`
   - Linux: `apt install jq` or `yum install jq`
   - Manual: https://jqlang.github.io/jq/download/
   Then re-run /vbw:init."
   Do NOT proceed to Step 0 without jq.
3. **Brownfield detection:** Check if the project already has source files. Try these in order, stop at the first that succeeds:
   - **Git repo:** Run `git ls-files --error-unmatch . 2>/dev/null | head -5`. If it returns any files, BROWNFIELD=true.
   - **No git / not initialized:** Use Glob to check for any files (`**/*.*`) excluding `.vbw-planning/`, `.claude/`, `node_modules/`, and `.git/`. If matches exist, BROWNFIELD=true.
   Do not restrict detection to specific file extensions — shell scripts, config files, markdown, C++, Rust, CSS, HTML, and any other language all count.

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

### Step 1.5: Install git hooks

1. Check if this is a git repository by running `git rev-parse --git-dir` via Bash.
2. If yes, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-hooks.sh` via Bash and capture stderr output.
3. Display the result based on the output:
   - If output contains "Installed": `✓ Git hooks installed (pre-push)`
   - If output contains "already installed": `✓ Git hooks (already installed)`
   - If the git check failed (not a git repo): `○ Git hooks skipped (not a git repository)`

### Step 2: Brownfield detection + discovery

**2a. Brownfield detection and file count:**

If BROWNFIELD=true:
1. Count source files by extension (Glob), excluding `.vbw-planning/`, `node_modules/`, `.git/`, `vendor/`, `dist/`, `build/`, `target/`, `.next/`, `__pycache__/`, `.venv/`, `coverage/`.
2. Store `SOURCE_FILE_COUNT` from this count.
3. Check for test files, CI/CD, Docker, monorepo indicators.
4. Add Codebase Profile section to STATE.md.

**2b. Run detect-stack (foreground):**

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh "$(pwd)"`.

Save the full JSON result but do NOT display curated suggestions yet. Only display the detected stack:
```
  ✓ Stack: {comma-separated detected_stack items}
```

**2c. Launch codebase mapping (adaptive):**

- If **greenfield** (BROWNFIELD=false): skip mapping entirely. Display: `○ Greenfield — skipping codebase mapping`
- If `SOURCE_FILE_COUNT < 200`: run map **inline** (synchronous). Read `${CLAUDE_PLUGIN_ROOT}/commands/map.md` and follow it directly. Solo mode completes fast. Display per-document progress as the map command outputs it.
- If `SOURCE_FILE_COUNT >= 200`: launch map **in background**. Read `${CLAUDE_PLUGIN_ROOT}/commands/map.md` and follow it as a background operation with Scout teammates. Display: `◆ Codebase mapping started in background ({SOURCE_FILE_COUNT} files)`

**2d. find-skills bootstrap** — check `find_skills_available` from the detect-stack JSON result:

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

**3a. Wait for mapping (if background):**

- If map ran inline (solo mode) or was skipped: proceed immediately.
- If map ran in background: wait for it to complete. Display:
  ```
  ◆ Waiting for codebase mapping...
  ```
  Then when complete:
  ```
  ✓ Codebase mapped ({document-count} documents)
  ```

**3b. Augment with map data:**

If `.vbw-planning/codebase/STACK.md` exists (mapping completed), read it to extract additional stack components that `detect-stack.sh` may have missed (e.g., frameworks detected through code analysis rather than manifest files). Merge these into `detected_stack[]`.

**3c. Parallel registry search** — if find-skills is available (either was already installed or just installed in 2d):

- If `detected_stack[]` is non-empty (including any augmented items from 3b): run `npx skills find "<stack-item>"` for ALL detected stack items **in parallel** (use multiple concurrent Bash tool calls in the SAME message). Collect and deduplicate results against already-installed skills.
- If `detected_stack[]` is empty: run a general search based on the project type (e.g., if there are .sh files, search "shell scripting"; if .md files dominate, search "documentation").
- Display registry results with `(registry)` attribution.

**3d. Unified skill prompt** — combine curated suggestions from detect-stack (saved in 2b) with registry results (from 3c) into a single AskUserQuestion using multiSelect. Tag each with `(curated)` or `(registry)`. Max 4 options. Include "Skip" as an option. For selected skills, run `npx skills add <skill> -g -y`.

**3e. Write Skills section to STATE.md** — using the format from `${CLAUDE_PLUGIN_ROOT}/references/skill-discovery.md` (SKIL-05).

### Step 3.5: Generate bootstrap CLAUDE.md

Write a CLAUDE.md at the project root. This is auto-loaded by Claude Code into every session, so it ensures VBW conventions are enforced from the very first interaction — even before `/vbw:implement` defines the project.

`/vbw:implement` will later regenerate CLAUDE.md with project-specific content. This bootstrap version establishes behavioral rules only.

Write the following to `CLAUDE.md` (adjust installed skills list from Step 3e):

```markdown
# VBW-Managed Project

This project uses VBW (Vibe Better with Claude Code) for structured development.

## VBW Rules

- **Always use VBW commands** for project work. Do not manually edit files in `.vbw-planning/`.
- **Commit format:** `{type}({scope}): {description}` — types: feat, fix, test, refactor, perf, docs, style, chore.
- **One commit per task.** Each task in a plan gets exactly one atomic commit.
- **Never commit secrets.** Do not stage .env, .pem, .key, credentials, or token files.
- **Plan before building.** Use /vbw:plan before /vbw:execute. Plans are the source of truth.
- **Do not fabricate content.** Only use what the user explicitly states in project-defining flows.

## State

- Planning directory: `.vbw-planning/`
- Project not yet defined — run /vbw:implement to set up project identity and roadmap.

## Installed Skills

{list installed skills from STATE.md Skills section, or "None" if empty}

## Commands

Run /vbw:status for current progress.
Run /vbw:help for all available commands.
```

Keep under 200 lines. Add `✓ CLAUDE.md` to the summary output.

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
  ✓ CLAUDE.md                  (bootstrap)
  {include next line only if statusline was installed during Step 0b}
  ✓ Statusline (restart to activate)

  {include Codebase block if mapping ran}
  ✓ Codebase mapped ({document-count} documents)

  {include Skills block only if skills were discovered in Step 3}
  Skills:
    Installed: {count} ({names})
    Stack:     {detected, including map-augmented items}
  {✓ Skills.sh registry (available) — if find-skills is installed}
  {○ Skills.sh registry (skipped) — if find-skills was declined or unavailable}
```

Then auto-launch `/vbw:implement` by reading `${CLAUDE_PLUGIN_ROOT}/commands/implement.md` and following it.

If greenfield:
```
➜ Next Up
  /vbw:implement -- Define your project and start building
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for init completion
- File Checklist (✓ prefix) for created files
- ○ for pending items
- Next Up Block for navigation
- No ANSI color codes
