<div align="center">

# Vibe Better With Claude Code (Opus 4.6+) - VBW

*You're not an engineer anymore.*

*You're a prompt jockey with commit access.*

*At least do it properly.*

<br>

<img src="assets/abraham.jpeg" width="300" />

<br>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-v1.0.33+-blue.svg)](https://code.claude.com)
[![Opus 4.6+](https://img.shields.io/badge/Model-Opus_4.6+-purple.svg)](https://anthropic.com)

</div>

<br>

## What Is This

VBW is a Claude Code plugin that bolts an actual development lifecycle onto your vibe coding sessions. It gives you 25 slash commands and 6 AI agents that handle planning, building, verifying, and shipping your code, so what you produce has at least a fighting chance of surviving a code review.

You describe what you want. VBW breaks it into phases. Agents plan, write, and verify the code. Commits are atomic. Verification is goal-backward. State persists across sessions. It's the entire software development lifecycle, except you replaced the engineering team with a plugin and a prayer.

Think of it as project management for the post-dignity era of software development.

<br>

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Quick Tutorial](#quick-tutorial)
- [Commands](#commands)
- [The Agents](#the-agents)
- [Effort Profiles](#effort-profiles)
- [Project Structure](#project-structure)
- [Under the Hood](#under-the-hood)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

<br>

---

<br>

## Features

### Built for Opus 4.6+, not bolted onto it

Most Claude Code plugins were built for the subagent era, one main session spawning helper agents that report back and die. Much like the codebases they produce. VBW is designed from the ground up for the three features that changed the game:

- **Agent Teams for real parallelism.** `/vbw:execute` creates a team of Dev teammates that execute tasks concurrently, each in their own context window. `/vbw:map` runs 4 Scout teammates in parallel to analyze your codebase. This isn't "spawn a subagent and wait" -- it's coordinated teamwork with a shared task list and direct inter-agent communication.

- **Native hooks for continuous verification.** 8 hook events run automatically during builds -- validating writes, checking commits, gating quality, blocking access to sensitive files. No more spawning a QA agent after every task. The platform enforces it, not the prompt.

- **Platform-enforced tool permissions.** Each agent has `tools`/`disallowedTools` in their YAML frontmatter. Scout and QA literally cannot write files. Dev can't be tricked into reading your `.env`. It's enforced by Claude Code itself, not by instructions an agent might ignore during compaction.

<br>

### Solves Agent Teams limitations out of the box

Agent Teams are [experimental with known limitations](https://code.claude.com/docs/en/agent-teams#limitations). VBW handles them so you don't have to:

- **Session resumption.** Agent Teams teammates don't survive `/resume`. VBW's `/vbw:pause` saves full session state, and `/vbw:resume` creates a fresh team from saved state -- detecting completed tasks via SUMMARY.md and git log, then assigning only remaining work.

- **Task status lag.** Teammates sometimes forget to mark tasks complete. VBW's `TaskCompleted` hook verifies every task closure has a corresponding atomic commit. The `TeammateIdle` hook runs a QA gate before any teammate goes idle.

- **Shutdown coordination.** VBW's team lead handles graceful shutdown sequencing -- no orphaned teammates, no dangling task lists.

- **File conflicts.** Plans decompose work into tasks with explicit file ownership. Dev teammates operate on disjoint file sets by design.

Agent Teams ship with seven known limitations. VBW solves them. The eighth... that you're using AI to write software doesn't need a fix. It needs an intervention.

<br>

### Skills.sh integration

VBW integrates with [Skills.sh](https://skills.sh), the open-source skill registry for AI agents with 20+ supported platforms and thousands of community-contributed skills:

- **Automatic stack detection.** `/vbw:init` scans your project, identifies your tech stack (Next.js, Django, Prisma, Tailwind, etc.), and recommends relevant skills from a curated mapping.

- **Dynamic registry search.** For stacks not covered by curated mappings, VBW falls back to the Skills.sh registry via the `find-skills` meta-skill. Results are cached locally with a 7-day TTL -- no repeated network calls.

- **Skill-hook wiring.** Use `/vbw:config` to wire installed skills to hook events. Run your linter after every file write. Run your test runner after every commit. The hooks call the skills automatically.

- **Zero lock-in.** Skills are standard Claude Code skills. They work with or without VBW. VBW just makes discovering and using them part of your workflow instead of an afterthought.

<br>

### What you get versus raw Claude Code

For the "I'll just prompt carefully" crowd.

| Without VBW | With VBW |
| :--- | :--- |
| One long session, no structure | Phased roadmap with requirements traceability |
| Manual agent spawning | 6 specialized agents with enforced permissions |
| Hope the AI remembers context | Persistent state across sessions via `.vbw-planning/` |
| No verification unless you ask | Continuous QA via hooks + deep verification on demand |
| Commits whenever, whatever | Atomic commits per task with validation |
| "It works on my machine" | Goal-backward verification against success criteria |
| Skills exist somewhere | Stack-aware skill discovery and auto-suggestion |

<br>

---

<br>

## Installation

Open Claude Code and run these two commands inside the Claude Code session:

```
/plugin marketplace add yidakee/vibe-better-with-claude-code-vbw
/plugin install vbw@vbw-marketplace
```

That's it. Two commands. If that was too many steps, this plugin might actually be for you.

To update later, inside Claude Code:

```
/vbw:update
```

### Running VBW

**Option A: Supervised mode** (recommended for the cautious)

```bash
claude
```

Claude Code will ask permission before file writes, bash commands, etc. You approve once per tool, per project -- it remembers after that. VBW has its own security layer (agent tool permissions, file access hooks), so the permission prompts are a second safety net. First session has some clicking. After that, smooth sailing.

**Option B: Full auto mode** (recommended for the brave)

```bash
claude --dangerously-skip-permissions
```

No permission prompts. No interruptions. Agents run uninterrupted until the work is done or your API budget isn't. VBW's built-in security controls (read-only agents can't write, `security-filter.sh` blocks `.env` and credentials, QA gates on every task) still apply. The platform just stops asking "are you sure?" every time an agent wants to create a file.

This is how most vibe coders run it. The agents work longer, the flow stays unbroken, and you get to pretend you're supervising while scrolling Twitter.

> **Disclaimer:** The `--dangerously-skip-permissions` flag is called that for a reason. It is not called `--everything-will-be-fine` or `--trust-the-AI-it-knows-what-its-doing`. By using it, you are giving an AI unsupervised write access to your filesystem. VBW does its best to keep agents on a leash, but at the end of the day you are trusting software written by an AI, managed by an AI, and verified by a different AI. If this arrangement doesn't concern you, you are exactly the target audience for this plugin.

<br>

---

<br>

## How It Works

VBW operates on a simple loop that will feel familiar to anyone who's ever shipped software. Or read about it on Reddit.

```
                    ┌─────────────────────────────┐
                    │  YOU HAVE AN IDEA           │
                    │  (dangerous, but continue)  │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                    ┌───────────────────────────────┐
                    │  /vbw:init                    │
                    │  Scaffolds .vbw-planning/ dir │
                    │  Detects your stack           │
                    │  Suggests skills you need     │
                    │  Creates PROJECT.md,          │
                    │  REQUIREMENTS.md, ROADMAP.md  │
                    └──────────────┬────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │ New project            │                        │ Existing codebase
          │                        │                        │
          ▼                        │                        ▼
┌──────────────────┐               │             ┌──────────────────┐
│ /vbw:discuss     │               │             │ /vbw:map         │
│ Clarify goals    │               │             │ 4 parallel agents│
│ before planning  │               │             │ analyze your code│
│ (optional)       │               │             │ Outputs INDEX.md │
└────────┬─────────┘               │             │ and PATTERNS.md  │
         │                         │             └────────┬─────────┘
         └─────────────────────────┼──────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  /vbw:plan [phase]           │
                    │  Lead agent: researches,     │
                    │  decomposes into tasks,      │
                    │  self-reviews the plan       │
                    │  Outputs: PLAN.md per wave   │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  /vbw:execute [phase]          │
                    │  Agent Team: Dev teammates   │
                    │  Atomic commits per task     │
                    │  Hooks verify continuously   │
                    │  Outputs: SUMMARY.md         │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  /vbw:qa [phase]             │
                    │  Three-tier verification     │
                    │  (Quick / Standard / Deep)   │
                    │  Goal-backward methodology   │
                    │  Outputs: VERIFICATION.md    │
                    └──────────────┬───────────────┘
                                   │
                          ┌────────┴────────┐
                          │  More phases?   │
                          └────────┬────────┘
                         yes │          │ no
                             │          │
                    ┌────────┘          └────────┐
                    │                            │
                    ▼                            ▼
         ┌──────────────────┐        ┌──────────────────┐
         │ Loop back to     │        │ /vbw:ship        │
         │ /vbw:plan        │        │ Audits milestone │
         │ for next phase   │        │ Archives state   │
         └──────────────────┘        │ Tags the release │
                                     │ You actually     │
                                     │ shipped something│
                                     └──────────────────┘
```

<br>

---

<br>

## Quick Tutorial

### Starting a brand new project

```
/vbw:init Build me a million dollar SaaS, make no mistakes.
```

VBW scaffolds a `.vbw-planning/` directory with your project definition, requirements, and roadmap. It detects your tech stack and suggests relevant Claude Code skills. Now you have structure. Your parents would be proud.

```
/vbw:plan
```

VBW auto-detects the next phase that needs planning. The Lead agent researches your phase, breaks it into tasks grouped by execution wave, and self-reviews the plan. You get a `PLAN.md` with YAML frontmatter, task breakdown, and dependency mapping. It's like having a tech lead who doesn't sigh audibly when you ask questions.

```
/vbw:execute
```

Again, VBW knows which phase to build next. An Agent Team of Dev teammates executes each task in parallel, making atomic commits. Hooks run continuous verification automatically. You get a `SUMMARY.md` with what was done, what deviated, and how many tokens were burned.

```
/vbw:status
```

At any point, check where you stand. Shows phase progress, completion bars, velocity metrics, and suggests what to do next. Add `--metrics` for a token consumption breakdown per agent. Think of it as the project dashboard you never bothered to set up manually.

Repeat `/vbw:plan` and `/vbw:execute` for each phase until your roadmap is complete.

```
/vbw:ship
```

Archives the milestone, tags the release, updates project docs. You shipped. With actual verification. Your future self won't want to set the codebase on fire. Probably.

> You can always be explicit with `/vbw:plan 3`, `/vbw:execute 2`, etc. Useful for re-running a phase, skipping ahead, or when working across multiple terminals.

<br>

### Picking up an existing codebase

```
/vbw:init "Modernize this legacy Django monolith before it gains sentience"
/vbw:map
```

`/vbw:map` creates an Agent Team with 4 Scout teammates that analyze your codebase across tech stack, architecture, code quality, and concerns. They produce synthesis documents (`INDEX.md`, `PATTERNS.md`) that feed into every subsequent planning session. Think of it as a full-body scan. Results may be upsetting.

Then proceed with `/vbw:plan`, `/vbw:execute`, `/vbw:qa`, `/vbw:ship` as above.

<br>

---

<br>

## Commands

### Lifecycle -- The Main Loop

These are the commands you'll use every day. This is the job now.

| Command | Description |
| :--- | :--- |
| `/vbw:init` | Initialize a project. Scaffolds `.vbw-planning/` with PROJECT.md, REQUIREMENTS.md, ROADMAP.md, and STATE.md. Detects your tech stack and suggests Claude Code skills. Works for both new and existing codebases. |
| `/vbw:plan [phase]` | Plan a phase. The Lead agent researches context, decomposes work into tasks grouped by wave, and self-reviews the plan. Produces PLAN.md files with YAML frontmatter. Accepts `--effort` flag (thorough/balanced/fast/turbo). Phase is auto-detected when omitted. |
| `/vbw:execute [phase]` | Execute a planned phase. Creates an Agent Team with Dev teammates for parallel execution. Atomic commits per task. Continuous QA via hooks. Produces SUMMARY.md. Resumes from last checkpoint if interrupted. Phase is auto-detected when omitted. |
| `/vbw:ship` | Complete a milestone. Runs audit, archives state to `.vbw-planning/milestones/`, tags the git release, merges milestone branch (if any), and updates project docs. The one command that means you actually finished something. |

Phase numbers are optional -- when omitted, VBW auto-detects the next phase based on artifact state.

<br>

### Monitoring -- Trust But Verify

| Command | Description |
| :--- | :--- |
| `/vbw:status` | Progress dashboard showing all phases, completion bars, velocity metrics, and suggested next action. Add `--metrics` for token consumption breakdown per agent. |
| `/vbw:qa [phase]` | Deep verification on demand. Three tiers (Quick, Standard, Deep) with goal-backward methodology. Continuous QA runs automatically via hooks during builds -- this command is for thorough, on-demand verification. Produces VERIFICATION.md. Phase is auto-detected when omitted. |

<br>

### Supporting -- The Safety Net

| Command | Description |
| :--- | :--- |
| `/vbw:fix` | Quick task in Turbo mode. One commit, no ceremony. For when the fix is obvious and you don't need six agents to add a missing comma. |
| `/vbw:debug` | Systematic bug investigation via the Debugger agent. Hypothesis, evidence, root cause, fix. Like the scientific method, except it actually finds things. |
| `/vbw:todo` | Add an item to a persistent backlog that survives across sessions. For all those "we should really..." thoughts that usually die in a terminal tab. |
| `/vbw:pause` | Save full session context. For when biological needs interrupt your workflow. Or your laptop battery does. |
| `/vbw:resume` | Restore previous session. Picks up exactly where you left off with full context. It remembers more about your project than you do. |
| `/vbw:config` | View and toggle VBW settings: effort profiles, skill suggestions, auto-install behavior, and skill-hook wiring. |
| `/vbw:help` | Command reference with usage examples. You are reading its output's spiritual ancestor right now. |

<br>

### Advanced -- For When You're Feeling Ambitious

| Command | Description |
| :--- | :--- |
| `/vbw:map` | Analyze a codebase with 4 parallel Scout teammates (Tech, Architecture, Quality, Concerns). Produces synthesis documents (INDEX.md, PATTERNS.md). Supports monorepo per-package mapping. Security-enforced via hooks: never reads `.env` or credentials. |
| `/vbw:discuss [phase]` | Gather context through adaptive questioning before planning. For when you want to think before you type. Revolutionary concept. Phase is auto-detected when omitted. |
| `/vbw:assumptions [phase]` | Surface Claude's assumptions about your phase approach. Useful for catching misunderstandings before they become commits. Phase is auto-detected when omitted. |
| `/vbw:research` | Standalone research task, decoupled from planning. For when you need answers but aren't ready to commit to a plan. |
| `/vbw:milestone` | Start a new milestone with isolated state, independent phase numbering, and scoped roadmap. Optional `--branch` flag creates a git branch. For projects that have more than one thing to ship. |
| `/vbw:switch` | Switch active milestone context and git branch. Checks for uncommitted changes before switching. |
| `/vbw:audit` | Audit milestone completeness before shipping. 6-check matrix with PASS/WARN/FAIL results. WARN ships, FAIL blocks. |
| `/vbw:add-phase` | Append a new phase to the active roadmap. |
| `/vbw:insert-phase` | Insert an urgent phase between existing ones with automatic renumbering. For when production is on fire. |
| `/vbw:remove-phase` | Remove a future phase and renumber. Refuses to delete phases containing completed work, because even VBW has principles. |
| `/vbw:whats-new` | View changelog entries since your installed version. |
| `/vbw:update` | Update VBW to the latest version. |

<br>

---

<br>

## The Agents

VBW uses 6 specialized agents, each with native tool permissions enforced via YAML frontmatter. They can't do what they shouldn't, which is more than can be said for most interns.

| Agent | Role | Tools |
| :--- | :--- | :--- |
| **Scout** | Research and information gathering. Reads everything, writes nothing. The responsible one. | Read, Grep, Glob, WebSearch, WebFetch |
| **Architect** | Creates roadmaps, derives success criteria, designs phase structure. Writes plans, not code. | Read, Write, Grep, Glob |
| **Lead** | Merges research + planning + self-review in one session. The one who actually makes decisions. | Read, Write, Grep, Glob, Task |
| **Dev** | Writes code, makes commits, builds things. Full tool access. Handle with care. | Full access |
| **QA** | Goal-backward verification. Reads everything, trusts nothing. Cannot modify code. | Read, Grep, Glob, Bash |
| **Debugger** | Scientific method bug investigation. One issue per session to prevent scope creep. | Full access |

<br>

Here's when each one shows up to work:

```
  /vbw:map                        /vbw:plan                       /vbw:execute
  ┌─────────┐                     ┌─────────┐                     ┌─────────┐
  │         │                     │         │                     │         │
  │  SCOUT  │ ──reads codebase──▶ │  LEAD   │ ──produces plan──▶  │   DEV   │
  │ (team)  │    INDEX.md         │(subagt) │    PLAN.md          │ (team)  │
  │         │    PATTERNS.md      │         │                     │         │
  └─────────┘                     └────┬────┘                     └────┬────┘
                                       │                               │
  /vbw:init                            │ reads context from            │ atomic
  ┌───────────┐                        │                               │ commits
  │           │                        ▼                               │
  │ ARCHITECT │ ──────────▶ ROADMAP.md, REQUIREMENTS.md                │
  │           │             SUCCESS CRITERIA                           ▼
  └───────────┘                                                   ┌─────────┐
                                                                  │         │
                                                                  │   QA    │
  /vbw:debug                                                      │(subagt) │
  ┌──────────┐                                                    └────┬────┘
  │          │                                                         │
  │ DEBUGGER │ ──one bug, one session, one fix──▶ commit               │ deep
  │(subagt)  │   (scope creep is for amateurs)                         │ verify
  └──────────┘                                                         │
                                                                       ▼
  HOOKS (continuous)                                             VERIFICATION.md
  ┌──────────────────────────────────────────────────────────────────────────┐
  │  PostToolUse ──── Validates writes and commits continuously              │
  │  TeammateIdle ─── QA gate before teammate goes idle                      │
  │  TaskCompleted ── Verifies atomic commit exists                          │
  │  PreToolUse ───── Blocks access to sensitive files (.env, keys)          │
  └──────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  PERMISSION MODEL                                                        │
  │                                                                          │
  │  Scout, QA ──────── Read-only. Can look, can't touch.                    │
  │  Architect ──────── Writes plans and roadmaps. Not code. Ever.           │
  │  Lead ──────────── Reads + writes plans. The middle manager.             │
  │  Dev, Debugger ──── Full access. The ones you actually worry about.      │
  └──────────────────────────────────────────────────────────────────────────┘
```

<br>

---

<br>

## Effort Profiles

Not every task deserves the same level of scrutiny. Most of yours don't. VBW provides four effort profiles that control how much your agents think before they act.

| Profile | What It Does | When To Use It |
| :--- | :--- | :--- |
| **Thorough** | Maximum agent depth. Full Lead planning, deep QA, comprehensive research. | Architecture decisions. Things that would be embarrassing to get wrong. |
| **Balanced** | Standard depth. Good planning, solid QA. The default. | Most work. The sweet spot between quality and not burning your API budget. |
| **Fast** | Lighter planning, quicker verification. | Straightforward phases where the path is obvious. |
| **Turbo** | Single Dev agent, no Lead or QA. Just builds. | Trivial changes. Adding a config value. Fixing a typo. Things that don't need a committee. |

```
/vbw:plan 3 --effort=turbo
```

<br>

---

<br>

## Project Structure

```
.claude-plugin/    Plugin manifest (plugin.json)
agents/            6 agent definitions with native tool permissions
skills/            25 slash commands (skills/*/SKILL.md)
config/            Default settings and stack-to-skill mappings
hooks/             Plugin hooks for continuous verification
scripts/           Hook handler scripts (security, validation, QA gates)
references/        Brand vocabulary, verification protocol, effort profiles
templates/         Artifact templates (PLAN.md, SUMMARY.md, etc.)
assets/            Images and static files
```

<br>

When you run `/vbw:init` in your project, it creates:

```
.vbw-planning/
  PROJECT.md       Project definition, core value, requirements, decisions
  REQUIREMENTS.md  Versioned requirements with traceability
  ROADMAP.md       Phases, plans, success criteria, progress tracking
  STATE.md         Current position, velocity metrics, session continuity
  config.json      Local VBW configuration
  phases/          Execution artifacts (PLAN.md, SUMMARY.md per phase)
  milestones/      Archived milestone records
```

Your AI-managed project now has more structure than most startups that raised a Series A.

<br>

---

<br>

## Under the Hood

VBW leverages three Opus 4.6 features that make the whole thing work:

**Agent Teams** -- `/vbw:execute` and `/vbw:map` create teams of parallel agents. Dev teammates execute tasks concurrently, each with their own context window. The session acts as team lead. This replaces the old sequential wave system.

**Native Hooks** -- 8 hook events provide continuous verification without agent overhead. PostToolUse validates writes and commits. TeammateIdle gates quality. TaskCompleted verifies atomic commits exist. PreToolUse blocks access to sensitive files. No more spawning QA agents after every wave.

**Tool Permissions** -- Each agent has native `tools`/`disallowedTools` in their YAML frontmatter. Scout and QA literally cannot write files. It's enforced by the platform, not by instructions that an agent might ignore.

Three platform features. Zero faith in the developer. As it should be.

<br>

---

<br>

## Requirements

- **Claude Code** with **Opus 4.6+** model
- **Agent Teams** enabled (`/vbw:init` will offer to set this up for you)
- A project directory (new or existing)
- The willingness to let an AI manage your development lifecycle

That last one is the real barrier to entry.

<br>

---

<br>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on local development, project structure, and pull requests.

<br>

## License

MIT -- see [LICENSE](LICENSE) for details.

Built by [Tiago Serôdio](https://github.com/yidakee).
