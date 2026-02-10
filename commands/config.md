---
name: config
disable-model-invocation: true
description: View and modify VBW configuration including effort profile, verification tier, and skill-hook wiring.
argument-hint: [setting value]
allowed-tools: Read, Write, Edit, Bash, Glob
---

# VBW Config $ARGUMENTS

## Context

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found -- run /vbw:init first"`
```

## Guard

If no .vbw-planning/ dir: STOP "Run /vbw:init first." (check `.vbw-planning/config.json`)

## Behavior

### No arguments: Interactive configuration

**Step 1:** Display current settings in single-line box table (setting, value, description) + skill-hook mappings.

**Step 2:** AskUserQuestion with up to 4 commonly changed settings (mark current values):
- Effort: thorough | balanced | fast | turbo
- Autonomy: cautious | standard | confident | pure-vibe
- Verification: quick | standard | deep
- Max tasks per plan: 3 | 5 | 7

**Step 3:** Apply changes to config.json. Display ✓ per changed setting with ➜. No changes: "✓ No changes made."

**Step 4: Profile drift detection** — if effort/autonomy/verification_tier changed:
- Compare against active profile's expected values
- If mismatch: AskUserQuestion "Settings no longer match '{profile}'. Save as new profile?" → "Save" (route to /vbw:profile save) or "No" (set active_profile to "custom")
- Skip if no profile-tracked settings changed or already "custom"

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh config` and display.

### With arguments: `<setting> <value>`

Validate setting + value. Update config.json. Display ✓ with ➜.

### Skill-hook wiring: `skill_hook <skill> <event> <matcher>`

- `config skill_hook lint-fix PostToolUse Write|Edit`
- `config skill_hook test-runner PostToolUse Bash`
- `config skill_hook remove <skill>`

Stored in config.json `skill_hooks`:
```json
{"skill_hooks": {"lint-fix": {"event": "PostToolUse", "matcher": "Write|Edit"}}}
```

## Settings Reference

| Setting | Type | Values | Default |
|---------|------|--------|---------|
| effort | string | thorough/balanced/fast/turbo | balanced |
| autonomy | string | cautious/standard/confident/pure-vibe | standard |
| auto_commit | boolean | true/false | true |
| verification_tier | string | quick/standard/deep | standard |
| skill_suggestions | boolean | true/false | true |
| auto_install_skills | boolean | true/false | false |
| visual_format | string | unicode/ascii | unicode |
| max_tasks_per_plan | number | 1-7 | 5 |
| agent_teams | boolean | true/false | true |
| branch_per_milestone | boolean | true/false | false |
| plain_summary | boolean | true/false | true |
| active_profile | string | profile name or "custom" | default |
| custom_profiles | object | user-defined profiles | {} |

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — single-line box, ✓ success, ⚠ invalid, ➜ transitions, no ANSI.
