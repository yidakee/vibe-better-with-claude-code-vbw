# Contributing to VBW

Thanks for considering a contribution. VBW is a Claude Code plugin, so the conventions are slightly different from a typical codebase.

## Prerequisites

- Claude Code v1.0.33+ with Opus 4.6+
- Agent Teams enabled
- Familiarity with the [Claude Code plugin system](https://code.claude.com/docs/en/plugins)

## Local Development

Clone the repo, install the git hooks, and load it as a local plugin:

```bash
git clone https://github.com/yidakee/vibe-better-with-claude-code-vbw.git
cd vibe-better-with-claude-code-vbw
bash scripts/install-hooks.sh
claude --plugin-dir .
```

The pre-push hook checks version file consistency (see Version Management below). All `/vbw:*` commands will be available. Restart Claude Code to pick up changes.

## Project Structure

```
.claude-plugin/    Plugin manifest (plugin.json)
agents/            6 agent definitions with native tool permissions
commands/          20 slash commands (commands/*.md)
config/            Default settings and stack-to-skill mappings
hooks/             Plugin hooks (hooks.json)
scripts/           Hook handler scripts
references/        Brand vocabulary, verification protocol, effort profiles
templates/         Artifact templates (PLAN.md, SUMMARY.md, etc.)
assets/            Images and static files
```

Key conventions:

- **Commands** live in `commands/*.md`. Use explicit prefixed names in frontmatter (e.g., `name: vbw:init`) so commands show as `/vbw:*`.
- **Agents** in `agents/` use YAML frontmatter for tool permissions enforced by the platform.
- **Hooks** in `hooks/hooks.json` self-resolve scripts via `ls | sort -V | tail -1` against the plugin cache (they do not use `CLAUDE_PLUGIN_ROOT`).

## Making Changes

1. **Fork the repo** and create a feature branch from `main`.
2. **Test locally** with `claude --plugin-dir .` before submitting.
   - Run automated checks: `bash testing/run-all.sh`
3. **Keep commits atomic** -- one logical change per commit.
4. **Match the existing tone** in command descriptions and user-facing text. VBW is direct, dry, and self-aware. It doesn't use corporate language or unnecessary enthusiasm.

## What to Contribute

Good candidates:

- Bug fixes in hook scripts or commands
- New slash commands that fit the lifecycle model (init, vibe, verify, release)
- Improvements to agent definitions or tool permissions
- Stack-to-skill mappings in `config/`
- Template improvements

Less good candidates:

- Rewrites of the core lifecycle flow without prior discussion
- Features that require dependencies or build steps (VBW is zero-dependency by design)
- Changes that break the effort profile system

## Pull Request Process

1. Open an issue first for non-trivial changes so we can discuss the approach.
2. Reference the issue in your PR.
3. Describe what changed and why. Include before/after if relevant.
4. Ensure `claude --plugin-dir .` loads without errors.
5. Test your changes against at least one real project.

## Version Management

VBW keeps the version in sync across four files:

| File | Field |
|------|-------|
| `VERSION` | Plain text, single line |
| `.claude-plugin/plugin.json` | `.version` |
| `.claude-plugin/marketplace.json` | `.plugins[0].version` |
| `marketplace.json` | `.plugins[0].version` |

All four **must** match at all times.

**Version bumping happens at merge time.** When a PR is merged to `main`, the maintainer bumps the version across all 4 files using the bump script and commits the result. Contributors do not need to bump versions in their branches.

To bump the version (maintainer only):

```bash
bash scripts/bump-version.sh
git add VERSION .claude-plugin/plugin.json .claude-plugin/marketplace.json marketplace.json
git commit -m "chore: bump version to $(cat VERSION)"
```

To verify that all four files are in sync locally:

```bash
scripts/bump-version.sh --verify
```

This exits `0` if all versions match and `1` with a diff report if they diverge.

### Push Workflow

A git pre-push hook enforces that all 4 version files are **consistent** (same value). It does **not** require a version bump — that happens at merge time.

```bash
# Work freely, commit as needed
git commit -m "feat(commands): add new feature"
git push
```

The hook only blocks pushes if the 4 version files have mismatched values. Use `git push --no-verify` to bypass in rare cases.

**Install the hook after cloning:**

```bash
bash scripts/install-hooks.sh
```

> **Note:** If you use VBW, the hook is auto-installed by `/vbw:init` and on session start. Manual installation is only needed for contributors not using VBW.

## Code Style

- Shell scripts: bash, no external dependencies beyond `jq` and `git`
- Markdown commands: YAML frontmatter with single-line `description` field
- No prettier on `.md` files with frontmatter (use `.prettierignore`)

## Reporting Bugs

Use the [bug report template](https://github.com/yidakee/vibe-better-with-claude-code-vbw/issues/new?template=bug_report.md). Include your Claude Code version, the command that failed, and any error output.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
