# BMAD + Beads Integration Sub-module

This sub-module adds Beads runtime coordination to BMAD workflows.

## What This Provides

| Feature | Description |
|---------|-------------|
| Work Claiming | Prevent concurrent story edits with `bd-claim` |
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
./src/modules/bmm/sub-modules/beads/install.sh

# Or manually:
bd init
bd hooks install
source ~/.bmad/beads-aliases.sh
```

## Quick Reference

```bash
# Session start
bd-status              # See ready work + blockers
bd-claim "story-key"   # Claim before starting

# During work
bd-decision "title"    # Runtime decision
bd-blocker "title"     # External blocker
bd-halt "reason"       # Critical failure (P0)

# Session end
bd-release <id>        # Release claim
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
