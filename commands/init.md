---
description: Initialize a new VBW project with .planning directory, artifact templates, and project definition.
argument-hint: [project-description]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Init: $ARGUMENTS

## Context

Working directory: `!`pwd``

Existing .planning state:
```
!`ls -la .planning 2>/dev/null || echo "No .planning directory"`
```

Current STATE.md:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No existing state"`
```

Detected project files:
```
!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No detected project files"`
```

Installed global skills:
```
!`ls ~/.claude/skills/ 2>/dev/null || echo "No global skills found"`
```

Installed project skills:
```
!`ls .claude/skills/ 2>/dev/null || echo "No project skills found"`
```

## Guard

1. **Already initialized:** If `.planning/` exists and contains a `PROJECT.md`, STOP and inform the user:
   "VBW is already initialized in this directory. Use /vbw:config to modify settings or delete .planning/ to re-initialize."

2. **Brownfield project:** If project files are detected (package.json, pyproject.toml, Cargo.toml, go.mod, *.sln, Gemfile, build.gradle, pom.xml), AND source code files exist (use Glob to check for *.ts, *.js, *.py, *.go, *.rs, *.java, *.rb, *.php in the working directory), this is an existing codebase. Set BROWNFIELD=true for use in Step 6.

## Steps

### Step 1: Scaffold .planning/ directory

Use the Read tool to read each template file from the VBW plugin directory at `${CLAUDE_PLUGIN_ROOT}/templates/` and the Write tool to create the corresponding file in the user's `.planning/` directory.

Files to create:

| Target                    | Source (Read from plugin)                        |
|---------------------------|--------------------------------------------------|
| .planning/PROJECT.md      | ${CLAUDE_PLUGIN_ROOT}/templates/PROJECT.md       |
| .planning/REQUIREMENTS.md | ${CLAUDE_PLUGIN_ROOT}/templates/REQUIREMENTS.md  |
| .planning/ROADMAP.md      | ${CLAUDE_PLUGIN_ROOT}/templates/ROADMAP.md       |
| .planning/STATE.md        | ${CLAUDE_PLUGIN_ROOT}/templates/STATE.md         |
| .planning/config.json     | ${CLAUDE_PLUGIN_ROOT}/config/defaults.json       |

Also create the directory: `.planning/phases/` (use `mkdir -p .planning/phases`).

### Step 2: Fill PROJECT.md with user input

If `$ARGUMENTS` was provided, use it as the project description. Otherwise, ask the user:
- "What is the name of your project?"
- "Describe your project's core purpose in 1-2 sentences."

Fill in these placeholders in PROJECT.md:
- `{project-name}` -- the project name
- `{core-value}` -- the core purpose/value proposition
- `{date}` -- today's date (YYYY-MM-DD format)

### Step 3: Initial requirements gathering

Ask the user 3-5 focused questions about their project scope:
1. What are the must-have features for your first release?
2. Who are the primary users/audience?
3. Are there any technical constraints (language, framework, hosting)?
4. What integrations or external services are needed?
5. What is explicitly out of scope for now?

Populate REQUIREMENTS.md with initial requirements:
- Use REQ-ID format (e.g., REQ-001, REQ-002)
- Organize into sections: v1 (must have), v2 (nice to have), out of scope
- Each requirement gets: ID, description, priority, status (pending)

### Step 4: Initial roadmap

Based on the gathered requirements, suggest 3-5 phases:
- Each phase gets a name, goal, and mapped requirements
- Each phase gets success criteria (what must be TRUE when phase is complete)
- Phases should build on each other logically

Fill in ROADMAP.md with the phase structure.

### Step 5: State initialization

Update STATE.md with:
- Project name and core value reference
- Current position: Phase 1, Plan 0 of N, Status: Planning
- Today's date as last activity
- Empty decisions table
- Progress bar at 0%

### Step 5.5: Brownfield codebase summary (if BROWNFIELD=true)

If an existing codebase was detected:

1. Count source files by extension using Glob:
   - TypeScript/JavaScript: *.ts, *.tsx, *.js, *.jsx
   - Python: *.py
   - Go: *.go
   - Rust: *.rs
   - Java: *.java
   - Ruby: *.rb
   - Other detected extensions

2. Check for test files (files matching *test*, *spec*, __tests__/)

3. Check for common patterns:
   - CI/CD configs (.github/workflows/, .gitlab-ci.yml, Jenkinsfile)
   - Docker (Dockerfile, docker-compose.yml)
   - Monorepo indicators (lerna.json, pnpm-workspace.yaml, packages/, apps/)

4. Store a brief summary in STATE.md under a "Codebase Profile" section:
   ```
   ### Codebase Profile
   - Type: Brownfield (existing codebase detected)
   - Languages: {detected languages with file counts}
   - Tests: {yes/no with framework if detected}
   - CI/CD: {yes/no with platform}
   - Monorepo: {yes/no}
   ```

### Step 5.7: Skill discovery and suggestions

Follow the protocol defined in @${CLAUDE_PLUGIN_ROOT}/references/skill-discovery.md.

**5.7.1 - Discover installed skills (SKIL-01):**

Scan for installed skills in three locations:
1. Global: `~/.claude/skills/` -- list directories containing skill definitions
2. Project: `.claude/skills/` -- project-scoped skills
3. MCP: Read `.claude/mcp.json` if it exists and note configured MCP servers

Record each discovered skill with its name and scope (global/project/mcp).

**5.7.2 - Detect project stack (SKIL-02):**

Read `${CLAUDE_PLUGIN_ROOT}/config/stack-mappings.json`. For each category (frameworks, testing, services, quality, devops):
- For file-based detection patterns: use Glob to check if the file exists
- For dependency-based patterns (e.g., `package.json:react`): read the manifest file and check if the dependency name appears in the content

Collect all matched stack entries and their recommended skills.

**5.7.3 - Suggest skills (SKIL-03, SKIL-04):**

Read `skill_suggestions` and `auto_install_skills` from `.planning/config.json`.

If `skill_suggestions` is false: skip this substep entirely.

Compare recommended skills (from stack detection) against installed skills. For each skill that is recommended but NOT installed:

If `auto_install_skills` is true:
- Display: "Auto-installing {skill-name}..."
- Run: `npx @anthropic-ai/claude-code skills add {skill-name}`
- Display result

If `auto_install_skills` is false (default):
- Display a suggestion list after the initialization summary:
  ```
  Suggested skills for your stack:
    {skill-name} -- {description}
    {skill-name} -- {description}
    Install: npx @anthropic-ai/claude-code skills add {skill-name}
  ```

**5.7.4 - Write capability map to STATE.md (SKIL-05):**

Add a `### Skills` section to STATE.md (after the Codebase Profile section if brownfield, or after the initial state if greenfield):

