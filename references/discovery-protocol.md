# Discovery Protocol (DISC-01)

Intelligent questioning system that helps users define what they want to build. Runs during `/vbw:vibe` at bootstrap and before each phase. Questions are non-developer friendly, scenario-based, and profile-gated.

## Profile Depth Mapping

| Profile | Depth | Questions | Style |
|---------|-------|-----------|-------|
| yolo | skip | 0 | No discovery — jump straight to building |
| prototype | quick | 1-2 | One scenario + one checklist. Speed over precision |
| default | standard | 3-5 | Mixed scenarios + checklists. The recommended balance |
| production | thorough | 5-8 | Deep scenarios, detailed checklists, edge cases, rollback |

Read active profile from `config.json` → `active_profile`. Map to depth above. If `discovery_questions` is `false`, skip entirely regardless of profile.

## Two Modes

### Bootstrap Discovery (implement State 1, Step B2)

Replaces static requirements questions. Triggered when project has no REQUIREMENTS.md or it contains template placeholders.

**Input:** User's project description (from $ARGUMENTS or "What do you want to build?")
**Output:** Populated REQUIREMENTS.md with REQ-IDs, `.vbw-planning/domain-research.md` (if research conducted), updated discovery.json

Flow:
1. Analyze user's description for: domain, scale, users, complexity signals
2. **Domain Research (if not skip depth):** Spawn Scout to research domain, produce domain-research.md. On success: read findings. On failure: set RESEARCH_AVAILABLE=false.
3. **Round-based questioning loop:**
   - Initialize ROUND=1, continue until user chooses to stop
   - Round 1: Generate scenario questions (research-informed if available)
   - Round 2+: Generate checklist questions building on previous round answers
   - After each round: present keep-exploring gate
   - Soft nudge wording appears at round 3+
4. Synthesize all answers into REQUIREMENTS.md, integrating research where relevant
5. Store answered questions and research summary in `.vbw-planning/discovery.json`

### Phase Discovery (implement States 3-4, before planning)

Lighter round scoped to the specific phase about to be planned. Skipped if phase already has a CONTEXT.md from `/vbw:vibe --discuss`.

**Input:** Phase goal, requirements, and success criteria from ROADMAP.md
**Output:** Phase context injected into Lead agent prompt

Flow:
1. Read phase scope from ROADMAP.md
2. Check `.vbw-planning/discovery.json` — skip questions already answered
3. Generate 1-3 phase-scoped questions (fewer than bootstrap)
4. Store answers, pass as context to planning step

### Phase Discussion (Discuss Mode)

Explicit deep-dive mode triggered by `/vbw:vibe --discuss`, separate from automatic Phase Discovery. Detects phase type from ROADMAP.md phase goal and requirements text, then generates domain-specific questions tailored to what the phase builds.

**Input:** Phase number (from $ARGUMENTS or auto-detected current phase)
**Output:** `{phase}-CONTEXT.md` with domain-typed discussion content, updated discovery.json with phase type metadata

#### Phase Type Detection

Discuss mode identifies what KIND of thing the phase builds using keyword matching on ROADMAP.md phase goal and requirements text. Five supported types:

**UI (User Interface):**
- Keywords: design, interface, layout, frontend, screens, components, responsive, page, view, form, dashboard
- Detection: minimum 2 keyword matches required
- Question domains: layout structure, UI states, user interactions, responsiveness

**API (Application Programming Interface):**
- Keywords: endpoint, service, backend, response, error handling, auth, versioning, route, REST, request
- Detection: minimum 2 keyword matches required
- Question domains: response format, error handling, authentication, versioning, rate limits

**CLI (Command-Line Interface):**
- Keywords: command, flags, arguments, output format, terminal, console, prompt, stdin, stdout
- Detection: minimum 2 keyword matches required
- Question domains: command structure, output format, error messages, help system, piping

