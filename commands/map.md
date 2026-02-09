---
name: map
description: Analyze existing codebase with adaptive Scout teammates to produce structured mapping documents.
argument-hint: [--incremental] [--package=name] [--tier=solo|duo|quad]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Map: $ARGUMENTS

## Context

Working directory: `!`pwd``

Existing mapping:
```
!`ls .vbw-planning/codebase/ 2>/dev/null || echo "No codebase mapping found"`
```

Current META.md:
```
!`cat .vbw-planning/codebase/META.md 2>/dev/null || echo "No META.md found"`
```

Project files:
```
!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No standard project files found"`
```

Git HEAD:
```
!`git rev-parse HEAD 2>/dev/null || echo "no-git"`
```

Agent Teams enabled:
```
!`echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **No git repo:** If not a git repo, WARN: "Not a git repo -- incremental mapping disabled." Continue in full mode.
3. **Empty project:** If no source files detected, STOP: "No source code found to map."

## Steps

### Step 1: Parse arguments and detect mode

- **--incremental**: force incremental refresh
- **--package=name**: scope to a single monorepo package
- **--tier=solo|duo|quad**: force a specific mapping tier (overrides auto-detection)

**Mode detection:**
1. If META.md exists and git repo: compare `git_hash` from META.md to HEAD. If <20% files changed: incremental. Otherwise: full.
2. If no META.md or no git: full mode.

Store `MAPPING_MODE` (full|incremental) and `CHANGED_FILES` (list, empty if full).

### Step 1.5: Size codebase and select tier

Count source files using Glob, excluding: `.vbw-planning/`, `node_modules/`, `.git/`, `vendor/`, `dist/`, `build/`, `target/`, `.next/`, `__pycache__/`, `.venv/`, `coverage/`.

If `--package=name` was specified, scope the file count to that package directory only.

Store `SOURCE_FILE_COUNT`.

**Tier selection:**

| Tier | File Count | Strategy | Scouts |
|------|-----------|----------|--------|
| **solo** | < 200 | Orchestrator maps all domains inline, no team | 0 |
| **duo** | 200–1000 | 2 scouts with combined domains | 2 |
| **quad** | 1000+ | Full 4-scout team | 4 |

**Overrides:**
- If `--tier=solo|duo|quad` argument was provided, use that tier regardless of file count.
- If Agent Teams is not enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not `"1"`), force solo mode. Display: `⚠ Agent Teams not enabled — using solo mode`

Display: `◆ Sizing: {SOURCE_FILE_COUNT} source files → {tier} mode`

### Step 2: Detect monorepo

Check for: lerna.json, pnpm-workspace.yaml, packages/ or apps/ with sub-package.json, root package.json workspaces field.

If monorepo: enumerate packages. If `--package=name`: scope mapping to that package only.

### Step 3: Execute mapping (tier-branched)

Branch execution based on the selected tier from Step 1.5.

---

**Step 3-solo (tier = solo):**

The orchestrator analyzes each domain sequentially, writing each document to `.vbw-planning/codebase/` immediately. Display progress per document.

**Domain 1 — Tech Stack:**
Analyze tech stack, frameworks, and dependencies. Write:
- `.vbw-planning/codebase/STACK.md`
- `.vbw-planning/codebase/DEPENDENCIES.md`

Display: `✓ STACK.md + DEPENDENCIES.md`

**Domain 2 — Architecture:**
Analyze code organization, architecture patterns, and directory structure. Write:
- `.vbw-planning/codebase/ARCHITECTURE.md`
- `.vbw-planning/codebase/STRUCTURE.md`

Display: `✓ ARCHITECTURE.md + STRUCTURE.md`

**Domain 3 — Quality:**
Analyze naming conventions, code style, and testing setup. Write:
- `.vbw-planning/codebase/CONVENTIONS.md`
- `.vbw-planning/codebase/TESTING.md`

Display: `✓ CONVENTIONS.md + TESTING.md`

**Domain 4 — Concerns:**
Analyze technical debt, risks, and concerns. Write:
- `.vbw-planning/codebase/CONCERNS.md`

Display: `✓ CONCERNS.md`

After all 7 documents are written, skip Step 3.5 and go straight to Step 4.

---

**Step 3-duo (tier = duo):**

Create an Agent Team with 2 Scout teammates. Use TaskCreate to create a task for each Scout with thin context:

**Scout A — Tech + Architecture:**
```
Analyze tech stack, dependencies, architecture, and project structure. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings"). Send TWO messages:
1. domain: "tech-stack" with documents for STACK.md and DEPENDENCIES.md
2. domain: "architecture" with documents for ARCHITECTURE.md and STRUCTURE.md
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

**Scout B — Quality + Concerns:**
```
Analyze quality signals, conventions, testing, technical debt, and risks. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings"). Send TWO messages:
1. domain: "quality" with documents for CONVENTIONS.md and TESTING.md
2. domain: "concerns" with documents for CONCERNS.md
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

Display per-scout progress as findings arrive:
- `✓ Scout A: STACK.md + DEPENDENCIES.md + ARCHITECTURE.md + STRUCTURE.md`
- `✓ Scout B: CONVENTIONS.md + TESTING.md + CONCERNS.md`

**Scout model selection (effort-gated):**
- At **Fast** or **Turbo** effort: include `Model: haiku` in each Scout's task description.
- At **Thorough** or **Balanced** effort: do not specify a model override — Scouts inherit the session model.

Wait for all teammates to send their findings. Then proceed to Step 3.5.

---

**Step 3-quad (tier = quad):**

Create an Agent Team with 4 Scout teammates. Use TaskCreate to create a task for each Scout with thin context:

**Scout 1 -- Tech Stack:**
```
Analyze tech stack and dependencies. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings", domain: "tech-stack"). Include documents for STACK.md and DEPENDENCIES.md.
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

