---
name: vbw:map
disable-model-invocation: true
description: Analyze existing codebase with adaptive Scout teammates to produce structured mapping documents.
argument-hint: [--incremental] [--package=name] [--tier=solo|duo|quad]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Map: $ARGUMENTS

## Context

Working directory: `!`pwd``
Existing mapping: `!`ls .vbw-planning/codebase/ 2>/dev/null || echo "No codebase mapping found"``
META.md:
```
!`cat .vbw-planning/codebase/META.md 2>/dev/null || echo "No META.md found"`
```
Project files: `!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No standard project files found"``
Git HEAD: `!`git rev-parse HEAD 2>/dev/null || echo "no-git"``
Agent Teams: `!`echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"``

## Guard

1. **Not initialized** (no .vbw-planning/ dir): STOP "Run /vbw:init first."
2. **No git:** WARN "Not a git repo -- incremental mapping disabled." Continue in full mode.
3. **Empty project:** No source files → STOP: "No source code found to map."

## Steps

### Step 1: Parse arguments and detect mode

- **--incremental**: force incremental refresh
- **--package=name**: scope to single monorepo package
- **--tier=solo|duo|quad**: force specific tier (overrides auto-detection)

**Mode detection:** If META.md exists + git repo: compare `git_hash` to HEAD. <20% files changed = incremental, else full. No META.md or no git = full. Store MAPPING_MODE and CHANGED_FILES.

### Step 1.5: Size codebase and select tier

Count source files (Glob), excluding: .vbw-planning/, node_modules/, .git/, vendor/, dist/, build/, target/, .next/, __pycache__/, .venv/, coverage/. If --package, scope to that dir. Store SOURCE_FILE_COUNT.

| Tier | Files | Strategy | Scouts |
|------|-------|----------|--------|
| solo | <200 | Orchestrator maps inline | 0 |
| duo | 200-1000 | 2 scouts, combined domains | 2 |
| quad | 1000+ | Full 4-scout team | 4 |

Overrides: --tier flag forces tier. Agent Teams not enabled → force solo (`⚠ Agent Teams not enabled — using solo mode`).
Display: `◆ Sizing: {SOURCE_FILE_COUNT} source files → {tier} mode`

### Step 2: Detect monorepo

Check lerna.json, pnpm-workspace.yaml, packages/ or apps/ with sub-package.json, root workspaces field. If monorepo + --package: scope to that package.

### Step 3: Execute mapping (tier-branched)

**Step 3-solo:** Orchestrator analyzes each domain sequentially, writes to `.vbw-planning/codebase/`:
- Domain 1 (Tech Stack): STACK.md + DEPENDENCIES.md
- Domain 2 (Architecture): ARCHITECTURE.md + STRUCTURE.md
- Domain 3 (Quality): CONVENTIONS.md + TESTING.md
- Domain 4 (Concerns): CONCERNS.md
Display ✓ per domain. After all 7 docs written, skip Step 3.5, go to Step 4.

---

**Step 3-duo:** Create Agent Team with 2 Scouts via TaskCreate:

Scout A (Tech + Architecture): analyze tech stack, deps, architecture, structure. Send 2 scout_findings messages (domain: "tech-stack" with STACK.md+DEPENDENCIES.md, domain: "architecture" with ARCHITECTURE.md+STRUCTURE.md). Mode: {MAPPING_MODE}. Schema ref: `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`

Scout B (Quality + Concerns): analyze quality, conventions, testing, debt, risks. Send 2 scout_findings messages (domain: "quality" with CONVENTIONS.md+TESTING.md, domain: "concerns" with CONCERNS.md). Mode: {MAPPING_MODE}. Schema ref: `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`

**Scout model (effort-gated):** Fast/Turbo: `Model: haiku`. Thorough/Balanced: inherit session model.
Wait for all findings. Proceed to Step 3.5.

---

**Step 3-quad:** Create Agent Team with 4 Scouts via TaskCreate. Each sends scout_findings with their domain. Schema ref: `${CLAUDE_PLUGIN_ROOT}/references/handoff-schemas.md`
- Scout 1 (Tech Stack): STACK.md + DEPENDENCIES.md
- Scout 2 (Architecture): ARCHITECTURE.md + STRUCTURE.md
- Scout 3 (Quality): CONVENTIONS.md + TESTING.md
- Scout 4 (Concerns): CONCERNS.md

Security: PreToolUse hook handles enforcement. **Scout model:** same as duo.

**Scout communication (effort-gated):**

| Effort | Messages |
|--------|----------|
| Thorough | Cross-cutting findings + contradiction flags for INDEX.md Validation Notes |
| Balanced | Cross-cutting findings only |
| Fast | Blockers only |

Use targeted `message` not `broadcast`. Wait for all findings. Display ✓ per scout.

### Step 3.5: Write mapping documents from Scout reports

**Skip if solo** (docs already written). Parse each scout_findings JSON message. If parse fails, treat as plain markdown. Write 7 docs to `.vbw-planning/codebase/`: STACK.md, DEPENDENCIES.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md. Verify all 7 exist.

### Step 4: Synthesize INDEX.md and PATTERNS.md

Read all 7 docs. Produce:
- **INDEX.md:** Cross-referenced index with key findings + "Validation Notes" for contradictions
- **PATTERNS.md:** Recurring patterns: architectural, naming, quality, concern, dependency

### Step 5: Create META.md and present summary

**Shutdown:** Solo: no team. Duo/Quad: send shutdown to each teammate, wait for approval, re-request if rejected, then TeamDelete.

Write META.md: mapped_at, git_hash, file_count, document list, mode, monorepo flag, mapping_tier.

Display per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md: Phase Banner (Codebase Mapped, Mode, Tier), ✓ per document, Key Findings (◆), Next Up block.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — Phase Banner (double-line box), File Checklist (✓), ◆ for findings, ⚠ for warnings, Next Up Block, no ANSI.
