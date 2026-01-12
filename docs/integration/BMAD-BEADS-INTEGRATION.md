# BMAD + Beads Integration (v3 - Corrected)

> **Principle**: No overlap. No sync. Each system owns distinct concerns.

---

## The Design

```
BMAD owns:
├── Documents (PRD, Architecture, Stories)
├── Story status (sprint-status.yaml)
├── Phase progress (bmm-workflow-status.yaml)
└── ADRs (in architecture.md)

Beads owns:
├── Runtime decisions (made outside formal workflows)
├── Blockers (external impediments)
└── Cross-story dependencies (A must complete before B)
```

**Key insight**: BMAD already tracks phases (workflow-status) and architectural decisions (ADRs). Beads should NOT duplicate these. Beads captures what happens OUTSIDE of BMAD workflows.

---

## What Each System Owns (No Overlap)

### BMAD Owns - Don't Put in Beads

| Concern | Location | Tracked By |
|---------|----------|------------|
| Requirements | `prd.md` | PM workflow |
| Architecture | `architecture.md` | Architect workflow |
| **ADRs** | `architecture.md` | step-04-decisions |
| Work breakdown | `epics.md` | PM workflow |
| Story status | `sprint-status.yaml` | SM + DEV workflows |
| **Phase progress** | `bmm-workflow-status.yaml` | workflow-status service |
| Task progress | Story file `[x]` marks | DEV workflow |

### Beads Owns - Don't Put in BMAD

| Concern | Issue Type | When to Create |
|---------|------------|----------------|
| **Runtime decisions** | `decision` | Choices made OUTSIDE formal workflows |
| **Blockers** | `blocker` | External impediments stopping work |
| **Cross-story deps** | `bd dep add` | When story A needs story B first |

---

## What IS a "Runtime Decision"?

**Create a Beads decision when** the decision is made OUTSIDE a BMAD workflow:

| Scenario | Beads? | Why |
|----------|--------|-----|
| Architect chooses GraphQL over REST | **No** | Captured in ADR during architecture workflow |
| DEV discovers auth needs refactoring mid-story | **Yes** | Not in any BMAD artifact, affects other work |
| PM reduces scope during implementation | **Yes** | Scope change after PRD was finalized |
| SM decides to defer story to next sprint | **Yes** | Runtime priority change |
| Team agrees to skip a story | **Yes** | Runtime scope change |

**The rule**: If it's captured in a BMAD workflow output (PRD, Architecture, Stories, sprint-status), don't duplicate in Beads. If it happens between workflows or changes something already decided, capture in Beads.

---

## What IS a "Blocker"?

External impediments that stop work - things BMAD workflows don't track:

```bash
bd create --title "Blocked: Waiting on API credentials" --type blocker
bd update <id> --notes "AFFECTS: Story 1-2 | OWNER: DevOps | ETA: unknown"
```

Examples:
- Waiting on external service/API
- Need approval from stakeholder
- Dependent system is down
- Missing test data
- License/legal review pending

---

## What IS a "Cross-Story Dependency"?

When one story must complete before another can start (BMAD doesn't track this):

```bash
# Story 1-3 can't start until Story 1-2 is done
bd create --title "Dep: Story 1-3 needs API from 1-2" --type blocker
bd update <id> --notes "BLOCKED: 1-3 | NEEDS: 1-2 API endpoint | DOC: stories/1-2-api.md"
```

Or if using Beads dependency graph:
```bash
bd dep add <story-1-3-id> <story-1-2-id>
```

---

## Session Protocols

### Session Start

```bash
# 1. Beads auto-primes (hook)

# 2. Check for runtime decisions and blockers
bd list --type decision --status open    # Any pending decisions?
bd list --type blocker --status open     # Any blockers?

# 3. Find work from BMAD (not Beads!)
# Read sprint-status.yaml for story status
# Read bmm-workflow-status.yaml for phase progress
# Load the appropriate story file
```

### During Work

```bash
# Follow BMAD workflows normally
# BMAD workflows capture their own outputs (PRD, ADRs, Stories)

# ONLY use Beads when something happens OUTSIDE the workflow:
bd create --type decision  # Runtime decision
bd create --type blocker   # External impediment
```

### Session End ("Land the Plane")

```bash
# 1. BMAD status updates (if any)
# - sprint-status.yaml for story changes
# - bmm-workflow-status.yaml updated by workflows automatically

# 2. Beads sync
bd sync

# 3. Commit and push
git add -A
git commit -m "{message}"
git push

# 4. Verify
git status    # Must show "up to date"
```

---

## Human Trigger Phrases

| Say | Action |
|-----|--------|
| "what runtime decisions?" | `bd list --type decision` |
| "what's blocked?" | `bd list --type blocker` |
| "file that as a runtime decision" | `bd create --type decision` |
| "that's a blocker" | `bd create --type blocker` |
| "land the plane" | Session close protocol |

---

## What NOT to Do (Avoid Duplication)

| Don't Do This | Why | Do This Instead |
|---------------|-----|-----------------|
| Create "Phase: PRD Complete" epic | BMAD workflow-status.yaml tracks this | Just run the workflow |
| Create decision for every ADR | ADRs live in architecture.md | Only capture runtime decisions |
| Create issues for stories | sprint-status.yaml tracks stories | Use BMAD |
| Create issues for tasks | Story file checkboxes track tasks | Use BMAD |

---

## Why This is 1+1 > 2

### BMAD Provides
- Rich document generation (PRD, Architecture, Stories)
- Guided workflows with quality gates
- Phase tracking (workflow-status.yaml)
- Story status (sprint-status.yaml)
- ADRs (architecture.md)

### Beads Adds (Things BMAD Can't Do)
- **Runtime decision memory**: Decisions made outside workflows, survives /clear
- **Blocker tracking**: External impediments
- **Cross-story dependencies**: Explicit "A needs B first"

### Combined Value
- Formal decisions → BMAD ADRs (architecture.md)
- Runtime decisions → Beads (discoverable, persistent)
- Phase progress → BMAD workflow-status (automatic)
- Blockers → Beads (visible, actionable)

---

## Context Recovery (After /clear)

```bash
# 1. Beads context auto-loads

# 2. Check runtime state
bd list --type decision     # What was decided outside workflows?
bd list --type blocker      # What's blocked?

# 3. Check BMAD state
# Read bmm-workflow-status.yaml (what phase are we in?)
# Read sprint-status.yaml (what story is active?)
# Read relevant story file

# 4. DOC: pointers in Beads notes help find BMAD docs
bd show <id>   # Notes field has DOC: path
```

---

## Quick Reference

```
Use BMAD for:
✓ Creating/editing documents (PRD, Architecture, Stories)
✓ Tracking story status (sprint-status.yaml)
✓ Tracking phase progress (workflow-status.yaml)
✓ Recording ADRs (architecture.md)
✓ Task checkboxes in story files

Use Beads for:
✓ Runtime decisions (made outside workflows)
✓ Blockers (external impediments)
✓ Cross-story dependencies
✓ Context that must survive /clear
```

---

`bd help` | `bd quickstart` | `bd doctor`
