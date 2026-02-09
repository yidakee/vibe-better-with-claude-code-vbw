---
name: release
disable-model-invocation: true
description: Bump version, finalize changelog, tag, commit, push, and create a GitHub release.
argument-hint: "[--dry-run] [--no-push] [--major] [--minor] [--skip-audit]"
allowed-tools: Read, Edit, Bash, Glob, Grep
---

# VBW Release $ARGUMENTS

## Context

Working directory: `!`pwd``

Current version:
```
!`cat VERSION 2>/dev/null || echo "No VERSION file"`
```

Git status:
```
!`git status --short 2>/dev/null || echo "Not a git repository"`
```

## Guard

1. **Not a VBW repo:** If `VERSION` does not exist, STOP: "No VERSION file found. This command must be run from the VBW plugin root."
2. **Dirty working tree:** If `git status --porcelain` shows uncommitted changes (excluding .claude/ and CLAUDE.md), WARN: "Uncommitted changes detected. They will NOT be included in the release commit. Continue?" Wait for confirmation.
3. **No changelog [Unreleased] section:** If CHANGELOG.md does not contain `## [Unreleased]`, WARN: "No [Unreleased] section in CHANGELOG.md. The release commit will only bump version files. Continue?"
4. **Version sync check:** Run `bash scripts/bump-version.sh --verify`. If files are out of sync, WARN but proceed (the bump will fix them).

## Pre-release Audit

Skip this entire section if `--skip-audit` was passed.

This runs after guards pass but before any mutations. It checks whether the changelog and README are up to date with the work done since the last release.

### Audit 1: Find commits since last release

1. Find the most recent release commit: `git log --oneline --grep="chore: release" -1`
2. Extract its hash. If no release commit exists, fall back to the root commit (`git rev-list --max-parents=0 HEAD`).
3. List all commits since that anchor: `git log {hash}..HEAD --oneline`
4. Store the list and count for subsequent steps.

### Audit 2: Analyze changelog completeness

1. Check if CHANGELOG.md contains an `## [Unreleased]` section.
2. If it exists, extract its content (everything between `## [Unreleased]` and the next `## [` heading or EOF).
3. For each commit since last release, check if its scope or key terms appear in the `[Unreleased]` content. Match on conventional commit prefixes (`feat`, `fix`, `refactor`, `chore`, `perf`, `docs`, `style`, `test`) and scope names.
4. Classify each commit as **documented** (matched in changelog) or **undocumented** (not found).
5. If no `[Unreleased]` section exists, all commits are classified as undocumented.

### Audit 3: Check README staleness

1. Count commands: `ls commands/*.md | wc -l` — compare against the number mentioned in README.md (search for patterns like "27 slash commands" or "27 commands").
2. Count hooks: search for hook count in README.md (e.g., "18 hooks") — compare against actual hook count from `hooks/` directory config.
3. Check command table coverage: for any command files modified since the last release (`git diff --name-only {hash}..HEAD -- commands/`), verify the command appears in the README command table.

### Audit 4: Present findings

Display a branded audit report using VBW conventions (single-line box, semantic symbols, no ANSI):

```
┌───────────────────────────────────────────┐
│  Pre-release Audit                        │
└───────────────────────────────────────────┘

  Commits since last release: {count}
  Changelog coverage:         {documented}/{total} ({percentage}%)

  {If all documented:}
  ✓ All commits documented in [Unreleased]

  {If undocumented commits exist:}
  ⚠ Undocumented commits:
    - {hash} {type}({scope}): {description}
    - {hash} {type}({scope}): {description}
    ...

  {If README stale:}
  ⚠ README staleness:
    - Command count: README says {n}, actual {m}
    - Hook count: README says {n}, actual {m}
    - Modified commands not in table: {list}

  {If README current:}
  ✓ README counts are current
```

### Audit 5: Offer remediation

If issues were found in Audit 2 or Audit 3:

**Changelog remediation** (if undocumented commits exist):
1. Generate changelog entries categorized by conventional commit prefix:
   - `feat` → **Added**
   - `fix` → **Fixed**
   - `refactor`, `perf` → **Changed**
   - Removed items → **Removed**
   - Other prefixes → **Changed**