**Data (Data/Schema):**
- Keywords: schema, database, migration, storage, persistence, retention, model, query, index
- Detection: minimum 2 keyword matches required
- Question domains: data model, relationships, migrations, retention policies, constraints

**Integration (Third-Party Integration):**
- Keywords: third-party, external service, sync, webhook, connection, protocol, import, export
- Detection: minimum 2 keyword matches required
- Question domains: protocol/format, authentication, error recovery, data flow, dependency handling

**Mixed-Type Handling:**
- 0 types detected (no keywords matched): use generic fallback questions
- 1 type detected (single type scored ≥2 matches): auto-select that type
- 2+ types detected (multiple types scored ≥2 matches): present AskUserQuestion with detected types as options, user chooses focus

#### Domain-Typed Questions

Each phase type has 3-5 specific question templates focused on domain-relevant concerns. All questions follow Wording Guidelines (plain language, no jargon, concrete situations). Questions use AskUserQuestion tool with 2-4 options per question.

**Question domains per type:**
- **UI:** Layout structure (pages/flows/components), state management (what changes when user acts), error states (what user sees on failure), responsiveness (mobile/tablet/desktop), user interactions (clicks/forms/navigation)
- **API:** Response format (what data gets returned), error handling (failure scenarios), authentication (access control), versioning (handling changes), rate limits or pagination (scale)
- **CLI:** Command structure (subcommands/flags), output format (human vs machine-readable), error messages (what users see), help system (documentation), piping/composition (stdin/stdout)
- **Data:** Data model (entities/fields), relationships (how data connects), migrations (schema changes), retention (data lifecycle), constraints and validation (data rules)
- **Integration:** Protocol and format (communication method), authentication (API keys/OAuth/tokens), error recovery (retry/fallback), data flow (import/export/sync), dependency handling (external service failures)

**Generic fallback (when no type detected):**
- Essential features question
- Technical preferences question
- Boundaries question

All questions build CONTEXT.md sections: User Vision, Essential Features, Technical Preferences, Boundaries, Acceptance Criteria, Decisions Made.

#### Scope Creep Guardrails

After each user answer in Discuss mode, the system analyzes feature mentions and compares them against other phases' goals and requirements from ROADMAP.md. When a mentioned feature appears to fit better in a different phase, the system offers to defer it rather than expanding current phase scope.

**Detection Method:**
- Parse user's answer for feature keywords and capability mentions
- Compare against ROADMAP.md phase goals and requirements for ALL phases
- Trigger when feature mention maps to a different phase's domain

**Redirect Pattern:**
When out-of-scope mention detected, present AskUserQuestion:
```
[Feature X] sounds like a new capability — that could be its own phase. Want me to note it for later?
```

**Options:**
- "Note it for later — add to Deferred Ideas" (captures feature to CONTEXT.md, conversation continues)
- "Include in this phase — it's part of the scope" (no capture, feature stays in current discussion)

**Deferred Ideas Capture:**
Appended to CONTEXT.md in a new "Deferred Ideas" section (added after Decisions Made section):

```markdown
## Deferred Ideas

Features mentioned during discussion that may fit better in other phases:

- **Dashboard analytics** — suggested for Phase 4: Reporting and Analytics. Status: noted for later planning.
- **Email notifications** — suggested for Phase 5: Notifications. Status: noted for later planning.
```

**discovery.json Recording:**
Deferred ideas recorded with:
```json
{
  "question": "[Generated question that revealed the mention]",
  "answer": "[User's original answer containing the mention]",
  "category": "deferred_idea",
  "phase": "03",
  "date": "2026-02-13",
  "deferred": {
    "mention": "Dashboard analytics",
    "suggested_phase": "Phase 4: Reporting and Analytics",
    "matched_keyword": "analytics",
    "user_decision": "deferred"
  }
}
```

**Style:**
- Gentle and non-blocking: single mention per feature, conversation continues immediately
- No judgment: framed as "could be its own phase" not "out of scope"
- User has final say: "Include in this phase" option always available

