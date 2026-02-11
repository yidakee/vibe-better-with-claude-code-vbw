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

After the settings table, display Model Profile section:
```bash
PROFILE=$(jq -r '.model_profile // "balanced"' .vbw-planning/config.json)
echo ""
echo "Model Profile: $PROFILE"
echo "Agent Models:"
# Resolve each agent model
LEAD=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh lead .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
DEV=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh dev .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
QA=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh qa .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
SCOUT=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh scout .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
DEBUGGER=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh debugger .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
ARCHITECT=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh architect .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
# Check for overrides and mark with asterisk
LEAD_DISPLAY=$LEAD
DEV_DISPLAY=$DEV
QA_DISPLAY=$QA
SCOUT_DISPLAY=$SCOUT
DEBUGGER_DISPLAY=$DEBUGGER
ARCHITECT_DISPLAY=$ARCHITECT
if [ "$(jq -r '.model_overrides.lead // ""' .vbw-planning/config.json)" != "" ]; then LEAD_DISPLAY="${LEAD}*"; fi
if [ "$(jq -r '.model_overrides.dev // ""' .vbw-planning/config.json)" != "" ]; then DEV_DISPLAY="${DEV}*"; fi
if [ "$(jq -r '.model_overrides.qa // ""' .vbw-planning/config.json)" != "" ]; then QA_DISPLAY="${QA}*"; fi
if [ "$(jq -r '.model_overrides.scout // ""' .vbw-planning/config.json)" != "" ]; then SCOUT_DISPLAY="${SCOUT}*"; fi
if [ "$(jq -r '.model_overrides.debugger // ""' .vbw-planning/config.json)" != "" ]; then DEBUGGER_DISPLAY="${DEBUGGER}*"; fi
if [ "$(jq -r '.model_overrides.architect // ""' .vbw-planning/config.json)" != "" ]; then ARCHITECT_DISPLAY="${ARCHITECT}*"; fi
echo "  Lead: $LEAD_DISPLAY | Dev: $DEV_DISPLAY | QA: $QA_DISPLAY | Scout: $SCOUT_DISPLAY | Debugger: $DEBUGGER_DISPLAY | Architect: $ARCHITECT_DISPLAY"
```

**Step 2:** AskUserQuestion with up to 5 commonly changed settings (mark current values):
- Effort: thorough | balanced | fast | turbo
- Autonomy: cautious | standard | confident | pure-vibe
- Verification: quick | standard | deep
- Max tasks per plan: 3 | 5 | 7
- Model Profile: quality | balanced | budget

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

### Model profile switching: `model_profile <profile>`

Validates profile name (quality/balanced/budget), shows before/after cost estimate, updates config.json model_profile field.

```bash
PROFILE="$1"
PROFILES_PATH="${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json"

# Validate profile
if ! jq -e ".$PROFILE" "$PROFILES_PATH" >/dev/null 2>&1; then
  echo "⚠ Unknown profile '$PROFILE'. Valid: quality, balanced, budget"
  exit 0
fi

# Get current profile
OLD_PROFILE=$(jq -r '.model_profile // "balanced"' .vbw-planning/config.json)

# Calculate cost estimate
# Cost weights: opus=100, sonnet=20, haiku=2
calc_cost() {
  local profile=$1
  local opus=$(jq "[.$profile | to_entries[] | select(.value == \"opus\")] | length" "$PROFILES_PATH")
  local sonnet=$(jq "[.$profile | to_entries[] | select(.value == \"sonnet\")] | length" "$PROFILES_PATH")
  local haiku=$(jq "[.$profile | to_entries[] | select(.value == \"haiku\")] | length" "$PROFILES_PATH")
  echo $(( opus * 100 + sonnet * 20 + haiku * 2 ))
}

OLD_COST=$(calc_cost "$OLD_PROFILE")
NEW_COST=$(calc_cost "$PROFILE")
DIFF=$(( (NEW_COST - OLD_COST) * 100 / OLD_COST ))

if [ $DIFF -lt 0 ]; then
  DIFF_ABS=$(( -DIFF ))
  echo "Switching from $OLD_PROFILE to $PROFILE (~${DIFF_ABS}% cost reduction per phase)"
else
  echo "Switching from $OLD_PROFILE to $PROFILE (~${DIFF}% cost increase per phase)"
fi

# Update config.json
jq ".model_profile = \"$PROFILE\"" .vbw-planning/config.json > .vbw-planning/config.json.tmp && mv .vbw-planning/config.json.tmp .vbw-planning/config.json

echo "✓ Model profile ➜ $PROFILE"
```

### Per-agent override: `model_override <agent> <model>`

Validates agent name (lead|dev|qa|scout|debugger|architect) and model (opus|sonnet|haiku). Updates config.json model_overrides object.

```bash
AGENT="$1"
MODEL="$2"

# Validate agent
case "$AGENT" in
  lead|dev|qa|scout|debugger|architect)
    # Valid
    ;;
  *)
    echo "⚠ Unknown agent '$AGENT'. Valid: lead, dev, qa, scout, debugger, architect"
    exit 0
    ;;
esac

# Validate model
case "$MODEL" in
  opus|sonnet|haiku)
    # Valid
    ;;
  *)
    echo "⚠ Unknown model '$MODEL'. Valid: opus, sonnet, haiku"
    exit 0
    ;;
esac

# Get current model for this agent
OLD_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh "$AGENT" .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)

echo "Set $AGENT model override: $MODEL (was: $OLD_MODEL)"

# Update config.json - ensure model_overrides object exists
if ! jq -e '.model_overrides' .vbw-planning/config.json >/dev/null 2>&1; then
  jq '.model_overrides = {}' .vbw-planning/config.json > .vbw-planning/config.json.tmp && mv .vbw-planning/config.json.tmp .vbw-planning/config.json
fi

jq ".model_overrides.$AGENT = \"$MODEL\"" .vbw-planning/config.json > .vbw-planning/config.json.tmp && mv .vbw-planning/config.json.tmp .vbw-planning/config.json

echo "✓ Model override: $AGENT ➜ $MODEL"
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
| discovery_questions | boolean | true/false | true |
| visual_format | string | unicode/ascii | unicode |
| max_tasks_per_plan | number | 1-7 | 5 |
| agent_teams | boolean | true/false | true |
| branch_per_milestone | boolean | true/false | false |
| plain_summary | boolean | true/false | true |
| active_profile | string | profile name or "custom" | default |
| custom_profiles | object | user-defined profiles | {} |

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md — single-line box, ✓ success, ⚠ invalid, ➜ transitions, no ANSI.
