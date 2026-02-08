---
name: config
description: View and modify VBW configuration including effort profile, verification tier, and skill-hook wiring.
argument-hint: [setting value]
allowed-tools: Read, Write, Edit, Bash, Glob
---

# VBW Config $ARGUMENTS

## Context

Current configuration:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found -- run /vbw:init first"`
```

## Guard

Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md` (check for `.vbw-planning/config.json` specifically).

## Behavior

### No arguments: Interactive configuration

Read .vbw-planning/config.json. Display current settings as a summary table, then use AskUserQuestion to let the user pick what to change.

**Step 1: Display current settings**

```
┌──────────────────────────────────────────┐
│  VBW Configuration                       │
└──────────────────────────────────────────┘

  Setting              Value        Description
  effort               balanced     Agent effort and cost/quality tradeoff
  auto_commit          true         Auto-commit after task completion
  verification_tier    standard     Default QA verification depth
  skill_suggestions    true         Suggest skills during init
  auto_install_skills  false        Auto-install without asking
  visual_format        unicode      Output formatting style
  max_tasks_per_plan   5            Max tasks per plan
  agent_teams          true         Use Agent Teams for parallel builds
  branch_per_milestone false        Auto-create git branch per milestone

  Skill-Hook Mappings:
    {skill-name} -> {hook-event} on {matcher}
    (or "None configured")
```

**Step 2: Ask what to change**

Use AskUserQuestion with up to 4 of the most commonly changed settings. Each question shows the current value and available options:

- **Effort profile**: "Which effort profile?" with options: thorough, balanced, fast, turbo (mark current as selected)
- **Verification tier**: "Default verification tier?" with options: quick, standard, deep
- **Max tasks per plan**: "Max tasks per plan?" with options: 3, 5, 7
- **Agent Teams**: "Use Agent Teams for parallel builds?" with options: Enabled, Disabled

**Step 3: Apply changes**

For each setting the user changed from its current value:
1. Update config.json
2. Display: "✓ {setting}: {old} ➜ {new}"

If nothing changed, display: "✓ No changes made."

Then show:
```
➜ Next Up
  /vbw:config <setting> <value> -- Change other settings directly
  /vbw:status -- View project state
```

### With arguments: Modify a setting

Parse $ARGUMENTS as `<setting> <value>`.

1. Validate setting exists
2. Validate value is allowed
3. Update config.json
4. Display: "✓ {setting}: {old} ➜ {new}"

### Skill-hook wiring: `skill_hook <skill> <event> <matcher>`

Special syntax for configuring skill-to-hook mappings:

- `config skill_hook lint-fix PostToolUse Write|Edit` -- run lint-fix skill after file writes
- `config skill_hook test-runner PostToolUse Bash` -- run test-runner after bash (e.g., git commit)
- `config skill_hook remove <skill>` -- remove a skill-hook mapping

Mappings stored in config.json under `skill_hooks`:
```json
{
  "skill_hooks": {
    "lint-fix": { "event": "PostToolUse", "matcher": "Write|Edit" },
    "test-runner": { "event": "PostToolUse", "matcher": "Bash" }
  }
}
```

These mappings are referenced by hooks/hooks.json to invoke skills at the right time.

## Settings Reference

| Setting              | Type    | Values                       | Default  |
|----------------------|---------|------------------------------|----------|
| effort               | string  | thorough/balanced/fast/turbo | balanced |
| auto_commit          | boolean | true/false                   | true     |
| verification_tier    | string  | quick/standard/deep          | standard |
| skill_suggestions    | boolean | true/false                   | true     |
| auto_install_skills  | boolean | true/false                   | false    |
| visual_format        | string  | unicode/ascii                | unicode  |
| max_tasks_per_plan   | number  | 1-7                          | 5        |
| agent_teams          | boolean | true/false                   | true     |
| branch_per_milestone | boolean | true/false                   | false    |

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Single-line box for config display
- ✓ for successful changes
- ⚠ for invalid setting/value
- ➜ for old-to-new transitions
- No ANSI color codes
