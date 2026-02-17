# BMAD + Beads Reference

> Single reference for the BMAD + Beads integration.
> For agent-specific guidance, see `.beads/AGENTS.md`.

---

## What BMAD Adds to Beads

Beads provides the CLI (`bd`), daemon, worktrees, and `beads-sync` branch. BMAD adds:

- **Story-to-Beads bridge**: `bd_sync_story` parses `[AI-Review]` items into Beads tasks
- **Three-way sync**: `bd_land` extends `bd sync --merge` with main → current dev branch
- **Handover protocol**: `bd_preflight` + `bd_land` for session-end safety
- **Agent guidance**: Two-tier injection (compiled agent .md + `.beads/AGENTS.md`)
- **Pre-push policy**: `bd_auto_land` (warning/auto/block/off modes)
- **Recovery tools**: `bd_fix`, `bd_health`
- **Convenience aliases**: Agent-friendly wrappers (`bd_claim`, `bd_halt`, `bd_decision`, etc.)

---

## Agent Lifecycle

### Session Start

```bash
bd_session_start       # Validates env, shows HALTs + ready work + sync status
bd_claim "{story-key}" # Claim before coding (prevents concurrent edits)
```

### During Work

```bash
# Commit normally — hooks auto-sync beads
bd_decision "{title}"  # Runtime decision (outside formal workflows)
bd_blocker "{title}"   # External blocker
bd_halt "{reason}"     # HALT: priority 0 — stops all work
bd_sync_story <file>   # After adding AI-Review items to story file
```

### Session End (Handover)

```bash
bd_release <id>        # Release claims
bd_land                # Sync: beads-sync → main → current branch
bd_preflight           # Verify ready to push
git push               # Push when all green
```

**Something broke?** `bd_fix`

---

## Git Sync Architecture

### The Problem

Beads daemon commits to `beads-sync` via a separate worktree. Without regular sync, branches diverge — `beads-sync` has tracking data that `main` and dev branches lack.

### Three-Way Sync (`bd_land`)

```
beads-sync → main → current-branch
```

1. **beads-sync → main**: Uses `bd sync --merge` (native Beads, `--no-ff`). Falls back to raw git merge on older Beads.
2. **main → current branch**: BMAD's unique value — merges main into your working branch with `--no-ff`.

### Auto-Sync Levels

| Level       | Trigger            | Action                        | Blocking?       |
| ----------- | ------------------ | ----------------------------- | --------------- |
| Post-commit | After every commit | `bd sync` (background)        | No              |
| Pre-push    | Before `git push`  | `bd_auto_land` (configurable) | Depends on mode |
| Handover    | Manual session end | `bd_land` (always)            | Yes             |

### Auto-Sync Modes

```bash
bd_config_sync <mode>
```

| Mode                | Behavior                 |
| ------------------- | ------------------------ |
| `warning` (default) | Ask before syncing       |
| `auto`              | Auto-sync silently       |
| `block`             | Refuse push until synced |
| `off`               | Disable checks           |

### Workflow Modes

Configure how Beads integration behaves in your workflow:

```bash
bd_config_workflow <mode>
```

| Mode              | Description                                   | When to Use                          |
| ----------------- | --------------------------------------------- | ------------------------------------ |
| `mixed` (default) | Smart detection based on daemon status        | Human & Code Agent collaboration     |
| `agent`           | Always sync beads-sync (strict)               | Pure Code Agent workflows            |
| `human`           | Never sync beads-sync                         | Pure human workflows (no daemon)     |
| `auto`            | Automatic mode switching                      | Let system decide based on daemon    |

**Examples:**

```bash
# Working alone without daemon
bd_config_workflow human

# Strict agent workflow (always require beads-sync sync)
bd_config_workflow agent

# Smart mixed workflow (default, recommended)
bd_config_workflow mixed
```

**How "mixed" mode works:**

- Daemon running + beads-sync ahead → Syncs beads-sync before push
- Daemon stopped → Skips beads-sync, syncs main → dev only
- Daemon idle for 24+ hours → Warning in `bd_health`

**Key difference from auto-sync mode:**

- **Auto-sync mode** controls _how_ to sync (warning/auto/block/off)
- **Workflow mode** controls _whether_ to sync beads-sync based on workflow context

---

## Story Sync (`bd_sync_story`)

