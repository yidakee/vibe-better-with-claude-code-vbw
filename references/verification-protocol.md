# VBW Verification Protocol

Single source of truth for VBW's verification pipeline. Referenced by `${CLAUDE_PLUGIN_ROOT}/agents/vbw-qa.md` and commands (`${CLAUDE_PLUGIN_ROOT}/commands/qa.md`, `${CLAUDE_PLUGIN_ROOT}/commands/build.md`).

## 1. Overview

The verification protocol defines how VBW validates completed work. Verification runs in two contexts:

- **Post-build:** Automatically after `/vbw:build` completes a phase (unless `--skip-qa` or turbo mode)
- **Standalone:** Via `/vbw:qa <phase>` for independent verification of any completed phase

The QA agent (`${CLAUDE_PLUGIN_ROOT}/agents/vbw-qa.md`) executes verification. It is strictly read-only -- it returns structured findings as text output. The parent command persists results to `VERIFICATION.md`.

This document is the authoritative specification. The QA agent's inline tier descriptions are derived from this reference.

## 2. Three-Tier Verification (VRFY-01)

Verification operates at three depth tiers, each building on the previous.

### Quick Tier (5-10 checks)

**Purpose:** Fast existence and sanity validation.

**Checks:**
- **Artifact existence:** Each file in `must_haves.artifacts` exists at its declared path
- **Frontmatter validity:** YAML parses without error, required fields present
- **Key string presence:** Each `contains` value from `must_haves.artifacts` appears in its artifact (verified via grep)
- **No placeholder text:** No `{placeholder}`, `TBD`, or `Phase N` stub markers remain in output files

**Used for:** Turbo-adjacent speed, low-risk phases, quick spot-checks.

### Standard Tier (15-25 checks)

**Purpose:** Structural and relational validation covering most phases.

Everything in Quick, plus:
- **Content structure:** Expected sections, headings, and organizational patterns present
- **Key link verification:** Each `must_haves.key_links` connection confirmed via grep (from-file references to-file)
- **Import/export chain:** Referenced files exist and cross-references resolve
- **Frontmatter cross-consistency:** Field values align across related artifacts (e.g., phase IDs match)
- **Line count thresholds:** Files meet minimum size expectations for their type
- **Convention compliance:** If `.planning/codebase/CONVENTIONS.md` exists, check new/modified files against established conventions (see Section 5)
- **Skill-augmented checks:** If quality-related skills are installed (per STATE.md Skills section), run additional domain-specific checks (e.g., security-audit, a11y-check)

**Used for:** Most phases, the recommended default tier.

### Deep Tier (30+ checks)

**Purpose:** Exhaustive validation for critical phases and pre-ship verification.

Everything in Standard, plus:
- **Anti-pattern scan:** Detect filler phrases, dead code, placeholder remnants, hardcoded secrets (see Section 6)
- **Requirement-to-artifact mapping:** Each requirement ID from ROADMAP.md traces to at least one artifact (see Section 7)
- **Cross-file consistency:** Shared constants, enums, or type definitions match everywhere they are used
- **Detailed convention verification:** Systematic comparison against CONVENTIONS.md -- every new file checked, every modified file verified for convention violations
- **Skill-augmented deep checks:** Thorough domain-specific verification for installed quality skills (security scanning, accessibility auditing, test coverage analysis)
- **Completeness audit:** No partial implementations, no TODO/FIXME without tracking

**Used for:** Critical phases, pre-ship verification, phases with >15 requirements.

## 3. Auto-Selection Heuristic (VRFY-01)

When no explicit tier is specified, VBW auto-selects based on context signals:

| Signal | Selected Tier |
|--------|---------------|
| `--effort=turbo` or `QA_EFFORT=skip` | No QA (skipped entirely) |
| `--effort=fast` or `QA_EFFORT=low` | Quick |
| `--effort=balanced` or `QA_EFFORT=medium` | Standard |
| `--effort=thorough` or `QA_EFFORT=high` | Deep |
| Standalone `/vbw:qa` with no effort flag | Standard (default) |
| Phase has >15 requirements | Deep (override) |
| Phase is the last before ship | Deep (override) |

**Override precedence:** Explicit `--tier` flag > context overrides > effort-based selection > default.

If both `--tier` and `--effort` are provided, `--tier` takes precedence (it is the more specific instruction).

## 4. Goal-Backward Methodology (VRFY-02)

Verification follows a goal-backward approach: start from desired outcomes, derive testable conditions, then verify each condition against actual artifacts.

### Verification Sequence

1. **State the goal:** Extract the objective from the plan and the phase success criteria from ROADMAP.md. These define what "done" looks like.

2. **Derive observable truths:** From `must_haves.truths` in the plan frontmatter. Each truth is a statement that must be verifiably true in the completed codebase.

