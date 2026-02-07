---
description: Plan a phase by spawning the Lead agent for research, decomposition, and self-review.
argument-hint: [phase-number] [--effort=thorough|balanced|fast|turbo]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Plan: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directories:
```
!`ls .vbw-planning/phases/ 2>/dev/null || echo "No phases directory"`
```

## Phase Auto-Detection

If `$ARGUMENTS` does not contain an integer phase number:

1. Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md` for the detection protocol
2. Resolve the phases directory: if `.vbw-planning/ACTIVE` exists, read its contents to get the milestone slug and use `.vbw-planning/{milestone-slug}/phases/`; otherwise use `.vbw-planning/phases/`
3. Scan phase directories in numeric order (`01-*`, `02-*`, ...). Find the first phase with NO `*-PLAN.md` files
4. If found: announce "Auto-detected Phase {N} ({slug}) -- next phase to plan" and proceed with that phase number
5. If all phases have plans: STOP and tell user "All phases are planned. Specify a phase to re-plan: `/vbw:plan N`"

## Guard

1. **Not initialized:** If .vbw-planning/ doesn't exist, STOP: "Run /vbw:init first."
2. **No roadmap:** If .vbw-planning/ROADMAP.md doesn't exist, STOP: "No roadmap found. Run /vbw:init to create one."
3. **Phase not in roadmap:** If phase {N} doesn't exist in ROADMAP.md, STOP: "Phase {N} not found in roadmap."
4. **Already planned:** If phase has PLAN.md files with SUMMARY.md files, WARN: "Phase {N} already has completed plans. Re-planning preserves existing plans with .bak extension."

## Steps

### Step 1: Parse arguments

- **Phase number** (optional — auto-detected if omitted): integer
- **--effort** (optional): thorough|balanced|fast|turbo. Falls back to config default.

### Step 2: Turbo mode shortcut

If effort = turbo: skip Lead agent. Read phase requirements from ROADMAP.md. Create a single lightweight PLAN.md with all tasks in one plan. Write to phase directory. Skip to Step 5.

### Step 3: Spawn Lead agent

Spawn vbw-lead as a subagent via the Task tool with thin context:

```
Plan phase {N}: {phase-name}.
Roadmap: .vbw-planning/ROADMAP.md
Requirements: .vbw-planning/REQUIREMENTS.md
State: .vbw-planning/STATE.md
Project: .vbw-planning/PROJECT.md
Patterns: .vbw-planning/patterns/PATTERNS.md (if exists)
Effort: {level}
Output: Write PLAN.md files to .vbw-planning/phases/{phase-dir}/
```

The Lead reads all files itself -- no content embedding in the task description.

### Step 4: Validate Lead output

Verify:
- At least one PLAN.md exists in the phase directory
- Each has valid YAML frontmatter (phase, plan, title, wave, depends_on, must_haves)
- Each has tasks with name, files, action, verify, done
- Wave assignments have no circular dependencies

If validation fails, report issues to user.

### Step 5: Update state and present summary

Update STATE.md: phase position, plan count, status = Planned.

Display using `${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md`:

```
╔═══════════════════════════════════════════╗
║  Phase {N}: {name} -- Planned             ║
╚═══════════════════════════════════════════╝

  Plans:
    ○ Plan 01: {title}  (wave {W}, {task-count} tasks)
    ○ Plan 02: {title}  (wave {W}, {task-count} tasks)

  Effort: {profile}

➜ Next Up
  /vbw:execute {N} -- Execute this phase
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:
- Phase Banner (double-line box) for completion
- File Checklist (✓ prefix) for validation
- ○ for plans ready to execute
- Next Up Block for navigation
- No ANSI color codes
