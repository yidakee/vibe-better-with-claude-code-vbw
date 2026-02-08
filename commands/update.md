---
name: update
description: Update VBW to the latest version with automatic cache refresh.
argument-hint: "[--check]"
allowed-tools: Read, Bash, Glob
---

# VBW Update $ARGUMENTS

## Steps

### Step 1: Read current version

Read `${CLAUDE_PLUGIN_ROOT}/VERSION`. Store as `old_version`.

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

If `remote_version` equals `old_version`, STOP with:
```
✓ VBW is already up to date (v{old_version}).
```

### Step 4: Nuclear cache wipe

Display: "Wiping all cached versions to prevent contamination..."

Run the cache-nuke script to completely wipe all VBW caches before the update:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/cache-nuke.sh
```

This removes `~/.claude/plugins/cache/vbw-marketplace/vbw/`, `~/.claude/commands/vbw/`, and `/tmp/vbw-*` temp files to ensure the subsequent plugin update creates a completely fresh cache with no stale remnants.

### Step 5: Perform update

Display: "Updating VBW v{old_version} -> v{remote_version}..."

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

### Step 6: Verify update

Read the newly cached VERSION to confirm the update landed correctly:
```bash
NEW_CACHED=$(cat ~/.claude/plugins/cache/vbw-marketplace/vbw/*/VERSION 2>/dev/null | sort -V | tail -1)
```

If `NEW_CACHED` does not equal `remote_version`, display:
```
⚠ Version mismatch: expected v{remote_version} but cache contains v{NEW_CACHED}.
  The update may not have applied correctly. Try running /vbw:update again after restarting Claude Code.
```

### Step 7: Display result

**IMPORTANT:** Do NOT re-read `${CLAUDE_PLUGIN_ROOT}/VERSION` — it still points to the old version for this session. Use `remote_version` from Step 3 instead.

```
╔═══════════════════════════════════════════╗
║  VBW Updated                              ║
╚═══════════════════════════════════════════╝

  ✓ Update applied (v{old_version} → v{remote_version}).

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
