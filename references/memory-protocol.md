# Memory Protocol

Single source of truth for VBW's persistent memory system. Referenced by commands that generate or update memory artifacts (init, plan, build, ship).

VBW manages three memory subsystems: CLAUDE.md (machine-facing context), pattern learning (phase retrospectives), and memory lifecycle (cleanup and validation).

## 1. CLAUDE.md Protocol (MEMO-01, MEMO-05)

CLAUDE.md lives at the project root. Claude Code automatically loads it into every session's system prompt, making it the primary cross-session context channel.

### Structure

The generated CLAUDE.md follows this structure:

```markdown
# {project-name}

**Core value:** {one-liner from PROJECT.md}

## Active Context

**Milestone:** {active milestone name or "default"}
**Phase:** {current phase number} - {phase name} ({status})
**Next action:** {suggested next command}

## Key Decisions

{5-10 most impactful decisions from STATE.md, newest first}
- {decision}
- {decision}

## Installed Skills

{from STATE.md Skills section, if exists}
- {skill} ({scope})

## Learned Patterns

{from .vbw-planning/patterns/PATTERNS.md, if exists -- 3-5 most relevant}
- {pattern summary}

## VBW Commands

This project uses VBW (Vibe Better with Claude Code).
Run /vbw:status for current progress.
Run /vbw:help for all commands.
```

### Rules

- **Maximum 200 lines.** Claude Code truncates beyond this limit.
- Core value and Active Context are mandatory sections. All other sections may be omitted if empty.
- Key Decisions: include only the 5-10 most impactful, prioritize recent decisions over older ones.
- Learned Patterns: include only the 3-5 most relevant to current work.
- CLAUDE.md is **regenerated** (not appended) on each update. The file reflects current state, not history.
- If no `.vbw-planning/` directory exists, CLAUDE.md is not generated.

### Commands that update CLAUDE.md

| Command | Trigger |
|---------|---------|
| /vbw:init | Creates CLAUDE.md for the first time |
| /vbw:plan | Updates after planning completes (new phase context) |
| /vbw:execute | Updates after phase build completes (new decisions, patterns) |
| /vbw:ship | Regenerates to reflect shipped state (milestone archived) |

## 2. Pattern Learning (MEMO-02, MEMO-03)

Patterns capture what worked and what failed after each phase build. They inform future planning decisions.

### Storage

Location: `.vbw-planning/patterns/` (project-scoped, persists across milestones per MLST-09)

Files:
- `.vbw-planning/patterns/PATTERNS.md` -- accumulated patterns from all completed phases

### Pattern Entry Format

Each phase produces one entry appended to PATTERNS.md:

```markdown
### Phase {N}: {name} ({date})

**What worked:**
- {pattern description} (e.g., "3-task plans completed faster than 5-task plans")
- {pattern description}

**What failed:**
- {pattern description} (e.g., "Tasks touching >5 files had deviations")
- {pattern description}

**Timing:**
- Plans: {count}, Average: {duration}, Total: {total}
- Effort: {profile used}

**Deviations:** {count} ({brief summary of types if any})
```

### Pattern Capture

Pattern capture is triggered by `/vbw:execute` after all plans in a phase complete. The build command:

1. Reads all SUMMARY.md files from the completed phase
2. Extracts timing data (duration per plan, total phase time)
3. Extracts deviation data (count, types, severity)
4. Identifies completion patterns (task count vs. success rate, file count vs. deviation rate)
5. Appends a new entry to `.vbw-planning/patterns/PATTERNS.md`

### Pattern Reading

Pattern reading is done by `/vbw:plan` (via the Lead agent). Before planning, the Lead:

1. Reads `.vbw-planning/patterns/PATTERNS.md` if it exists
2. Considers what decomposition strategies worked in previous phases
3. Applies learned patterns to plan structure (e.g., fewer tasks per plan if large plans had deviations)

## 3. Memory Lifecycle (MEMO-06)

### Ship Cleanup

When `/vbw:ship` completes a milestone:

| Artifact | Action | Reason |
|----------|--------|--------|
| `.vbw-planning/patterns/PATTERNS.md` | PRESERVED | Project-scoped, not milestone-scoped. Patterns apply across milestones. |
| `.vbw-planning/RESUME.md` (or `.vbw-planning/{slug}/RESUME.md`) | DELETED | Session state is stale after shipping. |
| `CLAUDE.md` | REGENERATED | Must reflect new state: milestone archived, no active work or next milestone active. |

### Memory Validation (MEMO-07)

During `/vbw:plan`, the Lead agent performs a lightweight staleness check on stored patterns:

1. **Path validity:** Are file paths mentioned in PATTERNS.md still valid in the current project structure?
2. **Structural relevance:** Has the project structure changed significantly since patterns were captured (e.g., major refactors, new frameworks)?
3. **Staleness marking:** Stale patterns are NOT deleted. They are noted as potentially outdated in the Lead's planning context.

This is a lightweight check, not a blocking gate. Stale patterns are deprioritized but remain available for reference.

## 4. STATE.md and CLAUDE.md Separation (MEMO-04)

STATE.md and CLAUDE.md serve complementary but distinct roles:

| Aspect | STATE.md | CLAUDE.md |
|--------|----------|-----------|
| **Audience** | Humans (developer dashboard) | Machine (Claude Code system prompt) |
| **Content** | Position, metrics, decisions, todos, blockers | Context, decisions, skills, patterns, commands |
| **Update** | After every plan completion | After init, plan, build, ship |
| **Lifespan** | Milestone-scoped (lives in milestone directory) | Project-scoped (lives at project root) |
| **Size** | Unlimited (grows with project) | Max 200 lines (Claude Code constraint) |

This separation means:
- STATE.md stays lean: current position, metrics, decisions, todos, blockers
- CLAUDE.md handles cross-session context loading that MEMO-05 requires
- Commands update CLAUDE.md automatically -- humans never need to maintain it
- Agents read CLAUDE.md for context instead of parsing the full STATE.md, reducing per-agent context overhead
