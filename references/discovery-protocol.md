# Discovery Protocol (DISC-01)

Intelligent questioning system that helps users define what they want to build through three distinct contexts: Bootstrap Discovery (requirements generation), Phase Discovery (phase-scoped context), and Phase Discussion (deep-dive exploration). Questions are non-developer friendly, scenario-based, and profile-gated.

## Overview

The Discovery Protocol operates in three distinct contexts:

**Bootstrap Discovery** runs during `/vbw:vibe` bootstrap mode, after the user provides a project description but before REQUIREMENTS.md is generated. It produces domain-informed requirements through research-backed scenario questions, round-based exploration, and three-tier feature classification (table stakes, differentiators, anti-features).

**Phase Discovery** runs automatically during `/vbw:vibe` plan mode, before planning begins for a phase. It asks 1-3 phase-scoped questions to gather context not already covered in REQUIREMENTS.md. This is a lighter, targeted round focused on the specific phase being planned.

**Phase Discussion** runs explicitly when the user invokes `/vbw:vibe --discuss [phase]`, triggering a deep-dive conversation separate from automatic Phase Discovery. It detects what KIND of thing the phase builds (UI, API, CLI, Data, Integration) and generates domain-typed questions tailored to that phase type. Includes scope creep detection and deferred ideas capture.

All three contexts share common patterns: plain-language questions via AskUserQuestion, profile-depth mapping, discovery.json recording, and non-developer friendly wording. They differ in depth, timing, and output artifacts.

## Profile Depth Mapping

| Profile | Depth | Questions | Style |
|---------|-------|-----------|-------|
| yolo | skip | 0 | No discovery — jump straight to building |
| prototype | quick | 1-2 | One scenario + one checklist. Speed over precision |
| default | standard | 3-5 | Mixed scenarios + checklists. The recommended balance |
| production | thorough | 5-8 | Deep scenarios, detailed checklists, edge cases, rollback |

Active profile is read from `config.json` → `active_profile`. If `discovery_questions` is `false`, skip discovery entirely regardless of profile.

## Bootstrap Discovery

Replaces static requirements questions with research-informed, round-based exploration. Runs during `/vbw:vibe` bootstrap mode (State 1, Step B2 in vibe.md).

**Input:** User's project description from $ARGUMENTS or "What do you want to build?"
**Output:** `.vbw-planning/REQUIREMENTS.md`, `.vbw-planning/domain-research.md` (if research succeeded), updated `.vbw-planning/discovery.json`

### Flow Overview

Bootstrap Discovery follows an eight-step flow: domain research → round-based questioning → vague answer disambiguation → pitfall warnings → three-tier classification → keep-exploring gates → synthesis → requirements generation.

### 1. Domain Research (B2.1)

**When:** First step after user provides project description, unless depth=skip.

**Process:**
1. Extract domain from project description (e.g., "recipe app" → "recipe management", "e-commerce site" → "e-commerce")
2. Resolve Scout agent model via `resolve-agent-model.sh`
3. Spawn Scout agent via Task tool with prompt: "Research the {domain} domain and write `.vbw-planning/domain-research.md` with four sections: ## Table Stakes (features every {domain} app has), ## Common Pitfalls (what projects get wrong), ## Architecture Patterns (how similar apps are structured), ## Competitor Landscape (existing products). Use WebSearch. Be concise (2-3 bullets per section)."
4. Set 120-second timeout for research task

**On Success:**
- Read domain-research.md
- Extract brief summary (3-5 lines max): 1-2 surprising table stakes from ## Table Stakes, 1 high-impact pitfall from ## Common Pitfalls, 1 competitor pattern from ## Competitor Landscape
- Display to user: "◆ Domain Research: {brief summary}\n\n✓ Research complete. Now let's explore your specific needs..."
- Set RESEARCH_AVAILABLE=true for subsequent steps

**On Failure (timeout, WebSearch failure, or empty results):**
- Log warning, display to user: "⚠ Domain research took longer than expected — skipping to questions. (You can re-run `/vbw:vibe` later if you want domain-specific insights.)"
- Set RESEARCH_AVAILABLE=false
- Continue to Round 1 with general questions

