# BMAD + Beads Integration Sub-module

This sub-module adds Beads runtime coordination to BMAD workflows (v6.2.0 skills architecture).

## What This Provides

| Feature | Description |
|---------|-------------|
| Work Claiming | Prevent concurrent story edits with `bd_claim` |
| Runtime Decisions | Capture decisions outside workflows |
| Blocker Tracking | Track external impediments |
| HALT Persistence | HALT conditions survive context clear |
| Action Items | Cross-epic action item tracking |
| Auto Sync | Git hooks for automatic Beads sync |
| Sprint Status | `bd_session_start` shows sprint-status.yaml summary |

## Installation

### Automatic (via BMAD installer)

During `npx bmad-beads-method install`, select "Enable Beads integration".

### Manual

```bash
# From project root
bash ./src/bmm-skills/sub-modules/beads/install.sh
```

This installs:

- Project-local aliases at `.beads/lib/bmad-aliases.sh`
- Git hooks (pre-push, post-commit) for auto-sync
- Documentation to `docs/`

**For shell usage:**

```bash
# Source manually when needed
source .beads/lib/bmad-aliases.sh
```

Aliases work automatically in git hooks without sourcing.

> **Two command families.** Native Beads CLI uses a space: `bd list`, `bd ready`, `bd doctor`,
> `bd help`. BMAD adds its own shortcuts with an underscore: `bd_land`, `bd_claim`, `bd_health`.
> A `bd_` command is provided by this installer (source `.beads/lib/bmad-aliases.sh` to load).
> For native Beads help run `bd help`; for BMAD integration see `docs/beads-reference.md`.

## Updating Existing Installations

Re-run the installer (idempotent, safe):

```bash
bash /path/to/bmad-repo/src/bmm-skills/sub-modules/beads/install.sh
```

**What gets updated:** aliases, hooks, AGENTS.md managed block, documentation.

**What gets preserved:** your custom notes in AGENTS.md, Beads database, git history, config.

## Quick Reference

```bash
# Session start
bd_session_start         # Check HALTs, ready work, sprint status
bd_claim "story-key"     # Claim before starting

# During work
bd_halt "reason"         # Critical failure (P0)
bd_decision "title"      # Runtime decision
bd_blocker "title"       # External blocker
bd_sync_story <file>     # Sync AI-Review items to Beads

# Session end
# Use bmad-beads-handover skill, or manually:
bd_release <id>          # Release claim
bd_land                  # Sync branches
bd_preflight             # Check push readiness
git push                 # Push when all green
```

## Documentation

Full integration docs: [docs/beads-reference.md](beads-reference.md) (installed to target project's `docs/`)
