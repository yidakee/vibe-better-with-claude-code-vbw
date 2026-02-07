# VBW Effort Profiles

Single source of truth for how effort levels map to agent behavior across all VBW operations.

## Overview

Effort profiles control the cost/quality tradeoff via the `effort` parameter -- an Opus 4.6 feature that adjusts reasoning depth. Higher effort means deeper analysis, more thorough verification, and more tokens consumed. Lower effort means faster execution with less exploration.

Model assignment is secondary. Thorough and Balanced profiles use Opus for maximum capability. Fast and Turbo profiles use Sonnet for cost reduction where deep reasoning is less critical.

The `effort` field in `config/defaults.json` sets the global default. Per-invocation overrides are available via the `--effort` flag.

## Profile Matrix

| Profile  | ID      | Model  | Lead | Architect | Dev    | QA     | Scout  | Debugger |
|----------|---------|--------|------|-----------|--------|--------|--------|----------|
| Thorough | EFRT-01 | Opus   | max  | max       | high   | high   | high   | high     |
| Balanced | EFRT-02 | Opus   | high | high      | medium | medium | medium | medium   |
| Fast     | EFRT-03 | Sonnet | high | medium    | medium | low    | low    | medium   |
| Turbo    | EFRT-04 | Sonnet | skip | skip      | low    | skip   | skip   | low      |

## Profile Details

### Thorough (EFRT-01)

**Model:** Opus
**Use when:** Critical features, complex architecture, production-impacting changes.

- **Scout (high):** Broad research across multiple sources. Cross-reference findings between web and codebase. Explore adjacent topics for context. Multiple URLs per finding.
- **Architect (max):** Comprehensive scope analysis. Detailed success criteria with multiple verification paths. Full requirement mapping with traceability matrix. Explicit dependency justification for every phase ordering decision.
- **Lead (max):** Exhaustive research across all sources including WebFetch for external docs. Detailed task decomposition with comprehensive action descriptions. Thorough self-review checking all eight criteria (coverage, DAG, file conflicts, completeness, feasibility, context refs, concerns, skills). Full goal-backward must_haves derivation for every plan.
- **Dev (high):** Careful implementation with thorough inline verification. Complete error handling and edge case exploration. Comprehensive commit messages with detailed change descriptions. Run all verify checks plus supplementary validation.
- **QA (high):** Deep verification tier (30+ checks). Full anti-pattern scan. Requirement-to-artifact traceability mapping. Cross-file consistency checks. Detailed convention verification. All skill-augmented checks if quality skills installed.
- **Debugger (high):** Exhaustive hypothesis testing -- check all 3 hypotheses even if the first seems confirmed. Full regression test suite after fix. Detailed investigation report with complete timeline.

### Balanced (EFRT-02)

**Model:** Opus
**Use when:** Standard development work, most phases. The recommended default.

- **Scout (medium):** Targeted research using primary sources. One source per finding is sufficient. No adjacent topic exploration.
- **Architect (high):** Complete scope coverage. Clear success criteria. Full requirement-to-phase mapping. Standard dependency justification.
- **Lead (high):** Solid research using primary sources (STATE.md, ROADMAP.md, REQUIREMENTS.md, CONCERNS.md). Clear decomposition with sufficient task detail. Self-review checking coverage and feasibility. Goal-backward must_haves for critical paths.
- **Dev (medium):** Focused implementation addressing the task action directly. Standard verification (run verify checks as written). Concise commit messages. No edge case exploration beyond what the plan specifies.
- **QA (medium):** Standard verification tier (15-25 checks). Content structure, key link verification, import/export chains. Convention compliance checks. Skill-augmented checks if installed.
- **Debugger (medium):** Focused investigation. Test hypotheses in rank order, stop when one is confirmed. Standard regression checks on the fixed area. Concise investigation report.

### Fast (EFRT-03)

**Model:** Sonnet
**Use when:** Well-understood features, low-risk changes, iteration speed matters.

- **Scout (low):** Single-source targeted lookups. Answer the specific question with no exploration. One URL per finding maximum.
- **Architect (medium):** Concise scope. Essential success criteria only. Requirements grouped but not individually traced.
- **Lead (high):** Still needs good plans even at speed. Focused research on essential context only (STATE.md, ROADMAP.md). Efficient decomposition with concise task actions. Light self-review for obvious issues (coverage, DAG, feasibility). Must_haves for top-level criteria only.
- **Dev (medium):** Direct implementation with minimal exploration. Implement the shortest path to satisfy done criteria. Standard verify checks. Concise commit messages.
- **QA (low):** Quick verification tier only (5-10 checks). Artifact existence, frontmatter validity, key string presence, no placeholder text. No anti-pattern scan, no convention checks.
- **Debugger (medium):** Efficient diagnosis with no deep exploration. Single most likely hypothesis first. Standard fix-and-verify. Concise report.

### Turbo (EFRT-04)

**Model:** Sonnet
**Use when:** Quick fixes, config changes, obvious tasks, low-stakes edits.

- **Scout:** skip -- not spawned.
- **Architect:** skip -- not spawned.
- **Lead:** skip -- not spawned. No planning step.
- **Dev (low):** Direct execution with no research phase and no planning ceremony. Implement the minimal change. Brief commit messages. Skip non-essential verify checks. No edge case handling beyond the obvious.
- **QA:** skip -- not spawned. No verification step. User judges output directly.
- **Debugger (low):** Rapid fix-and-verify cycle. Single most likely hypothesis only. Targeted fix, confirm reproduction passes. Minimal report (root cause + fix only).

## Per-Invocation Override (EFRT-05)

Users can override the global effort setting per command invocation:

```
/vbw:execute --effort=thorough
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
