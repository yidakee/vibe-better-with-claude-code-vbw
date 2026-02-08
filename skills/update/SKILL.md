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

### Step 4: Perform update

Display: "Updating VBW v{old_version} -> v{remote_version}..."

Try each approach in order. Stop at the first one that succeeds:

**Approach A — Platform update:**
```bash
claude plugin update vbw@vbw-marketplace 2>&1
```
If this succeeds (exit 0), go to Step 5.

**Approach B — Uninstall and reinstall:**
```bash
claude plugin uninstall vbw@vbw-marketplace 2>&1 && claude plugin marketplace update vbw-marketplace 2>&1 && claude plugin install vbw@vbw-marketplace 2>&1
```
If this succeeds, go to Step 5.

**Approach C — Manual fallback:**
If both Bash approaches fail, display the commands for the user to run manually after exiting this session:
```
⚠ Automatic update could not complete. Run these commands manually:

  /plugin marketplace update
  /plugin uninstall vbw@vbw-marketplace
  /plugin install vbw@vbw-marketplace

  Then restart Claude Code.
```
STOP here.

### Step 5: Clean old cache versions

Remove all old cached versions except the latest. This prevents stale caches from being used:
```bash
ls -d ~/.claude/plugins/cache/vbw-marketplace/vbw/*/ 2>/dev/null | sort -V | head -n -1 | while IFS= read -r d; do rm -rf "$d"; done
```

Verify cleanup succeeded:
```bash
REMAINING=$(ls -1d ~/.claude/plugins/cache/vbw-marketplace/vbw/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "${REMAINING:-0}" -gt 1 ]; then
  echo "WARNING: ${REMAINING} cached versions remain — attempting forced cleanup"
  ls -d ~/.claude/plugins/cache/vbw-marketplace/vbw/*/ 2>/dev/null | sort -V | head -n -1 | xargs rm -rf
fi
```

### Step 6: Display result

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