Research is best-effort. All failures fall back gracefully to current behavior with no user-facing error.

### 2. Round-Based Question Loop

**Initialization:**
- ROUND=1
- QUESTIONS_ASKED=0
- Profile depth sets minimum rounds (quick=1-2, standard=3-5, thorough=5-8)

**Round Structure:**

**Round 1: Scenarios**
Generate scenario questions presenting real situations the project will face. Each scenario includes a situation description, 2-4 outcome options, and "this means..." explanations for technical implications.

When RESEARCH_AVAILABLE=true, integrate domain-research.md findings:
- **Table Stakes** → inform checklist questions in Round 2
- **Common Pitfalls** → scenario situations (e.g., "What happens when [pitfall situation]?")
- **Architecture Patterns** → technical preference scenarios (e.g., "Should the system use [pattern A] or [pattern B]?")
- **Competitor Landscape** → differentiation scenarios (e.g., "{Competitor X} does {feature}. Should yours work the same way or differently?")

When RESEARCH_AVAILABLE=false, use description analysis only (analyze domain, scale, users, complexity signals from user's description).

Format scenarios as AskUserQuestion with descriptive options. Each option's description field carries the "this means..." explanation.

Example for an e-commerce site:
```
Scenario: Two customers try to buy the last item at the exact same time.

  A) First one wins, second sees "sold out"
     → This means the system locks inventory during checkout (simpler, occasional disappointed customers)

  B) Both can buy, you sort it out later
     → This means overselling is allowed and you handle it manually (flexible, but needs a process)

  C) Hold it for 10 minutes while they decide
     → This means a reservation system with timers (more complex, better experience)
```

**Round 2: Table Stakes Checklist**
When RESEARCH_AVAILABLE=true:
1. Read `## Table Stakes` section from domain-research.md
2. Extract 3-6 common features (bullet points)
3. Present as AskUserQuestion multiSelect: "Which of these are must-haves for your project?"
4. Options: Each table stake as checkbox with "(domain standard)" label. Example: "Offline access (domain standard — recipe apps need this)"
5. Add "None of these" option
6. Record selected items to discovery.json with category "table_stakes", tier "table_stakes"

When RESEARCH_AVAILABLE=false:
Skip to Round 3 thread-following checklists.

**Round 3: Thread-Following Checklist**
Generate checklist questions that BUILD ON previous round answers. Read discovery.json.answered[] for prior rounds. Identify gaps or follow-ups:
- If Round N-1 answer was vague: ask concrete follow-up
- If Round N-1 revealed complexity: ask edge case questions
- If Round N-1 mentioned integration: ask about auth, error handling, data flow
- If Round N-1 suggested scale: ask about performance, caching, limits

Check discovery.json.answered[] to avoid duplicate questions (skip categories already covered).

Format: Generate targeted pick-many questions with `multiSelect: true`.

Mark user-identified features as tier "differentiators".

**Round 4: Differentiator Identification**
After 2-3 rounds of checklists, explicitly ask about competitive advantage:

"What makes your project different from existing solutions?"

Present as AskUserQuestion with context-aware options:
- "It does [X] better than competitors" (where X comes from prior answers)
- "It targets a different audience: [Y]" (where Y is inferred from users/scale answers)
- "It combines features that don't exist together: [Z]"
- "Let me explain..."

Record answer to discovery.json with category "differentiators", tier "differentiators". Mark these features as competitive advantages during requirement synthesis.

**Round 5: Anti-Features (Deliberate Exclusions)**
After differentiator identification, confirm deliberate exclusions to establish scope boundaries.

When RESEARCH_AVAILABLE=true:
1. Read domain-research.md ## Common Pitfalls and ## Competitor Landscape
2. Identify features that appear in competitors but add complexity (from Pitfalls)
3. Present as AskUserQuestion: "These are common in [domain] apps, but add complexity. Should we deliberately NOT build them?"
4. Options: 2-3 scope-creep features as checkboxes (multiSelect). Example for recipe app: "Social sharing (adds privacy concerns)", "AI meal planning (complex, often unused)", "Grocery delivery integration (third-party dependency)"
5. Add "Build these anyway" option
6. Record selected exclusions to discovery.json with category "anti_features", tier "anti_features"

When RESEARCH_AVAILABLE=false:
Ask direct question: "What should this definitely NOT do?" Free-text, then convert to anti-features list.

Anti-features ensure explicit scope boundaries and prevent feature creep during planning.

**Round 6+: Additional Thread-Following**
Continue thread-following pattern from Round 3. Mark user-identified features as tier "differentiators".

### 3. Vague Answer Disambiguation

After each user response, check for vague language patterns. When detected, present 3-4 concrete interpretations rather than accepting the answer as-is.

**Vague Answer Triggers:**
- Quality adjectives without specifics: "easy", "fast", "simple", "secure", "reliable", "powerful", "flexible"
- Scope without boundaries: "everything", "lots of features", "comprehensive", "full-featured"
- Time without metrics: "quick", "slow", "immediate", "later"
- Scale without numbers: "big", "small", "many", "few"

**Disambiguation Flow:**
1. User gives vague answer (e.g., "I want it to be easy to use")
2. Generate 3-4 concrete domain-specific interpretations based on vague term and domain context:
   - "Easy to use" → ["Works on mobile devices?", "No signup required?", "Loads in under 2 seconds?", "Let me explain..."]
   - "Fast" → ["Page loads in under 1 second?", "Search results appear instantly?", "Can handle 1000+ users at once?", "Let me explain..."]
   - "Secure" → ["Passwords encrypted?", "Two-factor authentication?", "Data deleted when user requests?", "Let me explain..."]
   - "Lots of features" → ["10+ features?", "Everything competitors have?", "Covers all use cases?", "Let me explain..."]
3. Present interpretations as AskUserQuestion with descriptive options
4. If "Let me explain" chosen: capture free-text, offer to revisit question with context
5. Record disambiguated answer to discovery.json with disambiguation metadata

**discovery.json Schema for Disambiguated Answers:**
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

If answer was NOT disambiguated (no vague pattern), omit the `disambiguation` field entirely.

### 4. Pitfall Warnings

After Round 2 completes, if RESEARCH_AVAILABLE=true and domain-research.md contains ## Common Pitfalls section, surface 2-3 most relevant pitfalls as proactive warnings during Round 3.

**Relevance Scoring:**
Each pitfall from domain-research.md ## Common Pitfalls is scored based on project context from prior answers in discovery.json:

| Pitfall Mentions | User Context | Relevance Boost |
|------------------|--------------|-----------------|
| "scale", "performance" | Thousands of users mentioned | +2 |
| "offline", "sync" | Offline access selected in table stakes | +2 |
| "auth", "security" | User accounts or login mentioned | +2 |
| "data", "privacy" | Data-heavy features identified | +2 |
| "integration", "API" | Third-party tools mentioned | +2 |

Select top 2-3 pitfalls by relevance score (minimum score: 1). If no pitfalls score >0, skip pitfall warnings entirely.

**Presentation Format (Round 3 only):**
Frame as proactive risk mitigation: "Most [domain] projects run into a few common issues. Here are the ones most relevant to yours..."

For each selected pitfall (2-3 max):
```
⚠ [Pitfall title from research]
[Brief explanation: 1-2 sentences from research Common Pitfalls section]

How should we handle this?
  A) Address it now — add requirement
  B) Note for later — add to phase planning
  C) Skip — not relevant to my project
```

**Decision Recording:**
- "Address now" → add to inferred[] with priority "Must-have", category "risk_mitigation"
- "Note for later" → add to inferred[] with priority "Should-have", category "risk_mitigation"
- "Skip" → no action

**discovery.json Schema for Pitfall Warnings:**
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

**Example Pitfall Warning for Recipe App:**
```
⚠ Over-complicated recipe format
Most recipe apps fail when they try to capture every possible cooking detail. Users get overwhelmed and abandon the app.

How should we handle this?
  A) Address it now — keep recipe format simple
  B) Note for later — we'll figure this out during planning
  C) Skip — my format is already simple
```

### 5. Three-Tier Feature Classification

Features are classified into three tiers during the discovery process:

**Table Stakes (tier: "table_stakes")**
- Source: domain-research.md ## Table Stakes section (Round 2 checklist)
- Definition: Features every app in this domain has — users expect these out of the box
- Recording: Selected in Round 2 table stakes checklist, recorded with category "table_stakes"
- Requirement annotation: "(domain standard)" label in REQUIREMENTS.md

**Differentiators (tier: "differentiators")**
- Source: Round 4 differentiator identification, Round 3/6+ thread-following checklists
- Definition: Features that make this project unique or better than competitors
- Recording: Explicitly identified in Round 4, or user-selected features from thread-following checklists
- Requirement annotation: Marked as competitive advantages during synthesis

**Anti-Features (tier: "anti_features")**
- Source: Round 5 anti-features question
- Definition: Common features deliberately excluded to establish scope boundaries
- Recording: Selected exclusions from Round 5, recorded with category "anti_features"
- Requirement annotation: "(explicitly excluded)" label in REQUIREMENTS.md

This classification enables scope control during planning and helps differentiate must-haves from nice-to-haves.

### 6. Keep-Exploring Gate

After each question round, offer the user control over depth.

**Rounds 1-3 (equal encouragement):**
```
We've covered [topic]. What would you like to do?
  A) Keep exploring — I have more to share
  B) Move on — I'm ready for the next step
```

**Round 4+ (soft nudge):**
```
We've covered quite a bit about your project. What would you like to do?
  A) Keep exploring — there's more I want to discuss
  B) Move on — I think we have enough
  C) Skip to requirements — I'm ready to build
```

Profile depth (quick/standard/thorough) sets the MINIMUM rounds, not a hard cap. Users can continue as long as they choose "Keep exploring."

### 7. Answer Recording

After each question, record to discovery.json with round number. Append to `answered[]` with fields:
- `question`: Friendly wording
- `answer`: User's choice
- `category`: scope/users/scale/data/edge_cases/integrations/priorities/boundaries/table_stakes/differentiators/anti_features/risk_mitigation
- `phase`: "bootstrap"
- `round`: Current ROUND value
- `date`: Today (YYYY-MM-DD)
- `disambiguation`: (optional) Disambiguation metadata if answer was disambiguated
- `pitfall`: (optional) Pitfall metadata if question was a pitfall warning

### 8. Synthesis to REQUIREMENTS.md

After user chooses to stop exploring, synthesize all answers into `.vbw-planning/REQUIREMENTS.md`:
1. Extract all answered[] entries from discovery.json
2. Integrate research findings from domain-research.md where relevant
3. Annotate requirements with sources:
   - "(domain standard)" for table stakes
   - "(addresses common pitfall: X)" for risk mitigation requirements
   - "(typical approach: Y)" for architecture pattern adoptions
4. Mark differentiators as competitive advantages
5. List anti-features as explicit exclusions
6. Call `bootstrap-requirements.sh .vbw-planning/REQUIREMENTS.md .vbw-planning/discovery.json .vbw-planning/domain-research.md`

### Fallback Behavior (depth=skip)

When active_profile=yolo or discovery_questions=false:
1. Ask 2 minimal static questions via AskUserQuestion:
   - "What are the must-have features?"
   - "Who will use this?"
2. Create `.vbw-planning/discovery.json` with `{"answered":[],"inferred":[]}`
3. Proceed directly to requirements generation

## Phase Discovery

Lighter round scoped to the specific phase about to be planned. Runs automatically during `/vbw:vibe` plan mode before planning begins (States 3-4 in vibe.md).

**Input:** Phase goal, requirements, and success criteria from ROADMAP.md
**Output:** Phase context injected into Lead agent prompt

**Skip Conditions:**
- Phase already has CONTEXT.md from `/vbw:vibe --discuss` (explicit discussion session already completed)
- discovery_questions=false in config
- depth=skip (yolo profile)

**Flow:**
1. Read phase scope from ROADMAP.md
2. Check `.vbw-planning/discovery.json` — skip questions already answered for this phase
3. Generate 1-3 phase-scoped questions (fewer than bootstrap) based on phase goal and requirements
4. Store answers to discovery.json
5. Pass answers as context to planning step (injected into Lead agent prompt)

Phase Discovery is minimal and targeted — it fills gaps, not comprehensive exploration. For deep-dive discussion, use `/vbw:vibe --discuss` instead.

## Phase Discussion

Explicit deep-dive mode triggered by `/vbw:vibe --discuss [phase]`, separate from automatic Phase Discovery. Detects phase type from ROADMAP.md phase goal and requirements text, then generates domain-specific questions tailored to what the phase builds.

**Input:** Phase number (from $ARGUMENTS or auto-detected current phase)
**Output:** `.vbw-planning/phases/{phase-dir}/{phase}-CONTEXT.md`, updated `.vbw-planning/discovery.json` with phase type metadata

### Phase Type Detection

Discuss mode identifies what KIND of thing the phase builds using keyword matching on ROADMAP.md phase goal and requirements text. Five supported types:

**UI (User Interface):**
- Keywords: design, interface, layout, frontend, screens, components, responsive, page, view, form, dashboard, widget, navigation, menu, modal, button
- Detection: minimum 2 keyword matches required
- Question domains: layout structure, UI states, user interactions, responsiveness

**API (Application Programming Interface):**
- Keywords: endpoint, service, backend, response, error handling, auth, versioning, route, REST, request, JSON, status code, header, query parameter, middleware
- Detection: minimum 2 keyword matches required
- Question domains: response format, error handling, authentication, versioning, rate limits

**CLI (Command-Line Interface):**
- Keywords: command, flags, arguments, output format, terminal, console, prompt, stdin, stdout, pipe, subcommand, help text, option, switch
- Detection: minimum 2 keyword matches required
- Question domains: command structure, output format, error messages, help system, piping

**Data (Data/Schema):**
- Keywords: schema, database, migration, storage, persistence, retention, model, query, index, relation, table, field, constraint, transaction
- Detection: minimum 2 keyword matches required
- Question domains: data model, relationships, migrations, retention policies, constraints

**Integration (Third-Party Integration):**
- Keywords: third-party, external service, sync, webhook, connection, protocol, import, export, adapter, client, API key, OAuth, retry
- Detection: minimum 2 keyword matches required
- Question domains: protocol/format, authentication, error recovery, data flow, dependency handling

**Detection Process:**
1. Read ROADMAP.md phase goal + requirements text for target phase
2. Match keywords against combined text (goal + requirements), case-insensitive
3. Score each type: 1 point per unique keyword match
4. Identify detected types: score >= 2 (minimum 2 keyword matches required to prevent false positives)

**Mixed-Type Handling:**
- **0 types detected** (all scores < 2): use generic fallback questions
- **1 type detected** (only one type scored >= 2): use that type's questions, record as auto-detected
- **2+ types detected** (multiple types scored >= 2): present AskUserQuestion: "This phase involves {type1}, {type2}, and {type3} work. Which should we focus on for these questions?" User's selection determines question template, record as user-chosen

### Domain-Typed Questions

Each phase type has 3-5 specific question templates focused on domain-relevant concerns. All questions follow Wording Guidelines (plain language, no jargon, concrete situations). Questions use AskUserQuestion tool with 2-4 options per question.

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

**Generic fallback questions (when no type detected):**
- Essential features: "What are the must-have capabilities?" Options: ["Core functionality only (minimal)", "Common features expected by users", "Comprehensive feature set", "Let me explain..."]
- Technical preferences: "How should this be built?" Options: ["Simple and straightforward", "Optimized for performance", "Flexible and extensible", "Let me explain..."]
- Boundaries: "What should this NOT do?" Options: ["Keep it focused on core purpose", "Avoid complexity", "Don't duplicate existing systems", "Let me explain..."]

All questions build CONTEXT.md sections: User Vision, Essential Features, Technical Preferences, Boundaries, Acceptance Criteria, Decisions Made.

### Scope Creep Guardrails

After each user answer in Discuss mode, the system analyzes feature mentions and compares them against other phases' goals and requirements from ROADMAP.md. When a mentioned feature appears to fit better in a different phase, the system offers to defer it rather than expanding current phase scope.

**Detection Method:**
1. **Feature extraction:** Parse user's answer text for capability/feature keywords (nouns and noun phrases that suggest features). Look for patterns: "dashboard", "API", "notifications", "reports", "analytics", "authentication", "admin panel", "search", "export", "import", "integration", "sync", "automation", "scheduling", etc. Extract 2-4 word phrases that describe capabilities (e.g., "user authentication", "real-time sync", "data export").
2. **Boundary matching:** For each extracted feature mention:
   - Check if it appears in current phase's goal/requirements (case-insensitive keyword matching)
   - If YES (in current phase): skip, it's in scope
   - If NO (not in current phase): check if it appears in OTHER phases' goals/requirements
   - Match logic: case-insensitive substring match or keyword overlap
   - If feature text appears in another phase's boundary: flag as potential scope creep
3. **Suggested phase identification:** When scope creep flagged:
   - Identify which other phase(s) contain the matched keyword
   - Store: original mention text, matched keyword, target phase number, target phase name
   - If feature matches multiple other phases: pick the earliest phase number

**Redirect Pattern:**
When out-of-scope mention detected, present AskUserQuestion:
```
[Feature X] sounds like a new capability — that could be its own phase. Want me to note it for later?
```

**Options:**
- "Note it for later — add to Deferred Ideas" (captures feature to CONTEXT.md, conversation continues)
- "Include in this phase — it's part of the scope" (no capture, feature stays in current discussion)

**Style:**
- Gentle and non-blocking: single mention per feature, conversation continues immediately
- No judgment: framed as "could be its own phase" not "out of scope"
- User has final say: "Include in this phase" option always available

**Deferred Ideas Capture:**
When user chooses "Note it for later", append to CONTEXT.md in a new "Deferred Ideas" section (added after Decisions Made section):

```markdown
## Deferred Ideas

Features mentioned during discussion that may fit better in other phases:

- **Dashboard analytics** — suggested for Phase 4: Reporting and Analytics. Status: noted for later planning.
- **Email notifications** — suggested for Phase 5: Notifications. Status: noted for later planning.
```

If NO deferred ideas were captured during discussion, omit this section entirely (backward compatible — existing CONTEXT.md files without Deferred Ideas section remain valid).

**discovery.json Recording (Deferred Ideas):**
```json
{
  "question": "Scope boundary check: dashboard analytics",
  "answer": "Deferred to Phase 4: Reporting and Analytics",
  "category": "deferred_idea",
  "phase": "03",
  "date": "2026-02-13",
  "deferred": {
    "mention": "dashboard analytics",
    "suggested_phase": "4",
    "suggested_phase_name": "Reporting and Analytics",
    "matched_keyword": "analytics",
    "user_decision": "deferred"
  }
}
```

When user chooses "Include in this phase":
```json
{
  "question": "Scope boundary check: dashboard analytics",
  "answer": "Included in Phase 3: user confirmed in-scope",
  "category": "scope_boundary",
  "phase": "03",
  "date": "2026-02-13",
  "deferred": {
    "mention": "dashboard analytics",
    "suggested_phase": "4",
    "suggested_phase_name": "Reporting and Analytics",
    "matched_keyword": "analytics",
    "user_decision": "included"
  }
}
```

## Question Format Guidelines

**Always assume the user is not a developer.** They may not know what an API, database, or deployment means. Follow these rules:

1. **Plain language first:** Say "people log in" not "user authentication". Say "the system remembers" not "data persistence".
2. **Examples over definitions:** Don't explain what caching is — ask "Should the site load instantly even if the data is a few minutes old, or always show the absolute latest?"
3. **Cause and effect:** Every technical choice should explain what happens. "If you pick A, your site loads faster but shows slightly old data. If you pick B, it's always fresh but might feel slower."
4. **Concrete over abstract:** "What happens when someone's internet drops mid-purchase?" not "How should the system handle network failures?"
5. **No jargon in questions:** Terms like REST, GraphQL, microservices, CI/CD, Docker, etc. should never appear in questions. Use their effects instead.
6. **Jargon in requirements:** The answers GET translated to technical requirements in REQUIREMENTS.md. Questions are friendly, outputs are precise.

## discovery.json Reference

Storage location: `.vbw-planning/discovery.json`

### File Structure

```json
{
  "answered": [],
  "inferred": []
}
```

### answered[] Schema

Full schema including all Phase 1-3 extensions:

| Field | Type | Required | Source | Description |
|-------|------|----------|--------|-------------|
| question | string | Yes | All modes | Friendly question wording |
| answer | string | Yes | All modes | User's response |
| category | string | Yes | All modes | Question type: scope/users/scale/data/edge_cases/integrations/priorities/boundaries/table_stakes/differentiators/anti_features/risk_mitigation/technical_preferences/deferred_idea/scope_boundary |
| phase | string | Yes | All modes | "bootstrap" or zero-padded phase number (e.g., "03") |
| date | string | Yes | All modes | ISO date (YYYY-MM-DD) |
| round | number | No | Bootstrap only | Round number in round-based loop (1-N) |
| disambiguation | object | No | Bootstrap only | Vague answer disambiguation metadata |
| pitfall | object | No | Bootstrap only | Pitfall warning metadata |
| phase_type | string | No | Discuss only | Detected phase type: UI/API/CLI/Data/Integration/generic |
| phase_type_source | string | No | Discuss only | How type was determined: "auto-detected" or "user-chosen" |
| deferred | object | No | Discuss only | Scope creep detection metadata |

### disambiguation Object Schema (Bootstrap Only)

```json
{
  "original_vague": "easy to use",
  "interpretations_offered": [
    "Works on mobile devices?",
    "No signup required?",
    "Loads in under 2 seconds?",
    "Let me explain..."
  ],
  "chosen": "Works on mobile devices?"
}
```

### pitfall Object Schema (Bootstrap Only)

```json
{
  "title": "Over-complicated recipe format",
  "source": "domain-research.md",
  "relevance_score": 4,
  "decision": "address_now"
}
```

### deferred Object Schema (Discuss Only)

```json
{
  "mention": "dashboard analytics",
  "suggested_phase": "4",
  "suggested_phase_name": "Reporting and Analytics",
  "matched_keyword": "analytics",
  "user_decision": "deferred"
}
```

### inferred[] Schema

Full schema including Phase 2 extensions:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | No | Requirement ID (REQ-XX) |
| text | string | Yes | Inferred requirement or fact |
| tier | string | No | Feature classification: table_stakes/differentiators/anti_features/risk_mitigation |
| priority | string | No | Must-have/Should-have/Nice-to-have |
| source | string | Yes | Source question or reasoning |
| date | string | No | ISO date (YYYY-MM-DD) |

### Example Entries

**Standard question (Bootstrap):**
```json
{
  "question": "Who uses this?",
  "answer": "Public customers",
  "category": "users",
  "phase": "bootstrap",
  "round": 1,
  "date": "2026-02-13"
}
```

**Disambiguated answer (Bootstrap):**
```json
{
  "question": "What does 'easy to use' mean for your project?",
  "answer": "Works on mobile devices",
  "category": "technical_preferences",
  "phase": "bootstrap",
  "round": 2,
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

**Pitfall warning (Bootstrap):**
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

**Deferred idea (Discuss):**
```json
{
  "question": "Scope boundary check: dashboard analytics",
  "answer": "Deferred to Phase 4: Reporting and Analytics",
  "category": "deferred_idea",
  "phase": "03",
  "date": "2026-02-13",
  "deferred": {
    "mention": "dashboard analytics",
    "suggested_phase": "4",
    "suggested_phase_name": "Reporting and Analytics",
    "matched_keyword": "analytics",
    "user_decision": "deferred"
  }
}
```

**Inferred requirement with tier:**
```json
{
  "id": "REQ-05",
  "text": "Keep recipe format simple to prevent user overwhelm",
  "tier": "risk_mitigation",
  "priority": "Must-have",
  "source": "pitfall warning: Over-complicated recipe format",
  "date": "2026-02-13"
}
```

### Schema Evolution Notes

- Schema is backward compatible: new fields are optional
- Existing discovery.json files without Phase 2-3 extensions remain valid
- Fields are added, never removed or renamed
- Round field introduced in Phase 2 for thread-following
- Disambiguation and pitfall fields introduced in Phase 2 for vague answer handling and risk mitigation
- Phase_type, phase_type_source, and deferred fields introduced in Phase 3 for Discuss mode
- Tier field in inferred[] introduced in Phase 2 for three-tier classification

## Integration Points

### vibe.md Integration

**Bootstrap Discovery:** Implemented in vibe.md State 1, Step B2 (lines 105-290). Runs after PROJECT.md creation (B1) and before ROADMAP.md generation (B3). Profile depth mapping in B1.5 determines DISCOVERY_DEPTH. Domain research in B2.1 spawns Scout agent. Round-based loop in B2 steps a-i implements all features: scenarios, table stakes, thread-following, differentiators, anti-features, vague answer disambiguation, pitfall warnings, keep-exploring gate.

**Phase Discovery:** Implemented in vibe.md Plan mode (States 3-4), before planning begins. Reads phase scope from ROADMAP.md, checks discovery.json for prior answers, generates 1-3 phase-scoped questions, passes context to Lead agent prompt.

**Phase Discussion (Discuss Mode):** Implemented in vibe.md Discuss mode (lines 322-533). Phase type detection in steps 3-4 uses five keyword patterns (UI/API/CLI/Data/Integration) with 2+ match threshold. Domain-typed question generation in step 5 uses type-specific templates. Scope creep detection in step 5 after each answer extracts features, matches against phase boundaries, triggers gentle redirect. Deferred ideas captured to CONTEXT.md in step 6 and discovery.json in step 7.

### Bootstrap Scripts

**bootstrap-requirements.sh:** Called after Bootstrap Discovery completes to synthesize discovery.json and domain-research.md into REQUIREMENTS.md. Usage:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap/bootstrap-requirements.sh \
  .vbw-planning/REQUIREMENTS.md \
  .vbw-planning/discovery.json \
  .vbw-planning/domain-research.md
```

### Feature Flags

**discovery_questions (boolean, default: true)**
- When `false`: Skip discovery entirely for all profiles
- Affects: All three contexts (Bootstrap, Phase Discovery, Phase Discussion)
- Fallback: Bootstrap uses 2 minimal static questions, Phase Discovery skipped, Phase Discussion not available

**v3_plan_research_persist (boolean, default: false)**
- When `true`: Enable phase research in Plan mode (Phase Discovery research, separate from Bootstrap research)
- When `false`: Phase research skipped, domain-research.md only generated during Bootstrap
- Affects: Phase Discovery context depth
- Note: Feature flag name is historical, v3 prefix refers to planning system version

### Fallback Behaviors

**Skip depth (yolo profile or discovery_questions=false):**
- Bootstrap: Ask 2 minimal static questions ("What are the must-have features?", "Who will use this?"), create empty discovery.json, proceed to requirements
- Phase Discovery: Skipped entirely
- Phase Discussion: Not available

**Research timeout (RESEARCH_AVAILABLE=false):**
- Bootstrap Round 1: Use description analysis only, no domain-informed scenarios
- Bootstrap Round 2: Skip table stakes checklist, go directly to Round 3 thread-following
- Bootstrap Round 3: Skip pitfall warnings
- Bootstrap Round 5: Use direct question for anti-features ("What should this definitely NOT do?") instead of research-informed checklist
- Requirements synthesis: No research annotations ("(domain standard)", "(addresses common pitfall: X)")

**No phase type detected (Discuss mode, all scores < 2):**
- Use generic fallback questions (essential features, technical preferences, boundaries)
- Record phase_type as "generic"
- No domain-typed questions
- Scope creep detection still active (uses phase boundaries, not type-specific logic)

### Config Toggle Effects

Profile depth mapping to question counts:
- yolo → skip (0 questions, all discovery skipped)
- prototype → quick (1-2 questions minimum, user can extend)
- default → standard (3-5 questions minimum, user can extend)
- production → thorough (5-8 questions minimum, user can extend)

Keep-exploring gate allows users to exceed minimums in all profiles except yolo.
