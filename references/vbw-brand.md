# VBW Brand Vocabulary

Single source of truth for all VBW visual output formatting.

## Semantic Symbols

| Meaning          | Symbol | Unicode  | Usage                    |
|------------------|--------|----------|--------------------------|
| Success/complete | ✓      | U+2713   | Task done, check passed  |
| Failure/error    | ✗      | U+2717   | Task failed, check error |
| In progress      | ◆      | U+25C6   | Currently executing      |
| Pending/queued   | ○      | U+25CB   | Waiting to start         |
| Action/lightning | ⚡     | U+26A1   | Command invocation       |
| Warning          | ⚠      | U+26A0   | Non-blocking concern     |
| Info/arrow       | ➜      | U+279C   | Navigation, next step    |

## Box Drawing

### Critical / Phase-level (double-line)

```
╔══════════════════════════════╗
║  Phase 1: Core Framework     ║
║  Status: In Progress         ║
╚══════════════════════════════╝
```

Characters: ╔ (U+2554) ═ (U+2550) ╗ (U+2557) ║ (U+2551) ╚ (U+255A) ╝ (U+255D)

### Standard / Task-level (single-line)

```
┌──────────────────────────────┐
│  Task 1: Create agent stubs  │
│  Status: ✓ Complete          │
└──────────────────────────────┘
```

Characters: ┌ (U+250C) ─ (U+2500) ┐ (U+2510) │ (U+2502) └ (U+2514) ┘ (U+2518)

## Progress Bars

Format: `[filled][empty]` using block elements.

- Filled: █ (U+2588)
- Empty: ░ (U+2591)

Examples:
- 0%:   `░░░░░░░░░░`
- 30%:  `███░░░░░░░`
- 70%:  `███████░░░`
- 100%: `██████████`

Pair with percentage: `███████░░░ 70%`

## Rules

1. No ANSI color codes -- not rendered in Claude Code model output
2. No Nerd Font glyphs -- not universally available
3. Content must be readable even if box-drawing fails to render
4. Keep lines under 80 characters inside boxes
5. Use semantic symbols consistently across all agent output
6. Progress bars always 10 characters wide for visual consistency

## Output Templates

Reusable template patterns for every visual output type across VBW
commands. Each template uses `{placeholder}` syntax for dynamic values.

### 1. Phase Banner (VIZL-04)

Double-line box for phase-level operations (init, plan, build, ship).

```
╔═══════════════════════════════════════════╗
║  Phase {N}: {phase-name} -- {status}      ║
╚═══════════════════════════════════════════╝
```

With optional metadata lines:

```
╔═══════════════════════════════════════════╗
║  Phase {N}: {phase-name} -- {status}      ║
║  Plans: {count}  Waves: {count}           ║
║  Effort: {profile}  Tasks: {count}        ║
╚═══════════════════════════════════════════╝
```

**Usage:** Opening/closing banner for phase-level commands.
`{status}` values: Initialized, Planned, Built, Shipped, Failed.

### 2. Wave Banner (VIZL-05)

Single-line box for wave groupings during build execution.

```
┌──────────────────────────────────────────┐
│  Wave {N}: {count} plan(s)               │
│  {plan-01-title}, {plan-02-title}        │
└──────────────────────────────────────────┘
```

**Usage:** Displayed before executing each wave in /vbw:execute.
Plan titles are comma-separated; wrap to a second line if
needed to stay under 80 characters inside the box.

### 3. Execution Progress (VIZL-05)

Per-plan status lines during and after build execution.

```
  ◆ Plan {NN}: {title}                       (running)
  ✓ Plan {NN}: {title}    {duration}  {commits} commits
  ✗ Plan {NN}: {title}    (failed)
  ○ Plan {NN}: {title}    (skipped)
```

Symbol key:
- ◆ in-progress (currently executing)
- ✓ complete (with duration and commit count)
- ✗ failed (execution stopped or errored)
- ○ skipped (already complete or dependency unmet)

**Usage:** Listed under each Wave Banner during /vbw:execute.
Indented 2 spaces from the left margin.

### 4. Status Dashboard (VIZL-06)

Multi-section display for /vbw:status output.

```
╔═══════════════════════════════════════════╗
║  {project-name}                           ║
║  {milestone-name}                         ║
╚═══════════════════════════════════════════╝

  Phases:
    ✓ Phase 1: {name}       ██████████ 100%
    ✓ Phase 2: {name}       ██████████ 100%
    ◆ Phase 3: {name}       ██████░░░░  60%
    ○ Phase 4: {name}       ░░░░░░░░░░   0%

  Velocity:
    Plans completed:  {N}
    Average duration: {time}
    Total time:       {time}

  ➜ Next: /vbw:execute {N} to continue.
```

**Usage:** Standalone status overview invoked by /vbw:status.
Phase lines use progress bars (10 chars) aligned with names.
Velocity section uses Metrics Block formatting (see below).

