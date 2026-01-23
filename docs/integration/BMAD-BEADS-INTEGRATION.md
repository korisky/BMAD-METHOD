---
title: "BMAD + Beads Integration (v5 - Efficient)"
description: "BMAD owns formal outputs. Beads owns runtime state. Minimal overhead."
---

## Design Principles

1. **Use native Beads commands** - `bd ready`, `bd q` instead of verbose alternatives
2. **Shell aliases** - One-word commands for common operations
3. **Automatic hooks** - `bd hooks install` for seamless git sync
4. **No duplication** - Clear split between systems

---

## The Split

```
BMAD (Formal Outputs):              Beads (Runtime & Coordination):
├── Documents                       ├── Work claims
├── sprint-status.yaml              ├── Runtime decisions
├── workflow-status.yaml            ├── Blockers
├── ADRs (architecture.md)          ├── HALT conditions (P0)
├── Code review findings            ├── Cross-story deps
└── Retrospective docs              └── Action items
```

---

## Shell Aliases (Add to ~/.bashrc or ~/.zshrc)

```bash
# Quick operations
alias bd-next='bd ready --pretty --limit 10'
alias bd-halt='bd create --type blocker --priority 0 --title'
alias bd-decision='bd create --type decision --priority 2 --title'
alias bd-blocker='bd create --type blocker --priority 1 --title'

# Work claiming (one command)
bd-claim() {
  local story="$1"
  local id=$(bd q "Working: $story" --type task --priority 1 --silent)
  bd update $id --status in_progress --notes "AGENT: $(whoami) | STARTED: $(date -Iseconds)"
  echo "Claimed: $id"
}

# Release claim
bd-release() {
  local id="$1"
  bd close $id --reason "Done"
}

# Check what's happening
alias bd-status='bd ready --pretty && echo "---" && bd list --type blocker --status open'
```

---

## Session Start (Simplified)

```bash
# 1. Beads auto-primes (hook)

# 2. See everything at once
bd-status
# Shows: ready work + active blockers

# 3. If picking a story, claim it
bd-claim "1-2-user-auth"

# 4. Read BMAD files as needed
# sprint-status.yaml, story file, etc.
```

**One command (`bd-status`) replaces 4 manual checks.**

---

## Work Claiming (Efficient)

**Before:**
```bash
bd create --title "Working: Story 1-2" --type task --priority 1
bd update <id> --status in_progress
bd update <id> --notes "AGENT: claude | STARTED: 2025-01-13"
```

**After:**
```bash
bd-claim "Story 1-2"  # One command, done
```

---

## Recording Events

### HALT Condition
```bash
bd-halt "3 consecutive test failures in Story 1-2"
bd update <id> --notes "STORY: 1-2 | WORKFLOW: dev-story | LAST_ERROR: TypeError"
```

### Runtime Decision
```bash
bd-decision "Use Redis for session storage"
bd update <id> --notes "WHO: architect | WHY: Scale requirements | DOC: architecture.md"
```

### Blocker
```bash
bd-blocker "Waiting on API credentials from DevOps"
bd update <id> --notes "AFFECTS: Story 1-3 | OWNER: devops | ETA: unknown"
```

---

## Session End (Simple Workflow)

```bash
# 1. Release any claims
bd-release <claim-id>

# 2. Check if ready to push
bd-preflight

# 3. If ❌ Not ready: sync branches first
bd-land
bd-preflight  # verify again

# 4. If ✅ Ready: push
git push
```

**Key Commands:**
- `bd-preflight` - Check if ready to push (always run this)
- `bd-land` - Sync branches (beads-sync → main → current)
- `bd-fix` - Auto-fix common issues

---

## Priority Scale

| Priority | Use For | Alias |
|----------|---------|-------|
| 0 | HALT, critical | `bd-halt` |
| 1 | Claims, urgent blockers | `bd-blocker` |
| 2 | Decisions, actions | `bd-decision` |
| 3-4 | Low/backlog | manual |