```markdown
### Skills

**Installed:**
- {skill-name} ({scope})
- ...
(or "None detected" if no skills found)

**Suggested (not installed):**
- {skill-name} -- recommended for {detected-stack-item}
- ...
(or "None" if all recommended skills are installed)

**Stack detected:** {comma-separated list, e.g., "Next.js, React, TypeScript, Tailwind, Vitest"}
```

### Step 6: Present summary

Display the initialization summary using brand formatting from @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md.

Use the Phase Banner template (vbw-brand.md) for the completion banner:
```
╔══════════════════════════════╗
║  VBW Project Initialized     ║
║  {project-name}              ║
╚══════════════════════════════╝
```

Show created files with checkmarks:
- ✓ .planning/PROJECT.md
- ✓ .planning/REQUIREMENTS.md
- ✓ .planning/ROADMAP.md
- ✓ .planning/STATE.md
- ✓ .planning/config.json
- ✓ .planning/phases/

Show project core value and phase overview.

If skills were discovered or suggested in Step 5.7, display:
```
Skills:
  Installed: {count} ({list of names})
  Suggested: {count} ({list of names})
  Stack:     {detected stack summary}
```

If BROWNFIELD=true, add after the created files list:

```
⚠ Existing codebase detected ({total-source-files} source files)

Run /vbw:map to analyze your codebase before planning.
This produces architecture docs, conventions, and concern analysis
that improve planning quality for existing projects.

➜ Next Up
  /vbw:map -- Analyze your codebase (recommended)
  /vbw:plan 1 -- Skip mapping and plan directly
```

If BROWNFIELD=false, end with:
```
➜ Next Up
  /vbw:plan 1 -- Plan your first phase
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Use the **Phase Banner** template for the init completion banner (double-line box)
- Use the **File Checklist** template for the created files list (✓ prefix)
- Use the **Next Up Block** template for navigation (➜ header, indented commands with --)
- ○ for pending/future items
- Keep lines under 80 characters inside boxes
- No ANSI color codes
