---
name: discuss
description: Gather phase context through structured questions before planning.
argument-hint: [phase-number]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Discuss: $ARGUMENTS

## Context

Working directory: `!`pwd``

Roadmap:
```
!`head -50 .vbw-planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
```

## Guard

- Not initialized (no .vbw-planning/ dir): STOP "Run /vbw:init first."
- **Phase resolution** (no explicit number): Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md`, Planning Commands algorithm. Resolve phases dir (check .vbw-planning/ACTIVE). Scan numerically for first phase with NO `*-PLAN.md`. Found: announce "Auto-detected Phase {N} ({slug})". All planned: STOP "All phases planned. Specify: `/vbw:discuss N`"
- Phase not in roadmap: STOP "Phase {N} not found."

## Steps

1. **Load phase:** Read ROADMAP.md for goal, requirements, success criteria, dependencies.
2. **Question:** Ask 3-5 phase-specific questions across: essential features, technical preferences, boundaries, dependencies, acceptance criteria. Adapt to phase type.
3. **Synthesize:** Write `.vbw-planning/phases/{phase-dir}/{phase}-CONTEXT.md`:
```markdown
# Phase {N} Context

## User Vision
{What the user wants, in their words}

## Essential Features
{Prioritized list}

## Technical Preferences
{Specific implementation preferences}

## Boundaries
{Constraints and things to avoid}

## Acceptance Criteria (User)
{Beyond roadmap criteria}

## Decisions Made
{Decisions locked during discussion}
```
4. **Confirm:** Show summary, ask for corrections. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh discuss` and display.

## Output Format

Per @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md: ✓ for captured answers, Next Up Block, no ANSI.
