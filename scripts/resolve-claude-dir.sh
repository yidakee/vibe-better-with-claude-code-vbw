#!/usr/bin/env bash
# resolve-claude-dir.sh — Canonical CLAUDE_DIR resolution
#
# Source this file from other scripts:
#   . "$(dirname "$0")/resolve-claude-dir.sh"
#
# After sourcing, CLAUDE_DIR is set to the user's Claude config directory,
# respecting the CLAUDE_CONFIG_DIR environment variable when set.
#
# This is the single source of truth for config directory resolution.
# New scripts MUST source this file instead of inlining the fallback pattern.

export CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
