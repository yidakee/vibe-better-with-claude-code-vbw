---
name: update
disable-model-invocation: true
description: Update VBW to the latest version with automatic cache refresh.
argument-hint: "[--check]"
allowed-tools: Read, Bash, Glob
---

# VBW Update $ARGUMENTS

## Steps

### Step 1: Read current INSTALLED version

Read the **cached** version — this is what the user actually has installed, regardless of whether the session is running from a source repo or the cache:

```bash
cat ~/.claude/plugins/cache/vbw-marketplace/vbw/*/VERSION 2>/dev/null | sort -V | tail -1
```

Store the result as `old_version`. If empty (no cache exists), fall back to reading `${CLAUDE_PLUGIN_ROOT}/VERSION`.

**CRITICAL:** Do NOT read `${CLAUDE_PLUGIN_ROOT}/VERSION` as the primary source. In a dev session, `${CLAUDE_PLUGIN_ROOT}` resolves to the source repo (which may be ahead of the installed version), causing the update to falsely report "already up to date."

### Step 2: Handle --check

If `$ARGUMENTS` contains `--check`: display version info and STOP.

```
╔═══════════════════════════════════════════╗
║  VBW Version Check                        ║
╚═══════════════════════════════════════════╝

  Installed: v{old_version}

  To update: /vbw:update
```

### Step 3: Check for update

Fetch the latest version from GitHub:
```bash
curl -sf --max-time 5 "https://raw.githubusercontent.com/yidakee/vibe-better-with-claude-code-vbw/main/VERSION"
```

Store result as `remote_version`. If curl fails, STOP with:
```
⚠ Could not reach GitHub to check for updates. Try again later.
```

If `remote_version` equals `old_version`, display:
```
✓ VBW is already at the latest version (v{old_version}). Refreshing cache...
```
Then continue to Step 4 to force a clean cache refresh. This ensures the user always gets a pristine copy from the marketplace, which fixes corrupted caches or stale hook schemas without requiring a version bump.

### Step 4: Nuclear cache wipe

Display: "Wiping all cached versions to prevent contamination..."

Run the cache-nuke script to completely wipe all VBW caches before the update:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cache-nuke.sh
```

This removes `~/.claude/plugins/cache/vbw-marketplace/vbw/`, `~/.claude/commands/vbw/`, and `/tmp/vbw-*` temp files to ensure the subsequent plugin update creates a completely fresh cache with no stale remnants.

### Step 5: Perform update

If `remote_version` equals `old_version`, display: "Refreshing VBW v{old_version} cache..."
Otherwise, display: "Updating VBW v{old_version}..."

**CRITICAL: Always refresh the marketplace FIRST.** The marketplace checkout is a local git clone that can become stale. If you skip this, `plugin update` re-caches the old version.

```bash
claude plugin marketplace update vbw-marketplace 2>&1
```
If this fails, display "⚠ Marketplace refresh failed — trying update anyway..."

Then try each approach in order. Stop at the first one that succeeds:

**Approach A — Platform update:**
```bash
claude plugin update vbw@vbw-marketplace 2>&1
```
If this succeeds (exit 0), continue below to re-sync global commands, then go to Step 6.

**Approach B — Uninstall and reinstall:**
```bash
claude plugin uninstall vbw@vbw-marketplace 2>&1 && claude plugin install vbw@vbw-marketplace 2>&1
```
If this succeeds, continue below to re-sync global commands, then go to Step 6.

**Approach C — Manual fallback:**
If both Bash approaches fail, display the commands for the user to run manually after exiting this session:
```
⚠ Automatic update could not complete. Run these commands manually:

  /plugin marketplace update vbw-marketplace
  /plugin uninstall vbw@vbw-marketplace
  /plugin install vbw@vbw-marketplace

  Then restart Claude Code.
```
STOP here.

**Re-sync global commands** (after Approach A or B succeeds):
```bash
VBW_CACHE_CMD=$(ls -d ~/.claude/plugins/cache/vbw-marketplace/vbw/*/commands 2>/dev/null | sort -V | tail -1)
if [ -d "$VBW_CACHE_CMD" ]; then
  mkdir -p ~/.claude/commands/vbw
  cp "$VBW_CACHE_CMD"/*.md ~/.claude/commands/vbw/ 2>/dev/null
fi
```

### Step 5.5: Ensure VBW statusline

Read `~/.claude/settings.json` and check the `statusLine` field (may be a string or object with `.command`). Extract the command value.

**If it already contains `vbw-statusline`:** skip — VBW statusline is installed.

**If it does NOT contain `vbw-statusline`** (empty, missing, or belongs to another tool): update it to:
```json
{"type": "command", "command": "bash -c 'f=$(ls -1 \"$HOME\"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"$f\" ] && exec bash \"$f\"'"}
```

Use jq to write:
```bash
SETTINGS="$HOME/.claude/settings.json"
SL_CMD=$(jq -r '.statusLine.command // .statusLine // ""' "$SETTINGS" 2>/dev/null)
if ! echo "$SL_CMD" | grep -q 'vbw-statusline'; then
  CORRECT_CMD="bash -c 'f=\$(ls -1 \"\$HOME\"/.claude/plugins/cache/vbw-marketplace/vbw/*/scripts/vbw-statusline.sh 2>/dev/null | sort -V | tail -1) && [ -f \"\$f\" ] && exec bash \"\$f\"'"
  cp "$SETTINGS" "${SETTINGS}.bak"
  if jq --arg cmd "$CORRECT_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "${SETTINGS}.tmp"; then
    mv "${SETTINGS}.tmp" "$SETTINGS"
  else
    cp "${SETTINGS}.bak" "$SETTINGS"
    rm -f "${SETTINGS}.tmp"
  fi
  rm -f "${SETTINGS}.bak"
fi
```

Display `✓ Statusline restored (restart to activate)` if it was changed, or skip silently if already correct.

### Step 6: Verify update

Read the newly cached VERSION to confirm the update landed correctly:
```bash
NEW_CACHED=$(cat ~/.claude/plugins/cache/vbw-marketplace/vbw/*/VERSION 2>/dev/null | sort -V | tail -1)
```

Store `NEW_CACHED` as the authoritative installed version. The marketplace `git pull` may install a newer version than what the GitHub CDN reported in Step 3 — this is normal (CDN lag). Use `NEW_CACHED` for all display output from here on.

Only warn if `NEW_CACHED` is empty or equals `old_version` (meaning the update didn't change anything when it should have):
```
⚠ Update may not have applied — cache still shows v{old_version}.
  Try running /vbw:update again after restarting Claude Code.
```

### Step 7: Display result

**IMPORTANT:** Use `NEW_CACHED` from Step 6 for all version display — it reflects what was actually installed, not the CDN estimate. Do NOT re-read `${CLAUDE_PLUGIN_ROOT}/VERSION` (it points to the old version for this session).

If `NEW_CACHED` equals `old_version` (cache refresh, no version change):
```
╔═══════════════════════════════════════════╗
║  VBW Cache Refreshed                      ║
╚═══════════════════════════════════════════╝

  ✓ Cache refreshed (v{old_version}).

  Restart Claude Code to load the refreshed cache.
```

Otherwise (version upgrade):
```
╔═══════════════════════════════════════════╗
║  VBW Updated                              ║
╚═══════════════════════════════════════════╝

  ✓ Update applied (v{old_version} → v{NEW_CACHED}).

  Restart Claude Code to load the new version.

➜ After restart
  /vbw:whats-new — See what changed
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Double-line box for header
- ✓ success, ⚠ fallback warning
- Next Up Block
- No ANSI color codes
