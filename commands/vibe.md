---
name: vibe
description: "The one command. Detects state, parses intent, routes to any lifecycle mode -- bootstrap, scope, plan, execute, discuss, archive, and more."
argument-hint: "[intent or flags] [--plan] [--execute] [--discuss] [--assumptions] [--scope] [--add] [--insert] [--remove] [--archive] [--yolo] [--effort=level] [--skip-qa] [--skip-audit] [--plan=NN] [N]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
disable-model-invocation: true
---

# VBW Vibe: $ARGUMENTS

## Context

Working directory: `!`pwd``

Pre-computed state (via phase-detect.sh):
```
!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/phase-detect.sh 2>/dev/null || echo "phase_detect_error=true"`
```

Config:
```
!`cat .vbw-planning/config.json 2>/dev/null || echo "No config found"`
```

## Input Parsing

Three input paths, evaluated in order:

### Path 1: Flag detection

Check $ARGUMENTS for flags. If any mode flag is present, go directly to that mode:
- `--plan [N]` -> Plan mode
- `--execute [N]` -> Execute mode
- `--discuss [N]` -> Discuss mode
- `--assumptions [N]` -> Assumptions mode
- `--scope` -> Scope mode
- `--add "desc"` -> Add Phase mode
- `--insert N "desc"` -> Insert Phase mode
- `--remove N` -> Remove Phase mode
- `--archive` -> Archive mode

Behavior modifiers (combinable with mode flags):
- `--effort <level>`: thorough|balanced|fast|turbo (overrides config)
- `--skip-qa`: skip post-build QA
- `--skip-audit`: skip pre-archive audit
- `--yolo`: skip all confirmation gates, auto-loop remaining phases
- `--plan=NN`: execute single plan (bypasses wave grouping)
- Bare integer `N`: targets phase N (works with any mode flag)

If flags present: skip confirmation gate (flags express explicit intent).

### Path 2: Natural language intent

If $ARGUMENTS present but no flags detected, interpret user intent:
- Discussion keywords (talk, discuss, explore, think about, what about) -> Discuss mode
- Assumption keywords (assume, assuming, what if, what are you assuming) -> Assumptions mode
- Planning keywords (plan, scope, break down, decompose, structure) -> Plan mode
- Execution keywords (build, execute, run, do it, go, make it, ship it) -> Execute mode
- Phase mutation keywords (add, insert, remove, skip, drop, new phase) -> relevant Phase Mutation mode
- Completion keywords (done, ship, archive, wrap up, finish, complete) -> Archive mode
- Ambiguous -> AskUserQuestion with 2-3 contextual options

ALWAYS confirm interpreted intent via AskUserQuestion before executing.

### Path 3: State detection (no args)

If no $ARGUMENTS, evaluate phase-detect.sh output. First match determines mode:

| Priority | Condition | Mode | Confirmation |
|---|---|---|---|
| 1 | `planning_dir_exists=false` | Init redirect | (redirect, no confirmation) |
| 2 | `project_exists=false` | Bootstrap | "No project defined. Set one up?" |
| 3 | `phase_count=0` | Scope | "Project defined but no phases. Scope the work?" |
| 4 | `next_phase_state=needs_plan_and_execute` | Plan + Execute | "Phase {N} needs planning and execution. Start?" |
| 5 | `next_phase_state=needs_execute` | Execute | "Phase {N} is planned. Execute it?" |
| 6 | `next_phase_state=all_done` | Archive | "All phases complete. Run audit and archive?" |

### Confirmation Gate

Every mode triggers confirmation via AskUserQuestion before executing, with contextual options (recommended action + alternatives).
- **Exception:** `--yolo` skips all confirmation gates. Error guards (missing roadmap, uninitialized project) still halt.
- **Exception:** Flags skip confirmation (explicit intent).

## Modes

### Mode: Init Redirect

If `planning_dir_exists=false`: display "Run /vbw:init first to set up your project." STOP.

### Mode: Bootstrap

**Guard:** `.vbw-planning/` exists but no PROJECT.md.

**Critical Rules (non-negotiable):**
- NEVER fabricate content. Only use what the user explicitly states.
- If answer doesn't match question: STOP, handle their request, let them re-run.
- No silent assumptions -- ask follow-ups for gaps.
- Phases come from the user, not you.

**Constraints:** Do NOT explore/scan codebase (that's /vbw:map). Use existing `.vbw-planning/codebase/` if present.

**Brownfield detection:** `git ls-files` or Glob check for existing code.

**Steps:**
- **B1: PROJECT.md** -- If $ARGUMENTS provided (excluding flags), use as description. Otherwise ask name + core purpose. Then call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-project.sh .vbw-planning/PROJECT.md "$NAME" "$DESCRIPTION"
  ```
- **B1.5: Discovery Depth** -- Read `discovery_questions` and `active_profile` from config. Map profile to depth:

  | Profile | Depth | Questions |
  |---------|-------|-----------|
  | yolo | skip | 0 |
  | prototype | quick | 1-2 |
  | default | standard | 3-5 |
  | production | thorough | 5-8 |

  If `discovery_questions=false`: force depth=skip. Store DISCOVERY_DEPTH for B2.