2. Format entries matching existing changelog style: `- **\`{scope}\`** -- {description}`
3. Show generated entries to the user for review before writing.
4. On confirmation, insert entries under the `## [Unreleased]` section (create the section if it doesn't exist, placing it after the `# Changelog` header and before the first versioned section).

**README remediation** (if stale counts detected):
1. Show specific number corrections (e.g., "Update '27 slash commands' to '28 slash commands'").
2. On confirmation, apply the corrections.

**Dry-run behavior**: If `--dry-run` is active, show what would be suggested but do not offer writes. Display: "○ Dry run -- no changes written."

Both remediation actions require explicit user confirmation before any file writes.

## Steps

### Step 1: Parse arguments

- **--dry-run**: Show what would happen without making changes. Display the planned version, changelog rename, files to commit, and exit.
- **--no-push**: Bump, commit, but do not push. Useful for reviewing before pushing.
- **--major**: Bump major version (1.0.70 -> 2.0.0) instead of patch.
- **--minor**: Bump minor version (1.0.70 -> 1.1.0) instead of patch.
- **--skip-audit**: Skip the pre-release changelog and README audit entirely.

If no flags: bump patch version (default behavior of `bump-version.sh`).

### Step 2: Bump version

If **--major** or **--minor**:
1. Read current version from `VERSION`
2. Compute new version:
   - `--major`: increment major, reset minor and patch to 0
   - `--minor`: increment minor, reset patch to 0
3. Write new version to all 4 files manually (same files as `bump-version.sh`):
   - `VERSION`
   - `.claude-plugin/plugin.json` (`.version`)
   - `.claude-plugin/marketplace.json` (`.plugins[0].version`)
   - `marketplace.json` (`.plugins[0].version`)

If neither flag: run `bash scripts/bump-version.sh` (auto-increments patch).

Capture the new version number for subsequent steps.

### Step 3: Update CHANGELOG header

If CHANGELOG.md contains `## [Unreleased]`:
1. Replace `## [Unreleased]` with `## [{new-version}] - {YYYY-MM-DD}` (today's date)
2. Display "✓ CHANGELOG.md: [Unreleased] -> [{new-version}] - {date}"

If no `[Unreleased]` section: display "○ CHANGELOG.md: no [Unreleased] section to rename"

### Step 4: Verify version sync

Run `bash scripts/bump-version.sh --verify` to confirm all 4 files are now in sync at the new version. If this fails, STOP: "Version sync failed after bump. This should not happen -- investigate manually."

### Step 5: Commit

Stage the following files individually (only if they were modified):
- `VERSION`
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `marketplace.json`
- `CHANGELOG.md` (only if [Unreleased] was renamed or audit added entries)
- `README.md` (only if audit updated stale counts)

Commit with message:
```
chore: release v{new-version}
```

Display "✓ Committed: chore: release v{new-version}"

### Step 6: Tag

Create an annotated git tag for the release:

```
git tag -a v{new-version} -m "Release v{new-version}"
```

Display "✓ Tagged: v{new-version}"

### Step 7: Push

If **--no-push**: display "○ Push skipped (--no-push). Run `git push && git push --tags` when ready."

Otherwise:
1. `git push`
2. `git push --tags`
3. Display "✓ Pushed to {remote}/{branch} with tag v{new-version}"

### Step 8: GitHub Release

If **--no-push**: display "○ GitHub release skipped (--no-push)."

Otherwise:
1. Extract the changelog content for this version from CHANGELOG.md (everything under the `## [{new-version}]` heading until the next `## [` heading or `---`).
2. **Authenticate `gh`:** Extract the token from the git remote URL (`git remote get-url origin`). If the URL contains credentials in the format `https://user:TOKEN@github.com/...`, extract the TOKEN and set `GH_TOKEN={TOKEN}` as an env var prefix on the `gh` command. This is required because `gh auth login` may not be configured but the git remote already has a working PAT.
3. Create a GitHub release:
   ```
   GH_TOKEN={extracted-token} gh release create v{new-version} --title "v{new-version}" --notes "{changelog-content}"
   ```
   If no token is found in the remote URL, try `gh release create` without the env var (falls back to `gh auth` or keychain).
4. Display "✓ GitHub release created: v{new-version}"

If `gh` is not available or the command fails, WARN: "⚠ GitHub release failed -- create manually at the repo's releases page." Do not halt the release.

### Step 9: Present summary

Display using VBW brand format:

```
┌───────────────────────────────────────────┐
│  Released: v{new-version}                 │
└───────────────────────────────────────────┘

  Version:    {old} -> {new}
  Audit:      {✓ passed | ⚠ N items updated | ○ skipped}
  Changelog:  {✓ renamed | ○ no [Unreleased] section}
  Commit:     {short hash}
  Tag:        v{new-version}
  Push:       {✓ pushed to origin/main | ○ skipped}
  Release:    {✓ created | ⚠ failed | ○ skipped}

  Files updated:
    ✓ VERSION
    ✓ .claude-plugin/plugin.json
    ✓ .claude-plugin/marketplace.json
    ✓ marketplace.json
    {✓ CHANGELOG.md | ○ CHANGELOG.md (unchanged)}
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Task-level box (single-line) for release banner
- Semantic symbols for status
- No ANSI color codes
