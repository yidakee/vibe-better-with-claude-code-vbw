---
name: profile
disable-model-invocation: true
description: Switch between work profiles or create custom ones. Profiles change effort, autonomy, and verification in one go.
argument-hint: "[profile-name | save | delete <name>]"
allowed-tools: Read, Write, Edit
---

# VBW Profile $ARGUMENTS

## Context

Current configuration:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found -- run /vbw:init first"`
```

## Guard

Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md` (check for `.vbw-planning/config.json` specifically).

## Built-in Profiles

These profiles ship with VBW and cannot be deleted:

| Profile | Effort | Autonomy | Verification | Use case |
|---------|--------|----------|--------------|----------|
| `default` | balanced | standard | standard | Fresh install baseline |
| `prototype` | fast | confident | quick | Rapid iteration, exploring ideas |
| `production` | thorough | cautious | deep | Code heading to production |
| `yolo` | turbo | pure-vibe | skip | Just build it, no guardrails |

## Behavior

### No arguments: List and switch

**Step 1: Display profiles**

Read `config.json` to get `active_profile` (default: "default") and `custom_profiles` (default: {}).

```
┌──────────────────────────────────────────┐
│  Work Profiles                           │
└──────────────────────────────────────────┘

  Profile        Effort     Autonomy    Verification
  default *      balanced   standard    standard
  prototype      fast       confident   quick
  production     thorough   cautious    deep
  yolo           turbo      pure-vibe   skip
  {custom ones from config.json, if any}

  * = active profile
```

Mark the active profile with `*`. If `active_profile` is "custom" (settings were manually tweaked after last profile switch), show:
```
  Active: custom (modified from {last_profile})
```

**Step 2: Ask which profile to switch to**

Use AskUserQuestion:
- Question: "Which profile do you want to use?"
- Options: list all available profiles (built-in + custom), plus "Create new profile"
- Mark the current profile with "(active)" in its label

**Step 3: Apply profile**

If the user picks a profile:
1. Read the profile's settings (effort, autonomy, verification_tier)
2. Update those 3 settings in `config.json`
3. Set `active_profile` to the profile name
4. Display:
```
  ✓ Switched to {name}
    effort:       {old} ➜ {new}
    autonomy:     {old} ➜ {new}
    verification: {old} ➜ {new}
```

Only show lines where the value actually changed. If all values were already matching:
```
  ✓ Already on {name} -- no changes needed.
```

If the user picks "Create new profile", proceed to the Save flow below.

### `save` argument: Create a new profile interactively

Guide the user through creating a custom profile. This flow is designed for non-technical users.

**Step S1: Ask for a name**

Use AskUserQuestion:
- Question: "What should this profile be called?"
- Options: "From current settings" (uses current config values as starting point), "From scratch" (pick each setting)

**Step S2: If "From scratch", ask for each setting**

Use AskUserQuestion with up to 3 questions:

1. "How thorough should builds be?" (header: "Effort")
   - "Thorough -- careful, high quality" (thorough)
   - "Balanced -- good quality, reasonable speed" (balanced)
   - "Fast -- speed over perfection" (fast)
   - "Turbo -- fastest possible, minimal checks" (turbo)

2. "How much should VBW ask before acting?" (header: "Autonomy")
   - "Ask me first -- confirm before big actions" (cautious)
   - "Normal -- confirm sometimes" (standard)
   - "Trust me -- only stop for errors" (confident)
   - "Full auto -- never stop, just build" (pure-vibe)

3. "How deep should quality checks go?" (header: "Verify")
   - "Quick glance -- basic sanity checks" (quick)
   - "Standard -- normal verification" (standard)
   - "Deep dive -- thorough QA review" (deep)
   - "Skip -- no verification" (skip)

**Step S3: Ask for the profile name**

Use AskUserQuestion:
- Question: "Name for this profile?"
- Options: suggest 2-3 contextual names based on the settings chosen (e.g., "careful-builder" for thorough+cautious+deep, "speed-demon" for fast+confident+quick), plus user can type their own

**Step S4: Save**

1. Validate the name:
   - Cannot match a built-in name (default, prototype, production, yolo)
   - Cannot contain spaces (suggest hyphens)
   - Must be 1-30 characters
2. Add to `custom_profiles` in `config.json`:
   ```json
   {
     "custom_profiles": {
       "profile-name": {
         "effort": "...",
         "autonomy": "...",
         "verification_tier": "..."
       }
     }
   }
   ```
3. Ask: "Switch to {name} now?"
4. If yes, apply it (same as Step 3 above)
5. Display:
   ```
     ✓ Profile "{name}" saved
     {✓ Switched to {name} | ○ Staying on {current}}
   ```

If "From current settings" was chosen in S1, skip S2 — use current effort, autonomy, and verification_tier values. Go directly to S3 for naming.

### Direct profile name: `profile <name>`

If $ARGUMENTS is a single word that matches a built-in or custom profile name:
1. Apply that profile immediately (same as Step 3 above)
2. No listing or prompting needed

If the name doesn't match any profile:
```
  ⚠ Unknown profile: {name}

  Available: default, prototype, production, yolo{, custom-ones}
  Run /vbw:profile to see all profiles.
```

### `delete <name>`: Remove a custom profile

If $ARGUMENTS starts with "delete":
1. Parse the profile name
2. If it's a built-in: `⚠ Cannot delete built-in profile: {name}`
3. If it doesn't exist in `custom_profiles`: `⚠ Profile not found: {name}`
4. Remove from `custom_profiles` in `config.json`
5. If `active_profile` was the deleted profile, reset to "default" and apply default settings
6. Display: `✓ Deleted profile: {name}`

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Single-line box for profile listing
- ✓ for successful operations
- ⚠ for errors/warnings
- ➜ for old-to-new transitions
- No ANSI color codes
