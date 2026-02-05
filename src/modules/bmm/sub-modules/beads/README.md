# BMAD + Beads Integration Sub-module

This sub-module adds Beads runtime coordination to BMAD workflows.

## What This Provides

| Feature | Description |
|---------|-------------|
| Work Claiming | Prevent concurrent story edits with `bd_claim` |
| Runtime Decisions | Capture decisions outside workflows |
| Blocker Tracking | Track external impediments |
| HALT Persistence | HALT conditions survive context clear |
| Action Items | Cross-epic action item tracking |
| Auto Sync | Git hooks for automatic Beads sync |

## Installation

### Automatic (via BMAD installer)

During `npx bmad-method install`, select "Enable Beads integration".

### Manual

```bash
# From project root
bash ./src/modules/bmm/sub-modules/beads/install.sh
```

This installs:
- ✅ Project-local aliases at `.beads/lib/bmad-aliases.sh`
- ✅ Git hooks (pre-push, post-commit) for auto-sync
- ✅ Documentation to `docs/`

**For shell usage:**
```bash
# Source manually when needed
source .beads/lib/bmad-aliases.sh
```

Aliases work automatically in git hooks without sourcing.

> **Two command families.** Native Beads CLI uses a space: `bd list`, `bd ready`, `bd doctor`,
> `bd help`. BMAD adds its own shortcuts with an underscore: `bd_land`, `bd_claim`, `bd_health`.
> A `bd_` command is provided by this installer (source `.beads/lib/bmad-aliases.sh` to load).
> For native Beads help run `bd help`; for BMAD integration help run `bd_help`.

## Quick Reference

```bash
# Session start
bd_status              # See ready work + blockers
bd_claim "story-key"   # Claim before starting

# During work
bd_decision "title"    # Runtime decision
bd_blocker "title"     # External blocker
bd_halt "reason"       # Critical failure (P0)

# Session end
bd_release <id>        # Release claim
git commit && push     # Hooks sync Beads
```

## What to Track Where

### BMAD (Don't put in Beads)
- Story status → sprint-status.yaml
- Phase progress → workflow-status.yaml
- ADRs → architecture.md
- Task checkboxes → story files

### Beads (Don't put in BMAD)
- Work claims
- Runtime decisions
- Blockers
- HALTs
- Action items

## Documentation

Full integration docs: [docs/integration/BMAD-BEADS-INTEGRATION.md](../../../../docs/integration/BMAD-BEADS-INTEGRATION.md)
