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
[![Discord](https://img.shields.io/badge/Discord-Join%20Us-5865F2.svg?logo=discord&logoColor=white)](https://discord.gg/zh6pV53SaP)

</div>

<br>

## Manifesto

VBW is open source because the best tools are built by the people who use them.

Whether you're a seasoned engineer who wants to push the boundaries of what AI-assisted development can do, or someone who just discovered that a terminal isn't just for airport departures, you belong here. This project exists to make AI coding better for everyone, and "everyone" means exactly that.

**For contributors:** VBW is a living project. The plugin system, the agents, the verification pipeline - all of it is open to improvement. If you've found a better way to plan, build, or verify code with Claude, bring it. File an issue, open a PR, or just show up and share what you've learned. Every contribution makes the next person's experience better.

**For vibe coders:** You don't need to know how VBW works under the hood to get help with your projects. Come to the Discord, share what you're building, ask questions, get unstuck. No gatekeeping, no judgment. We've all stared at a terminal wondering what just happened. The difference is now you don't have to stare alone.

**[Join the Discord](https://discord.gg/zh6pV53SaP)** -- whether you want to help build VBW or just want VBW to help you build.

<br>

## What Is This

> **Platform:** macOS and Linux only. Windows is not supported natively — all hooks, scripts, and context blocks require bash. If you're on Windows, run Claude Code inside [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

Inspired by **[Ralph](https://github.com/frankbria/ralph-claude-code)** and **[Get Shit Done](https://github.com/glittercowboy/get-shit-done)**, however, an entirely new architecture.

VBW is a Claude Code plugin that bolts an actual development lifecycle onto your vibe coding sessions. It gives you 29 slash commands and 6 AI agents that handle planning, building, verifying, and shipping your code, so what you produce has at least a fighting chance of surviving a code review.

You describe what you want. VBW breaks it into phases. Agents plan, write, and verify the code. Commits are atomic. Verification is goal-backward. State persists across sessions. It's the entire software development lifecycle, except you replaced the engineering team with a plugin and a prayer.

Think of it as project management for the post-dignity era of software development.

<br>

## Table of Contents

- [Manifesto](#manifesto)
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

Most Claude Code plugins were built for the subagent era, one main session spawning helper agents that report back and die. Much like the codebases they produce. VBW is designed from the ground up for the platform features that changed the game:

- **Agent Teams for real parallelism.** `/vbw:execute` creates a team of Dev teammates that execute tasks concurrently, each in their own context window. `/vbw:map` runs 4 Scout teammates in parallel to analyze your codebase. This isn't "spawn a subagent and wait" -- it's coordinated teamwork with a shared task list and direct inter-agent communication.

- **Native hooks for continuous verification.** 17 hooks across 11 event types run automatically -- validating SUMMARY.md structure, checking commit format, gating task completion, blocking sensitive file access, enforcing plan file boundaries, managing session lifecycle, tracking session metrics, pre-flight prompt validation, and post-compaction context verification. No more spawning a QA agent after every task. The platform enforces it, not the prompt.

- **Platform-enforced tool permissions.** Each agent has `tools`/`disallowedTools` in their YAML frontmatter -- 4 of 6 agents have platform-enforced deny lists. Scout and QA literally cannot write files. Sensitive file access (`.env`, credentials) is intercepted by the `security-filter` hook. `disallowedTools` is enforced by Claude Code itself, not by instructions an agent might ignore during compaction.

- **Structured handoff schemas.** Agents communicate via JSON-structured SendMessage with typed schemas (`scout_findings`, `dev_progress`, `dev_blocker`, `qa_result`, `debugger_report`). No more hoping the receiving agent can parse free-form markdown. Schema definitions live in a single reference document with backward-compatible fallback to plain text.

<br>

### Solves Agent Teams limitations out of the box

Agent Teams are [experimental with known limitations](https://code.claude.com/docs/en/agent-teams#limitations). VBW handles them so you don't have to:

- **Session resumption.** Agent Teams teammates don't survive `/resume`. VBW's `/vbw:pause` saves full session state, and `/vbw:resume` creates a fresh team from saved state -- detecting completed tasks via SUMMARY.md and git log, then assigning only remaining work.

- **Task status lag.** Teammates sometimes forget to mark tasks complete. VBW's `TaskCompleted` hook verifies task-related commits exist via keyword matching. The `TeammateIdle` hook runs a structural completion check (SUMMARY.md or conventional commit format) before any teammate goes idle.

- **Shutdown coordination.** Claude Code's platform handles teammate cleanup when sessions end. VBW's hooks ensure verification runs before teammates go idle.

- **File conflicts.** Plans decompose work into tasks with explicit file ownership. Dev teammates operate on disjoint file sets by design, enforced at runtime by the `file-guard.sh` hook that blocks writes to files not declared in the active plan.

Agent Teams ship with seven known limitations. VBW addresses all of them. The eighth... that you're using AI to write software doesn't need a fix. It needs an intervention.

<br>

### Skills.sh integration

VBW integrates with [Skills.sh](https://skills.sh), the open-source skill registry for AI agents with 20+ supported platforms and thousands of community-contributed skills:

- **Automatic stack detection.** `/vbw:init` scans your project during setup, identifies your tech stack (Next.js, Django, Prisma, Tailwind, etc.), and recommends relevant skills from a curated mapping.

- **On-demand skill discovery.** Run `/vbw:skills` anytime to detect your stack, browse curated suggestions, search the Skills.sh registry, and install skills in one step. Use `--search <query>` for direct registry lookups.

- **Dynamic registry search.** For stacks not covered by curated mappings, VBW can search the Skills.sh registry via the optional `find-skills` meta-skill. Results are cached locally with a 7-day TTL -- no repeated network calls. Install it with `npx skills add vercel-labs/skills --skill find-skills -g -y`.

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
| No verification unless you ask | Continuous QA via 17 hooks + deep verification on demand |
| Commits whenever, whatever | Atomic commits per task with validation |
| "It works on my machine" | Goal-backward verification against success criteria |
| Agents talk in free-form text | Structured JSON handoff schemas between agents |
| Skills exist somewhere | Stack-aware skill discovery and auto-suggestion |

<br>

### Real-time statusline that knows more about your project than you do

<img src="assets/statusline.png" width="100%" />

Five lines of pure situational awareness, rendered after every response. Phase progress, plan completion, effort profile, QA status... everything a senior engineer would track on a whiteboard, except the whiteboard has been replaced by a terminal and the senior engineer has been replaced by you.

Context window with a live burn bar and token counts. Because somewhere, a staff engineer just felt a disturbance in the force - someone with no CS degree is managing memory allocation, and they're doing it with a progress bar that updates automatically.

API usage limits with countdown timers for session, weekly, and per-model quotas. Session running hot? The bar goes red. Weekly ceiling approaching? You'll know before Anthropic does. Extra usage tracking down to the cent so you always know exactly where your money went. Spoiler: it went to an AI that writes better code than most bootcamp graduates. And some actual graduates, but we don't talk about that at dinner parties.

Cost, duration, diff stats, model info, and GitHub branch, all in one line. It's the kind of dashboard a real engineering team would build after three sprints and a retrospective. You got it by installing a plugin. Twenty years of software craftsmanship, mass layoffs, and all it took to replace the monitoring team was `bash -c` and a dream.

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
                        ┌──────────────┴──────────────┐
                        │ Greenfield?   │  Brownfield? │
                        └──────┬───────┴──────┬───────┘
                               │              │
                  ┌────────────┘              └────────────┐
                  │                                        │
                  ▼                                        ▼
     ┌───────────────────────┐               ┌───────────────────────┐
     │  /vbw:init            │               │  /vbw:init            │
     │  Environment setup    │               │  Environment setup    │
     │  Scaffold + skills    │               │  Scaffold + skills    │
     └──────────┬────────────┘               │                       │
                │                            │  ⚠ Codebase detected  │
                │                            │  Auto-chains:         │
                ▼                            │    → /vbw:map         │
     ┌───────────────────────┐               │    → /vbw:new         │
     │  /vbw:new             │               └──────────┬────────────┘
     │  Define project       │                          │
     │  Requirements,        │                          │
     │  roadmap, CLAUDE.md   │                          │
     └──────────┬────────────┘                          │
                │                                       │
                └───────────────────┬───────────────────┘
                                    │
                                    │ Project defined
                                    │
                   ┌────────────────┴────────────────┐
                   │                                 │
                   ▼                                 ▼
      ┌──────────────────────┐      ┌──────────────────────────────┐
      │ /vbw:discuss         │      │ /vbw:implement [phase]       │
      │ Gather context       │─────▶│ Plan + execute in one step   │
      │ before planning      │      │ Auto-detects what the        │
      │ (optional)           │      │ phase needs                  │
      └──────────────────────┘      └──────────────┬───────────────┘
                                                   │
                                    ┌──────────────┘
                                    │
                                    │  Or separately:
                                    │
                   ┌────────────────┴────────────────┐
                   │                                 │
                   ▼                                 │
      ┌──────────────────────────────┐               │
      │  /vbw:plan [phase]           │               │
      │  Lead agent: researches,     │               │
      │  decomposes, self-reviews    │               │
      │  Outputs: PLAN.md per wave   │               │
      └──────────────┬───────────────┘               │
                     │                               │
                     ▼                               │
      ┌──────────────────────────────┐               │
      │  /vbw:execute [phase]        │               │
      │  Agent Team: Dev teammates   │               │
      │  Per-plan dependency wiring  │               │
      │  Hooks verify continuously   │               │
      │  Outputs: SUMMARY.md         │               │
      └──────────────┬───────────────┘               │
                     │                               │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                      ┌──────────────────────────────┐
                      │  /vbw:qa [phase]             │
                      │  Three-tier verification     │
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
           │ /vbw:implement   │        │ Audits milestone │
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
/vbw:init
```

VBW sets up your environment (Agent Teams, statusline) and scaffolds a `.vbw-planning/` directory with template files. It detects your tech stack and suggests relevant Claude Code skills.

```
/vbw:new Build me a million dollar SaaS, make no mistakes.
```

VBW asks about your project, gathers requirements, and creates a phased roadmap. Now you have structure. Your parents would be proud.

```
/vbw:implement
```

VBW auto-detects the next phase and handles everything -- planning and execution in one step. The Lead agent plans, Dev teammates build in parallel with per-plan dependency wiring, and hooks verify continuously. You get `PLAN.md` + `SUMMARY.md` without switching commands.

Want more control? Use `/vbw:plan` and `/vbw:execute` separately instead.

```
/vbw:status
```

At any point, check where you stand. Shows phase progress, completion bars, velocity metrics, and suggests what to do next. Add `--metrics` for a token consumption breakdown per agent. Think of it as the project dashboard you never bothered to set up manually.

Repeat `/vbw:implement` for each phase until your roadmap is complete.

```
/vbw:ship
```

Archives the milestone, tags the release, updates project docs. You shipped. With actual verification. Your future self won't want to set the codebase on fire. Probably.

> You can always be explicit with `/vbw:plan 3`, `/vbw:execute 2`, etc. Useful for re-running a phase, skipping ahead, or when working across multiple terminals.

<br>

### Picking up an existing codebase

```
/vbw:init
```

VBW detects the existing codebase and auto-chains everything: `/vbw:map` launches 4 Scout teammates to analyze your code across tech stack, architecture, quality, and concerns. Then `/vbw:new` runs automatically with the mapping results, so you define your project with full codebase awareness. One command, three workflows, zero manual sequencing. Think of it as a full-body scan followed by a treatment plan. Results may be upsetting.

Then proceed with `/vbw:implement` (or `/vbw:plan` + `/vbw:execute` separately), `/vbw:qa`, `/vbw:ship` as above.

<br>

---

<br>

## Commands

### Lifecycle -- The Main Loop

These are the commands you'll use every day. This is the job now.

| Command | Description |
| :--- | :--- |
| `/vbw:init` | Set up environment and scaffold `.vbw-planning/` directory with templates and config. Configures Agent Teams and statusline. Detects your tech stack and suggests Claude Code skills. For existing codebases, auto-chains to `/vbw:map` then `/vbw:new`. |
| `/vbw:new [desc]` | Define your project. Asks for name, requirements, creates a phased roadmap, initializes state, and generates CLAUDE.md. |
| `/vbw:plan [phase]` | Plan a phase. The Lead agent researches context, decomposes work into tasks grouped by wave, and self-reviews the plan. Produces PLAN.md files with YAML frontmatter. Accepts `--effort` flag (thorough/balanced/fast/turbo). Phase is auto-detected when omitted. |
| `/vbw:execute [phase]` | Execute a planned phase. Creates an Agent Team with Dev teammates for parallel execution with per-plan dependency wiring. At Thorough effort, Devs enter plan-approval mode before writing code. Atomic commits per task. Continuous QA via hooks. Produces SUMMARY.md. Resumes from last checkpoint if interrupted. Phase is auto-detected when omitted. |
| `/vbw:implement [phase]` | Plan and execute in one command. Auto-detects whether a phase needs planning, execution, or both. Skips the intermediate "Planned" state. Shortcut for `/vbw:plan` then `/vbw:execute`. |
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
| `/vbw:debug` | Systematic bug investigation via the Debugger agent. At Thorough effort with ambiguous bugs, spawns 3 parallel debugger teammates for competing hypothesis investigation. Hypothesis, evidence, root cause, fix. Like the scientific method, except it actually finds things. |
| `/vbw:todo` | Add an item to a persistent backlog that survives across sessions. For all those "we should really..." thoughts that usually die in a terminal tab. |
| `/vbw:pause` | Save full session context. For when biological needs interrupt your workflow. Or your laptop battery does. |
| `/vbw:resume` | Restore previous session. Picks up exactly where you left off with full context. It remembers more about your project than you do. |
| `/vbw:skills` | Browse and install community skills from skills.sh based on your project's tech stack. Detects your stack, suggests relevant skills, and installs them with one command. |
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
| `/vbw:uninstall` | Clean removal of VBW -- statusline, settings, and project data. For when you want to go back to prompting manually like it's 2024. |

<br>

---

<br>

## The Agents

VBW uses 6 specialized agents, each with native tool permissions enforced via YAML frontmatter. Three layers of control -- `tools` (what they can use), `disallowedTools` (what's platform-denied), and `permissionMode` (how they interact with the session) -- mean they can't do what they shouldn't, which is more than can be said for most interns.

| Agent | Role | Tools | Denied | Mode |
| :--- | :--- | :--- | :--- | :--- |
| **Scout** | Research and information gathering. The responsible one. | Read, Grep, Glob, WebSearch, WebFetch | Write, Edit, NotebookEdit, Bash | `plan` |
| **Architect** | Creates roadmaps and phase structure. Writes plans, not code. | Read, Glob, Grep, Write | Edit, WebFetch, Bash | `acceptEdits` |
| **Lead** | Merges research + planning + self-review. The one who actually makes decisions. | Read, Glob, Grep, Write, Bash, WebFetch | Edit | `acceptEdits` |
| **Dev** | Writes code, makes commits, builds things. Handle with care. | Full access | -- | `acceptEdits` |
| **QA** | Goal-backward verification. Trusts nothing. Can run commands but cannot write files. | Read, Grep, Glob, Bash | Write, Edit, NotebookEdit | `plan` |
| **Debugger** | Scientific method bug investigation. One issue, one session. | Full access | -- | `acceptEdits` |

**Denied** = `disallowedTools` -- platform-enforced denial. These tools are blocked by Claude Code itself, not by instructions an agent might ignore during compaction. **Mode** = `permissionMode` -- `plan` means read-only exploration (Scout, QA), `acceptEdits` means the agent can propose and apply changes.

<br>

Here's when each one shows up to work:

```
  /vbw:map                        /vbw:plan              /vbw:execute (or /vbw:implement)
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
  HOOKS (11 event types, 17 handlers)                              VERIFICATION.md
  ┌───────────────────────────────────────────────────────────────────────────────┐
  │  Verification                                                                 │
  │    PostToolUse ──── Validates SUMMARY.md on write, checks commit format,      │
  │                     dispatches skill hooks, updates execution state            │
  │    SubagentStop ─── Validates SUMMARY.md structure on subagent completion      │
  │    TeammateIdle ─── Structural completion gate (SUMMARY.md or commit format)   │
  │    TaskCompleted ── Verifies task-related commit via keyword matching          │
  │                                                                               │
  │  Security                                                                     │
  │    PreToolUse ──── Blocks sensitive file access (.env, keys), enforces plan    │
  │                    file boundaries, dispatches skill hooks                     │
  │                                                                               │
  │  Lifecycle                                                                    │
  │    SessionStart ──── Detects project state, checks map staleness              │
  │    PreCompact ────── Injects agent-specific compaction priorities              │
  │    PostCompact ───── Verifies critical context survived compaction             │
  │    Stop ──────────── Logs session metrics and duration                         │
  │    UserPromptSubmit  Pre-flight prompt validation                              │
  │    NotificationReceived  Logs teammate communication                           │
  └───────────────────────────────────────────────────────────────────────────────┘

  ┌───────────────────────────────────────────────────────────────────────────────┐
  │  PERMISSION MODEL                                                             │
  │                                                                               │
  │  Scout ─────────── True read-only (plan mode). Can look, can't touch.         │
  │  QA ───────────── Read + Bash. Can verify, can't write. The auditor.          │
  │  Architect ─────── Edit/Bash blocked by platform. Write limited to plans      │
  │                    by instruction. Writes roadmaps, not code. Mostly.         │
  │  Lead ─────────── Read, Write, Bash, WebFetch. The middle manager.            │
  │  Dev, Debugger ─── Full access. The ones you actually worry about.            │
  │                                                                               │
  │  Platform-enforced: tools / disallowedTools (cannot be overridden)            │
  │  Instruction-enforced: behavioral constraints in agent prompts                │
  └───────────────────────────────────────────────────────────────────────────────┘
```

<br>

---

<br>

## Effort Profiles

Not every task deserves the same level of scrutiny. Most of yours don't. VBW provides four effort profiles that control how much your agents think before they act.

| Profile | What It Does | When To Use It |
| :--- | :--- | :--- |
| **Thorough** | Maximum agent depth. Full Lead planning, deep QA, comprehensive research. Dev teammates require plan approval before writing code. Competing hypothesis debugging for ambiguous bugs. | Architecture decisions. Things that would be embarrassing to get wrong. |
| **Balanced** | Standard depth. Good planning, solid QA. The default. | Most work. The sweet spot between quality and not burning your API budget. |
| **Fast** | Lighter planning, quicker verification. | Straightforward phases where the path is obvious. |
| **Turbo** | Single Dev agent, no Lead or QA. Just builds. | Trivial changes. Adding a config value. Fixing a typo. Things that don't need a committee. |

```
/vbw:plan 3 --effort=turbo
/vbw:implement --effort=thorough
```

<br>

---

<br>

## Project Structure

```
.claude-plugin/    Plugin manifest (plugin.json)
agents/            6 agent definitions with native tool permissions
commands/          29 slash commands (commands/*.md)
config/            Default settings and stack-to-skill mappings
hooks/             Plugin hooks for continuous verification
scripts/           Hook handler scripts (security, validation, QA gates)
references/        Brand vocabulary, verification protocol, effort profiles, handoff schemas
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

VBW leverages four Opus 4.6 features that make the whole thing work:

**Agent Teams** -- `/vbw:execute`, `/vbw:implement`, and `/vbw:map` create teams of parallel agents. Dev teammates execute tasks concurrently with per-plan dependency wiring (platform-enforced via TaskCreate blockedBy). At Thorough effort, Devs enter plan-approval mode before writing code. Scout teammates communicate via structured JSON schemas for reliable cross-agent handoff. The session acts as team lead.

**Native Hooks** -- 17 hooks across 11 event types provide continuous verification without agent overhead. PostToolUse validates SUMMARY.md structure, commit format, and auto-updates execution state. TeammateIdle gates task completion via structural checks. TaskCompleted verifies task-related commits via keyword matching. SubagentStop validates completion artifacts. PreToolUse blocks sensitive file access and enforces plan boundaries. SessionStart detects project state and checks map staleness. PreCompact preserves agent-specific context. PostCompact verifies critical context survived. Stop logs session metrics. UserPromptSubmit runs pre-flight validation. NotificationReceived logs teammate communication. No more spawning QA agents after every wave.

**Tool Permissions** -- Each agent has native `tools`/`disallowedTools` in their YAML frontmatter. Scout and QA literally cannot write files. It's enforced by the platform, not by instructions that an agent might ignore.

**Structured Handoff Schemas** -- Five JSON schemas define how agents communicate via SendMessage: `scout_findings` (Scout to Map Lead), `dev_progress` and `dev_blocker` (Dev to Execute Lead), `qa_result` (QA to Lead), and `debugger_report` (Debugger to Debug Lead). Type-discriminated with backward-compatible fallback to plain markdown. No more parsing free-form text and hoping for the best.

Four platform features. Zero faith in the developer. As it should be.

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
