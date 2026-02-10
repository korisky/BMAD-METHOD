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

## Agent Beads Integration

**Agents automatically check Beads** for context when executing workflows. This makes Beads a primary coordination system, not an afterthought.

### Story Discovery (Automatic)

When you trigger story-targeted workflows like `[DS]` (dev story) or `[CR]` (code review), agents use the `resolve_story_target` protocol to intelligently discover which story to work on:

**Sources checked (in order):**
1. **Sprint-status.yaml** (if exists) - Official planned work
2. **User conversation** - "finished 2-1" → suggests 2-2
3. **Beads ready/in-progress** - `bd ready`, `bd list --status=in_progress`
4. **HALT detection** - `bd_halts` checks for priority 0 blockers

**Ranking algorithm:**
```
Priority order:
1. User explicit request (current conversation)
2. Sprint-status with preferred statuses
3. User context inferred next story
4. Beads high-priority ready work (P0-P1)
5. Beads in-progress work
6. Sprint-status other statuses
7. Beads medium-priority work (P2-P3)
8. Available stories (fallback)
```

**Agent presents:**
- Single match → Suggests with confirmation
- Multiple matches → Shows top 3 with sources/statuses
- No matches → Manual selection with helpful prompts

### Agent Critical Actions (Automatic)

All agents have Beads-aware critical actions when Beads is detected:

**All Agents:**
- Session start: Run `bd_status` to see ready work + blockers
- During work: Track decisions, blockers, HALTs
- Session end: Release claims, sync branches

**Dev Agent:**
- Always claims story before starting: `bd_claim "{story-key}"`
- Checks for HALTs before work
- Tracks mid-implementation discoveries as decisions
- Releases claim when done: `bd_release <id>`

**PM Agent:**
- Tracks scope changes AFTER PRD done: `bd_decision "Scope: {change}"`
- ADRs remain in architecture.md (NOT Beads)

**Scrum Master Agent:**
- Tracks cross-story dependencies: `bd_blocker "Dep: Story {B} needs {A}"`
- Tracks sprint deferrals: `bd_decision "Defer: {story}"`
- Story status remains in sprint-status.yaml (NOT Beads)

**Architect Agent:**
- Tracks post-architecture tech pivots: `bd_decision "Tech: {change}"`
- Tracks technical blockers: `bd_blocker "{blocker}"`
- ADRs remain in architecture.md (NOT Beads)

### What Agents Track in Beads

✅ **DO track in Beads:**
- Work claims (prevent concurrent edits)
- Runtime decisions (outside formal workflows)
- External blockers
- HALT conditions (priority 0)
- Cross-story dependencies
- Persistent action items

❌ **DON'T track in Beads:**
- Phase completion → workflow-status.yaml
- ADRs → architecture.md
- Story status → sprint-status.yaml
- Task progress → story file checkboxes
- Code review findings → story file

### Agent Guidance File

Detailed guidance for agents is maintained in `.beads/AGENTS.md`. This file is automatically created/updated by the installer and contains:

- Story discovery process documentation
- HALT detection explanation
- Beads commands reference
- Agent-specific guidance
- Priority scale
- Notes format

**Updating guidance:**
```bash
# Re-run installer to update .beads/AGENTS.md
bash /path/to/beads/install.sh

# Your custom notes outside managed blocks are preserved
```

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
bd_land               # Sync all branches
```

---

## Session End (Handover)

At the end of every session, run the `[HO]` handover workflow:

```bash
# Via agent menu
[HO]

# Or manually
bd_release <claim-id>     # Release any claims
bd_land                   # Sync beads-sync → main → current branch
git push origin HEAD      # Push if needed
bd_status                 # Report next ready work
```

For complex recovery scenarios, see `docs/beads-git-workflow.md`.
