---
name: debug
description: Investigate a bug using the Debugger agent's scientific method protocol.
argument-hint: "<bug description or error message>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Debug: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`head -40 .vbw-planning/STATE.md 2>/dev/null || echo "No state found"`
```

Recent commits:
```
!`git log --oneline -10 2>/dev/null || echo "No git history"`
```

## Guard

1. **Not initialized:** Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.
2. **Missing bug description:** If $ARGUMENTS is empty, STOP: "Usage: /vbw:debug \"description of the bug or error message\""

## Steps

### Step 1: Parse and resolve effort

The entire $ARGUMENTS string is the bug description.

Read effort from config or --effort flag. Map per `${CLAUDE_PLUGIN_ROOT}/references/effort-profiles.md`:

| Profile  | DEBUGGER_EFFORT |
|----------|-----------------|
| Thorough | high            |
| Balanced | medium          |
| Fast     | medium          |
| Turbo    | low             |

### Step 2: Classify bug ambiguity

Determine if the bug is ambiguous using these signals (any 2+ = ambiguous):
- Bug description contains words like "intermittent", "sometimes", "random", "unclear", "inconsistent", "flaky", "sporadic", "nondeterministic"
- Multiple potential root cause areas mentioned
- Error message is generic or missing (e.g., "it just doesn't work", "something is wrong")
- Bug has been investigated before without resolution (check git log for reverted fix attempts)

**Flag overrides:**
- `--competing` or `--parallel` in $ARGUMENTS: always classify as ambiguous regardless of signals
- `--serial` in $ARGUMENTS: never classify as ambiguous regardless of signals

### Step 3: Spawn investigation

This step has two paths based on effort level and ambiguity classification.

**Path A: Competing Hypotheses (DEBUGGER_EFFORT=high AND bug is ambiguous)**

1. Generate 3 independent hypotheses about the bug's root cause before spawning any agents. Each hypothesis must identify: the suspected cause, which area of the codebase to investigate, and what evidence would confirm/refute it.

2. Create an Agent Team via TeamCreate with name "debug-{timestamp}" and description "Competing hypothesis investigation".

3. Create 3 tasks via TaskCreate -- one per hypothesis. Each task description includes:
   - The bug report
   - ONLY this teammate's assigned hypothesis (not the others -- prevent cross-contamination)
   - Working directory
   - Instruction: "Investigate ONLY this hypothesis. Use SendMessage to report your findings to the lead when done. Include: evidence found (for/against), confidence level (high/medium/low), and recommended fix if confirmed."

4. Spawn 3 vbw-debugger teammates, assign one task each.

5. Wait for all 3 to complete. Collect their findings via received messages.

6. Synthesize: Compare findings across all 3 investigations. The hypothesis with the strongest confirming evidence and highest confidence wins. If multiple hypotheses are confirmed, they may be contributing factors -- document all.

7. If a winning hypothesis has a recommended fix: apply the fix (or spawn one more debugger to apply it), commit with `fix({scope}): {description}`.

8. Follow the Agent Teams Shutdown Protocol in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md`.

**Path B: Standard Investigation (all other effort levels, or DEBUGGER_EFFORT=high + non-ambiguous)**

Spawn vbw-debugger as a subagent via the Task tool with thin context:

```
Bug investigation. Effort: {DEBUGGER_EFFORT}.
Bug report: {description}.
Working directory: {pwd}.
Follow protocol: reproduce, hypothesize, gather evidence, diagnose, fix, verify, document.
If you apply a fix, commit with: fix({scope}): {description}.
```

### Step 4: Present investigation summary

```
┌──────────────────────────────────────────┐
│  Bug Investigation Complete              │
└──────────────────────────────────────────┘

  Mode:       {investigation mode -- see below}
  Issue:      {one-line summary}
  Root Cause: {from report}
  Fix:        {commit hash and message, or "No fix applied"}

  Files Modified: {list}

➜ Next: /vbw:status -- View project status
```

**Investigation mode line:**
- For Path A: "Competing Hypotheses (3 parallel)" followed by a brief summary of each hypothesis and its outcome (confirmed/refuted/inconclusive)
- For Path B: "Standard (single debugger)"

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Single-line box for investigation banner
- Metrics Block for issue/root cause/fix
- Next Up Block for navigation
- No ANSI color codes
