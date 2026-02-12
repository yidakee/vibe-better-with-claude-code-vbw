# Migrating from GSD to VBW

**TL;DR:** Run `/vbw:init` in your GSD project. VBW will detect `.planning/` and offer to import it.

---

## GSD Import Process

### What Happens During Init

When you run `/vbw:init` in a directory with an existing `.planning/` folder (GSD's planning directory):

1. **Detection** (Step 0.5): VBW checks for `.planning/` after environment setup but before scaffold
2. **Consent**: Prompts with AskUserQuestion: "GSD project detected. Import work history?"
3. **Archive Copy** (if approved):
   - Creates `.vbw-planning/gsd-archive/`
   - Copies `.planning/*` to `.vbw-planning/gsd-archive/`
   - Original `.planning/` remains untouched
4. **Index Generation**: Runs `generate-gsd-index.sh` to create INDEX.json
5. **Normal Init**: Continues with VBW scaffold (STATE.md, ROADMAP.md, config.json, etc.)

**Timing**: Detection happens BEFORE VBW creates `.vbw-planning/` to ensure clean separation.

---

## Archive Structure

After import, your project has both planning systems:

```
.planning/                  # Original GSD (preserved, read-only for VBW)
  ├── ROADMAP.md
  ├── PROJECT.md
  ├── config.json
  └── phases/
      ├── 01-foundation/
      └── 02-features/

.vbw-planning/              # New VBW planning directory
  ├── gsd-archive/          # Archived GSD copy
  │   ├── INDEX.json        # Generated metadata
  │   ├── ROADMAP.md
  │   ├── PROJECT.md
  │   ├── config.json
  │   └── phases/
  ├── STATE.md
  ├── ROADMAP.md
  ├── config.json
  └── phases/
```

**Key points:**
- Original `.planning/` is never modified or deleted
- VBW agents reference `gsd-archive/` for historical context
- You can continue using GSD commands (they read `.planning/`)
- GSD isolation (optional) prevents GSD agents from touching `.vbw-planning/`

---

## Version Control

**Recommendation:** Add `.vbw-planning/gsd-archive/` to `.gitignore`

**Rationale:**
- The archive is a point-in-time snapshot for local agent reference
- Original `.planning/` is likely already in version control
- Committing the archive duplicates history and bloats the repo

**Alternative:** Keep INDEX.json in version control, gitignore the rest

Add to `.gitignore`:
```
.vbw-planning/gsd-archive/*
!.vbw-planning/gsd-archive/INDEX.json
```

This preserves the lightweight index (useful for team context) while excluding the full archive copy.

**Team scenario:** If teammates need the GSD context, they can:
1. Manually copy `.planning/` to `.vbw-planning/gsd-archive/`
2. Run `bash scripts/generate-gsd-index.sh`
3. Or just reference the original `.planning/` directory if it's in the repo

---

## INDEX.json Format

The index provides fast lookups without scanning the full archive:

```json
{
  "imported_at": "2026-02-12T14:30:00Z",
  "gsd_version": "1.2.3",
  "phases_total": 4,
  "phases_complete": 2,
  "milestones": ["MVP", "Beta", "GA"],
  "quick_paths": {
    "roadmap": "gsd-archive/ROADMAP.md",
    "project": "gsd-archive/PROJECT.md",
    "phases": "gsd-archive/phases/",
    "config": "gsd-archive/config.json"
  },
  "phases": [
    {
      "num": 1,
      "slug": "foundation",
      "plans": 3,
      "status": "complete"
    },
    {
      "num": 2,
      "slug": "features",
      "plans": 2,
      "status": "in_progress"
    }
  ]
}
```

**Field descriptions:**
- `imported_at`: UTC timestamp when import ran
- `gsd_version`: From `.planning/config.json` (or "unknown")
- `phases_total`: Total phase directories found
- `phases_complete`: Phases with all plans having SUMMARY files
- `milestones`: Extracted from ROADMAP.md h2 headers
- `quick_paths`: Relative paths to key archive files
- `phases`: Array of phase metadata (num, slug, plan count, status)

**Performance**: Generation completes in <5 seconds (scans metadata only, not file contents)

---

## Using GSD Context in VBW

VBW agents can reference archived GSD files when needed:

### Example: Referring to Past Work

When planning a new feature that builds on GSD work:
- Lead agent reads `.vbw-planning/gsd-archive/INDEX.json` to find relevant phases
- Uses `quick_paths.phases` to locate specific phase directories
- References archived PLAN or SUMMARY files for context

### Example: Avoiding Duplication

When researching existing patterns:
- Scout agent scans INDEX.json to see what was already built
- Reads archived summaries to understand prior decisions
- Incorporates learnings into new VBW plans

**Note**: The archive is read-only for VBW agents. Use it as reference, not as active planning state.

---

## GSD Isolation (Optional)

If you want to prevent GSD commands/agents from accessing VBW files:

**During /vbw:init Step 1.7:**
- VBW detects GSD (via global commands, `.planning/`, or `gsd-archive/`)
- Prompts: "Enable plugin isolation?"
- If approved:
  - Creates `.vbw-planning/.gsd-isolation` flag
  - Plugin Isolation instructions are embedded in the root `CLAUDE.md` by `scripts/bootstrap/bootstrap-claude.sh`
  - PreToolUse hooks block cross-plugin file access

**Effect:**
- GSD agents CANNOT read/write `.vbw-planning/`
- VBW agents CANNOT read/write `.planning/`
- Prevents accidental cross-contamination

**When to use:**
- You're actively using both plugins in the same project
- You want strict separation between planning systems
- You're migrating incrementally and need safety rails

**When to skip:**
- You're fully migrating to VBW (no more GSD usage)
- You want maximum flexibility for agents to cross-reference

---

## Migration Strategies

### Full Migration (Recommended)

1. Run `/vbw:init` and approve GSD import
2. Review archived GSD work via INDEX.json
3. Define new VBW project goals with `/vbw:vibe`
4. Reference GSD archive as needed during planning
5. Decommission `.planning/` when comfortable

**Pros:** Clean break, VBW-native workflow
**Cons:** Learning curve for VBW patterns

### Incremental Migration

1. Run `/vbw:init` and approve GSD import
2. Enable GSD isolation
3. Use GSD for existing milestones
4. Use VBW for new milestones
5. Gradually shift to VBW-only

**Pros:** Lower risk, gradual transition
**Cons:** Complexity of managing two systems

### Archive-Only (No Migration)

1. Run `/vbw:init` and approve GSD import
2. Use VBW for new work only
3. Keep GSD archive as historical reference
4. Never delete `.planning/`

**Pros:** Zero migration work
**Cons:** GSD context isolated from VBW planning

---

## Troubleshooting

### Import didn't run during init

- **Cause**: `.planning/` directory wasn't detected or you declined the prompt
- **Fix**: Manually copy `.planning/` to `.vbw-planning/gsd-archive/` and run `bash scripts/generate-gsd-index.sh`

### INDEX.json is missing fields

- **Cause**: GSD project had non-standard structure (missing config.json, ROADMAP.md, etc.)
- **Fix**: Check `generate-gsd-index.sh` for graceful fallbacks (should output "unknown" or empty arrays)

### Agents aren't referencing GSD archive

- **Cause**: Agents don't know about the archive or INDEX.json
- **Fix**: Explicitly prompt agents: "Check .vbw-planning/gsd-archive/INDEX.json for prior work on this topic"

### GSD isolation blocking legitimate access

- **Cause**: PreToolUse hook is rejecting cross-plugin reads
- **Fix**: Delete `.vbw-planning/.gsd-isolation` to disable isolation

---

## FAQ

**Q: Is the original `.planning/` directory deleted?**
No. VBW copies (not moves) to `gsd-archive/`. Your original GSD files remain untouched.

**Q: Can I still use GSD commands after import?**
Yes. GSD reads from `.planning/`, which is preserved. Enable isolation if you want strict separation.

**Q: What if I decline import during init?**
VBW continues with normal initialization. You can manually import later by copying `.planning/` and running the index script.

**Q: How do VBW agents use the INDEX.json?**
Agents read it for quick lookups (e.g., "What phases were completed in GSD?") without scanning the full archive.

**Q: Can I import multiple GSD projects?**
Not currently. One `.planning/` import per VBW project. Multi-project import is out of scope.

**Q: Does import work without jq?**
No. The index generation script requires jq (VBW's zero-dependency principle: jq is the ONLY external dep).

---

## Next Steps

- Run `/vbw:help` to see all VBW commands
- Run `/vbw:vibe` to define your project and start planning
- Reference `gsd-archive/INDEX.json` during planning to build on prior work

---

**Feedback?** Open an issue if this guide is missing something you need.
