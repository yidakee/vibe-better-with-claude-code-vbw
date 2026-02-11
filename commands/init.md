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
Skills:
```
!`ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/" 2>/dev/null || echo "No global skills"`
```
```
!`ls .claude/skills/ 2>/dev/null || echo "No project skills"`
```

## Guard

1. **Already initialized:** If .vbw-planning/config.json exists, STOP: "VBW is already initialized. Use /vbw:config to modify settings or /vbw:vibe to start building."
2. **jq required:** `command -v jq` via Bash. If missing, STOP: "VBW requires jq. Install: macOS `brew install jq`, Linux `apt install jq`, Manual: https://jqlang.github.io/jq/download/ — then re-run /vbw:init." Do NOT proceed without jq.
3. **Brownfield detection:** Check for existing source files (stop at first match):
   - Git repo: `git ls-files --error-unmatch . 2>/dev/null | head -5` — any output = BROWNFIELD=true
   - No git: Glob `**/*.*` excluding `.vbw-planning/`, `.claude/`, `node_modules/`, `.git/` — any match = BROWNFIELD=true
   - All file types count (shell, config, markdown, C++, Rust, CSS, etc.)

## Steps

### Step 0: Environment setup (settings.json)

**CRITICAL: Complete ENTIRE step (including writing settings.json) BEFORE Step 1. Use AskUserQuestion for prompts. Wait for answers. Write settings.json. Only then proceed.**

**Resolve config directory:** Check env var `CLAUDE_CONFIG_DIR`. If set, use that as `CLAUDE_DIR`. Otherwise default to `~/.claude`. Use `CLAUDE_DIR` for all config paths in this command.

Read `CLAUDE_DIR/settings.json` (create `{}` if missing).

**0a. Agent Teams:** Check `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` == `"1"`.
- Enabled: display "✓ Agent Teams — enabled", go to 0b
- Not enabled: AskUserQuestion: "⚠ Agent Teams is not enabled\n\nVBW uses Agent Teams for parallel builds and codebase mapping.\nEnable it now?"
  - Approved: set to `"1"`. Declined: display "○ Skipped."

**0b. Statusline:** Read `statusLine` (may be string or object with `command` field).

| State | Condition | Action |
|-------|-----------|--------|
| HAS_VBW | Value contains `vbw-statusline` | Display "✓ Statusline — installed", skip to 0c |
| HAS_OTHER | Non-empty, no `vbw-statusline` | AskUserQuestion (mention replacement) |
| EMPTY | Missing/null/empty | AskUserQuestion |

AskUserQuestion text: "○ VBW includes a custom status line showing phase progress, context usage, cost, duration, and more — updated after every response. Install it?" (If HAS_OTHER, mention existing statusline would be replaced.)

If approved, set `statusLine` to:
```json
{"type": "command", "command": "bash -c 'f=$(ls -1 \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"$f\" ] && exec bash \"$f\"'"}
```
Object format with `type`+`command` is **required** — plain string fails silently.
If declined: display "○ Skipped. Run /vbw:config to install it later."

**0c. Write settings.json** if changed (single write). Display summary:
```
Environment setup complete:
  {✓ or ○} Agent Teams
  {✓ or ○} Statusline {add "(restart to activate)" if newly installed}
```

### Step 1: Scaffold directory

Read each template from `${CLAUDE_PLUGIN_ROOT}/templates/` and write to .vbw-planning/:

| Target | Source |
|--------|--------|
| .vbw-planning/PROJECT.md | ${CLAUDE_PLUGIN_ROOT}/templates/PROJECT.md |
| .vbw-planning/REQUIREMENTS.md | ${CLAUDE_PLUGIN_ROOT}/templates/REQUIREMENTS.md |
| .vbw-planning/ROADMAP.md | ${CLAUDE_PLUGIN_ROOT}/templates/ROADMAP.md |
| .vbw-planning/STATE.md | ${CLAUDE_PLUGIN_ROOT}/templates/STATE.md |
| .vbw-planning/config.json | ${CLAUDE_PLUGIN_ROOT}/config/defaults.json |

Create `.vbw-planning/phases/`. Ensure config.json includes `"agent_teams": true`.

### Step 1.5: Install git hooks

1. `git rev-parse --git-dir` — if not a git repo, display "○ Git hooks skipped (not a git repository)" and skip
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-hooks.sh`, display based on output:
   - Contains "Installed": `✓ Git hooks installed (pre-push)`
   - Contains "already installed": `✓ Git hooks (already installed)`

### Step 1.7: GSD isolation (conditional)

**1.7a. Detection:** `[ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/gsd" ] || [ -d ".planning" ]`
- Neither true: GSD_DETECTED=false, display nothing, skip to Step 2
- Either true: GSD_DETECTED=true, proceed to 1.7b

**1.7b. Consent:** AskUserQuestion: "GSD detected. Enable plugin isolation?\n\nThis adds a PreToolUse hook that prevents GSD commands and agents from\nreading or writing files in .vbw-planning/. VBW commands are unaffected."
Options: "Enable (Recommended)" / "Skip". If declined: "○ GSD isolation skipped", skip to Step 2.

**1.7c. Create isolation:** If approved:
1. `echo "enabled" > .vbw-planning/.gsd-isolation`
2. `echo "session" > .vbw-planning/.vbw-session`
3. `mkdir -p .claude`
4. Write `.claude/CLAUDE.md`:
```markdown
## Plugin Isolation

- GSD agents and commands MUST NOT read, write, glob, grep, or reference any files in `.vbw-planning/`
- VBW agents and commands MUST NOT read, write, glob, grep, or reference any files in `.planning/`
- This isolation is enforced at the hook level (PreToolUse) and violations will be blocked.
```
5. Display: `✓ GSD isolation enabled` + `✓ .vbw-planning/.gsd-isolation (flag)` + `✓ .claude/CLAUDE.md (instruction guard)`

Set GSD_ISOLATION_ENABLED=true for Step 3.5.

### Step 2: Brownfield detection + discovery

**2a.** If BROWNFIELD=true:
- Count source files by extension (Glob), excluding .vbw-planning/, node_modules/, .git/, vendor/, dist/, build/, target/, .next/, __pycache__/, .venv/, coverage/
- Store SOURCE_FILE_COUNT. Check for test files, CI/CD, Docker, monorepo indicators.
- Add Codebase Profile to STATE.md.

**2b.** Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh "$(pwd)"`. Save full JSON. Display: `✓ Stack: {comma-separated detected_stack items}`

**2c. Codebase mapping (adaptive):**
- Greenfield (BROWNFIELD=false): skip. Display: `○ Greenfield — skipping codebase mapping`
- SOURCE_FILE_COUNT < 200: run map **inline** — read `${CLAUDE_PLUGIN_ROOT}/commands/map.md` and follow directly
- SOURCE_FILE_COUNT >= 200: run map **inline** (blocking) — display: `◆ Codebase mapping started ({SOURCE_FILE_COUNT} files)`. **Do NOT run in background.** The map MUST complete before proceeding to Step 3.

**2d. find-skills bootstrap:** Check `find_skills_available` from detect-stack JSON.
- `true`: display "✓ Skills.sh registry — available"
- `false`: AskUserQuestion: "○ Skills.sh Registry\n\nVBW can search the Skills.sh registry (~2000 community skills) to find\nskills matching your project. This requires the find-skills meta-skill.\nInstall it now?" Options: "Install (Recommended)" / "Skip"
  - Approved: `npx skills add vercel-labs/skills --skill find-skills -g -y`
  - Declined: "○ Skipped. Run /vbw:skills later to search the registry."

### Step 3: Convergence — augment and search

**3a.** Verify mapping completed. Display `✓ Codebase mapped ({document-count} documents)`. If skipped (greenfield): proceed immediately.

**3b.** If `.vbw-planning/codebase/STACK.md` exists, read it and merge additional stack components into detected_stack[].

**3b2. Auto-detect conventions:** If `.vbw-planning/codebase/PATTERNS.md` exists:
- Read PATTERNS.md, ARCHITECTURE.md, STACK.md, CONCERNS.md
- Extract conventions per `${CLAUDE_PLUGIN_ROOT}/commands/teach.md` (Step R2)
- Write `.vbw-planning/conventions.json`. Display: `✓ {count} conventions auto-detected from codebase`

If greenfield: write `{"conventions": []}`. Display: `○ Conventions — none yet (add with /vbw:teach)`

**3c. Parallel registry search** (if find-skills available): run `npx skills find "<stack-item>"` for ALL detected_stack items **in parallel** (multiple concurrent Bash calls). Deduplicate against installed skills. If detected_stack empty, search by project type. Display results with `(registry)` tag.

**3d. Unified skill prompt:** Combine curated (from 2b) + registry (from 3c) results into single AskUserQuestion multiSelect. Tag `(curated)` or `(registry)`. Max 4 options + "Skip". Install selected: `npx skills add <skill> -g -y`.

**3e.** Write Skills section to STATE.md (SKIL-05 capability map). Protocol:
  1. **Discovery (SKIL-01):** Scan `CLAUDE_DIR/skills/` (global), `.claude/skills/` (project), `.claude/mcp.json` (mcp). Record name, scope, path per skill.
  2. **Stack detection (SKIL-02):** Read `${CLAUDE_PLUGIN_ROOT}/config/stack-mappings.json`. For each category, match `detect` patterns via Glob/file content. Collect `recommended_skills[]`.
  3. **find-skills bootstrap (SKIL-06):** Check `CLAUDE_DIR/skills/find-skills/` or `~/.agents/skills/find-skills/`. If missing + `skill_suggestions=true`: offer install (`npx skills add vercel-labs/skills --skill find-skills -g -y`).
  4. **Suggestions (SKIL-03/04):** Compare recommended vs installed. Tag each `(curated)` or `(registry)`. If `auto_install_skills=true`: auto-install. Else: display with install commands.
  5. **Write STATE.md section:** Format: `### Skills` / `**Installed:** {list or "None detected"}` / `**Suggested:** {list or "None"}` / `**Stack detected:** {comma-separated}` / `**Registry available:** yes/no`

### Step 3.5: Generate bootstrap CLAUDE.md

VBW needs its rules and state sections in a CLAUDE.md file. /vbw:vibe regenerates later with project content.

**Brownfield handling:** Read root `CLAUDE.md` via the Read tool.
- **Exists:** The user already has a CLAUDE.md. Do NOT overwrite it. Instead, append VBW sections (`## VBW Rules`, `## State`, `## Installed Skills`, `## Project Conventions`, `## Commands`, and optionally `## Plugin Isolation`) to the END of the existing file, separated by a `---` line. Preserve all existing content verbatim. Display `✓ CLAUDE.md (VBW sections appended to existing)`.
- **Does not exist:** Write a new `CLAUDE.md` at project root with the full template below. Display `✓ CLAUDE.md (created)`.

Template for NEW files — write verbatim, substituting `{...}` placeholders:
```markdown
# VBW-Managed Project
This project uses VBW (Vibe Better with Claude Code) for structured development.
## VBW Rules
- **Always use VBW commands** for project work. Do not manually edit files in `.vbw-planning/`.
- **Commit format:** `{type}({scope}): {description}` — types: feat, fix, test, refactor, perf, docs, style, chore.
- **One commit per task.** Each task in a plan gets exactly one atomic commit.
- **Never commit secrets.** Do not stage .env, .pem, .key, credentials, or token files.
- **Plan before building.** Use /vbw:vibe for all lifecycle actions. Plans are the source of truth.
- **Do not fabricate content.** Only use what the user explicitly states in project-defining flows.
## State
- Planning directory: `.vbw-planning/`
- Project not yet defined — run /vbw:vibe to set up project identity and roadmap.
## Installed Skills
{list from STATE.md Skills section, or "None"}
## Project Conventions
{If conventions.json has entries: "These conventions are enforced during planning and verified during QA." + bulleted list of rules}
{If none: "None yet. Run /vbw:teach to add project conventions."}
## Commands
Run /vbw:status for current progress.
Run /vbw:help for all available commands.
{ONLY if GSD_ISOLATION_ENABLED=true — include this section:}
## Plugin Isolation
- GSD agents and commands MUST NOT read, write, glob, grep, or reference any files in `.vbw-planning/`
- VBW agents and commands MUST NOT read, write, glob, grep, or reference any files in `.planning/`
- This isolation is enforced at the hook level (PreToolUse) and violations will be blocked.
```

Sections to append when **existing** CLAUDE.md found (same content, no `# VBW-Managed Project` header):
```markdown

---

## VBW Rules
{same rules as above}
## State
{same state as above}
## Installed Skills
{same}
## Project Conventions
{same}
## Commands
{same}
{## Plugin Isolation if applicable}
```
Keep total VBW addition under 40 lines. Add `✓ CLAUDE.md` to summary.

### Step 4: Present summary

Display Phase Banner then file checklist (✓ for each created file), conditional lines for GSD isolation, statusline, codebase mapping, conventions, skills. Then auto-launch `/vbw:vibe` by reading `${CLAUDE_PLUGIN_ROOT}/commands/vibe.md` and following it. If greenfield, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh init` and display output.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), File Checklist (✓), ○ for pending, Next Up Block, no ANSI color codes.