3. **Verify at three levels:**

   **Truth checks:** For each truth in `must_haves.truths`, determine what observable condition proves it. Execute the check (grep, file read, pattern match) and classify as PASS/FAIL/PARTIAL with evidence.

   **Artifact checks:** For each artifact in `must_haves.artifacts`, verify:
   - File exists at the declared `path`
   - File contains each required `contains` string
   - File provides the declared `provides` capability

   **Key link checks:** For each link in `must_haves.key_links`, verify:
   - The `from` file references the `to` file
   - The connection matches the declared `pattern` (via grep)
   - The relationship described in `via` is confirmed

4. **Classify and report:** Each check receives PASS, FAIL, or PARTIAL status with specific evidence (file paths, line numbers, grep output).

### Why Goal-Backward

Traditional verification asks "did we write the code?" Goal-backward verification asks "does the code achieve the stated goal?" This catches issues where code exists but doesn't fulfill its purpose -- misnamed exports, unwired features, partial implementations that pass existence checks but fail behavioral ones.

## 5. Convention Verification (VRFY-06)

When `.planning/codebase/CONVENTIONS.md` exists, QA checks new and modified code against documented conventions.

### Convention Categories

- **Naming patterns:** File names, function names, variable names follow detected project patterns (e.g., camelCase, kebab-case, PascalCase)
- **File placement:** Tests live in test directories, components in component directories, utilities in utility directories -- matching the project's established layout
- **Import ordering:** Imports follow project conventions if documented (e.g., external before internal, sorted alphabetically)
- **Export patterns:** Default vs named exports, barrel file usage, re-export conventions match established patterns

### Verification Behavior by Tier

- **Quick tier:** Convention checks are skipped (too slow for quick validation)
- **Standard tier:** Spot-check conventions -- verify naming patterns and file placement for new files
- **Deep tier:** Systematic comparison -- every new file checked against naming conventions, every modified file verified for convention violations, code patterns checked against documented idioms (error handling style, async patterns)

### When CONVENTIONS.md Does Not Exist

Convention verification is silently skipped. No warning is emitted -- convention documentation is optional. QA proceeds with all other checks.

## 6. Anti-Pattern Scanning (VRFY-07)

Anti-pattern scanning detects common quality issues in completed work. Active at Standard tier (limited) and Deep tier (full).

### Anti-Pattern Definitions

| Anti-Pattern | Detection | Severity | Tier |
|---|---|---|---|
| TODO/FIXME without tracking | `grep -rn "TODO\|FIXME"` in source files, not linked to a tracking system | WARN | Deep |
| Placeholder text | Presence of `{placeholder}`, `TBD`, `Phase N` stubs, `lorem ipsum` in output files | FAIL | Standard+ |
| Empty function bodies | Functions or methods with no implementation (empty body or only a comment) | FAIL | Deep |
| Filler phrases | Presence of "think carefully", "be thorough", "as an AI", "I'll help you" in agent/reference files | FAIL | Standard+ |
| Unwired code | Exported functions or components never imported elsewhere in the codebase | WARN | Deep |
| Dead imports | Import statements for symbols not used in the importing file | WARN | Deep |
| Hardcoded secrets | Patterns matching API keys (`sk-`, `pk_`, `AKIA`), tokens, passwords in source files | FAIL | Standard+ |

### Severity Definitions

- **FAIL:** Must be fixed before shipping. Indicates a quality or security issue.
- **WARN:** Should be reviewed. May be intentional (e.g., a TODO for a future phase) but warrants acknowledgment.

### Detection Notes

- Placeholder text detection excludes template files (`${CLAUDE_PLUGIN_ROOT}/templates/`) where `{placeholder}` syntax is intentional
- Filler phrase detection applies to agent definitions, reference documents, and command files -- not to user-facing templates
- Hardcoded secret detection uses pattern matching, not entropy analysis. Known key prefixes (`sk-`, `pk_`, `AKIA`, `ghp_`, `glpat-`) and common patterns (`password\s*=\s*["']`, `secret\s*=\s*["']`) are scanned
- Dead import detection is language-aware when possible (JS/TS `import` statements, Python `import`/`from` statements)

## 7. Requirement Mapping Verification (VRFY-08)

Requirement mapping traces each requirement ID to its implementing artifacts. Active at Deep tier only.

### Verification Sequence

1. **Read phase requirements:** Extract requirement IDs from the phase section of ROADMAP.md (e.g., `VRFY-01`, `CMD-08`)

2. **Trace to plans:** For each requirement ID, search all PLAN.md files in the phase directory for the ID in `must_haves`, task descriptions, or success criteria

3. **Trace to artifacts:** For each requirement ID, search all SUMMARY.md files for evidence that the requirement was implemented (mentioned in accomplishments, task commits, or files created/modified)

