---
phase: {phase-id}
plan_count: {N}
status: {in_progress|complete|issues_found}
started: {YYYY-MM-DD}
completed: {YYYY-MM-DD}
total_tests: {N}
passed: {N}
skipped: {N}
issues: {N}
---

{one-line-summary}

## Tests

### P{plan}-T{N}: {test-title}

- **Plan:** {plan-id} -- {plan-title}
- **Scenario:** {what to do}
- **Expected:** {what should happen}
- **Result:** {pass|skip|issue}
- **Issue:** {if result=issue}
  - Description: {issue-description}
  - Severity: {critical|major|minor}
  - Fix: /vbw:fix "{suggested-fix-description}"

## Summary

- Passed: {N}
- Skipped: {N}
- Issues: {N}
- Total: {N}