#### Example Flows by Phase Type

Sample question flows for each phase type, demonstrating domain-typed questions in plain language following Wording Guidelines.

**UI Phase Example: "Phase 2: User Dashboard"**

1. "How should the layout adapt when someone switches from desktop to phone?"
   - Same layout scaled down
   - Simplified mobile version
   - Mobile app instead
   - Let me explain

2. "What happens when data is loading?"
   - Show spinner
   - Show skeleton placeholders
   - Show cached data with refresh indicator
   - Let me explain

3. "How should users navigate between sections?"
   - Sidebar menu
   - Top tabs
   - Hamburger menu
   - Let me explain

**API Phase Example: "Phase 3: Data Sync Service"**

1. "What should the system return when a sync request succeeds?"
   - Just success/fail status
   - Full updated data
   - Change summary
   - Let me explain

2. "What happens if someone's API key is invalid?"
   - Return error code
   - Lock account
   - Send email alert
   - Let me explain

3. "How should the system handle too many requests from one source?"
   - Slow them down automatically
   - Block after limit
   - Require upgrade
   - Let me explain

**CLI Phase Example: "Phase 2: Build Command"**

1. "What should the command print when a build finishes?"
   - Summary line only
   - Detailed file list
   - Machine-readable JSON
   - Let me explain

2. "How should errors appear in the terminal?"
   - Red text with explanation
   - Error code with docs link
   - Stack trace
   - Let me explain

3. "What happens when someone runs the command with no arguments?"
   - Show help automatically
   - Start interactive wizard
   - Use default settings
   - Let me explain

**Data Phase Example: "Phase 3: User Profiles Schema"**

1. "What should happen to someone's data when they delete their account?"
   - Delete immediately
   - Keep for 30 days
   - Anonymize and keep
   - Let me explain

2. "How should the system handle two people trying to update the same profile at once?"
   - Last edit wins
   - Lock while editing
   - Merge changes
   - Let me explain

3. "What fields must always have a value?"
   - Name and email
   - Just email
   - No required fields
   - Let me explain

**Integration Phase Example: "Phase 4: Third-Party Calendar Sync"**

1. "What happens if the calendar service is down when someone tries to sync?"
   - Show error and stop
   - Retry automatically
   - Queue for later
   - Let me explain

2. "How should the system authenticate with the calendar service?"
   - User connects their account once
   - Use our API key
   - Ask each time
   - Let me explain

3. "What data flows between the systems?"
   - Events only
   - Events and attendees
   - Full calendar
   - Let me explain

### Thread-Following Questions

Round 2+ questions build on previous answers rather than following a fixed script:

- **If prior answer was vague:** Generate concrete follow-up (see Vague Answer Handling)
- **If prior answer revealed complexity:** Ask edge case questions
- **If prior answer mentioned integration:** Ask about auth, error handling, data flow
- **If prior answer suggested scale:** Ask about performance, caching, limits

Check `discovery.json.answered[]` before generating questions to avoid duplicates. Each answer records its round number for thread analysis.

### Keep-Exploring Gate

After each question round, offer the user control over depth:

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

The profile depth (quick/standard/thorough) sets the MINIMUM rounds, not a hard cap. Users can continue as long as they choose "Keep exploring."

## Mixed Question Format

### Research-Informed Question Generation

When domain research is available (RESEARCH_AVAILABLE=true):
- **Scenarios (Round 1):** Reference specific pitfalls, patterns, or competitor behaviors from research. Example: "App X handles offline sync by caching recipes locally. Should yours work the same way or always require internet?"
- **Checklists (Round 2):** Include table-stakes features as default-checked items with "(domain standard)" labels. Example: "☑ Offline access (domain standard — recipe apps need this)"
- **Requirement synthesis:** Annotate requirements with research sources: "(domain standard)", "(addresses common pitfall: X)", "(typical approach: Y)"

