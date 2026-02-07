---
description: Remove a future phase from the active milestone's roadmap and renumber subsequent phases.
argument-hint: <phase-number>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Remove-Phase: $ARGUMENTS

## Context

Working directory: `!`pwd``

Active milestone:
```
!`cat .planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Planning structure:
```
!`ls .planning/ 2>/dev/null || echo "Not initialized"`
```

## Guard

1. **Not initialized:** If `.planning/` directory doesn't exist, STOP: "Run /vbw:init first."

2. **Missing phase number:** If `$ARGUMENTS` doesn't include a phase number, STOP: "Usage: /vbw:remove-phase <phase-number>"

3. **Phase not found:** If the specified phase number doesn't exist in the roadmap, STOP: "Phase {N} not found in roadmap."

4. **Phase has work:** If the phase directory contains any PLAN.md or SUMMARY.md files, STOP: "Phase {N} has planned or completed work. Remove plans first or use a different approach. Phase directories with artifacts cannot be removed."

5. **Phase is complete:** If the phase is marked complete in ROADMAP.md (checkbox checked: `- [x]`), STOP: "Cannot remove completed Phase {N}. Completed phases are part of the project history."

## Steps

### Step 1: Resolve milestone context

Determine which milestone's roadmap to modify:

1. Check if `.planning/ACTIVE` exists
2. If ACTIVE exists: read the slug, set:
   - `ROADMAP_PATH=.planning/{slug}/ROADMAP.md`
   - `PHASES_DIR=.planning/{slug}/phases`
   - `MILESTONE_NAME={slug}`
3. If ACTIVE does NOT exist (single-milestone mode): set:
   - `ROADMAP_PATH=.planning/ROADMAP.md`
   - `PHASES_DIR=.planning/phases`
   - `MILESTONE_NAME=default`
4. Read the resolved ROADMAP.md

### Step 2: Parse arguments

Extract from `$ARGUMENTS`:
- **Phase number:** Must be a valid integer
- Validate that the phase exists in the roadmap
- Look up the phase name and slug from the roadmap for display purposes

### Step 3: Confirm removal

Display the phase details and ask for confirmation before this destructive action:

```
Removing Phase {N}: {name}
  Goal:   {goal from roadmap}
  Status: {status -- e.g., "Not started", "In progress"}
  Dir:    {PHASES_DIR}/{NN}-{slug}/

Type 'confirm' to remove this phase and renumber subsequent phases.
```

Wait for the user to confirm. If not confirmed, STOP: "Removal cancelled."

### Step 4: Remove phase directory

Delete the phase directory and its contents:

```bash
rm -rf {PHASES_DIR}/{NN}-{slug}/
```

### Step 5: Renumber subsequent phases

Process in FORWARD order (rename lowest-numbered first since we are decrementing):

For each phase with number > removed phase number, starting from (removed + 1) up to the last phase:

**5a. Rename directory:**
```bash
mv {PHASES_DIR}/{NN}-{slug} {PHASES_DIR}/{NN-1}-{slug}
```

**5b. Rename internal PLAN.md and SUMMARY.md files:**
Each file inside the directory follows the pattern `{phase}-{plan}-PLAN.md` or `{phase}-{plan}-SUMMARY.md`. Rename them to use the decremented phase number:
```bash
mv {PHASES_DIR}/{NN-1}-{slug}/{old-NN}-01-PLAN.md {PHASES_DIR}/{NN-1}-{slug}/{new-NN}-01-PLAN.md
```
Repeat for all plan numbers found in the directory.

**5c. Update YAML frontmatter in renamed files:**
For each renamed PLAN.md and SUMMARY.md file, update:
- `phase:` field to reflect the new phase directory name

**5d. Update depends_on references:**
For each PLAN.md file that has `depends_on` entries referencing other renumbered phases, update the references:
- `"07-01"` becomes `"06-01"` if Phase 07 was renumbered to Phase 06

**CRITICAL:** Forward order prevents directory name collisions when decrementing. If Phase 4, 5, 6 all need to shift down by 1 (after removing Phase 3), rename Phase 4 to Phase 3 first, then Phase 5 to Phase 4, then Phase 6 to Phase 5. Reverse order would fail because renaming Phase 6 to Phase 5 would collide with the existing Phase 5 directory.

### Step 6: Update ROADMAP.md

Edit the resolved ROADMAP.md with the following changes:

**6a. Phase list:** Remove the phase entry and renumber all subsequent entries:
- Delete the `- [ ] **Phase {N}: {name}**` line
- Update every subsequent phase: `Phase {old-N}` becomes `Phase {new-N}`

**6b. Phase Details sections:** Remove the entire Phase Details section for the deleted phase (from `### Phase {N}:` up to but not including the next `### Phase` header or end of section).

Renumber all subsequent Phase Details headers: `### Phase {old-N}:` becomes `### Phase {new-N}:`.

**6c. Update cross-references in Phase Details:**
- `Depends on:` references that point to renumbered phases must be updated
- The phase immediately after the removed one should have its `Depends on:` updated to point to the phase before the removed one
- Plan name references like `{old-NN}-01-PLAN.md` must become `{new-NN}-01-PLAN.md`

**6d. Progress table:** Remove the row for the deleted phase and renumber subsequent rows.

**6e. Update total phase counts** if they appear anywhere in the roadmap.

### Step 7: Present summary

Display using brand formatting:

```
╔═══════════════════════════════════════════╗
║  Phase Removed: {phase-name}              ║
║  {total} phases remaining                 ║
╚═══════════════════════════════════════════╝

  Milestone:   {MILESTONE_NAME}
  Renumbered:  {count} phase(s) shifted

  Phase Changes:
    REMOVED Phase {N}: {name}
    Phase {old} -> Phase {new}: {name}
    Phase {old} -> Phase {new}: {name}
    ...

  ✓ Removed {PHASES_DIR}/{NN}-{slug}/
  ✓ Updated {ROADMAP_PATH}
  ✓ Renumbered {count} subsequent phases

➜ Next Up
  /vbw:status -- View updated roadmap
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Use the **Phase Banner** template (double-line box) for the phase removed banner
- Use the **Metrics Block** template for milestone/renumbered display
- Use the **File Checklist** template for the removed/updated files list (✓ prefix)
- Use the **Next Up Block** template for navigation (➜ header, indented commands with --)
- Show the renumbering map under "Phase Changes:" so the user sees what shifted
- No ANSI color codes
- Keep lines under 80 characters inside boxes
