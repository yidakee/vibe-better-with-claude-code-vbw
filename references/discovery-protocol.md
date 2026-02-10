# Discovery Protocol (DISC-01)

Intelligent questioning system that helps users define what they want to build. Runs during `/vbw:implement` at bootstrap and before each phase. Questions are non-developer friendly, scenario-based, and profile-gated.

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
**Output:** Populated REQUIREMENTS.md with REQ-IDs

Flow:
1. Analyze the user's description for: domain, scale, users, complexity signals
2. Generate scenario questions first (Round 1)
3. Based on answers, generate targeted checklist questions (Round 2)
4. Synthesize all answers into REQUIREMENTS.md
5. Store answered questions in `.vbw-planning/discovery.json`

### Phase Discovery (implement States 3-4, before planning)

Lighter round scoped to the specific phase about to be planned. Skipped if phase already has a CONTEXT.md from `/vbw:discuss`.

**Input:** Phase goal, requirements, and success criteria from ROADMAP.md
**Output:** Phase context injected into Lead agent prompt

Flow:
1. Read phase scope from ROADMAP.md
2. Check `.vbw-planning/discovery.json` — skip questions already answered
3. Generate 1-3 phase-scoped questions (fewer than bootstrap)
4. Store answers, pass as context to planning step

## Mixed Question Format

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
| implement State 1, B2 | Bootstrap | After project description, before REQUIREMENTS.md |
| implement States 3-4 | Phase | Before planning, after phase auto-detection |
| discuss | N/A | Separate command, not gated by discovery_questions |

`/vbw:discuss` remains independent — it's a manual deep-dive the user triggers explicitly. Discovery is the automatic layer.
