# VBW Shared Patterns

Reusable protocol fragments referenced across multiple skills.

## Initialization Guard

If `.vbw-planning/` doesn't exist, STOP: "Run /vbw:init first."

## Milestone Resolution

Check for `.vbw-planning/ACTIVE` file to resolve the active milestone. If ACTIVE exists, read its contents for the milestone identifier and scope all phase paths accordingly.

## Agent Teams Shutdown Protocol

After all teammates have completed their tasks:
1. Send a shutdown request to each teammate.
2. Wait for each teammate to respond with shutdown approval.
3. If a teammate rejects shutdown (still finishing work), wait for it to complete and re-request.
4. Once ALL teammates have shut down, run TeamDelete to clean up the team and its shared task list.

## Phase Auto-Detection

Read `${CLAUDE_PLUGIN_ROOT}/references/phase-detection.md` for the full algorithm. Summary: scan phase directories in numeric order, checking for the presence/absence of PLAN.md and SUMMARY.md files to determine the next actionable phase.