4. **Report coverage:**
   - **Mapped:** Requirement ID found in both a plan and a summary -- implementation evidence exists
   - **Planned only:** Requirement ID found in a plan but not in any summary -- planned but not yet verified as complete
   - **Unmapped:** Requirement ID not found in any plan or summary -- missing from the phase entirely

5. **Classify:** Unmapped requirements are reported as FAIL. Planned-only requirements are reported as WARN (may indicate incomplete work).

### Scope

Requirement mapping only checks within the current phase. Cross-phase requirements (where a requirement is partially addressed across multiple phases) are noted but not flagged as failures.

## 8. Continuous Verification Hooks Protocol (VRFY-03, VRFY-04, VRFY-05)

These are protocol instructions embedded in agent definitions -- NOT JavaScript hooks or Claude Code event handlers. They define verification behaviors that agents follow as part of their standard operating procedure.

### Post-Write/Edit Verification (VRFY-03)

**Where:** Protocol instruction in `${CLAUDE_PLUGIN_ROOT}/agents/vbw-dev.md`

**Trigger:** After Dev creates or edits a source file

**Behavior:**
- If the project has a linter configured (ESLint, Prettier, Ruff, etc.), run the linter on the modified file
- If the project has a type checker configured (TypeScript, mypy, etc.), run the type checker
- If either reports errors, fix before committing
- This is advisory -- the Dev agent follows this protocol as part of careful implementation, not as an automated enforcement mechanism

### Post-Commit Verification (VRFY-04)

**Where:** Protocol instruction in `${CLAUDE_PLUGIN_ROOT}/agents/vbw-dev.md`

**Trigger:** After Dev creates a commit

**Behavior:**
- Verify the commit message follows the format: `{type}({scope}): {description}`
- Check that only task-related files are staged (no stray files from other tasks)
- If format is wrong, amend the commit (only for format issues, not content changes)
- This is a self-check protocol, not an automated git hook

### OnStop / Summary Validation (VRFY-05)

**Where:** Protocol instruction in `${CLAUDE_PLUGIN_ROOT}/commands/build.md`

**Trigger:** When build completes a plan

**Behavior:**
- Verify the SUMMARY.md exists for the completed plan
- Verify SUMMARY.md has required frontmatter fields: `phase`, `plan`, `duration`, `completed`
- Verify SUMMARY.md has the standard sections: Accomplishments, Task Commits, Files Created/Modified, Deviations from Plan
- If validation fails, the build command reports the issue rather than silently continuing

## 9. Verification Output Format

The standard output format for VERIFICATION.md files. QA returns this structure as text; the parent command adds YAML frontmatter and persists to disk.

### YAML Frontmatter

```yaml
---
phase: {phase-id}
tier: {quick|standard|deep}
result: {PASS|FAIL|PARTIAL}
passed: {N}
failed: {N}
total: {N}
date: {YYYY-MM-DD}
---
```

### Document Structure

```markdown
# Verification: Phase {N}

## Must-Have Checks

| # | Truth/Condition | Status | Evidence |
|---|-----------------|--------|----------|
| 1 | {condition from must_haves.truths} | PASS/FAIL/PARTIAL | {specific evidence} |

## Artifact Checks

| Artifact | Exists | Contains | Status |
|----------|--------|----------|--------|
| {path} | yes/no | {required content} | PASS/FAIL |

## Key Link Checks

| From | To | Via | Status |
|------|-----|-----|--------|
| {source} | {target} | {relationship} | PASS/FAIL |

## Anti-Pattern Scan (standard+ tiers)

| Pattern | Found | Location | Severity |
|---------|-------|----------|----------|
| {name} | yes/no | {file:line if found} | WARN/FAIL |

## Requirement Mapping (deep tier only)

| Requirement | Plan Reference | Artifact Evidence | Status |
|-------------|----------------|-------------------|--------|
| {REQ-ID} | {plan file} | {summary evidence} | Mapped/Planned Only/Unmapped |

## Convention Compliance (standard+ tiers, if CONVENTIONS.md exists)

| Convention | File | Status | Detail |
|------------|------|--------|--------|
| {convention name} | {file path} | PASS/FAIL | {specific finding} |

## Skill-Augmented Checks (if quality skills installed)

| Skill | Check | Status | Evidence |
|-------|-------|--------|----------|
| {skill-name} | {what was checked} | PASS/FAIL | {evidence} |

## Summary

Tier: {quick|standard|deep}
Result: {PASS|FAIL|PARTIAL}
Passed: {N}/{total}
Failed: {list of failed check descriptions}
```

### Result Classification

- **PASS:** All checks pass. No FAIL results. WARNs are acceptable.
- **PARTIAL:** Some checks pass, some fail, but core functionality is verified. At least one FAIL exists but it is non-blocking.
- **FAIL:** Critical checks fail. Core functionality or security is compromised. Must be fixed before proceeding.
