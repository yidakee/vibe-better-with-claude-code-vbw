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

## VBW Token Efficiency vs Stock Opus 4.6 Agent Teams

VBW wraps Claude Code's native Agent Teams with 15 optimization mechanisms across 7 architectural layers -- shell pre-computation, model routing, context diet, compaction resilience, scope enforcement, structured coordination, and effort scaling. The result: same coordination capability, significantly fewer tokens burned on overhead.

Stock teams load all command descriptions into every request, run every agent on Opus, coordinate via expensive message round-trips, and let each agent independently discover project state by reading the same files. VBW replaces all of that with 1,624 lines of bash that execute at zero model token cost, hardcoded model routing (Scout on Haiku, QA on Sonnet), disk-based coordination, and pre-computed state injection.

| Category | Stock Agent Teams | VBW | Saving |
| :--- | ---: | ---: | ---: |
| Base context overhead | 10,800 tokens | 3,200 tokens | **70%** |
| State computation per command | 1,300 tokens | 200 tokens | **85%** |
| Agent coordination (x4 agents) | 16,000 tokens | 3,200 tokens | **80%** |
| Compaction recovery | 5,000 tokens | 2,000 tokens | **60%** |
| Context duplication (shared files) | 16,500 tokens | 5,000 tokens | **70%** |
| Agent model cost per phase | $2.78 | $1.59 | **43%** |
| **Total coordination overhead** | **87,100 tokens** | **33,200 tokens** | **62%** |

The three highest-impact optimizations: `disable-model-invocation` on 19 of 29 commands removes ~7,600 tokens from every API request; model routing sends Scout to Haiku (60x cheaper than Opus) and QA to Sonnet (5x cheaper); and shell pre-computation via `phase-detect.sh` and `session-start.sh` replaces 5-7 file reads with 22 pre-computed key-value pairs.

**What this means for your bill:**

VBW's 42% total token reduction per phase means each phase burns fewer tokens on coordination overhead. For API users, that's direct dollar savings. For subscription plans, your rate limit budget stretches ~1.7x further -- equivalent to getting 70% more development capacity for the same price.

| Scenario | Without VBW | With VBW | Impact |
| :--- | ---: | ---: | ---: |
| API: single project (10 phases) | ~$28 | ~$16 | **~$12 saved** |
| API: active dev (20 phases/mo) | ~$56/mo | ~$32/mo | **~$24/mo saved (~$288/yr)** |
| API: heavy dev (50 phases/mo) | ~$139/mo | ~$80/mo | **~$59/mo saved (~$714/yr)** |
| Pro ($20/mo) | baseline capacity | ~1.7x phases per cycle | **worth ~$14/mo extra** |
| Pro annual ($17/mo) | baseline capacity | ~1.7x phases per cycle | **worth ~$12/mo extra** |
| Max 5x ($100/mo) | 5x Pro capacity | ~8.5x effective | **worth ~$70/mo extra** |
| Max 20x ($200/mo) | 20x Pro capacity | ~34x effective | **worth ~$140/mo extra** |