- **B2: REQUIREMENTS.md (Discovery)** -- Behavior depends on DISCOVERY_DEPTH:
  - **B2.1: Domain Research (if not skip):** If DISCOVERY_DEPTH != skip:
    1. Extract domain from user's project description (the $NAME or $DESCRIPTION from B1)
    2. Resolve Scout model via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh scout .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json`
    3. Spawn Scout agent via Task tool with prompt: "Research the {domain} domain and write `.vbw-planning/domain-research.md` with four sections: ## Table Stakes (features every {domain} app has), ## Common Pitfalls (what projects get wrong), ## Architecture Patterns (how similar apps are structured), ## Competitor Landscape (existing products). Use WebSearch. Be concise (2-3 bullets per section)."
    4. Set `model: "${SCOUT_MODEL}"` and `timeout: 120000` in Task tool invocation
    5. On success: Read domain-research.md. Extract brief summary (3-5 lines max): (1) Pick 1-2 most surprising table stakes from ## Table Stakes, (2) Pick 1 high-impact pitfall from ## Common Pitfalls, (3) Mention 1 competitor pattern from ## Competitor Landscape. Use plain language (no jargon). Format as narrative, not bullet list. Example: "Most recipe apps need offline access, ingredient scaling, and meal planning — users expect these out of the box. A common mistake is over-complicating the recipe format, which confuses users. Apps like Paprika prioritize speed over features." Display to user: "◆ Domain Research: {brief summary}\n\n✓ Research complete. Now let's explore your specific needs..."
    6. On failure: Log warning "⚠ Domain research timed out, proceeding with general questions". Display to user: "⚠ Domain research took longer than expected — skipping to questions. (You can re-run `/vbw:vibe` later if you want domain-specific insights.)" Set RESEARCH_AVAILABLE=false, continue to Round 1
    7. Store RESEARCH_AVAILABLE flag for Round 1 context
    8. Comment: Research is best-effort. Timeout, WebSearch failures, or empty results all fall back to current behavior with no user-facing error.
  - **If skip:** Ask 2 minimal static questions via AskUserQuestion: (1) "What are the must-have features?" (2) "Who will use this?" Create `.vbw-planning/discovery.json` with `{"answered":[],"inferred":[]}`.
  - **If quick/standard/thorough:** Read `${CLAUDE_PLUGIN_ROOT}/references/discovery-protocol.md`. Follow Bootstrap Discovery flow:
    1. Analyze user's description for domain, scale, users, complexity signals
    2. Initialize ROUND=1, QUESTIONS_ASKED=0
    3. **Round loop:**
       a. **Question generation:**
          - **Round 1 (Scenarios):** Generate scenario questions per protocol. Present as AskUserQuestion with descriptive options. **Scenario generation:** If RESEARCH_AVAILABLE=true, read `.vbw-planning/domain-research.md` and integrate findings: (a) Table Stakes → checklist questions in Round 2, (b) Common Pitfalls → scenario situations (e.g., 'What happens when [pitfall situation]?'), (c) Architecture Patterns → technical preference scenarios (e.g., 'Should the system use [pattern A] or [pattern B]?'), (d) Competitor Landscape → differentiation scenarios (e.g., '{Competitor X} does {feature}. Should yours work the same way or differently?'). If RESEARCH_AVAILABLE=false, use description analysis only per existing protocol.
          - **Round 2 (Table Stakes Checklist):** If RESEARCH_AVAILABLE=true, generate table stakes checklist from domain-research.md:
            1. Read `## Table Stakes` section
            2. Extract 3-6 common features (bullet points)
            3. Present as AskUserQuestion multiSelect with format: "Which of these are must-haves for your project?"
            4. Options: Each table stake as checkbox with "(domain standard)" label
               Example: "Offline access (domain standard — recipe apps need this)"
            5. Add "None of these" option
            6. Record selected items to discovery.json with category "table_stakes", tier "table_stakes"
            If RESEARCH_AVAILABLE=false: Skip to thread-following checklists (Round 3+ logic).
          - **Round 3 (Thread-Following Checklist):** Generate checklist questions that BUILD ON previous round answers. Read discovery.json.answered[] for prior rounds. Identify gaps or follow-ups using these patterns: (1) If Round N-1 answer was vague: ask concrete follow-up, (2) If Round N-1 revealed complexity: ask edge case questions, (3) If Round N-1 mentioned integration: ask about auth, error handling, data flow, (4) If Round N-1 suggested scale: ask about performance, caching, limits. Check discovery.json.answered[] to avoid duplicate questions (skip categories already covered). Format: Generate targeted pick-many questions with `multiSelect: true`. Mark user-identified features as tier "differentiators".
          - **Round 4 (Differentiator Identification):** After 2-3 rounds of checklists, explicitly ask about competitive advantage:
            "What makes your project different from existing solutions?"
            Present as AskUserQuestion with context-aware options:
            - "It does [X] better than competitors" (where X comes from prior answers)
            - "It targets a different audience: [Y]" (where Y is inferred from users/scale answers)
            - "It combines features that don't exist together: [Z]"
            - "Let me explain..."
            Record answer to discovery.json with category "differentiators", tier "differentiators".
            Mark these features as competitive advantages during requirement synthesis.
          - **Round 5 (Anti-Features - Deliberate Exclusions):** After differentiator identification, infer common scope-creep features from research and confirm exclusions:
            If RESEARCH_AVAILABLE=true:
            1. Read domain-research.md ## Common Pitfalls and ## Competitor Landscape
            2. Identify features that appear in competitors but add complexity (from Pitfalls)
            3. Present as AskUserQuestion: "These are common in [domain] apps, but add complexity. Should we deliberately NOT build them?"
            4. Options: 2-3 scope-creep features as checkboxes (multiSelect)
               Example for recipe app: "Social sharing (adds privacy concerns)", "AI meal planning (complex, often unused)", "Grocery delivery integration (third-party dependency)"
            5. Add "Build these anyway" option
            6. Record selected exclusions to discovery.json with category "anti_features", tier "anti_features"
            If RESEARCH_AVAILABLE=false:
            Ask direct question: "What should this definitely NOT do?" Free-text, then convert to anti-features list.
            Anti-features ensure explicit scope boundaries and prevent feature creep during planning.
          - **Round 6+ (Additional Thread-Following):** Continue thread-following pattern from Round 3. Mark user-identified features as tier "differentiators".
       b. Present questions via AskUserQuestion
       c. **Pitfall relevance scoring (Round 2 → Round 3 transition):** After Round 2 completes, if RESEARCH_AVAILABLE=true and domain-research.md contains ## Common Pitfalls section:
          1. Read all pitfalls from domain-research.md
          2. Score each pitfall for relevance to user's project based on prior answers in discovery.json:
             - If pitfall mentions "scale" or "performance" AND user answered "thousands of users" → +2 relevance
             - If pitfall mentions "offline" or "sync" AND user selected offline access in table stakes → +2 relevance
             - If pitfall mentions "auth" or "security" AND user mentioned user accounts/login → +2 relevance
             - If pitfall mentions "data" or "privacy" AND user has data-heavy features → +2 relevance
             - If pitfall mentions "integration" or "API" AND user mentioned third-party tools → +2 relevance
          3. Select top 2-3 pitfalls by relevance score (minimum score: 1)
          4. If no pitfalls score >0: skip pitfall warnings entirely
          5. Store selected pitfalls for presentation in Round 3
       d. **Pitfall warnings presentation (Round 3 only):** If ROUND=3 and selected pitfalls exist (from step c):
          1. Frame as proactive risk mitigation: "Most [domain] projects run into a few common issues. Here are the ones most relevant to yours..."
          2. For each selected pitfall (2-3 max):
             Present as AskUserQuestion with format:
             "⚠ [Pitfall title from research]
             [Brief explanation: 1-2 sentences from research Common Pitfalls section]

             How should we handle this?"

             Options:
             - "Address it now — add requirement"
             - "Note for later — add to phase planning"
             - "Skip — not relevant to my project"
          3. Record decision to discovery.json:
             - "Address now" → add to inferred[] with priority "Must-have", category "risk_mitigation"
             - "Note for later" → add to inferred[] with priority "Should-have", category "risk_mitigation"
             - "Skip" → no action
          4. Continue to next question (vague answer handling)

          Example pitfall warning for recipe app:
          "⚠ Over-complicated recipe format
          Most recipe apps fail when they try to capture every possible cooking detail. Users get overwhelmed and abandon the app.

          How should we handle this?
            A) Address it now — keep recipe format simple
            B) Note for later — we'll figure this out during planning
            C) Skip — my format is already simple"
       e. **Vague answer handling:** After user responds, check for vague language patterns:
          - Quality adjectives without specifics: "easy", "fast", "simple", "secure", "reliable", "powerful", "flexible"
          - Scope without boundaries: "everything", "lots of features", "comprehensive", "full-featured"
          - Time without metrics: "quick", "slow", "immediate", "later"
          - Scale without numbers: "big", "small", "many", "few"
          If vague pattern detected:
          1. **Generate 3-4 concrete interpretations** based on the vague term and domain context (from project description and previous answers):
             - "Easy to use" → ["Works on mobile devices?", "No signup required?", "Loads in under 2 seconds?", "Let me explain..."]
             - "Fast" → ["Page loads in under 1 second?", "Search results appear instantly?", "Can handle 1000+ users at once?", "Let me explain..."]
             - "Secure" → ["Passwords encrypted?", "Two-factor authentication?", "Data deleted when user requests?", "Let me explain..."]
             - "Lots of features" → ["10+ features?", "Everything competitors have?", "Covers all use cases?", "Let me explain..."]
             Pattern for generating interpretations:
             1. Identify the domain context (from project description and previous answers)
             2. Generate 3 domain-specific concrete versions of the vague term
             3. Frame as yes/no or measurable questions
             4. Add "Let me explain..." as 4th option
          2. Present interpretations as AskUserQuestion with descriptive options
          3. If "Let me explain" chosen: record user's free-text explanation, then ask if they want to revisit the original question with their explanation as context
          4. Record disambiguated answer to discovery.json with extended schema including disambiguation metadata
          If no vague pattern: proceed to record answer as-is.
       f. Record answers to discovery.json with round number (append to answered[] with fields: question, answer, category, phase='bootstrap', round=ROUND, date). **Extended schema for disambiguated answers:**
          ```json
          {
            "question": "...",
            "answer": "Works on mobile devices",
            "category": "...",
            "phase": "bootstrap",
            "round": 1,
            "date": "2026-02-13",
            "disambiguation": {
              "original_vague": "easy to use",
              "interpretations_offered": [
                "Works on mobile devices?",
                "No signup required?",
                "Loads in under 2 seconds?",
                "Let me explain..."
              ],
              "chosen": "Works on mobile devices?"
            }
          }
          ```
          If answer was NOT disambiguated (no vague pattern), omit the `disambiguation` field entirely. **Extended schema for pitfall warnings (step d):**
          ```json
          {
            "question": "⚠ Over-complicated recipe format - Most recipe apps fail...",
            "answer": "Address it now — keep recipe format simple",
            "category": "risk_mitigation",
            "phase": "bootstrap",
            "round": 3,
            "date": "2026-02-13",
            "pitfall": {
              "title": "Over-complicated recipe format",
              "source": "domain-research.md",
              "relevance_score": 4,
              "decision": "address_now"
            }
          }
          ```
          When adding to inferred[] (for "address now" or "note for later"):
          ```json
          {
            "id": "REQ-XX",
            "text": "Keep recipe format simple to prevent user overwhelm",
            "tier": "risk_mitigation",
            "priority": "Must-have",
            "source": "pitfall warning: Over-complicated recipe format"
          }
          ```
          This preserves the user's intent journey and enables future analysis of common vague→concrete patterns and risk mitigation decisions.
       g. Increment ROUND, update QUESTIONS_ASKED count
       h. **Keep-exploring gate:**
          - If ROUND <= 3: AskUserQuestion "We've covered [topic]. What would you like to do?" with options ["Keep exploring — I have more to share", "Move on — I'm ready for the next step"]
          - If ROUND > 3: AskUserQuestion "We've covered quite a bit about your project. What would you like to do?" with options ["Keep exploring — there's more I want to discuss", "Move on — I think we have enough", "Skip to requirements — I'm ready to build"]
          - If user chooses continue: loop to step 3a
          - If user chooses stop: proceed to synthesis (step 4)
       i. **Profile depth as minimum:** quick=1-2 minimum rounds, standard=3-5 minimum, thorough=5-8 minimum. User can continue beyond minimum via keep-exploring gate.
    4. Synthesize answers into `.vbw-planning/discovery.json` with `answered[]` and `inferred[]`. Append each question+answer to `answered[]` with fields: question (friendly wording), answer (user's choice), category (scope/users/scale/data/edge_cases/integrations/priorities/boundaries), phase ('bootstrap'), round (current ROUND value), date (today). Extract inferences to `inferred[]` (questions=friendly, requirements=precise).
  - **Wording rules (all depths):** No jargon. Plain language. Concrete situations. Cause and effect. Assume user is not a developer.
  - **After discovery (all depths):** Call:
    ```
    bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-requirements.sh .vbw-planning/REQUIREMENTS.md .vbw-planning/discovery.json .vbw-planning/domain-research.md
    ```

- **B3: ROADMAP.md** -- Suggest 3-5 phases from requirements. If `.vbw-planning/codebase/` exists, read INDEX.md, PATTERNS.md, ARCHITECTURE.md, CONCERNS.md. Each phase: name, goal, mapped reqs, success criteria. Write phases JSON to temp file, then call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-roadmap.sh .vbw-planning/ROADMAP.md "$PROJECT_NAME" /tmp/vbw-phases.json
  ```
  Script handles ROADMAP.md generation and phase directory creation.
- **B4: STATE.md** -- Extract project name, milestone name, and phase count from earlier steps. Call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-state.sh .vbw-planning/STATE.md "$PROJECT_NAME" "$MILESTONE_NAME" "$PHASE_COUNT"
  ```
  Script handles today's date, Phase 1 status, empty decisions, and 0% progress.
- **B5: Brownfield summary** -- If BROWNFIELD=true AND no codebase/: count files by ext, check tests/CI/Docker/monorepo, add Codebase Profile to STATE.md.
- **B6: CLAUDE.md** -- Extract project name and core value from PROJECT.md. If root CLAUDE.md exists, pass it as EXISTING_PATH for section preservation. Call:
  ```
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-claude.sh CLAUDE.md "$PROJECT_NAME" "$CORE_VALUE" [CLAUDE.md]
  ```
  Script handles: new file generation (heading + core value + VBW sections), existing file preservation (replaces only VBW-managed sections: Active Context, VBW Rules, Key Decisions, Installed Skills, Project Conventions, Commands, Plugin Isolation; preserves all other content). Omit the fourth argument if no existing CLAUDE.md. Max 200 lines.
- **B7: Transition** -- Display "Bootstrap complete. Transitioning to scoping..." Re-evaluate state, route to next match.

### Mode: Scope

**Guard:** PROJECT.md exists but `phase_count=0`.

**Steps:**
1. Load context: PROJECT.md, REQUIREMENTS.md. If `.vbw-planning/codebase/` exists, read INDEX.md + ARCHITECTURE.md.
2. If $ARGUMENTS (excl. flags) provided, use as scope. Else ask: "What do you want to build?" Show uncovered requirements as suggestions.
3. Decompose into 3-5 phases (name, goal, success criteria). Each independently plannable. Map REQ-IDs.
4. Write ROADMAP.md. Create `.vbw-planning/phases/{NN}-{slug}/` dirs.
5. Update STATE.md: Phase 1, status "Pending planning". Do NOT write next-action suggestions (e.g. "Run /vbw:vibe --plan 1") into the Todos section — those are ephemeral display output from suggest-next.sh, not persistent state.
6. Display "Scoping complete. {N} phases created." STOP -- do not auto-continue to planning.

### Mode: Discuss

**Guard:** Initialized, phase exists in roadmap.
**Phase auto-detection:** First phase without `*-PLAN.md`. All planned: STOP "All phases planned. Specify: `/vbw:vibe --discuss N`"

**Steps:**
1. Load phase goal, requirements, success criteria, dependencies from ROADMAP.md.

2. **Phase boundary detection:** Extract ALL phases from ROADMAP.md for scope creep detection.

   Read `.vbw-planning/ROADMAP.md` and parse all phases:
   a. Extract phase number, name, goal, and requirements text for each phase
   b. Store as phase boundary map: array of `{ phase: N, name: "...", goal: "...", requirements: "..." }`
   c. Identify current phase number (from user input or auto-detection from Step 1)
   d. Store current phase and other phases' boundaries separately
   e. Current phase boundary = goal + requirements for current phase (used to check if mentions are IN scope)
   f. Other phases' boundaries = goal + requirements for all non-current phases (used to detect OUT of scope mentions)

   This map enables scope creep detection in Step 5 by comparing user mentions against other phases' boundaries.

3. **Phase type detection:** Identify what KIND of thing the phase builds from ROADMAP.md phase goal and requirements text.

   Define 5 phase type keyword patterns (case-insensitive matching):
   - **UI**: design, interface, layout, frontend, screens, components, responsive, page, view, form, dashboard, widget, navigation, menu, modal, button
   - **API**: endpoint, service, backend, response, error handling, auth, versioning, route, REST, request, JSON, status code, header, query parameter, middleware
   - **CLI**: command, flags, arguments, output format, terminal, console, prompt, stdin, stdout, pipe, subcommand, help text, option, switch
   - **Data**: schema, database, migration, storage, persistence, retention, model, query, index, relation, table, field, constraint, transaction
   - **Integration**: third-party, external service, sync, webhook, connection, protocol, import, export, adapter, client, API key, OAuth, retry

   Detection process:
   a. Read ROADMAP.md phase goal + requirements text for target phase
   b. Match keywords against combined text (goal + requirements), case-insensitive
   c. Score each type: 1 point per unique keyword match
   d. Identify detected types: score >= 2 (minimum 2 keyword matches required to prevent false positives)
   e. Store detected types for next step

4. **Mixed-type handling:** Determine which question template to use.
   - **If 0 types detected** (all scores < 2): use generic fallback questions
   - **If 1 type detected** (only one type scored >= 2): use that type's questions, record as auto-detected
   - **If 2+ types detected** (multiple types scored >= 2): present AskUserQuestion:
     "This phase involves {type1}, {type2}, and {type3} work. Which should we focus on for these questions?"
     Options: each detected type name (UI, API, CLI, Data, Integration) as separate choice
     User's selection determines question template, record as user-chosen
   - Store selected phase type (and source: auto-detected or user-chosen) for question generation and discovery.json recording

5. **Domain-typed question generation:** Generate 3-5 questions using the selected phase type template (from step 4).

   ## Domain-typed question templates

   **UI type questions:**
   - Layout structure: "How should the screens be organized?" Options: ["Single-page flow (everything on one screen)", "Multi-page with navigation (users move between pages)", "Dashboard with panels (multiple views at once)", "Let me explain..."]
   - State management: "What happens when someone interacts with the interface?" Options: ["Changes appear immediately (live updates)", "Need to save/submit first (explicit actions)", "Mix of both (some live, some require save)", "Let me explain..."]
   - Error states: "What should users see when something goes wrong?" Options: ["Red text next to the problem area", "Pop-up message that blocks the screen", "Banner at the top that can be dismissed", "Let me explain..."]
   - Responsiveness: "How should this adapt to different devices?" Options: ["Works on phones, tablets, and desktop (fully responsive)", "Desktop only (no mobile support)", "Mobile-first (works best on phones)", "Let me explain..."]
   - User interactions: "How do people navigate through the interface?" Options: ["Click buttons and links", "Forms with multiple steps", "Drag and drop items", "Let me explain..."]

   **API type questions:**
   - Response format: "What information should the system send back?" Options: ["Just the data requested (minimal response)", "Data plus metadata (timestamps, counts, etc.)", "Data plus related information (connections to other data)", "Let me explain..."]
   - Error handling: "What happens when something fails?" Options: ["Return an error message explaining what went wrong", "Try again automatically", "Return partial results if possible", "Let me explain..."]
   - Authentication: "Who can access this?" Options: ["Anyone (no restrictions)", "Requires login (username/password)", "Requires special key or token", "Let me explain..."]
   - Versioning: "How should changes be handled over time?" Options: ["Everyone gets updates immediately (no versioning)", "Multiple versions available (users choose)", "Automatic migration (users upgraded automatically)", "Let me explain..."]
   - Scale considerations: "How much traffic should this handle?" Options: ["Dozens of requests (small scale)", "Hundreds per minute (medium scale)", "Thousands per minute (high scale)", "Let me explain..."]

   **CLI type questions:**
   - Command structure: "How should the command work?" Options: ["Single command with flags (app --flag value)", "Subcommands (app subcommand --flag)", "Interactive mode (prompts for input)", "Let me explain..."]
   - Output format: "What should the output look like?" Options: ["Human-readable text (easy to read)", "Structured data (JSON, CSV for scripts)", "Both formats available (flag to choose)", "Let me explain..."]
   - Error messages: "What should users see when something fails?" Options: ["Brief error message", "Detailed explanation with suggestions", "Error code plus message", "Let me explain..."]
   - Help system: "How should documentation work?" Options: ["Built-in help command (--help)", "Separate documentation file", "Interactive tutorial mode", "Let me explain..."]
   - Piping and composition: "Should this work with other commands?" Options: ["Reads from stdin, writes to stdout (pipe-friendly)", "Standalone only (no piping)", "Optional piping (works both ways)", "Let me explain..."]

   **Data type questions:**
   - Data model: "What information needs to be stored?" Options: ["Simple fields (name, date, count)", "Connected records (relationships between data)", "Flexible structure (different types per item)", "Let me explain..."]
   - Relationships: "How does data connect?" Options: ["Independent records (no connections)", "Parent-child relationships (hierarchical)", "Many-to-many connections (complex links)", "Let me explain..."]
   - Migrations: "How should data structure changes be handled?" Options: ["Manual updates (user runs script)", "Automatic migration (happens on startup)", "Versioned migrations (tracked changes)", "Let me explain..."]
   - Retention: "How long should data persist?" Options: ["Forever (unless manually deleted)", "Time-limited (auto-delete after period)", "Archive old data (keep but mark as old)", "Let me explain..."]
   - Constraints and validation: "What rules apply to the data?" Options: ["Required fields only (minimal validation)", "Format checking (email, phone, etc.)", "Business rules (dates, ranges, limits)", "Let me explain..."]

   **Integration type questions:**
   - Protocol and format: "How should systems communicate?" Options: ["HTTP requests (REST-style)", "Real-time connection (websocket, streaming)", "Message queue (async processing)", "Let me explain..."]
   - Authentication: "How should access be secured?" Options: ["API key in request", "OAuth tokens (delegated access)", "Username and password", "Let me explain..."]
   - Error recovery: "What happens when the connection fails?" Options: ["Retry automatically", "Queue for later", "Fail and notify user", "Let me explain..."]
   - Data flow direction: "How does information move?" Options: ["One-way import (pull data in)", "One-way export (push data out)", "Two-way sync (keep in sync)", "Let me explain..."]
   - Dependency handling: "What if the external system is down?" Options: ["Block and wait", "Cache last known data", "Fail gracefully with fallback", "Let me explain..."]

   **Generic fallback questions:**
   - Essential features: "What are the must-have capabilities?" Options: ["Core functionality only (minimal)", "Common features expected by users", "Comprehensive feature set", "Let me explain..."]
   - Technical preferences: "How should this be built?" Options: ["Simple and straightforward", "Optimized for performance", "Flexible and extensible", "Let me explain..."]
   - Boundaries: "What should this NOT do?" Options: ["Keep it focused on core purpose", "Avoid complexity", "Don't duplicate existing systems", "Let me explain..."]

   Present selected questions via AskUserQuestion following REQ-C2 constraint (2-4 options per question).
   Follow existing AskUserQuestion patterns: single-select for scenarios, multiSelect for checklists.

   **Scope creep detection (after each answer):**
   After user responds to each question, check the answer text for out-of-scope feature mentions:

   a. **Feature extraction:** Parse user's answer text for capability/feature keywords (nouns and noun phrases that suggest features):
      - Look for patterns: "dashboard", "API", "notifications", "reports", "analytics", "authentication", "admin panel", "search", "export", "import", "integration", "sync", "automation", "scheduling", etc.
      - Extract 2-4 word phrases that describe capabilities (e.g., "user authentication", "real-time sync", "data export")

   b. **Boundary matching:** For each extracted feature mention:
      - Check if it appears in current phase's goal/requirements (from phase boundary map, case-insensitive keyword matching)
      - If YES (in current phase): skip, it's in scope
      - If NO (not in current phase): check if it appears in OTHER phases' goals/requirements
      - Match logic: case-insensitive substring match or keyword overlap
      - If feature text appears in another phase's boundary: flag as potential scope creep

   c. **Suggested phase identification:** When scope creep flagged:
      - Identify which other phase(s) contain the matched keyword
      - Store: original mention text, matched keyword, target phase number, target phase name
      - If feature matches multiple other phases: pick the earliest phase number

   d. **Single-mention redirect:** If scope creep detected for current answer:
      - Trigger gentle redirect (Step 5a, below) ONCE per feature mention
      - Non-blocking: conversation continues regardless of user's choice
      - Store deferred ideas for later capture (Step 6 and Step 7)

   **5a. Gentle redirect with defer offer (triggered by scope creep detection):**
   When step 5 scope creep detection flags a feature mention, present redirect via AskUserQuestion:

   Wording (per REQ-08): "[Feature X] sounds like a new capability — that could be its own phase. Want me to note it for later?"

   Options:
   - "Note it for later — add to Deferred Ideas"
   - "Include in this phase — it's part of the scope"

   User choice handling:
   - **"Note it for later"**: Store deferred idea with metadata (original mention, suggested phase, user decision="deferred"). Append to CONTEXT.md Deferred Ideas section (Step 6) and record to discovery.json (Step 7).
   - **"Include in this phase"**: Record decision (user decision="included"), no CONTEXT.md append. Feature is treated as in-scope, continue question flow.

   Single redirect per detected feature. Non-blocking: continue to next question after user responds.

6. Write `.vbw-planning/phases/{phase-dir}/{phase}-CONTEXT.md` with sections: User Vision, Essential Features, Technical Preferences, Boundaries, Acceptance Criteria, Decisions Made, Deferred Ideas.

   **Deferred Ideas section (optional, append-only):**
   If deferred ideas were captured during scope creep detection (Step 5a user chose "Note it for later"), append this section after Decisions Made:

   ```markdown
   ## Deferred Ideas

   Features mentioned during discussion that may fit better in other phases:

   - **[Feature name/description]** — suggested for Phase [N]: [phase name]. Status: noted for later planning.
   - **[Another feature]** — suggested for Phase [M]: [other phase name]. Status: noted for later planning.
   ```

   Format for each deferred idea:
   - **Feature description**: User's original mention text (the exact words from their answer)
   - **Suggested phase**: "Phase [N]: [phase name]" (from scope detection step, the phase where keyword matched)
   - **Status**: Always "noted for later planning" initially

   If NO deferred ideas were captured during discussion: omit this section entirely (backward compatible — existing CONTEXT.md files without Deferred Ideas section remain valid).

   This section enables tracking of out-of-scope ideas without blocking the current phase's planning.

7. Update `.vbw-planning/discovery.json`: append each question+answer to `answered[]` with extended schema including phase type metadata.

   **Standard question recording:**
   ```json
   {
     "question": "How should the screens be organized?",
     "answer": "Multi-page with navigation",
     "category": "technical_preferences",
     "phase": "03",
     "date": "2026-02-13",
     "phase_type": "UI",
     "phase_type_source": "auto-detected"
   }
   ```
   Fields: question, answer, category, phase (zero-padded phase number), date, phase_type (UI/API/CLI/Data/Integration/generic), phase_type_source (auto-detected or user-chosen).

   **Deferred ideas recording:**
   When user chooses to defer an idea (Step 5a "Note it for later"), append to `answered[]` with extended schema:
   ```json
   {
     "question": "Scope boundary check: [feature mention]",
     "answer": "Deferred to Phase [N]: [phase name]",
     "category": "deferred_idea",
     "phase": "03",
     "date": "2026-02-13",
     "deferred": {
       "mention": "[original user text that triggered detection]",
       "suggested_phase": "[N]",
       "suggested_phase_name": "[phase name]",
       "matched_keyword": "[keyword that triggered scope detection]",
       "user_decision": "deferred"
     }
   }
   ```

   When user chooses "Include in this phase" (Step 5a), record with `user_decision: "included"`:
   ```json
   {
     "question": "Scope boundary check: [feature mention]",
     "answer": "Included in Phase [current phase]: user confirmed in-scope",
     "category": "scope_boundary",
     "phase": "03",
     "date": "2026-02-13",
     "deferred": {
       "mention": "[original user text]",
       "suggested_phase": "[N]",
       "suggested_phase_name": "[phase name]",
       "matched_keyword": "[keyword]",
       "user_decision": "included"
     }
   }
   ```

   Preserve existing discovery.json schema for non-deferred answers (standard questions use format above without `deferred` field).

   Extract inferences to `inferred[]`, include phase type context if relevant.

8. Show summary, ask for corrections. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Mode: Assumptions

**Guard:** Initialized, phase exists in roadmap.
**Phase auto-detection:** Same as Discuss mode.

**Steps:**
1. Load context: ROADMAP.md, REQUIREMENTS.md, PROJECT.md, STATE.md, CONTEXT.md (if exists), codebase signals.
2. Generate 5-10 assumptions by impact: scope (included/excluded), technical (implied approaches), ordering (sequencing), dependency (prior phases), user preference (defaults without stated preference).
3. Gather feedback per assumption: "Confirm, correct, or expand?" Confirm=proceed, Correct=user provides answer, Expand=user adds nuance.
4. Present grouped by status (confirmed/corrected/expanded). This mode does NOT write files. For persistence: "Run `/vbw:vibe --discuss {N}` to capture as CONTEXT.md." Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Mode: Plan

**Guard:** Initialized, roadmap exists, phase exists.
**Phase auto-detection:** First phase without PLAN.md. All planned: STOP "All phases planned. Specify phase: `/vbw:vibe --plan N`"

**Steps:**
1. **Parse args:** Phase number (optional, auto-detected), --effort (optional, falls back to config).
2. **Phase Discovery (if applicable):** Skip if already planned, phase dir has `{phase}-CONTEXT.md`, or DISCOVERY_DEPTH=skip. Otherwise: read `${CLAUDE_PLUGIN_ROOT}/references/discovery-protocol.md` Phase Discovery mode. Generate phase-scoped questions (quick=1, standard=1-2, thorough=2-3). Skip categories already in `discovery.json.answered[]`. Present via AskUserQuestion. Append to `discovery.json`. Write `{phase}-CONTEXT.md`.
3. **Research persistence (REQ-08):** If `v3_plan_research_persist=true` in config AND effort != turbo:
   - Check for `{phase-dir}/{phase}-RESEARCH.md`.
   - **If missing:** Spawn Scout agent to research the phase goal, requirements, and relevant codebase patterns. Scout writes `{phase}-RESEARCH.md` with sections: `## Findings`, `## Relevant Patterns`, `## Risks`, `## Recommendations`. Resolve Scout model:
     ```bash
     SCOUT_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh scout .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
     ```
     Pass `model: "${SCOUT_MODEL}"` to the Task tool.
   - **If exists:** Include it in Lead's context for incremental refresh. Lead may update RESEARCH.md if new information emerges.
   - **On failure:** Log warning, continue planning without research. Do not block.
   - If `v3_plan_research_persist=false` or effort=turbo: skip entirely.
4. **Context compilation:** If `config_context_compiler=true`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} lead {phases_dir}`. Include `.context-lead.md` in Lead agent context if produced.
5. **Turbo shortcut:** If effort=turbo, skip Lead. Read phase reqs from ROADMAP.md, create single lightweight PLAN.md inline.
6. **Other efforts:**
   - Resolve Lead model:
     ```bash
     LEAD_MODEL=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-agent-model.sh lead .vbw-planning/config.json ${CLAUDE_PLUGIN_ROOT}/config/model-profiles.json)
     if [ $? -ne 0 ]; then
       echo "$LEAD_MODEL" >&2
       exit 1
     fi
     ```
   - Spawn vbw-lead as subagent via Task tool with compiled context (or full file list as fallback).
   - **CRITICAL:** Add `model: "${LEAD_MODEL}"` parameter to the Task tool invocation.
   - Display `◆ Spawning Lead agent...` -> `✓ Lead agent complete`.
7. **Validate output:** Verify PLAN.md has valid frontmatter (phase, plan, title, wave, depends_on, must_haves) and tasks. Check wave deps acyclic.
8. **Present:** Update STATE.md (phase position, plan count, status=Planned). Resolve model profile:
   ```bash
   MODEL_PROFILE=$(jq -r '.model_profile // "quality"' .vbw-planning/config.json)
   ```
   Display Phase Banner with plan list, effort level, and model profile:
   ```
   Phase {N}: {name}
   Plans: {N}
     {plan}: {title} (wave {W}, {N} tasks)
   Effort: {effort}
   Model Profile: {profile}
   ```
9. **Cautious gate (autonomy=cautious only):** STOP after planning. Ask "Plans ready. Execute Phase {N}?" Other levels: auto-chain.

### Mode: Execute

Read `${CLAUDE_PLUGIN_ROOT}/references/execute-protocol.md` and follow its instructions.

This mode delegates entirely to the protocol file. Before reading:
1. **Parse arguments:** Phase number (auto-detect if omitted), --effort, --skip-qa, --plan=NN.
2. **Run execute guards:**
   - Not initialized: STOP "Run /vbw:init first."
   - No PLAN.md in phase dir: STOP "Phase {N} has no plans. Run `/vbw:vibe --plan {N}` first."
   - All plans have SUMMARY.md: cautious/standard -> WARN + confirm; confident/pure-vibe -> warn + auto-continue.
3. **Compile context:** If `config_context_compiler=true`, run:
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} dev {phases_dir} {plan_path}`
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/compile-context.sh {phase} qa {phases_dir}`
   Include compiled context paths in Dev and QA task descriptions.

Then Read the protocol file and execute Steps 2-5 as written.

### Mode: Add Phase

**Guard:** Initialized. Requires phase name in $ARGUMENTS.
Missing name: STOP "Usage: `/vbw:vibe --add <phase-name>`"

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: phase name (first non-flag arg), --goal (optional), slug (lowercase hyphenated).
3. Next number: highest in ROADMAP.md + 1, zero-padded.
4. Update ROADMAP.md: append phase list entry, append Phase Details section, add progress row.
5. Create dir: `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
6. Present: Phase Banner with milestone, position, goal. Checklist for roadmap update + dir creation. Next Up: `/vbw:vibe --discuss` or `/vbw:vibe --plan`.