When research is unavailable (RESEARCH_AVAILABLE=false):
- Use description analysis only, per existing protocol
- Generate scenarios from inferred complexity signals
- No domain-specific annotations

### Round 1: Scenarios

Present real situations the user's project will face. Each scenario has:
- A **situation** described in plain language
- **Two or more outcomes** the user picks from
- A brief **"this means..."** explaining the technical implication of each choice

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

Format scenarios as AskUserQuestion with descriptive options. Each option's description field carries the "this means..." explanation.

### Round 2: Checklists

After scenarios reveal the project shape, ask targeted yes/no or pick-many questions. Group related items.

Example after learning the project is customer-facing:
```
Which of these does your project need?

  □ User accounts (people log in and have profiles)
  □ Payments (customers pay you money through the site)
  □ Email notifications (the system sends emails automatically)
  □ Admin dashboard (you manage things through a control panel)
```

Format as AskUserQuestion with `multiSelect: true`.

## Wording Guidelines

**Always assume the user is not a developer.** They may not know what an API, database, or deployment means. Follow these rules:

1. **Plain language first:** Say "people log in" not "user authentication". Say "the system remembers" not "data persistence".
2. **Examples over definitions:** Don't explain what caching is — ask "Should the site load instantly even if the data is a few minutes old, or always show the absolute latest?"
3. **Cause and effect:** Every technical choice should explain what happens. "If you pick A, your site loads faster but shows slightly old data. If you pick B, it's always fresh but might feel slower."
4. **Concrete over abstract:** "What happens when someone's internet drops mid-purchase?" not "How should the system handle network failures?"
5. **No jargon in questions:** Terms like REST, GraphQL, microservices, CI/CD, Docker, etc. should never appear in questions. Use their effects instead.
6. **Jargon in requirements:** The answers GET translated to technical requirements in REQUIREMENTS.md. Questions are friendly, outputs are precise.

## Disambiguation Pattern

When a user gives a vague answer, present 3-4 concrete interpretations rather than accepting it as-is.

### Vague Answer Triggers

Detect these patterns:
- **Quality adjectives:** easy, fast, simple, secure, reliable, powerful, flexible (without specifics)
- **Scope terms:** everything, lots, comprehensive, full-featured (without boundaries)
- **Time terms:** quick, slow, immediate, later (without metrics)
- **Scale terms:** big, small, many, few (without numbers)

### Disambiguation Flow

1. User gives vague answer (e.g., "I want it to be easy to use")
2. Generate 3-4 concrete domain-specific interpretations:
   - "Works on mobile devices?"
   - "No signup required?"
   - "Loads in under 2 seconds?"
   - "Let me explain..." (escape hatch)
3. Present as AskUserQuestion with descriptive options
4. If "Let me explain" chosen: capture free-text, offer to revisit question with context
5. Record disambiguated answer to discovery.json with metadata

### Example Patterns

| Vague Term | Concrete Interpretations |
|------------|-------------------------|
| "Easy to use" | Mobile support? / No signup? / Fast load? |
| "Fast" | <1s page load? / Instant search? / 1000+ concurrent users? |
| "Secure" | Encrypted passwords? / Two-factor auth? / Data deletion? |
| "Lots of features" | 10+ features? / Match competitors? / Cover all use cases? |

The goal: convert vague intent into testable, actionable requirements.

## Pitfall Warnings

After domain research, surface 2-3 most relevant pitfalls as proactive warnings during the question flow.

### When Pitfalls Appear

Pitfall warnings are injected during Round 3 (after table stakes checklist, before differentiator question). Only appear if:
- Domain research completed successfully (RESEARCH_AVAILABLE=true)
- At least one pitfall scores relevance > 0 based on prior answers

### Relevance Scoring

Each pitfall from domain-research.md ## Common Pitfalls is scored based on project context:

| Pitfall Mentions | User Context | Relevance Boost |
|------------------|--------------|-----------------|
| "scale", "performance" | Thousands of users mentioned | +2 |
| "offline", "sync" | Offline access selected in table stakes | +2 |
| "auth", "security" | User accounts or login mentioned | +2 |
| "data", "privacy" | Data-heavy features identified | +2 |
| "integration", "API" | Third-party tools mentioned | +2 |

Top 2-3 pitfalls by score are presented. If all score 0, pitfall warnings are skipped.

### Presentation Format

```
⚠ [Pitfall Title]
[Brief explanation from research, 1-2 sentences]

How should we handle this?
  A) Address it now — add requirement
  B) Note for later — add to phase planning
  C) Skip — not relevant to my project
```

Decisions recorded to discovery.json:
- "Address now" → Must-have requirement with tier "risk_mitigation"
- "Note for later" → Should-have requirement with tier "risk_mitigation"
- "Skip" → no action

### Example

For a recipe app where user selected offline access:

```
⚠ Offline sync conflicts
When users edit recipes offline on multiple devices, conflicts happen on sync. Most apps handle this poorly, leading to data loss.

How should we handle this?
  A) Address it now — define conflict resolution strategy
  B) Note for later — we'll tackle this during sync feature planning
  C) Skip — single device only, no conflicts
```

## Question Categories

Use these to ensure coverage. Not every category applies to every project — select based on the user's description.

| Category | Bootstrap | Phase | Example Question |
|----------|-----------|-------|-----------------|
| Scope | Always | If ambiguous | "You mentioned X — does that include Y, or just Z?" |
| Users | Always | Rarely | "Who uses this? Just you, your team, or the public?" |
| Scale | If unclear | Rarely | "Are we talking dozens of users or thousands?" |
| Data | If relevant | If data phase | "What happens to someone's data if they delete their account?" |
| Edge cases | Standard+ | Always | "What should happen when [unexpected situation]?" |
| Integrations | If mentioned | If integration phase | "Does this need to talk to any other tools you already use?" |
| Priorities | Always | Always | "If you had to pick one: speed, features, or polish?" |
| Boundaries | Standard+ | If scope creep risk | "What should this definitely NOT do?" |

## Per-Project Memory

Store in `.vbw-planning/discovery.json`:

```json
{
  "answered": [
    {
      "question": "Who uses this?",
      "answer": "Public customers",
      "category": "users",
      "phase": "bootstrap",
      "date": "2026-02-10"
    }
  ],
  "inferred": [
    {
      "fact": "Customer-facing application",
      "source": "users question",
      "date": "2026-02-10"
    }
  ]
}
```

Before generating questions:
1. Read `discovery.json` (create empty `{"answered":[],"inferred":[]}` if missing)
2. Skip questions whose category + topic overlap with existing answers
3. Skip questions whose answer can be inferred from existing facts
4. After user answers, append to `answered[]` and extract inferences to `inferred[]`

## Config Toggle

| Setting | Type | Default | Effect |
|---------|------|---------|--------|
| discovery_questions | boolean | true | false = skip discovery entirely, all profiles |

When `false`, implement proceeds directly to requirements gathering (bootstrap) or planning (phases) without discovery questions.

## Integration Points

| Command | Mode | When |
|---------|------|------|
| vibe bootstrap mode | Bootstrap | After project description, before REQUIREMENTS.md |
| vibe plan mode | Phase | Before planning, after phase auto-detection |
| vibe --discuss | N/A | Explicit discuss mode with domain-typed questions based on phase type (UI/API/CLI/Data/Integration) |

`/vbw:vibe --discuss` remains independent — it's a manual deep-dive the user triggers explicitly. Discovery is the automatic layer.

**Note:** Phase Discussion (Discuss mode) includes phase type detection and scope creep guardrails as of Phase 3 implementation (REQ-05, REQ-08).