*API projections use the per-phase agent costs from the table above ($2.78 stock, $1.59 VBW). Subscription projections reflect equivalent capacity gain from the 62% overhead token reduction during development sessions -- each phase consumes fewer tokens from your quota, so you fit more work into the same rate limit window. Based on [current API pricing](https://claude.com/pricing).*

Full analysis with methodology, per-mechanism breakdowns, architecture diagrams, and worked examples: **[VBW vs Stock Teams Token Analysis](docs/vbw-1-0-99-vs-stock-teams-token-analysis.md)**

<br>

## Manifesto

VBW is open source because the best tools are built by the people who use them.

This project exists to make AI coding better for everyone, and "everyone" means exactly that.

**For absolute beginners:** VBW may look intimidating, expecially if you've never used Claude Code, but it is, in fact, incredibly easy to use. And your results will be significantly better than using an IDE with a chatbot.

**For seasoned developers:** Four effort profiles control agent depth and cost tradeoff. Four autonomy levels gate confirmation prompts from cautious (plan approval at balanced effort) to pure-vibe (full phase looping, zero stops). Verification tiers scale from quick sanity checks to deep goal-backward QA. Work profiles bundle effort, autonomy, and verification into switchable presets. Model routing pins Scout to Haiku and QA to Sonnet while Dev runs on Opus. Skill-hook wiring lets you trigger installed skills on PostToolUse and PreToolUse events with custom matchers. Convention enforcement auto-detects your codebase patterns during init and injects them into every agent's context via. Platform-enforced `disallowedTools` on 4 of 6 agents, not prompt-based restrictions. The beginners get guardrails; you get a control surface.

**For contributors:** VBW is a living project. The plugin system, the agents, the verification pipeline - all of it is open to improvement. If you've found a better way to plan, build, or verify code with Claude, bring it. File an issue, open a PR, or just show up and share what you've learned. Every contribution makes the next person's experience better.

**For vibe coders:** You don't need to know how VBW works under the hood to get help with your projects. Come to the Discord, share what you're building, ask questions, get unstuck. No gatekeeping, no judgment. We've all stared at a terminal wondering what just happened. The difference is now you don't have to stare alone.

**[Join the Discord](https://discord.gg/zh6pV53SaP)** -- whether you want to help build VBW or just want VBW to help you build.

<br>

## What Is This

> **Platform:** macOS and Linux only. Windows is not supported natively — all hooks, scripts, and context blocks require bash. If you're on Windows, run Claude Code inside [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

Inspired by **[Ralph](https://github.com/frankbria/ralph-claude-code)** and **[Get Shit Done](https://github.com/glittercowboy/get-shit-done)**, however, an entirely new architecture.

VBW is a Claude Code plugin that bolts an actual development lifecycle onto your vibe coding sessions. It gives you 29 slash commands and 6 AI agents that handle planning, building, verifying, and archiving your code, so what you produce has at least a fighting chance of surviving a code review.

You describe what you want. VBW breaks it into phases. Agents plan, write, and verify the code. Commits are atomic. Verification is goal-backward. State persists across sessions. It's the entire software development lifecycle, except you replaced the engineering team with a plugin and a prayer.

Think of it as project management for the post-dignity era of software development.

<br>

## Table of Contents

- [VBW Token Efficiency vs Stock Opus 4.6 Agent Teams](#vbw-token-efficiency-vs-stock-opus-46-agent-teams)
- [Manifesto](#manifesto)
- [Features](#features)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Quick Tutorial](#quick-tutorial)
- [Commands](#commands)
- [The Agents](#the-agents)
- [Effort Profiles](#effort-profiles)
- [Autonomy Levels](#autonomy-levels)
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

- **Native hooks for continuous verification.** 20 hooks across 11 event types run automatically -- validating SUMMARY.md structure, checking commit format, validating frontmatter descriptions, gating task completion, blocking sensitive file access, enforcing plan file boundaries, managing session lifecycle, tracking agent lifecycle and cost attribution, tracking session metrics, pre-flight prompt validation, and post-compaction context verification. No more spawning a QA agent after every task. The platform enforces it, not the prompt.

- **Platform-enforced tool permissions.** Each agent has `tools`/`disallowedTools` in their YAML frontmatter -- 4 of 6 agents have platform-enforced deny lists. Scout and QA literally cannot write files. Sensitive file access (`.env`, credentials) is intercepted by the `security-filter` hook. `disallowedTools` is enforced by Claude Code itself, not by instructions an agent might ignore during compaction.

- **Structured handoff schemas.** Agents communicate via JSON-structured SendMessage with typed schemas (`scout_findings`, `dev_progress`, `dev_blocker`, `qa_result`, `debugger_report`). No more hoping the receiving agent can parse free-form markdown. Schema definitions live in a single reference document with backward-compatible fallback to plain text.

<br>

### Solves Agent Teams limitations out of the box

Agent Teams are [experimental with known limitations](https://code.claude.com/docs/en/agent-teams#limitations). VBW handles them so you don't have to:

- **Session resumption.** Agent Teams teammates don't survive `/resume`. VBW's `/vbw:resume` reads ground truth directly from `.vbw-planning/` -- STATE.md, ROADMAP.md, PLAN.md and SUMMARY.md files -- without requiring a prior `/vbw:pause`. It detects interrupted builds via `.execution-state.json`, reconciles stale execution state by detecting tasks completed between sessions via SUMMARY.md files, and suggests the right next action.

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
| No verification unless you ask | Continuous QA via 20 hooks + deep verification on demand |
| Commits whenever, whatever | Atomic commits per task with validation |
| "It works on my machine" | Goal-backward verification against success criteria |
| Agents talk in free-form text | Structured JSON handoff schemas between agents |
| Skills exist somewhere | Stack-aware skill discovery and auto-suggestion |
| Generic "what now?" after every command | Context-aware next-action suggestions with plan IDs, phase names, staleness % |
| Technical output only | Plain-language "What happened" summary after builds (toggleable) |
| Implicit cross-phase dependencies | Explicit `cross_phase_deps` in plans, validated before execution |
| Raw agent names in cost tracking | Workflow categories (Build/Plan/Verify) with efficiency insights |
| Hook failure blocks your session | Universal hook wrapper -- errors logged, session always continues |
| Install plugin, stare at blank screen | Branded welcome with single call to action on first run |
| Memorize flags for each command | Consistent argument hints on all 29 commands with discoverable flags |
| Change 3-4 settings to switch work mode | Work profiles: one command to switch between prototype, production, and yolo modes |
| Conventions live as free text in CLAUDE.md | Structured conventions auto-detected from codebase, conflict-checked, QA-verified |

<br>

### Output that adapts to what just happened

Every command ends with a "Next Up" block suggesting what to do next. These suggestions aren't static -- they read project state from disk and adapt:

- After a build with zero deviations: prominently suggests `/vbw:archive`
- After a failed QA: suggests `/vbw:fix` with the specific failing plan ID
- After planning 5 plans at thorough effort: shows plan count and effort in the suggestion
- When your codebase map is stale: injects `/vbw:map --incremental` with the staleness percentage
- When phases remain: names the next phase instead of generic "continue building"

Build reports also include a plain-language "What happened" summary -- 2-4 sentences explaining what was built, any deviations, and the QA outcome in plain English. No plan IDs, no wave numbers, no frontmatter jargon. Veterans can disable it with `/vbw:config plain_summary false`.

<br>

### Cross-phase dependency intelligence

Plans within a phase already have `depends_on` for intra-phase ordering. But what about cross-phase dependencies -- when Phase 3 needs files that Phase 2 was supposed to create?

VBW's Lead agent explicitly declares these in `cross_phase_deps` frontmatter during planning: which phase, which plan, which artifact, and why. Before execution starts, the execute command validates every dependency -- checking that the source plan completed successfully and the artifact exists on disk. If a dependency is unsatisfied, you get a clear error naming the failing plan and a fix command, not a mystery failure halfway through the build.

<br>

### Real-time statusline that knows more about your project than you do

<img src="assets/statusline.png" width="100%" />

Five or six lines of pure situational awareness, rendered after every response. Phase progress, plan completion, effort profile, QA status... everything a senior engineer would track on a whiteboard, except the whiteboard has been replaced by a terminal and the senior engineer has been replaced by you.

Context window with a live burn bar and token counts. Because somewhere, a staff engineer just felt a disturbance in the force - someone with no CS degree is managing memory allocation, and they're doing it with a progress bar that updates automatically.

API usage limits with countdown timers for session, weekly, and per-model quotas. Session running hot? The bar goes red. Weekly ceiling approaching? You'll know before Anthropic does. Extra usage tracking down to the cent so you always know exactly where your money went. Spoiler: it went to an AI that writes better code than most bootcamp graduates. And some actual graduates, but we don't talk about that at dinner parties.

Cost, duration, diff stats, model info, and GitHub branch, all in one line. It's the kind of dashboard a real engineering team would build after three sprints and a retrospective. You got it by installing a plugin. Twenty years of software craftsmanship, mass layoffs, and all it took to replace the monitoring team was `bash -c` and a dream.

Economy line with workflow cost breakdown -- Build, Plan, Verify, and Other categories aggregated from per-agent cost data. Cache hit rate, cost-per-line, and contextual efficiency insights that surface when patterns warrant action: "QA heavy -- try balanced" when verification exceeds 35% of total spend, "Plan heavy -- try fast" when planning dominates, or a cache efficiency warning when hit rates drop below 40%. The economy line appears automatically once any token cost is incurred and politely disappears when there's nothing to report. It's the CFO your project never asked for and definitely can't afford to ignore.

<br>

---

<br>

## Installation

Open Claude Code and run these two commands inside the Claude Code session, **one at a time**:

**Step 1:** Add the marketplace
```
/plugin marketplace add yidakee/vibe-better-with-claude-code-vbw
```

**Step 2:** Install the plugin
```
/plugin install vbw@vbw-marketplace
```

That's it. Two commands, two separate inputs. Do not paste them together — Claude Code will treat both lines as a single command and the URL will break.

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
     │  Scaffold             │               │  Scaffold             │
     │  Skills               │               │                       │
     │                       │               │  ⚠ Codebase detected  │
     │  Auto-chains:         │               │  Auto-chains:         │
     │    → /vbw:implement   │               │    → /vbw:map         │
     └──────────┬────────────┘               │    → Skills (informed │
                │                            │      by map data)     │
                │                            │    → /vbw:implement   │
                │                            └──────────┬────────────┘
                │                                       │
                └───────────────────┬───────────────────┘
                                    │
                                    ▼
                 ┌──────────────────────────────────────┐
                 │  /vbw:implement                      │
                 │  The one command — auto-detects:     │
                 │                                      │
                 │  No project?  → Bootstrap setup      │
                 │  No phases?   → Scope & plan work    │
                 │  Unplanned?   → Plan next phase      │
                 │  Planned?     → Execute next phase   │
                 │  All done?    → Suggest archive      │
                 └──────────────────┬───────────────────┘
                                    │
                                    │  Or for more control:
                                    │  /vbw:discuss (gather context)
                                    │  /vbw:plan + /vbw:execute
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
          │ Loop back to     │        │ /vbw:archive     │
          │ /vbw:implement   │        │ Audits completion│
          │ for next phase   │        │ Archives state   │
          └──────────────────┘        │ Tags the release │
                                      │ Work archived    │
                                      └──────────────────┘
```

<br>

---

<br>

## Quick Tutorial

You only need to remember two commands. Seriously. VBW auto-detects where your project is and does the right thing. No decision trees, no memorizing workflows. Just init, then implement until it's done.

### Starting a brand new project

```
/vbw:init
```

Run this once. VBW sets up your environment — Agent Teams, statusline, git hooks — and scaffolds a `.vbw-planning/` directory. It detects your tech stack and suggests relevant Claude Code skills. You answer a few questions, and you're ready to build.

```
/vbw:implement
```

This is the one command. Run it, and VBW figures out what to do next:

- **No project defined?** It asks about your project, gathers requirements, and creates a phased roadmap.
- **Phases ready but not planned?** The Lead agent researches, decomposes, and produces plans.
- **Plans ready but not built?** Dev teammates execute in parallel with atomic commits and continuous verification.
- **Everything built?** It tells you and suggests wrapping up.

You don't need to know which state your project is in. VBW knows. Just keep running `/vbw:implement` and it handles the rest — planning, building, verifying — one phase at a time. Or if you're feeling brave, set your autonomy to `pure-vibe` and it'll loop through every remaining phase without stopping.

```
/vbw:implement
```

Yes, the same command again. When Phase 1 finishes, run it again for Phase 2. And again for Phase 3. Each invocation picks up where the last one left off. State persists in `.vbw-planning/` across sessions, so you can close your terminal, come back tomorrow, and `/vbw:implement` still knows exactly where you are.

```
/vbw:archive
```

When all phases are built, archive the work. VBW runs a completion audit, archives state to `.vbw-planning/milestones/`, tags the git release, and updates project docs. You shipped. With actual verification. Your future self won't want to set the codebase on fire. Probably.

```
/vbw:release
```

Ready to publish? This runs a pre-release audit first — checking that your changelog covers all commits since the last release and that README counts aren't stale. If anything's missing, it offers to generate entries for your review. Then it bumps the version, finalizes the changelog, creates an annotated git tag, commits, pushes, and creates a GitHub release with the changelog notes. Supports `--dry-run` to preview, `--skip-audit` to bypass the audit, `--major` or `--minor` for non-patch bumps.

That's it. `init` → `implement` (repeat) → `archive` → `release`. Four commands for an entire development lifecycle.

### Picking up an existing codebase

Same flow, one difference:

```
/vbw:init
```

VBW detects the existing codebase and auto-chains everything: `/vbw:map` launches 4 Scout teammates to analyze your code across tech stack, architecture, quality, and concerns. Skill suggestions are based on what's actually in your codebase, not just which manifest files exist. Then `/vbw:implement` runs automatically with full codebase awareness. One command, four workflows, zero manual sequencing.

From there, it's the same loop: `/vbw:implement` until done, `/vbw:archive`, `/vbw:release`.

### Coming back to a project

```
/vbw:resume
```

Closed your terminal? Switched branches? Came back after a weekend of pretending you have hobbies? `/vbw:resume` reads ground truth directly from `.vbw-planning/` -- STATE.md, ROADMAP.md, plans, summaries -- and rebuilds your full project context. No prior `/vbw:pause` needed. It detects interrupted builds, reconciles stale execution state, and tells you exactly what to do next. One command, full situational awareness, zero guessing.

> **⚠️ Do not use `/clear`.**
>
> Opus 4.6 auto-compacts your context window when it fills up. It intelligently summarizes older conversation turns while preserving critical state — active plan tasks, file paths, commit history, deviation decisions, error context — so the session continues seamlessly with full project awareness. VBW enhances this further with `PreCompact` hooks and post-compaction verification that inject agent-specific preservation priorities and verify nothing critical was lost.
>
> `/clear` bypasses all of this. It destroys your entire context — every file read, every decision made, every task in progress — and drops you into a blank session with no memory of what just happened. Auto-compaction is surgical; `/clear` is a sledgehammer.
>
> **If you accidentally `/clear`**, run `/vbw:resume` immediately. It restores project context from ground truth files in `.vbw-planning/` — state, roadmap, plans, summaries — and tells you exactly where to pick up.

> **For advanced users:** The [full command reference](#commands) below has 29 commands for granular control — `/vbw:plan` and `/vbw:execute` to separate planning from building, `/vbw:qa` for on-demand verification, `/vbw:debug` for systematic bug investigation, `/vbw:discuss` for pre-planning context gathering, and more. But you never *need* them. `/vbw:implement` handles the entire lifecycle on its own.

<br>

---

<br>

## Commands

### Lifecycle -- The Main Loop

These are the commands you'll use every day. This is the job now.

| Command | Description |
| :--- | :--- |
| `/vbw:init` | Set up environment and scaffold `.vbw-planning/` directory with templates and config. Configures Agent Teams and statusline. Automatically installs git hooks (pre-push version enforcement). For existing codebases, maps the codebase first, then uses the map data to inform stack detection and skill suggestions before auto-chaining to `/vbw:implement`. |
| `/vbw:implement [phase]` | The one command. Auto-detects project state and does the right thing -- bootstraps new projects, gathers requirements, plans phases, executes builds. Smart router through the full lifecycle. |
| `/vbw:plan [phase]` | Plan a phase. The Lead agent researches context, decomposes work into tasks grouped by wave, and self-reviews the plan. Produces PLAN.md files with YAML frontmatter. Accepts `--effort` flag (thorough/balanced/fast/turbo). Phase is auto-detected when omitted. |
| `/vbw:execute [phase]` | Execute a planned phase. Creates an Agent Team with Dev teammates for parallel execution with per-plan dependency wiring. At Thorough effort, Devs enter plan-approval mode before writing code. Atomic commits per task. Continuous QA via hooks. Produces SUMMARY.md. Resumes from last checkpoint if interrupted. Phase is auto-detected when omitted. |
| `/vbw:archive` | Close out completed work. Runs audit, archives state to `.vbw-planning/milestones/`, tags the git release, and updates project docs. |
| `/vbw:release` | Bump version, finalize changelog, tag, commit, push, and create a GitHub release. Runs a pre-release audit that checks changelog completeness against commits since last release and detects stale README counts, offering to fix issues before shipping. Runs `bump-version.sh` across all 4 version files, renames `[Unreleased]` to the new version in CHANGELOG.md, creates an annotated git tag, pushes, and creates a GitHub release with changelog notes via `gh`. Supports `--dry-run`, `--no-push`, `--major`, `--minor`, `--skip-audit`. |

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
| `/vbw:pause` | Save session notes for next time. State auto-persists in `.vbw-planning/` -- pause just lets you leave a sticky note for future you. |
| `/vbw:resume` | Restore project context from `.vbw-planning/` ground truth. Reads state, roadmap, plans, and summaries directly -- no prior `/vbw:pause` needed. |
| `/vbw:skills` | Browse and install community skills from skills.sh based on your project's tech stack. Detects your stack, suggests relevant skills, and installs them with one command. |
| `/vbw:config` | View and toggle VBW settings: effort profiles, autonomy levels (cautious/standard/confident/pure-vibe), plain-language summaries (`plain_summary`), skill suggestions, auto-install behavior, and skill-hook wiring. Detects profile drift and offers to save as new profile. |
| `/vbw:profile` | Switch between work profiles or create custom ones. 4 built-in presets (default, prototype, production, yolo) change effort, autonomy, and verification in one command. Interactive profile creation for custom workflows. |
| `/vbw:teach` | View, add, or manage project conventions. Auto-detected from codebase during init, manually teachable anytime. Shows what VBW already knows and warns about conflicts before adding. Conventions are injected into agent context via CLAUDE.md and verified by QA. |
| `/vbw:help` | Command reference with usage examples. You are reading its output's spiritual ancestor right now. |

<br>

### Advanced -- For When You're Feeling Ambitious

| Command | Description |
| :--- | :--- |
| `/vbw:map` | Analyze a codebase with 4 parallel Scout teammates (Tech, Architecture, Quality, Concerns). Produces synthesis documents (INDEX.md, PATTERNS.md). Supports monorepo per-package mapping. Security-enforced via hooks: never reads `.env` or credentials. |
| `/vbw:discuss [phase]` | Gather context through adaptive questioning before planning. For when you want to think before you type. Revolutionary concept. Phase is auto-detected when omitted. |
| `/vbw:assumptions [phase]` | Surface Claude's assumptions about your phase approach. Useful for catching misunderstandings before they become commits. Phase is auto-detected when omitted. |
| `/vbw:research` | Standalone research task, decoupled from planning. For when you need answers but aren't ready to commit to a plan. |
| `/vbw:audit` | Audit completion readiness. 6-check matrix with PASS/WARN/FAIL results. WARN passes, FAIL blocks. |
| `/vbw:add-phase` | Append a new phase to the active roadmap. |
| `/vbw:insert-phase` | Insert an urgent phase between existing ones with automatic renumbering. For when production is on fire. |
| `/vbw:remove-phase` | Remove a future phase and renumber. Refuses to delete phases containing completed work, because even VBW has principles. |
| `/vbw:whats-new` | View changelog entries since your installed version. |
| `/vbw:update` | Update VBW to the latest version with automatic cache refresh. |
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
  HOOKS (11 event types, 20 handlers)                              VERIFICATION.md
  ┌───────────────────────────────────────────────────────────────────────────────┐
  │  Verification                                                                 │
  │    PostToolUse ──── Validates SUMMARY.md on write, checks commit format,      │
  │                     validates frontmatter descriptions, dispatches skill     │
  │                     hooks, updates execution state                           │
  │    SubagentStart ── Writes active agent marker for cost attribution            │
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
  │    SessionStart(compact) Verifies critical context survived compaction          │
  │    Stop ──────────── Logs session metrics, persists cost ledger                │
  │    UserPromptSubmit  Pre-flight prompt validation                              │
  │    Notification ──── Logs teammate communication                               │
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

Or switch effort, autonomy, and verification together with `/vbw:profile`:

```
/vbw:profile prototype    → fast + confident + quick
/vbw:profile production   → thorough + cautious + deep
/vbw:profile yolo         → turbo + pure-vibe + skip
```

<br>

---

<br>

## Autonomy Levels

Effort controls how hard your agents think. Autonomy controls how often they stop to ask you about it.

Four levels, from "review everything" to "just build the whole thing while I get coffee":

| Level | What It Does | When To Use It |
| :--- | :--- | :--- |
| **Cautious** | Stops between plan and execute. Plan approval at Thorough AND Balanced effort. All confirmations enforced. | First time on a codebase. Production-critical work. When you want to review every step before it happens. |
| **Standard** | Auto-chains plan into execute within a phase. Plan approval at Thorough only. Stops between phases. The default. | Most work. You trust the plan but want to see results before continuing. |
| **Confident** | Skips "already complete" confirmations. Plan approval OFF even at Thorough. QA warnings non-blocking. | Experienced with VBW, rebuilding known-good phases, iteration speed matters more than gate checks. |
| **Pure Vibe** | Loops ALL remaining phases in a single `/vbw:implement`. No confirmations. No plan approval. Only error guards (missing roadmap, uninitialized project) stop execution. | When you want to walk away and come back to a finished project. Full autonomy with VBW's safety nets still active. |

```
/vbw:config autonomy confident
/vbw:config autonomy pure-vibe
```

Autonomy interacts with effort profiles. At `cautious`, plan approval expands to cover Balanced effort (not just Thorough). At `confident` and `pure-vibe`, plan approval is disabled regardless of effort level. Error guards — missing roadmap, uninitialized project, missing plans — always halt at every level. Autonomy controls friction, not safety.

| Gate | Cautious | Standard | Confident | Pure Vibe |
| :--- | :--- | :--- | :--- | :--- |
| Plan to execute | Stop and ask | Auto-chain | Auto-chain | Auto-chain |
| Between phases | Stop | Stop | Stop | Auto-loop |
| "Already complete" warning | Confirm | Confirm | Skip | Skip |
| Plan approval (Thorough) | Required | Required | Off | Off |
| Plan approval (Balanced) | Required | Off | Off | Off |

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

**Native Hooks** -- 20 hooks across 11 event types provide continuous verification without agent overhead. Every hook routes through a universal wrapper (`hook-wrapper.sh`) that resolves the target script from the plugin cache, logs any failure to `.vbw-planning/.hook-errors.log`, and always exits 0 -- no hook can ever break a session. PostToolUse validates SUMMARY.md structure, commit format, frontmatter descriptions, and auto-updates execution state. TeammateIdle gates task completion via structural checks. TaskCompleted verifies task-related commits via keyword matching. SubagentStart tracks the active agent for cost attribution. SubagentStop validates completion artifacts and clears the agent marker. PreToolUse blocks sensitive file access and enforces plan boundaries. SessionStart detects project state and checks map staleness. PreCompact preserves agent-specific context. SessionStart (compact matcher) verifies critical context survived. Stop logs session metrics and persists the cost ledger. UserPromptSubmit runs pre-flight validation. Notification logs teammate communication. No more spawning QA agents after every wave.

**Tool Permissions** -- Each agent has native `tools`/`disallowedTools` in their YAML frontmatter. Scout and QA literally cannot write files. It's enforced by the platform, not by instructions that an agent might ignore.

**Structured Handoff Schemas** -- Five JSON schemas define how agents communicate via SendMessage: `scout_findings` (Scout to Map Lead), `dev_progress` and `dev_blocker` (Dev to Execute Lead), `qa_result` (QA to Lead), and `debugger_report` (Debugger to Debug Lead). Type-discriminated with backward-compatible fallback to plain markdown. No more parsing free-form text and hoping for the best.

Four platform features. Zero faith in the developer. As it should be.

<br>

---

<br>

## Requirements

- **Claude Code** with **Opus 4.6+** model
- **jq** -- the only external dependency. Install via `brew install jq` (macOS) or `apt install jq` (Linux). VBW checks for jq during `/vbw:init` and session start, and warns clearly if it's missing.
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