**Scout 2 -- Architecture:**
```
Analyze architecture and project structure. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings", domain: "architecture"). Include documents for ARCHITECTURE.md and STRUCTURE.md.
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

**Scout 3 -- Quality:**
```
Analyze quality signals, conventions, and testing. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings", domain: "quality"). Include documents for CONVENTIONS.md and TESTING.md.
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

**Scout 4 -- Concerns:**
```
Analyze concerns, technical debt, and risks. Send findings to the lead via SendMessage using the scout_findings schema (type: "scout_findings", domain: "concerns"). Include documents for CONCERNS.md.
Mode: {MAPPING_MODE}. {If incremental: "Changed files: {list}"}
{If monorepo: "Packages: {list}"}
Schema reference: ${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md
```

Security enforcement is handled by the PreToolUse hook -- no inline exclusion lists needed.

**Scout model selection (effort-gated):**

- At **Fast** or **Turbo** effort: include `Model: haiku` in each Scout's task description for cost efficiency.
- At **Thorough** or **Balanced** effort: do not specify a model override -- Scouts inherit the session model (Opus) via their `model: inherit` agent config.

Wait for all teammates to send their findings.

Display per-scout progress as findings arrive:
- `✓ Scout 1: STACK.md + DEPENDENCIES.md`
- `✓ Scout 2: ARCHITECTURE.md + STRUCTURE.md`
- `✓ Scout 3: CONVENTIONS.md + TESTING.md`
- `✓ Scout 4: CONCERNS.md`

**Scout communication protocol (effort-gated):**

Instruct Scout teammates to use SendMessage for cross-cutting discovery sharing based on the active effort level. Note: `/vbw:map` does not accept an `--effort` flag -- effort is inherited from the global config. If effort is not determinable, default to Balanced behavior.

- At **Thorough** or **Balanced** effort:
  - **Cross-cutting findings:** If a Scout discovers something relevant to another Scout's domain (e.g., Tech Stack scout finds an architectural pattern that Architecture scout should know about, Architecture scout finds a dependency concern that Tech Stack scout should cross-reference), message the relevant Scout directly.
- At **Thorough** effort only, additionally:
  - **Contradictions:** If a Scout's findings contradict another Scout's area (e.g., Quality scout finds conventions that conflict with what Architecture scout documented), message that Scout to flag the discrepancy for the INDEX.md Validation Notes section.
- At **Fast** effort: instruct Scouts to report blockers only via SendMessage (e.g., if a Scout cannot access expected files or encounters an empty project area that prevents mapping).

Use targeted `message` (not `broadcast`). Scout domains are independent; most findings stay within domain.

### Step 3.5: Write mapping documents from Scout reports

**Guard:** Skip this step entirely if tier is **solo** (documents were already written inline in Step 3-solo).

After receiving all Scout findings via SendMessage, parse each message as JSON (`scout_findings` schema). If parsing fails, fall back to treating the content as plain markdown. Write the 7 individual mapping documents to `.vbw-planning/codebase/`:

- **STACK.md** and **DEPENDENCIES.md** -- from Tech Stack findings
- **ARCHITECTURE.md** and **STRUCTURE.md** -- from Architecture findings
- **CONVENTIONS.md** and **TESTING.md** -- from Quality findings
- **CONCERNS.md** -- from Concerns findings

Write each document using the structured data received from Scouts. Verify all 7 documents exist before proceeding.

### Step 4: Synthesize INDEX.md and PATTERNS.md

After all documents are written (either inline for solo, or from Scout reports for duo/quad), read all 7 mapping documents and produce:

**INDEX.md:** Cross-referenced index with key findings and cross-references per document. Add a "Validation Notes" section flagging any contradictions between mapper outputs.

**PATTERNS.md:** Recurring patterns extracted across documents: architectural, naming, quality, concern, and dependency patterns.

### Step 5: Create META.md and present summary

**Shutdown and cleanup (tier-branched):**

- **Solo:** No team to shut down. Proceed directly to META.md creation.
- **Duo / Quad:** After all Scout teammates have completed their tasks, follow the Agent Teams Shutdown Protocol in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`. Do not proceed to META.md creation until TeamDelete has succeeded.

Write META.md with: mapped_at timestamp, git_hash, file_count, document list, mode, monorepo flag, **mapping_tier** (solo|duo|quad).

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md`:

```
╔══════════════════════════════════════════╗
║  Codebase Mapped                         ║
║  Mode: {full | incremental}              ║
║  Tier: {solo | duo | quad}               ║
╚══════════════════════════════════════════╝

  ✓ STACK.md          -- Tech stack and frameworks
  ✓ DEPENDENCIES.md   -- Dependency graph and versions
  ✓ ARCHITECTURE.md   -- Code organization and data flow
  ✓ STRUCTURE.md      -- Directory tree and file patterns
  ✓ CONVENTIONS.md    -- Naming rules and code style
  ✓ TESTING.md        -- Test framework and coverage
  ✓ CONCERNS.md       -- Technical debt and risks
  ✓ INDEX.md          -- Cross-referenced index
  ✓ PATTERNS.md       -- Recurring codebase patterns

  Key Findings:
    ◆ {finding from INDEX.md}
    ◆ {finding from INDEX.md}
    ◆ {finding from INDEX.md}

➜ Next Up
  /vbw:plan {next-phase} -- Plan with codebase context
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for completion
- File Checklist (✓ prefix) for documents
- ◆ for key findings, ⚠ for validation warnings
- Next Up Block for navigation
- No ANSI color codes