### Mode: Insert Phase

**Guard:** Initialized. Requires position + name.
Missing args: STOP "Usage: `/vbw:vibe --insert <position> <phase-name>`"
Invalid position (out of range 1 to max+1): STOP with valid range.
Inserting before completed phase: WARN + confirm.

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: position (int), phase name, --goal (optional), slug (lowercase hyphenated).
3. Identify renumbering: all phases >= position shift up by 1.
4. Renumber dirs in REVERSE order: rename dir {NN}-{slug} -> {NN+1}-{slug}, rename internal PLAN/SUMMARY files, update `phase:` frontmatter, update `depends_on` references.
5. Update ROADMAP.md: insert new phase entry + details at position, renumber subsequent entries/headers/cross-refs, update progress table.
6. Create dir: `mkdir -p {PHASES_DIR}/{NN}-{slug}/`
7. Present: Phase Banner with renumber count, phase changes, file checklist, Next Up.

### Mode: Remove Phase

**Guard:** Initialized. Requires phase number.
Missing number: STOP "Usage: `/vbw:vibe --remove <phase-number>`"
Not found: STOP "Phase {N} not found."
Has work (PLAN.md or SUMMARY.md): STOP "Phase {N} has artifacts. Remove plans first."
Completed ([x] in roadmap): STOP "Cannot remove completed Phase {N}."

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths, otherwise defaults.
2. Parse args: extract phase number, validate, look up name/slug.
3. Confirm: display phase details, ask confirmation. Not confirmed -> STOP.
4. Remove dir: `rm -rf {PHASES_DIR}/{NN}-{slug}/`
5. Renumber FORWARD: for each phase > removed: rename dir {NN} -> {NN-1}, rename internal files, update frontmatter, update depends_on.
6. Update ROADMAP.md: remove phase entry + details, renumber subsequent, update deps, update progress table.
7. Present: Phase Banner with renumber count, phase changes, file checklist, Next Up.

