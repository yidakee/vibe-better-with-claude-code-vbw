# VBW Effort Profiles

Single source of truth for how effort levels map to agent behavior across all VBW operations.

## Overview

Effort profiles control the cost/quality tradeoff via the `effort` parameter -- an Opus 4.6 feature that adjusts reasoning depth. Higher effort means deeper analysis, more thorough verification, and more tokens consumed. Lower effort means faster execution with less exploration. Model assignment is secondary: Thorough and Balanced use Opus; Fast and Turbo use Sonnet.

The `effort` field in `config/defaults.json` sets the global default. Per-invocation overrides are available via the `--effort` flag.

## Profile Matrix

| Profile  | ID      | Model  | Lead | Architect | Dev    | QA     | Scout  | Debugger | Plan Approval |
|----------|---------|--------|------|-----------|--------|--------|--------|----------|---------------|
| Thorough | EFRT-01 | Opus   | max  | max       | high   | high   | high*  | high     | required      |
| Balanced | EFRT-02 | Opus   | high | high      | medium | medium | medium*| medium   | off           |
| Fast     | EFRT-03 | Sonnet | high | medium    | medium | low    | low    | medium   | off           |
| Turbo    | EFRT-04 | Sonnet | skip | skip      | low    | skip   | skip   | low      | off           |

\* Scout uses inherited model (Opus) at Thorough/Balanced and Haiku at Fast/Turbo.

## Profile Details

Individual profile behavior is documented in dedicated files:
- **Thorough:** `references/effort-profile-thorough.md`
- **Balanced:** `references/effort-profile-balanced.md`
- **Fast:** `references/effort-profile-fast.md`
- **Turbo:** `references/effort-profile-turbo.md`

Load only the active profile's file when executing a command.

## Per-Invocation Override (EFRT-05)

Users can override the global effort setting per command invocation:

```
/vbw:execute --effort=thorough
/vbw:implement --effort=thorough
```

The `--effort` flag takes precedence over the `config/defaults.json` default for that invocation only. It does not modify the stored default.

Valid values: `thorough`, `balanced`, `fast`, `turbo`.

## Effort Logging (EFRT-06)

After each plan execution, the effort profile used is recorded in SUMMARY.md frontmatter:

```yaml
effort_used: balanced
```

This enables quality correlation: if a plan built at `fast` has verification failures, the user may want to rebuild at `balanced` or `thorough`.

## Agent Effort Parameter Mapping

Map abstract effort levels to the `effort` parameter values that Claude Code accepts:

| Level  | Behavior                                            |
|--------|-----------------------------------------------------|
| max    | No effort override (default maximum reasoning)      |
| high   | Deep reasoning with focused scope                   |
| medium | Moderate reasoning depth, standard exploration      |
| low    | Minimal reasoning, direct execution                 |
| skip   | Agent is not spawned at all                         |

When spawning a subagent, the orchestrating command sets the effort parameter based on the active profile and the agent's column value from the profile matrix above.

## Plan Approval Gate (EFRT-07)

At Thorough effort, Dev teammates are spawned with `plan_mode_required`. This activates a platform-enforced review gate:

1. Dev receives its task and reads the PLAN.md
2. Dev proposes its implementation approach (read-only mode -- cannot write files)
3. Lead reviews the proposed approach
4. Lead approves (Dev exits plan mode, begins implementation) or rejects with feedback (Dev revises approach)

This is **platform-enforced**: the Dev literally cannot make file changes until the lead approves. This is strictly stronger than instruction-enforced constraints (per the two-tier enforcement framework from the v1.1 audit).

**Autonomy overrides effort-based plan approval.** The `autonomy` config setting can expand or disable the plan approval gate regardless of effort level:

| Effort Level | Default (standard) | cautious | confident / dangerously-vibe |
|-------------|-------------------|----------|------------------------------|
| Thorough    | required          | required | **OFF**                      |
| Balanced    | off               | **required** | OFF                      |
| Fast        | off               | off      | OFF                          |
| Turbo       | off               | off      | OFF                          |

- `cautious` expands plan approval to Balanced effort (more oversight)
- `standard` uses the effort-based defaults shown above (current behavior)
- `confident` and `dangerously-vibe` disable plan approval entirely (less friction)

Rationale per effort level at `standard` autonomy:

| Effort Level | Plan Approval | Rationale |
|-------------|---------------|-----------|
| Thorough    | required      | Correctness over speed; review gate catches misinterpretation before code is written |
| Balanced    | off           | Standard execution; review gate would slow iteration without proportional quality gain |
| Fast        | off           | Speed priority; review gate contradicts purpose |
| Turbo       | off           | No lead agent at Turbo; plan approval requires a lead to approve |
