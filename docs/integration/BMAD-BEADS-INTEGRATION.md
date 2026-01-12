# BMAD + Beads Integration (Simplified)

> **Version**: 2.0.0
> **Principle**: No overlap. No sync. Maximum value from each.

---

## The Design

```
BMAD = Documents + Story Status
Beads = Decisions + Dependencies + Blockers
```

**That's it.** Each system does what it's best at. No duplication.

---

## What Each System Owns

### BMAD Owns (Don't Put in Beads)

| Asset | Location | Purpose |
|-------|----------|---------|
| Requirements | `prd.md` | What to build |
| Architecture | `architecture.md` | How to build |
| Work breakdown | `epics.md` | Stories and scope |
| Story status | `sprint-status.yaml` | Which story is ready/in-progress/done |
| Story details | `{story}.md` | Tasks, AC, implementation spec |
| Task progress | Story file checkboxes | `[x]` marks in story |

### Beads Owns (Don't Put in BMAD)

| Asset | Issue Type | Purpose |
|-------|------------|---------|
| Decisions | `decision` | Cross-agent memory that survives /clear |
| Blockers | `blocker` | Impediments stopping work |
| Dependencies | `bd dep add` | Story A needs Story B first |
| Phase gates | `epic` | "PRD complete", "Architecture done" |

---

## The Rules (Simple)

### Rule 1: Story status lives in sprint-status.yaml ONLY

```yaml
# sprint-status.yaml (BMAD manages this)
development_status:
  epic-1: in-progress
  1-1-user-auth: done
  1-2-account-mgmt: in-progress  # DEV working on this
  1-3-profile-page: ready-for-dev  # Ready to pick up
```

**Don't create Beads issues for individual stories.** Sprint-status.yaml handles this perfectly.

### Rule 2: Decisions always go to Beads

When ANY agent makes a choice that affects other agents:

```bash
bd create --title "Decision: {summary}" --type decision --priority 2
bd update <id> --notes "WHO: {agent} | WHAT: {choice} | WHY: {rationale}"
```

**Examples of decisions:**
- PM: "Removing feature X from scope"
- Architect: "Using GraphQL instead of REST"
- DEV: "Need to refactor auth before this story"
- SM: "Deferring epic 3 to next sprint"

### Rule 3: Dependencies go to Beads

When story A must complete before story B:

```bash
bd create --title "Dep: Story 1-3 needs 1-2" --type blocker
bd update <id> --notes "STORY: 1-3 | BLOCKED_BY: 1-2 | REASON: API endpoint"
```

**Or track at phase level:**
```bash
bd create --title "Phase: Architecture" --type epic
bd create --title "Phase: Implementation" --type epic
bd dep add <impl_id> <arch_id>  # Implementation blocked until Architecture done
```

### Rule 4: Blockers go to Beads

External impediments that stop work:

```bash
bd create --title "Blocked: Waiting on API credentials" --type blocker --priority 1
bd update <id> --notes "AFFECTS: Story 1-2 | OWNER: DevOps | ETA: unknown"
```

### Rule 5: Doc pointers in Beads notes

Every Beads issue should reference its BMAD doc:

```bash
bd update <id> --notes "DOC: docs/architecture.md | SECTION: API Design"
```

This enables context recovery after /clear.

---

## Session Protocols

### Session Start

```bash
# 1. Get Beads context
bd prime                         # Auto-loads on session start with hooks

# 2. Check decisions and blockers
bd list --type decision          # What decisions exist?
bd list --type blocker           # What's blocked?

# 3. Find what to work on (from BMAD)
cat {implementation}/sprint-status.yaml  # Or load via agent workflow
# Find first "ready-for-dev" story

# 4. Load BMAD docs
# Read project-context.md, relevant story file
```

### During Work

```bash
# Follow BMAD workflows normally
# When making a decision that affects other agents:
bd create --title "Decision: {short}" --type decision
bd update <id> --notes "WHO: {me} | WHAT: {choice} | WHY: {reason}"

# When discovering a blocker:
bd create --title "Blocked: {issue}" --type blocker
```

