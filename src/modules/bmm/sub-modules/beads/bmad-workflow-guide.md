# Development Workflow Guide

> BMAD + Beads integration. Human commits freely, agent syncs later.
>
> This file covers strategic workflow (phases, ADRs, sprints).
> For git branch sync procedures, see `docs/beads-git-workflow.md`.

---

## Current Mode: Phase 1 (Simple Workflow)

```
Pick Story → Claude Codes → You Review → You Commit
  (bd show)    (no commits)   (git diff)    (lazygit)
```

**Branch Strategy:**
```
main (protected)
  └── dev (working branch)

beads-sync (Beads-managed, issue metadata only)
```

**Key Points:**
- Claude never auto-commits
- Beads auto-commit: disabled
- You review all changes before commit
- Hooks warn but don't block commits
- Run `[HO]` handover workflow at session end to sync all branches

---

## Beads Configuration

```
Auto-Commit: false
Auto-Push: false
Sync Branch: beads-sync (separate from code)
```

Hooks installed: `pre-commit`, `post-merge`, `post-checkout`, `prepare-commit-msg`, `pre-push`

These sync **issue metadata only** - not code commits

---

## Future: Phase 2 (Multi-Agent Ready)

**When to switch:** Architecture validated, want parallel Claude sessions.

```
agent/story-1-2 ──PR──> dev ──PR──> main
agent/story-1-3 ──PR──> dev
```

**Branch Strategy:**
```
main (protected)
  └── dev (integration)
        ├── agent/story-1-2-chain-client
        ├── agent/story-1-3-block-fetcher
        └── agent/story-1-4-decoder
```

**Setup:**
```bash
# Before Claude session:
git checkout dev
git checkout -b agent/story-{id}-{short-desc}

# For parallel sessions (separate worktree):
git worktree add ../worktree-story-1-3 -b agent/story-1-3-block-fetcher
```

**Why agent branches matter:**

| Scenario | Without | With |
|----------|---------|------|
| 2 Claude sessions | Conflicts | Isolated |
| Rollback | Manual revert | Delete branch |
| Review | Mixed changes | Clean PR |

---

## ADR Workflow (Architecture Decisions)

Track architectural decisions as Beads chores with `ADR:` prefix.

**Create ADR:**
```bash
bd create "ADR: Use Kafka over Redis Streams" -t chore -p 1
```

**Priority mapping:**
- P1: Critical (database, language, framework)
- P2: Important (libraries, patterns)
- P3: Minor (tooling)

**ADR Lifecycle:**
```
1. PROPOSE   bd create "ADR: [Decision]" -t chore
2. DISCUSS   Update description with notes
3. ACCEPT    bd close {id} --reason "Accepted: See architecture.md#section"
4. DOCUMENT  Update architecture.md + project-context.md
```

**List ADRs:**
```bash
bd list -t chore | grep "ADR:"                    # All ADRs
bd list -t chore --status=closed | grep "ADR:"   # Accepted ADRs
```

**After accepting an ADR:**
1. Update `docs/architecture.md` with full decision details
2. Update `docs/project-context.md` ADR summary table
3. Reference the Beads ID in both documents

---

## Sprint Management

Track sprints as Beads chores with `SPRINT:` prefix. Stories linked via `parent-child` dependencies.

**Create sprint:**
```bash
bd create --title "SPRINT: Sprint N - [Goal]" --type chore --priority 1 \
  --description "Sprint Goal: [goal]

Capacity: [N] stories
Duration: [start date] to [end date]

Commitment:
- Story X-Y (bead-id): [story title]
...

Metrics:
- Planned: [N] stories
- Completed: 0 stories
- Velocity: TBD"
```

**Link stories to sprint:**
```bash
# Sprint is parent, stories are children
bd dep add <story-bead-id> <sprint-bead-id> --type parent-child
```

**Sprint lifecycle:**
```
1. PLAN     bd create "SPRINT: Sprint N - Goal" (SM Agent)
2. LINK     bd dep add <story-id> <sprint-id> --type parent-child
3. EXECUTE  bd update <story-id> --status in_progress (DEV Agent)
4. CLOSE    bd close <sprint-id> --reason "Velocity: N stories/sprint"
5. RETRO    bd create "RETRO: Sprint N - Theme" -t chore -p 2
```

**Find current sprint:**
```bash
bd list --status open | grep "SPRINT:"   # Active sprint
bd dep list <sprint-id>                  # Stories in sprint
```

---

## BMAD Full Workflow

| Phase | Agent | Purpose |
|-------|-------|---------|
| Discovery | analyst | Research, product brief |
| Planning | pm, ux | PRD, design |
| Solutioning | architect, tea | Architecture, test strategy |
| Implementation | sm, dev | Story prep, coding |

---

## Quick Commands

```bash
# Verify setup
bd daemon --status    # Should show auto-commit: false

# Phase 1 workflow (human commits)
git checkout dev
# ... Claude codes ...
git diff              # Review
git add -p && git commit  # Commit what you approve

# Phase 2 workflow (agent branches)
git checkout -b agent/story-{id}-{desc}
# ... Claude codes and commits ...
gh pr create --base dev

# Session end (all phases)
# Run [HO] handover workflow or manually:
bd-land               # Sync all branches
```

---

## Session End (Handover)

At the end of every session, run the `[HO]` handover workflow:

```bash
# Via agent menu
[HO]

# Or manually
bd-release <claim-id>     # Release any claims
bd-land                   # Sync beads-sync → main → current branch
git push origin HEAD      # Push if needed
bd-status                 # Report next ready work
```

For complex recovery scenarios, see `docs/beads-git-workflow.md`.
