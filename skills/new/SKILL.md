---
name: new
disable-model-invocation: true
description: Define your project — name, requirements, roadmap, and initial state.
argument-hint: [project-description]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW New: $ARGUMENTS

## Context

Working directory: `!`pwd``

Existing state:
```
!`ls -la .vbw-planning 2>/dev/null || echo "No .vbw-planning directory"`
```

Project definition:
```
!`head -20 .vbw-planning/PROJECT.md 2>/dev/null || echo "No PROJECT.md"`
```

Project files:
```
!`ls package.json pyproject.toml Cargo.toml go.mod *.sln Gemfile build.gradle pom.xml 2>/dev/null || echo "No detected project files"`
```

Codebase map (from /vbw:map):
```
!`ls .vbw-planning/codebase/ 2>/dev/null || echo "No codebase mapping found"`
```

Codebase index (if mapped):
```
!`head -60 .vbw-planning/codebase/INDEX.md 2>/dev/null || echo "No INDEX.md"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Already defined:** If .vbw-planning/PROJECT.md exists AND does NOT contain the template placeholder `{project-description}`, the project has already been defined. STOP: "Project already defined. Use /vbw:plan to plan your next phase, or pass --re-scope to redefine from scratch."
3. **Re-scope mode:** If $ARGUMENTS contains `--re-scope`, skip guard 2 and proceed (allows redefining an existing project).
4. **Brownfield detection:** If project files AND source files (*.ts, *.js, *.py, *.go, *.rs, *.java, *.rb) exist, set BROWNFIELD=true.

## Critical Rules

**NEVER FABRICATE CONTENT.** These rules are non-negotiable:

1. **Only use what the user explicitly states.** Do not infer, embellish, or generate requirements, phases, or roadmap content that the user did not articulate. If the user says "a todo app", the requirements are about a todo app — do not add authentication, deployment, CI/CD, or other features unless the user asked for them.

2. **If the user's answer does not match the question, STOP.** If you ask "What are the must-have features?" and the user responds with an unrelated request (e.g., "create a file for me" or "just do X"), do NOT continue the /vbw:new flow. Instead, acknowledge their request, explain that /vbw:new is paused, and handle what they actually asked for. They can re-run /vbw:new later.

3. **Confirmation before every file write.** Before writing each project file (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, CLAUDE.md), display the full generated content to the user and ask for explicit approval. Use AskUserQuestion with options: "Looks good", "Edit this", "Skip this file". Only write the file if the user approves.

4. **No silent assumptions.** If the user's answers leave gaps (e.g., they mention features but not constraints), ask a follow-up question. Do not fill gaps with your own assumptions.

5. **Phases come from the user, not from you.** When creating the roadmap, propose phases based strictly on the requirements the user provided. Present the proposed phases and ask for confirmation before writing ROADMAP.md. The user may want a completely different phase structure.

## Constraints

**Do NOT explore or scan the codebase.** Codebase analysis is `/vbw:map`'s job. Do not spawn Explore agents, do not read source files, do not run `find` or `ls` on the project tree. The only files you should read are `.vbw-planning/` contents (templates, codebase map) and the plugin's own reference files.

If a codebase map exists at `.vbw-planning/codebase/`, use it — read INDEX.md, PATTERNS.md, STACK.md, and ARCHITECTURE.md to inform your requirements and roadmap. This is your codebase knowledge. Do not go looking for more.

## Steps

### Step 1: Fill PROJECT.md

If $ARGUMENTS provided (excluding flags like --re-scope), use as project description. Otherwise ask:
- "What is the name of your project?"
- "Describe your project's core purpose in 1-2 sentences."

Fill placeholders: {project-name}, {core-value}, {date}.

**Confirmation gate:** Display the generated PROJECT.md content and ask: "Does this look right?" Only write if approved.

### Step 2: Gather requirements

Ask 3-5 focused questions:
1. Must-have features for first release?
2. Primary users/audience?
3. Technical constraints (language, framework, hosting)?
4. Integrations or external services?
5. What is out of scope?

**If the user's answer to any question is off-topic or requests something unrelated to project definition, STOP the flow.** Acknowledge their request, handle it separately, and let them re-run /vbw:new when ready.

Populate REQUIREMENTS.md with REQ-ID format, organized into v1/v2/out-of-scope. Use ONLY what the user stated — do not add requirements they did not mention.

**Confirmation gate:** Display the generated REQUIREMENTS.md content and ask: "Does this capture your requirements correctly?" Only write if approved.

### Step 3: Create roadmap

Suggest 3-5 phases based on requirements. If a codebase map exists (`.vbw-planning/codebase/`), read its documents (INDEX.md, PATTERNS.md, ARCHITECTURE.md, CONCERNS.md) and factor findings into the roadmap — e.g., technical debt from CONCERNS.md may warrant a dedicated phase, architecture patterns may shape phase ordering.

Each phase: name, goal, mapped requirements, success criteria. Fill ROADMAP.md.

**Confirmation gate:** Display the proposed phases (names, goals, requirement mappings) and ask: "Does this phase structure work for you?" Only write ROADMAP.md if approved. The user may want to reorder, merge, split, or remove phases.

### Step 4: Initialize state

Update STATE.md: project name, Phase 1 position, today's date, empty decisions, 0% progress.

### Step 4.5: Brownfield codebase summary

If BROWNFIELD=true AND `.vbw-planning/codebase/` does NOT exist (no prior map):
1. Count source files by extension (Glob)
2. Check for test files, CI/CD, Docker, monorepo indicators
3. Add Codebase Profile section to STATE.md

If `.vbw-planning/codebase/` already exists, skip — the map has this data.

### Step 5: Generate CLAUDE.md

Follow `${CLAUDE_PLUGIN_ROOT}/references/memory-protocol.md`. Write CLAUDE.md at project root with:
- Project header (name, core value)
- Active Context (milestone, phase, next action)
- Key Decisions (empty)
- Installed Skills (from STATE.md Skills section, if exists)
- Learned Patterns (empty)
- VBW Commands section (static)

Keep under 200 lines.

### Step 6: Brownfield auto-map

If BROWNFIELD=true AND `.vbw-planning/codebase/` does NOT exist (no prior map):
```
  ⚠ Existing codebase detected ({file-count} source files)
  ➜ Auto-launching /vbw:map to analyze your codebase...
```
Then immediately invoke `/vbw:map` by following `@${CLAUDE_PLUGIN_ROOT}/skills/map/SKILL.md`.

If `.vbw-planning/codebase/` already exists, skip — display "✓ Codebase map already exists" and move to summary.

### Step 7: Present summary

```
╔══════════════════════════════════════════╗
║  VBW Project Defined                     ║
║  {project-name}                          ║
╚══════════════════════════════════════════╝

  ✓ .vbw-planning/PROJECT.md
  ✓ .vbw-planning/REQUIREMENTS.md
  ✓ .vbw-planning/ROADMAP.md
  ✓ .vbw-planning/STATE.md
  ✓ CLAUDE.md
```

If greenfield:
```
➜ Next Up
  /vbw:plan -- Plan your first phase
```

If brownfield and map was launched, the map skill handles its own next-up.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Phase Banner (double-line box) for completion
- File Checklist (✓ prefix) for created/updated files
- ○ for pending items
- Next Up Block for navigation
- No ANSI color codes
