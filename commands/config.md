---
description: View and modify VBW configuration including effort profile, verification tier, and skill preferences.
argument-hint: [setting value]
allowed-tools: Read, Write, Edit, Bash, Glob
---

# VBW Config $ARGUMENTS

## Context

Current configuration:
```
!`cat .planning/config.json 2>/dev/null || echo "No config found -- run /vbw:init first"`
```

## Guard

If `.planning/config.json` does not exist, STOP and inform the user:
"No VBW configuration found. Run /vbw:init first to initialize your project."

## Behavior

### No arguments: Display current configuration

Read `.planning/config.json` and display all settings as a formatted table with current values and descriptions.

Use a single-line box for the config display:
```
 VBW Configuration
 Setting              Value        Description
 effort               balanced     Controls agent effort and cost/quality tradeoff
 auto_commit          true         Auto-commit after each task completion
 verification_tier    standard     Default QA verification depth
 ...
```

### With arguments: Modify a setting

Parse `$ARGUMENTS` as `<setting> <value>` (e.g., `effort turbo`, `auto_commit false`).

1. Validate the setting name exists in config
2. Validate the value is allowed for that setting type
3. Read current value from `.planning/config.json`
4. Update the setting using the Edit tool
5. Display confirmation: old value ➜ new value

If setting name is invalid, show available settings.
If value is invalid, show allowed values for that setting.

## Settings Reference

| Setting             | Type    | Values                          | Default  | Description                                  |
|---------------------|---------|---------------------------------|----------|----------------------------------------------|
| effort              | string  | thorough/balanced/fast/turbo    | balanced | Controls agent effort levels and cost/quality |
| auto_commit         | boolean | true/false                      | true     | Auto-commit after each task completion        |
| verification_tier   | string  | quick/standard/deep             | standard | Default QA verification depth                 |
| skill_suggestions   | boolean | true/false                      | true     | Suggest skills during init and planning       |
| auto_install_skills | boolean | true/false                      | false    | Auto-install suggested skills without asking  |
| visual_format       | string  | unicode/ascii                   | unicode  | Output formatting style                       |
| compaction_trigger  | number  | 100000-180000                   | 130000   | Token threshold for compaction awareness      |
| max_tasks_per_plan  | number  | 1-7                             | 5        | Maximum tasks per plan                        |

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for visual formatting:
- Single-line box for config display table
- ✓ for successful setting changes
- ⚠ for invalid setting name or value
- ➜ for old value to new value transitions
- No ANSI color codes