### 5. QA Verification Report (VIZL-07)

Summary block for QA agent results.

```
╔═══════════════════════════════════════════╗
║  QA Verification: Phase {N}               ║
║  Tier: {tier}  Result: {PASS|PARTIAL|FAIL}║
╚═══════════════════════════════════════════╝

  Checks: {passed}/{total} passed

  ✓ {check-name-1}
  ✓ {check-name-2}
  ✗ {check-name-3}: {failure reason}
  ✗ {check-name-4}: {failure reason}
```

**Usage:** Displayed after QA agent completes in /vbw:execute.
Double-line box for the header; individual checks listed below
with ✓ for passed and ✗ for failed (with reason).

### 6. Ship Confirmation (VIZL-08)

Double-line celebration box for milestone completion.

```
╔═══════════════════════════════════════════╗
║  Shipped: {milestone-name}                ║
╚═══════════════════════════════════════════╝

  Phases:       {completed}/{total}
  Tasks:        {count}
  Commits:      {count}
  Requirements: {satisfied}/{total}
```

**Usage:** Final output of /vbw:ship after all phases pass.
Metrics below the box use Metrics Block formatting.

### 7. Next Up Block (VIZL-09)

Consistent end-of-output navigation block.

```
➜ Next Up
  /vbw:{command} -- {description}
  /vbw:{command} -- {description}
```

**Usage:** Appears at the end of every major command output,
separated from preceding content by a blank line. The arrow
symbol (➜) marks the header. Commands are indented 2 spaces,
each on its own line with a brief description after `--`.

Suggest 1-3 commands based on context:
- After init: `/vbw:map` or `/vbw:plan`
- After plan: `/vbw:execute {N}`
- After build: `/vbw:plan {N+1}` or `/vbw:ship`
- After map: `/vbw:plan {N}`

### 8. File Checklist

Checkmark-prefixed list of created or verified files.

```
  ✓ {file-path-1}
  ✓ {file-path-2}
  ✓ {file-path-3}
  ✗ {file-path-4}  (missing)
```

**Usage:** Used by init (created files), map (produced
documents), and build (plan artifacts). Each line is indented
2 spaces. Use ✓ for present/created and ✗ for missing/failed.
Optionally add a brief annotation after the path in parens.

### 9. Metrics Block

Key-value pairs with consistent label padding.

```
  {Label-1}:     {value}
  {Label-2}:     {value}
  {Label-3}:     {value}
```

**Usage:** Used inside Status Dashboard, Ship Confirmation,
and build completion summaries. Labels are left-aligned and
padded with spaces so colons align vertically. Values follow
after consistent spacing. Indented 2 spaces from left margin.

Example with real values:

```
  Plans:      3/3
  Effort:     balanced
  Deviations: 0
  Duration:   4m 32s
```

## Graceful Degradation (VIZL-10)

Guidance for maintaining readability when Unicode rendering
fails or output is viewed in limited environments.

### Principles

1. **Content over decoration:** Text inside boxes must be
   self-explanatory without the box frame. Never put critical
   information only in border characters.

2. **Symbols carry meaning independently:** ✓, ✗, ◆, ○
   convey status even without surrounding box context.

3. **Progress bars degrade to text:** If block characters
   (█ ░) fail to render, the paired percentage (e.g., "70%")
   still communicates progress.

4. **Headings provide structure:** Section headers like
   "Phases:", "Velocity:", "Next Up" create visual hierarchy
   even without box boundaries.

5. **Indentation is structural:** 2-space indentation for
   sub-items works regardless of Unicode support.

### Plain Text Fallback Examples

**Phase Banner -- fallback:**

```
--- Phase 3: Codebase Mapping -- Built ---

  Plans: 3  Waves: 1
  Effort: balanced  Tasks: 5
```

**Status Dashboard -- fallback:**

```
--- My Project / v1.0 Milestone ---

  Phases:
    [done]    Phase 1: Core Framework       100%
    [done]    Phase 2: Agent System          100%
    [active]  Phase 3: Codebase Mapping       60%
    [pending] Phase 4: Visual Feedback         0%

  Velocity:
    Plans completed:  10
    Average duration: 3 min
    Total time:       32 min

  Next: /vbw:execute 4 to continue.
```

**Execution Progress -- fallback:**

```
  [running] Plan 01: Expand brand reference
  [done]    Plan 02: Update init command     3m  2 commits
  [failed]  Plan 03: Status dashboard
  [skipped] Plan 04: Ship confirmation
```

### Fallback Rules

1. Replace double-line box (╔═╗║╚╝) with `---` header/footer
2. Replace single-line box (┌─┐│└┘) with `---` header/footer
3. Replace ◆ with `[active]`, ✓ with `[done]`, ✗ with
   `[failed]`, ○ with `[pending]`
4. Replace progress bar with percentage only: "60%"
5. Keep all text content, indentation, and line structure
6. ➜ degrades to "Next:" prefix
