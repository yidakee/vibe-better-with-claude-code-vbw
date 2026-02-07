# Contributing to VBW

Thanks for considering a contribution. VBW is a Claude Code plugin, so the conventions are slightly different from a typical codebase.

## Prerequisites

- Claude Code v1.0.33+ with Opus 4.6+
- Agent Teams enabled
- Familiarity with the [Claude Code plugin system](https://code.claude.com/docs/en/plugins)

## Local Development

Clone the repo and load it as a local plugin:

```bash
git clone https://github.com/yidakee/vibe-better-with-claude-code-vbw.git
cd vibe-better-with-claude-code-vbw
claude --plugin-dir .
```

This loads VBW without installing it. All `/vbw:*` commands will be available. Restart Claude Code to pick up changes.

## Project Structure

```
.claude-plugin/    Plugin manifest (plugin.json)
agents/            6 agent definitions with native tool permissions
commands/          25 slash commands (flat .md files)
config/            Default settings and stack-to-skill mappings
hooks/             Plugin hooks (hooks.json)
scripts/           Hook handler scripts
references/        Brand vocabulary, verification protocol, effort profiles
templates/         Artifact templates (PLAN.md, SUMMARY.md, etc.)
assets/            Images and static files
```

Key conventions:

- **Commands** live in `commands/` as flat `.md` files. The plugin name (`vbw`) auto-prefixes them, so `commands/init.md` becomes `/vbw:init`. Don't duplicate the prefix.
- **Skills** in `skills/*/SKILL.md` are passive knowledge for agents, not user-invocable commands.
- **Agents** in `agents/` use YAML frontmatter for tool permissions enforced by the platform.
- **Hooks** in `hooks/hooks.json` reference scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/`.

## Making Changes

1. **Fork the repo** and create a feature branch from `main`.
2. **Test locally** with `claude --plugin-dir .` before submitting.
3. **Keep commits atomic** -- one logical change per commit.
4. **Match the existing tone** in command descriptions and user-facing text. VBW is direct, dry, and self-aware. It doesn't use corporate language or unnecessary enthusiasm.

## What to Contribute

Good candidates:

- Bug fixes in hook scripts or commands
- New slash commands that fit the lifecycle model (plan, build, verify, ship)
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

## Code Style

- Shell scripts: bash, no external dependencies beyond `jq` and `git`
- Markdown commands: YAML frontmatter with single-line `description` field
- No prettier on `.md` files with frontmatter (use `.prettierignore`)

## Reporting Bugs

Use the [bug report template](https://github.com/yidakee/vibe-better-with-claude-code-vbw/issues/new?template=bug_report.md). Include your Claude Code version, the command that failed, and any error output.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
