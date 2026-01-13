# BMAD + Beads Agent Instructions

> This file provides optional Beads integration for BMAD workflows.
> **Beads is optional.** BMAD works perfectly without it.

---

## What is Beads?

Beads adds runtime coordination and persistent memory to BMAD:
- **Work claims** - Prevent concurrent story edits
- **Runtime decisions** - Capture choices made outside workflows
- **Blockers** - Track external impediments
- **Context persistence** - Survives `/clear` and session boundaries

**Without Beads**: BMAD works normally using sprint-status.yaml and workflow-status.yaml.

**With Beads**: You get additional coordination and memory features.

---

## Setup (Optional)

If you want Beads integration:

```bash
# 1. Install Beads CLI
# See: https://github.com/steveyegge/beads

# 2. Initialize in your project
bd init
bd hooks install

# 3. Load helper aliases (optional but recommended)
source ./src/modules/bmm/sub-modules/beads/beads-aliases.sh
```

If Beads is not installed, simply ignore the `bd-*` commands below.

---

## The Split (When Using Beads)

```
BMAD (always):                      Beads (if installed):
├── Documents                       ├── Work claims (bd-claim)
├── sprint-status.yaml              ├── Runtime decisions (bd-decision)
├── workflow-status.yaml            ├── Blockers (bd-blocker)
├── ADRs (architecture.md)          ├── HALTs (bd-halt)
└── Task checkboxes                 └── Action items (bd-action)
```

**Rule**: Don't duplicate. BMAD handles formal outputs. Beads handles runtime state.

---

## Quick Reference (If Beads Installed)

### Session Start
```bash
bd-status              # See ready work + blockers
bd-claim "story-key"   # Claim before starting
```

### During Work
```bash
bd-decision "title"    # Runtime decision (outside workflow)
bd-blocker "title"     # External blocker
bd-halt "reason"       # Critical failure (P0)
```

### Session End
```bash
bd-release <id>        # Release claim
git commit && push     # Hooks auto-sync Beads
```

---

## Key Commands

| Command | What It Does |
|---------|--------------|
| `bd-status` | Ready work + blockers |
| `bd-claim X` | Claim a story |
| `bd-release X` | Release a claim |
| `bd-decision X` | Create decision |
| `bd-blocker X` | Create blocker |
| `bd-halt X` | Create HALT (P0) |
| `bd-help` | Show all commands |

---

## When to Use Beads (If Installed)

### Use Beads For:
- **Work claims** - Before starting a story, claim it
- **Runtime decisions** - Choices made OUTSIDE formal workflows
- **External blockers** - Waiting on APIs, approvals, etc.
- **HALTs** - Critical failures that must persist
- **Cross-story dependencies** - Story B needs Story A first

### Don't Use Beads For (Use BMAD Instead):
- Story status → `sprint-status.yaml`
- Phase progress → `workflow-status.yaml`
- ADRs → `architecture.md`
- Task checkboxes → Story files

---

## If Beads is NOT Installed

If you see errors like `bd: command not found`:
1. You can ignore Beads commands and use BMAD normally
2. Or install Beads: https://github.com/steveyegge/beads

BMAD's core functionality works perfectly without Beads.

---

## Landing the Plane (Session End)

**With Beads:**
```bash
bd-release <claim-id>   # Release work claim
bd sync                 # Sync Beads (or let hooks do it)
git add -A && git commit -m "message"
git push
```

**Without Beads:**
```bash
git add -A && git commit -m "message"
git push
```

---

`bd-help` | `bd-status` | BMAD workflows work without Beads
