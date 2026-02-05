---
title: "Integration Design Decisions (v5 - Final)"
description: "Complete rationale for BMAD + Beads integration"
---

## Design Evolution

| Version | Key Change |
|---------|------------|
| v1 | Initial split: BMAD docs, Beads tracking |
| v2 | Removed story-level Beads (use sprint-status) |
| v3 | Removed phase/ADR duplication |
| v4 | Added work claiming, HALT tracking |
| v5 | Shell aliases for efficiency |

---

## Issues Resolved

| Issue | Solution | Efficiency |
|-------|----------|------------|
| Concurrent edits | Work claiming | `bd_claim` (1 cmd) |
| Blocker visibility | Check first | `bd_status` (1 cmd) |
| HALT lost on clear | Priority 0 blockers | `bd_halt` (1 cmd) |
| Verbose commands | Shell aliases | 75% fewer keystrokes |
| Manual sync | Git hooks | Zero manual sync |

---

## What Each System Owns

### BMAD (Don't Duplicate in Beads)

| Item | Location | Reason |
|------|----------|--------|
| Phase progress | workflow-status.yaml | BMAD workflow manages |
| Story status | sprint-status.yaml | BMAD workflow manages |
| ADRs | architecture.md | Formal decisions |
| Task checkboxes | story files | Implementation detail |
| Review findings | story files | Tied to code |

### Beads (Don't Duplicate in BMAD)

| Item | Type | Priority | Reason |
|------|------|----------|--------|
| Work claims | task | 1 | Prevent conflicts |
| Runtime decisions | decision | 2 | Outside workflows |
| External blockers | blocker | 1 | BMAD can't track |
| HALTs | blocker | 0 | Must persist |
| Action items | task | 2 | Cross-epic visibility |

---

## Efficiency Improvements

### Before (v4)
```bash
# Session start: 4 commands
bd list --type blocker --priority 0
bd list --type blocker --status open
bd list --type task --status in_progress
# Read sprint-status.yaml

# Claim: 3 commands
bd create --title "Working: Story X" --type task --priority 1
bd update <id> --status in_progress
bd update <id> --notes "..."
```

### After (v5)
```bash
# Session start: 1 command
bd_status

# Claim: 1 command
bd_claim "Story X"
```

**Result**: 75% fewer commands, same functionality.

---

## Shell Aliases

| Alias | Replaces |
|-------|----------|
| `bd_status` | 2 `bd list` commands |
| `bd_claim X` | 3 `bd` commands |
| `bd_halt X` | `bd create --type blocker --priority 0 --title X` |
| `bd_decision X` | `bd create --type decision --priority 2 --title X` |
| `bd_blocker X` | `bd create --type blocker --priority 1 --title X` |

---

## Installation Integration

### Sub-module Structure

```
src/modules/bmm/sub-modules/beads/
├── config.yaml        # Sub-module metadata
├── injections.yaml    # Agent critical_actions injection
├── beads-aliases.sh   # Shell aliases
├── install.sh         # Setup script
└── README.md
```

### Installation Flow

1. User runs `npx bmad-method install`
2. Selects "Enable Beads integration"
3. Installer runs `install.sh`:
   - Checks for `bd` CLI
   - Runs `bd init`
   - Runs `bd hooks install`
   - Installs aliases to `~/.bmad/`
   - Adds source line to shell RC
4. Injections add Beads instructions to agents

---

## Success Criteria

| Criterion | How Verified |
|-----------|--------------|
| No concurrent edits | `bd_claim` before work |
| Blockers visible | `bd_status` shows all |
| HALT persists | Priority 0, survives clear |
| Decisions discoverable | `bd_decisions` lists all |
| Minimal overhead | 1-2 commands per operation |
| No manual sync | Git hooks handle it |

---

## Why This Design Works

1. **Clear ownership** - Each system handles distinct concerns
2. **No duplication** - No sync needed because no overlap
3. **Efficient commands** - Aliases reduce friction
4. **Automatic sync** - Git hooks eliminate manual step
5. **Persistent memory** - Beads survives context clear
6. **Coordination** - Work claims prevent conflicts