### Session End ("Land the Plane")

```bash
# 1. Update BMAD status
# Edit sprint-status.yaml if story status changed

# 2. Capture any pending decisions
bd list --status in_progress    # Check if anything needs closing

# 3. Sync and commit
bd sync
git add -A
git commit -m "{message}"
git push

# 4. Verify
git status                      # Must show "up to date"

# 5. Handoff
bd list --type decision --status open   # Decisions for next session
bd list --type blocker --status open    # Blockers to address
```

---

## What Happens at Phase Boundaries

### PRD Complete (PM)

```bash
bd create --title "Phase: PRD Complete" --type epic
bd update <id> --notes "DOC: docs/prd.md | FRs: {n} | NFRs: {n}"
```

### Architecture Complete (Architect)

```bash
bd create --title "Phase: Architecture Complete" --type epic
bd update <id> --notes "DOC: docs/architecture.md | ADRs: {n}"

# For each major ADR:
bd create --title "ADR: {title}" --type decision
bd update <id> --notes "OPTIONS: {a,b,c} | CHOSEN: {x} | WHY: {reason}"
```

### Sprint Planning Complete (SM)

```bash
bd create --title "Phase: Sprint {n} Planned" --type epic
bd update <id> --notes "DOC: sprint-status.yaml | STORIES: {n}"
```

### Story Complete (DEV)

```bash
# Update sprint-status.yaml (BMAD)
# If made implementation decisions:
bd create --title "Impl: {choice}" --type decision
bd update <id> --notes "STORY: {key} | CHOICE: {what} | WHY: {reason}"
```

---

## Context Recovery (After /clear)

```bash
# 1. Beads context auto-loads (bd prime)

# 2. Find decisions
bd list --type decision
bd show <id>                    # Read notes for DOC: path

# 3. Find blockers
bd list --type blocker

# 4. Read BMAD docs
# From decision/blocker notes, find DOC: paths
# Load those documents for full context

# 5. Find current work
cat {implementation}/sprint-status.yaml
# Find in-progress story, load its story file
```

---

## Human Trigger Phrases

| Say | Action |
|-----|--------|
| "land the plane" | Session close protocol |
| "what decisions?" | `bd list --type decision` |
| "what's blocked?" | `bd list --type blocker` |
| "what's next?" | Read sprint-status.yaml for ready-for-dev |
| "file that decision" | `bd create --type decision` |
| "that's a blocker" | `bd create --type blocker` |

---

## Why This Design is 1+1 > 2

### BMAD Provides
- Rich document generation (PRD, Architecture, Stories)
- Guided workflows with quality gates
- Human-readable status dashboard (sprint-status.yaml)
- Story-level detail (tasks, AC, file lists)

### Beads Adds (Things BMAD Can't Do)
- **Decision memory**: Survives context clearing
- **Dependency tracking**: Explicit "A needs B first"
- **Blocker visibility**: External impediments tracked
- **Phase gates**: Clear handoff points

### Combined Value
- Agent loses context → `bd list --type decision` recovers choices
- Agent needs to know what's blocked → `bd list --type blocker`
- Agent needs story to work on → sprint-status.yaml + check blockers
- Agent makes tradeoff → Decision issue preserves reasoning for others

### What We Avoided
- **No story duplication**: Stories live in sprint-status.yaml only
- **No sync scripts**: Systems don't need synchronization
- **No status mapping**: Each system tracks different things
- **No confusion**: Clear rules about what goes where

---

## Quick Reference

```
When to use BMAD:
- Creating/editing documents (PRD, Architecture, Stories)
- Tracking story status (sprint-status.yaml)
- Following methodology workflows
- Task checkboxes in story files

When to use Beads:
- Recording a decision that affects other agents
- Tracking a blocker/impediment
- Noting a dependency between work items
- Session handoff context
- Anything that must survive /clear
```

---

`bd help` | `bd quickstart` | `bd doctor`
