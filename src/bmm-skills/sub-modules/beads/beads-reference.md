# BMAD + Beads Reference

> Single reference for the BMAD + Beads integration (v6.2.1 skills architecture).
> For agent-specific guidance, see `.beads/AGENTS.md`.

---

## Two Command Families

| Family | Prefix | Source | Example |
|--------|--------|--------|---------|
| **Native Beads** | `bd ` (space) | Beads CLI | `bd list`, `bd ready`, `bd doctor` |
| **BMAD extensions** | `bd_` (underscore) | `.beads/lib/bmad-aliases.sh` | `bd_land`, `bd_claim`, `bd_health` |

**Native commands** are always available when `bd` is installed.
**BMAD commands** require sourcing: `source .beads/lib/bmad-aliases.sh`
(git hooks do this automatically).

---

## Native Beads Commands

```bash
bd list [--type TYPE] [--status STATUS] [--priority N]  # Filter items (blocker/decision/task, open/in_progress, 0-4)
bd ready                   # Ready work queue
bd create --type TYPE "t"  # Create blocker/decision/task
bd doctor                  # Basic health check
bd help                    # Full native help
```

---

## BMAD Extension Commands

### Session Start

```bash
bd_session_start       # Validates env, shows HALTs + ready work + sprint status + sync status
bd_claim "{story-key}" # Claim before coding (prevents concurrent edits)
```

### During Work

```bash
# Commit normally — hooks auto-sync beads
bd_halt "{reason}"     # HALT: priority 0 — stops all work
bd_decision "{title}"  # Runtime decision (outside formal workflows)
bd_blocker "{title}"   # External blocker
bd_action "{title}"    # Action item
bd_sync_story <file>   # After adding AI-Review items to story file
bd_quick "msg"         # Quick commit (skip tests)
bd_qadd "msg"          # Stage all + quick commit
```

### Session End (Handover)

Use the `bmad-beads-handover` skill for guided session end, or manually:

```bash
bd_release <id>        # Release claims
bd_land                # Sync: beads-sync → main → current branch
bd_preflight           # Verify ready to push
git push               # Push when all green
```

**Something broke?** `bd_fix`

---

## Git Sync

Three-way sync via `bd_land`: `beads-sync → main → current-branch` (both merges use `--no-ff`).
See `SYNC_FLOW_DIAGRAM.md` for detailed architecture and error handling flows.

### Auto-Sync Levels

| Level | Trigger | Action | Blocking? |
|-------|---------|--------|-----------|
| Post-commit | After every commit | `bd sync` (background) | No |
| Pre-push | Before `git push` | `bd_auto_land` (configurable) | Depends on mode |
| Handover | Manual session end | `bd_land` (always) | Yes |

### Auto-Sync Modes (`bd_config_sync <mode>`)

| Mode | Behavior |
|------|----------|
| `warning` (default) | Ask before syncing |
| `auto` | Auto-sync silently |
| `block` | Refuse push until synced |
| `off` | Disable checks |

### Workflow Modes (`bd_config_workflow <mode>`)

| Mode | When to Use |
|------|-------------|
| `mixed` (default) | Human & Code Agent collaboration (smart daemon detection) |
| `agent` | Pure Code Agent workflows (always sync beads-sync) |
| `human` | Pure human workflows, no daemon |
| `auto` | Let system decide based on daemon |

---

## Story Sync (`bd_sync_story`)

Parses AI-Review checkboxes from story files and creates Beads tasks:

```bash
bd_sync_story implementation_artifacts/story-1-2-auth.md
```

**Format:** `- [ ] [AI-Review][HIGH|MEDIUM|LOW] Description`

**Priority mapping:** `[HIGH]` → 0, `[MEDIUM]` → 1, `[LOW]` → 2

**Idempotency:** Each task is tagged with a content hash. Re-running sync skips existing tasks.

Sprint status display: `bd_session_start` reads `sprint-status.yaml` if present (read-only summary).

---

## Troubleshooting

| Command | Purpose |
|---------|---------|
| `bd_health` | Full diagnostic: repo, `.beads/`, daemon, branches, claims, HALTs, config |
| `bd_fix` | Auto-recovery: worktree branch fixes, branch sync |
| `bd_preflight` | Pre-push check: clean tree, synced branches, no claims |

### Manual Recovery (When `bd_fix` Fails)

```bash
git log main..beads-sync                    # Diagnose divergence
git checkout main && git merge beads-sync --no-ff  # Manual sync
# If .beads/issues.jsonl conflicts: git checkout --theirs .beads/issues.jsonl
git push origin main && git checkout <your-branch> && git merge main
bd_health                                   # Verify
```

### Push Blocked with "daemon using --auto-push"?

```bash
bd daemon --stop
bd daemon --start --interval 5s --auto-commit --auto-pull
```

---

## Best Practices

### Do

- Run `bd_session_start` at session start
- Claim stories before working: `bd_claim`
- Run `bd_land` at session end (every time)
- Use `bd_preflight` before pushing
- Start daemon without `--auto-push`: `bd daemon --start --interval 5s --auto-commit --auto-pull`

### Don't

- Don't work directly on `beads-sync` (daemon's branch)
- Don't force-push `beads-sync`
- Don't edit `.beads/` manually (use `bd` commands)
- **CRITICAL**: Never use `bd daemon --auto-push` (causes race conditions with pre-push hook)

---

## What to Track Where

| What | Where | NOT in |
|------|-------|--------|
| Work claims | Beads | — |
| Runtime decisions | Beads | architecture.md |
| External blockers | Beads | — |
| HALTs (priority 0) | Beads | — |
| Phase completion | workflow-status.yaml | Beads |
| ADRs | architecture.md | Beads |
| Story status | sprint-status.yaml | Beads |
| Task progress | Story file checkboxes | Beads |
| Code review findings | Story file | Beads |

---

## See Also

- `.beads/AGENTS.md` — Agent-specific guidance
- `bmad-beads-handover` skill — Guided session-end procedure
- [Beads documentation](https://github.com/steveyegge/beads)