---

## What to Track Where

### BMAD Only
- Story status (sprint-status.yaml)
- Phase progress (workflow-status.yaml)
- ADRs (architecture.md)
- Task checkboxes (story files)
- Review findings (story files)

### Beads Only
- Work claims (coordination)
- Runtime decisions (outside workflows)
- Blockers (external)
- HALTs (priority 0)
- Cross-story deps
- Action items

---

## Installation Integration

### Option 1: Sub-module (Recommended)

Add to BMAD installer as optional sub-module:

```
src/modules/bmm/sub-modules/beads/
├── config.yaml
├── injections.yaml
├── install.sh          # Runs: bd init && bd hooks install
└── aliases.sh          # Shell aliases to source
```

**User flow:**
1. Run `npx bmad-method install`
2. Select "Enable Beads integration"
3. Installer runs `bd init` and `bd hooks install`
4. Aliases added to shell config
5. Injections add critical_actions to agents

### Option 2: Manual Setup

```bash
# In project root
bd init
bd hooks install

# Add to shell
source /path/to/bmad/beads/aliases.sh

# Or add aliases manually to ~/.bashrc
```

---

## Agent Critical Actions (Injected)

Add to all agents via `injections.yaml`:

```yaml
# Session start
- "Run `bd-status` to see ready work and blockers"
- "Run `bd-claim {story}` before starting work"

# During work
- "Runtime decisions: `bd-decision {title}`"
- "Blockers: `bd-blocker {title}`"
- "HALT conditions: `bd-halt {title}` immediately"

# Session end
- "Release claim: `bd-release {id}`"
- "Git commit triggers auto-sync via hooks"
- "Push before saying done"
```

---

## Trigger Phrases

| Say | Alias/Command |
|-----|---------------|
| "what's ready?" | `bd-next` |
| "status" | `bd-status` |
| "claim story X" | `bd-claim "X"` |
| "release claim" | `bd-release <id>` |
| "HALT" | `bd-halt "reason"` |
| "that's a decision" | `bd-decision "title"` |
| "that's a blocker" | `bd-blocker "title"` |

---

## Quick Reference Card

```
SESSION START:
  bd-status              # See ready work + blockers
  bd-claim "story"       # Claim before starting

DURING WORK:
  (commit normally - hooks auto-sync beads)
  bd-halt "..."          # Critical failure (P0)
  bd-blocker "..."       # External blocker
  bd-decision "..."      # Runtime decision

SESSION END:
  bd-release <id>        # Release claim
  bd-preflight           # Check if ready to push
  (if ❌) bd-land        # Sync branches
  (if ✅) git push       # Done!

TROUBLESHOOTING:
  bd-fix                 # Auto-fix common issues
  bd-help                # Show all commands
```

---

## Why This is More Efficient

| Before (v4) | After (v5) | Improvement |
|-------------|------------|-------------|
| 4 manual `bd list` checks | `bd-status` (1 command) | 75% fewer commands |
| 3 commands to claim | `bd-claim` (1 alias) | 66% fewer commands |
| Manual `bd sync` | Git hooks auto-sync | Zero manual sync |
| Long command strings | Short aliases | Faster typing |
| Check then cross-reference | `bd ready` does it | Built-in intelligence |

---

## Recent Review (2026-01-22)

A comprehensive review of the current integration identified critical gaps that need addressing for production team use. 

**Key Findings**:
- Git workflow implementation gap (three-way sync documented but not enforced)
- Missing validation and error handling in installer
- Clarity gaps in agent instructions
- No recovery commands for common failure scenarios

**See full review**: [BMAD-BEADS-INTEGRATION-REVIEW.md](./BMAD-BEADS-INTEGRATION-REVIEW.md) for detailed analysis and prioritized recommendations.

---

`bd help` | `bd-status` | `bd-next`