### Mode: Archive

**Guard:** Initialized, roadmap exists.
No roadmap: STOP "No milestones configured. Run `/vbw:vibe` to bootstrap."
No work (no SUMMARY.md files): STOP "Nothing to ship."

**Pre-gate audit (unless --skip-audit or --force):**
Run 6-point audit matrix:
1. Roadmap completeness: every phase has real goal (not TBD/empty)
2. Phase planning: every phase has >= 1 PLAN.md
3. Plan execution: every PLAN.md has SUMMARY.md
4. Execution status: every SUMMARY.md has `status: complete`
5. Verification: VERIFICATION.md files exist + PASS. Missing=WARN, failed=FAIL
6. Requirements coverage: req IDs in roadmap exist in REQUIREMENTS.md
FAIL -> STOP with remediation suggestions. WARN -> proceed with warnings.

**Steps:**
1. Resolve context: ACTIVE -> milestone-scoped paths. No ACTIVE -> SLUG="default", root paths.
2. Parse args: --tag=vN.N.N (custom tag), --no-tag (skip), --force (skip audit).
3. Compute summary: from ROADMAP (phases), SUMMARY.md files (tasks/commits/deviations), REQUIREMENTS.md (satisfied count).
4. Archive: `mkdir -p .vbw-planning/milestones/`. Move roadmap, state, phases to milestones/{SLUG}/. Write SHIPPED.md. Delete stale RESUME.md.
5. Git branch merge: if `milestone/{SLUG}` branch exists, merge --no-ff. Conflict -> abort, warn. No branch -> skip.
6. Git tag: unless --no-tag, `git tag -a {tag} -m "Shipped milestone: {name}"`. Default: `milestone/{SLUG}`.
7. Update ACTIVE: remaining milestones -> set ACTIVE to first. None -> remove ACTIVE.
8. Regenerate CLAUDE.md: update Active Context, remove shipped refs. Preserve non-VBW content — only replace VBW-managed sections, keep user's own sections intact.
9. Present: Phase Banner with metrics (phases, tasks, commits, requirements, deviations), archive path, tag, branch status, memory status. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe`.

### Pure-Vibe Phase Loop

After Execute mode completes (autonomy=pure-vibe only): if more unbuilt phases exist, auto-continue to next phase (Plan + Execute). Loop until `next_phase_state=all_done` or error. Other autonomy levels: STOP after phase.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md for all output.

Per-mode output:
- **Bootstrap:** project-defined banner + transition to scoping
- **Scope:** phases-created summary + STOP
- **Discuss:** ✓ for captured answers, Next Up Block
- **Assumptions:** numbered list, ✓ confirmed, ✗ corrected, ○ expanded, Next Up
- **Plan:** Phase Banner (double-line box), plan list with waves/tasks, Effort, Next Up
- **Execute:** Phase Banner, plan results (✓/✗), Metrics (plans, effort, deviations), QA result, "What happened" (NRW-02), Next Up
- **Add/Insert/Remove Phase:** Phase Banner, ✓ checklist, Next Up
- **Archive:** Phase Banner, Metrics (phases, tasks, commits, reqs, deviations), archive path, tag, branch, memory status, Next Up

Rules: Phase Banner (double-line box), ◆ running, ✓ complete, ✗ failed, ○ skipped, Metrics Block, Next Up Block, no ANSI color codes.

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-next.sh vibe {result}` for Next Up suggestions.