Parses AI-Review checkboxes from story files and creates Beads tasks:

```bash
bd_sync_story implementation_artifacts/story-1-2-auth.md
```

**Format:** `- [ ] [AI-Review][HIGH|MEDIUM|LOW] Description`

**Priority mapping:** `[HIGH]` → 0, `[MEDIUM]` → 1, `[LOW]` → 2

**Idempotency:** Each task is tagged with a content hash. Re-running sync skips existing tasks. Only new/changed items are created.

**When tasks are re-created:**

- Description changed → new hash → new task
- Priority changed → new hash → new task
- Task manually deleted → re-created from story file (source of truth)

**Troubleshooting duplicates:**

```bash
bd search "Story: 1-2-auth" --status open   # Find tasks
bd close <id> --reason "duplicate"           # Close duplicates
```

---

## Troubleshooting

### `bd_health` — Full Diagnostic

Checks: git repo, `.beads/` dir, daemon status, branch sync, active claims, HALTs, config.

```bash
bd_health
```

### `bd_fix` — Auto-Recovery

Handles: worktree on wrong branch, branch sync needed.

```bash
bd_fix
```

### Manual Recovery (When `bd_fix` Fails)

```bash
# 1. Diagnose
git log main..beads-sync    # What's in beads-sync but not main?
git log beads-sync..main    # What's in main but not beads-sync?

# 2. Manual merge (beads-sync → main)
git checkout main
git merge beads-sync --no-ff -m "manual merge: sync beads tracking"

# 3. If conflicts in .beads/issues.jsonl — ALWAYS prefer beads-sync version
git checkout --theirs .beads/issues.jsonl
git add .beads/issues.jsonl && git commit

# 4. Push and sync to dev
git push origin main
git checkout <your-branch>
git merge main
git push origin <your-branch>

# 5. Verify
bd_health
```

### Worktree Issues

```bash
# "already used by worktree" error
git worktree list
git -C .git/beads-worktrees/beads-sync checkout beads-sync
```

### Common Causes of Divergence

1. **Direct commits to main** without running `bd_land` — always sync at session end
2. **Force-push to beads-sync** — never do this; daemon manages that branch
3. **Manual edits to `.beads/issues.jsonl`** — use `bd` commands instead
4. **Long-running branches** — run `bd_land` periodically
5. **Daemon using `--auto-push`** — pre-push hook will block; see fix below

### Push Blocked with "daemon using --auto-push"?

```bash
bd daemon --stop
bd daemon --start --interval 5s --auto-commit --auto-pull
# Now push will work
```

### Prevention

- Run `bd_land` at every session end
- Use auto-sync: `bd_config_sync auto` or `bd_config_sync warning`
- Check health before push: `bd_preflight`
- Don't skip handover, even for "just a typo"

---

## Best Practices

### Do

- Run `bd_session_start` at session start
- Claim stories before working: `bd_claim`
- Run `bd_land` at session end (every time)
- Use `bd_preflight` before pushing
- Keep daemon enabled for auto-sync
- Start daemon without `--auto-push`: `bd daemon --start --interval 5s --auto-commit --auto-pull`

### Don't

- Don't work directly on `beads-sync` (daemon's branch)
- Don't force-push `beads-sync`
- Don't edit `.beads/` manually (use `bd` commands)
- Don't remove the beads-sync worktree
- Don't skip handover workflow
- **CRITICAL**: Never use `bd daemon --auto-push` (pre-push hook will block; causes race conditions)
  - Correct: `bd daemon --start --interval 5s --auto-commit --auto-pull`

---

## What to Track Where

| What                 | Where                 | NOT in          |
| -------------------- | --------------------- | --------------- |
| Work claims          | Beads                 | —               |
| Runtime decisions    | Beads                 | architecture.md |
| External blockers    | Beads                 | —               |
| HALTs (priority 0)   | Beads                 | —               |
| Phase completion     | workflow-status.yaml  | Beads           |
| ADRs                 | architecture.md       | Beads           |
| Story status         | sprint-status.yaml    | Beads           |
| Task progress        | Story file checkboxes | Beads           |
| Code review findings | Story file            | Beads           |

---

## See Also

- `.beads/AGENTS.md` — Agent-specific guidance (story discovery, HALT detection)
- `bd_help` — Full command reference (run in shell)
- [Beads documentation](https://github.com/steveyegge/beads)
