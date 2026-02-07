# Beads Git Workflow Guide

> **For BMAD + Beads integrated projects**
> Last Updated: 2026-01-30

## Overview

This document explains the git workflow for projects using both BMAD (Build, Measure, Adapt, Deliver) and Beads issue tracking with daemon mode enabled. It covers a critical integration pattern that prevents branch divergence issues.

---

## Story → Beads Task Sync

After adding AI-Review follow-ups to story files during code review, sync them to Beads:

```bash
bd_sync_story implementation_artifacts/story-1-2-auth.md
# Parses: - [ ] [AI-Review][HIGH|MEDIUM|LOW] Description
# Creates matching Beads tasks with correct priorities
# Output: "Created N Beads task(s) from 1-2-auth"
```

**Why sync to Beads?**
- Fresh agents run `bd ready`, not grep story files
- Ensures action items are visible in runtime coordination
- Prevents dual-tracking mistakes

**Priority mapping:**
- `[HIGH]` → Priority 0 (halt)
- `[MEDIUM]` → Priority 1 (blocker)
- `[LOW]` → Priority 2 (action)

**What gets synced:**
- Only unchecked `- [ ]` items (completed `[x]` items are skipped)
- Only items tagged with `[AI-Review]` prefix
- Story key automatically added to task notes

**Verify tasks created:**
```bash
bd ready
# Shows newly created tasks
```

---

## The Challenge: Beads Daemon + Git Worktrees

### How Beads Works with Git

When beads daemon is enabled (recommended for auto-sync), it creates a **separate git worktree** for the `beads-sync` branch:

```
your-project/                          # Main worktree (dev/main branches)
  └── .git/beads-worktrees/beads-sync  # Daemon worktree (beads-sync branch)
```

**Why a worktree?**
- Daemon commits to `beads-sync` automatically without interfering with your work
- You work on `dev` or feature branches without conflicts
- Isolation prevents accidental overwrites

**The limitation:**
- Git worktrees don't allow the same branch in multiple places
- `main` can only be checked out in ONE worktree at a time
- `dev` can only be checked out in ONE worktree at a time

---

## The Problem: Branch Divergence

### What Happens Without Regular Syncing

```
Time →

beads-sync:  A──B──C──D──E──F (beads daemon commits)

main:        A──────X──Y──Z   (development commits)

dev:         A──────X──Y──Z──M──N (development commits)
```

**Result:** Three branches with different `.beads/issues.jsonl` states:
- `beads-sync`: Latest beads tracking (116 issues)
- `main`: Missing beads data (0 issues or stale data)
- `dev`: Missing beads data (0 issues or stale data)

**Symptoms:**
- Can't checkout to `main` (worktree conflict)
- `.beads/` exists differently across branches
- Git refuses to switch branches ("would overwrite .beads/issues.jsonl")
- Merge conflicts in `.beads/issues.jsonl`

---

## The Solution: Regular Three-Way Sync

### Workflow: beads-sync → main → dev

At the end of every work session ("land the plane"), sync all three branches:

```bash
# 1. Close your work
bd close {id} --reason "summary"

# 2. Fetch latest from remote
git fetch origin

# 3. Merge beads-sync → main
git checkout main
git merge beads-sync --ff-only       # Fast-forward only (clean history)
git push origin main

# 4. Merge main → dev
git checkout dev
git merge main                        # Bring beads data + main changes
bd sync && git push origin dev

# 5. Verify and prepare for next session
bd ready --limit 3
```

### Why This Works

1. **beads-sync → main**: Brings beads tracking data to production branch
2. **main → dev**: Synchronizes dev with both beads data and production code
3. **Fast-forward only (`--ff-only`)**: Prevents merge commits if branches diverged (alerts you early)
4. **Regular syncing**: Prevents branches from diverging in the first place

> **Note (v0.0.2+):** The `bd_land` command now uses `--ff-only` for the critical `beads-sync → main` merge.
> This provides early divergence detection—it will fail if branches have diverged, alerting you to investigate before proceeding.
> See "When bd_land Fails" section below for recovery procedures.

---

## Auto-Sync Features

### Overview

The BMAD + Beads integration provides three levels of automatic synchronization to prevent branch divergence:

1. **Post-commit sync** - Background sync after commits (Phase 3)
2. **Pre-push check** - Interactive sync before push (Phase 2)
3. **Handover sync** - Mandatory sync during session end (Phase 3)

### Post-Commit Background Sync

After each commit, a background hook runs `bd_auto_sync` to check for divergence:

```bash
# Runs automatically after: git commit
# Non-blocking, runs in background
# Logs to: .beads/sync.log
```

**How it works:**
- Only syncs if beads-sync is ahead of main
- Runs silently in background (no output during commit)
- Logs all activity to `.beads/sync.log` for debugging

**Check sync logs:**
```bash
tail -f .beads/sync.log
```

### Pre-Push Interactive Check

Before pushing, the pre-push hook runs `bd_auto_land` to check divergence:

```bash
# Runs automatically before: git push
# Behavior controlled by git config beads.auto-sync
```

**Configure behavior:**
```bash
bd_config_sync <mode>
```

**Available modes:**

| Mode | Behavior |
|------|----------|
| `warning` (default) | Ask before syncing: "Run bd_land? [y/N]" |
| `block` | Refuse push until branches synced |
| `auto` | Auto-sync without asking |
| `off` | Disable pre-push check |

**Examples:**
```bash
# Ask before syncing (default)
bd_config_sync warning

# Auto-sync always
bd_config_sync auto

# Block pushes if not synced
bd_config_sync block

# Disable auto-sync
bd_config_sync off

# Check current mode
bd_config_sync
```

### Handover Mandatory Sync

During `[HO]` handover workflow, `bd_land` always executes (not conditional):

```bash
# 3. Sync branches (always run)
bd_land

# 4. Verify ready
bd_preflight

# 5. Push
git push
```

This ensures session-end syncs happen even if no divergence warning appeared.

### When to Use Each Mode

**`warning` mode (recommended):**
- Default safe mode
- Good for learning the workflow
- Gives you control while preventing accidents

**`auto` mode:**
- Best for experienced users
- Seamless workflow, no prompts
- Trust background sync to keep branches aligned

**`block` mode:**
- Enforces strict sync discipline
- Good for teams requiring always-synced branches
- Prevents any push until synced

**`off` mode:**
- Only for solo work without daemon
- Or when beads-sync doesn't exist
- Not recommended for team projects

### Troubleshooting Auto-Sync

**Background sync not working?**

Check the log:
```bash
tail -20 .beads/sync.log
```

Common issues:
- Daemon not running → `bd daemon start`
- beads-sync doesn't exist → normal if daemon just started
- Merge conflict → run `bd_land` manually to resolve

**Pre-push check failing?**

Run health check:
```bash
bd_health
```

Fix issues:
```bash
bd_fix          # Auto-fix common issues
bd_land         # Manual sync if needed
bd_preflight    # Verify ready
```

**Disable auto-sync temporarily:**

For one-off push without check:
```bash
git push --no-verify
```

Or disable permanently:
```bash
bd_config_sync off
```

---

## When bd_land Fails: Branch Divergence Handling

### Understanding --ff-only Safety Check

**Starting from version 0.0.2**, `bd_land` uses `--ff-only` for the critical `beads-sync → main` merge:

```bash
git merge beads-sync --ff-only  # Safety check: fails if diverged
```

**Why --ff-only?**
- ✅ **Fails fast**: Alerts you immediately if branches have diverged
- ✅ **Prevents silent merges**: Won't hide conflicts or divergence
- ✅ **Production pattern**: Matches crypto-data-extend-system safety approach
- ✅ **Forces investigation**: Makes you understand what diverged before proceeding

**Old behavior (--no-ff):**
- ❌ Always created merge commits, even when unnecessary
- ❌ Silently merged diverged branches (could hide problems)
- ❌ No early warning of branch divergence

### When bd_land Fails

**Typical error message:**

```bash
$ bd_land
=== LANDING THE PLANE ===

1. Checking for open claims...
  ✅ No open claims

2. Syncing branches (beads-sync → main → your-branch)...

  ❌ Cannot fast-forward. Branches diverged.
     Diagnosis: git log main..beads-sync
     Recovery: bd_fix divergence
```

**What this means:**
- `main` and `beads-sync` have diverged (both have unique commits)
- Fast-forward merge is impossible
- **This is a safety check**, not an error!

### Step-by-Step Recovery

#### 1. Diagnose the Divergence

Run health check to see the full picture:

```bash
bd_health
```

**Example output:**

```
=== BEADS HEALTH CHECK ===
✅ Git repository
✅ Beads initialized
✅ bd CLI available

Branch Sync Status:
  ⚠️  beads-sync is 3 commit(s) ahead of main
     Run: bd_land (to sync branches)
```

Or check manually:

```bash
# What commits are in beads-sync but not in main?
git log main..beads-sync

# What commits are in main but not in beads-sync?
git log beads-sync..main
```

#### 2. Automatic Recovery (Recommended)

Use the built-in fix command:

```bash
bd_fix divergence
```

This runs diagnostics and provides specific recovery guidance.

#### 3. Manual Recovery (Production Pattern)

If automatic recovery doesn't apply, use the production pattern from `crypto-data-extend-system`:

```bash
# 1. Checkout main
git checkout main

# 2. Merge with --no-ff (allow merge commit for diverged branches)
git merge beads-sync --no-ff -m "manual merge: sync beads tracking after divergence"

# 3. Resolve conflicts if any
#    For .beads/issues.jsonl conflicts: ALWAYS prefer beads-sync version
git checkout --theirs .beads/issues.jsonl  # Accept beads-sync version
git add .beads/issues.jsonl
git commit

# 4. Push to remote
git push origin main

# 5. Sync to current branch
git checkout dev  # or your feature branch
git merge main
git push origin dev

# 6. Verify alignment
bd_health
```

**Why accept beads-sync version of .beads/issues.jsonl?**
- Beads daemon is the source of truth for issue tracking
- `beads-sync` has the most up-to-date issue data
- Overwriting beads data with stale main data would lose tracking history

#### 4. Verify Recovery

After manual merge:

```bash
# Check branch alignment
bd_health

# Verify issue counts match
bd stats

# Try bd_land again (should succeed now)
bd_land
```

### Common Causes of Divergence

**1. Direct commits to main** (without syncing from beads-sync)
```bash
# Bad: Committed to main while daemon was running
git checkout main
git commit -m "feature: something"  # ⚠️ Skipped bd_land!
git push
```

**Fix:** Always run `bd_land` at session end to keep branches aligned

**2. Force-push to beads-sync** (corrupts daemon state)
```bash
# Bad: Never force-push beads-sync!
git push --force origin beads-sync  # ❌ Corrupts daemon
```

**Fix:** Never force-push beads-sync; let daemon manage it

**3. Manual edits to .beads/issues.jsonl** (bypasses daemon)
```bash
# Bad: Edited beads data directly
vim .beads/issues.jsonl
git commit -m "manual edit"  # ⚠️ Bypassed daemon!
```

**Fix:** Use `bd` commands for all issue changes

**4. Long-running branches** (missed multiple syncs)
```bash
# Risky: Feature branch hasn't synced in days
git checkout feature/long-running
# ... work for days without bd_land ...
```

**Fix:** Periodically run `bd_land` even during long feature work

### Prevention Best Practices

✅ **Run bd_land at session end** (every time!)
```bash
# End of every work session
bd_land
```

✅ **Use auto-sync modes**
```bash
bd_config_sync auto     # Auto-sync on push
bd_config_sync warning  # Prompt before push
```

✅ **Check health before push**
```bash
bd_health      # Diagnose issues
bd_preflight   # Pre-push validation
```

✅ **Enable post-commit background sync** (automatic)
```bash
# Check if working
tail -20 .beads/sync.log
```

❌ **Don't skip bd_land** (even if you're "just fixing a typo")
❌ **Don't force-push beads-sync** (daemon's branch)
❌ **Don't edit .beads/ manually** (use bd commands)

### See Also

- **bd_health**: Comprehensive diagnostics
- **bd_fix**: Automatic recovery for common issues
- **bd_preflight**: Pre-push validation checks
- **Recovery Procedure** section below: Step-by-step manual recovery

---

## Implementation Guide

### For New Projects

When initializing beads in a new BMAD project:

```bash
# 1. Initialize beads
bd init

# 2. Configure daemon to use beads-sync branch
# This is usually auto-configured, verify with:
bd sync --status

# 3. Add sync workflow to .claude/CLAUDE.md
# See "End (Land the Plane)" section

# 4. Commit this workflow documentation
git add docs/beads-git-workflow.md
git commit -m "docs: add beads git workflow guide"
```

### For Existing Projects

If branches are already diverged (like we experienced):

See "Recovery Procedure" section below.

---

## Recovery Procedure

### Symptoms of Branch Divergence

- Error: `fatal: 'main' is already used by worktree at ...`
- Error: `Your local changes to the following files would be overwritten: .beads/issues.jsonl`
- Can't switch between branches

### Recovery Steps

**Step 1: Identify divergence**

```bash
git log --oneline --graph --all -15
git show-ref --heads
```

**Step 2: Merge main into beads-sync worktree**

```bash
# Navigate to beads-sync worktree
git -C .git/beads-worktrees/beads-sync status

# Merge main
git -C .git/beads-worktrees/beads-sync merge main -m "Merge main into beads-sync"

# Resolve conflicts (keep .beads/issues.jsonl from beads-sync)
git -C .git/beads-worktrees/beads-sync checkout --ours .beads/issues.jsonl
git -C .git/beads-worktrees/beads-sync add --sparse .
git -C .git/beads-worktrees/beads-sync commit
```

**Step 3: Switch main worktree to dev**

```bash
# Stash local changes if needed
git stash

# Switch to dev to free up other branches
git checkout dev
```

**Step 4: Switch beads-sync worktree to beads-sync branch**

```bash
git -C .git/beads-worktrees/beads-sync checkout beads-sync
```

**Step 5: Merge beads-sync into main**

```bash
git checkout main
git merge beads-sync --no-ff -m "Merge beads-sync: integrate beads tracking"
git push origin main
```

**Step 6: Merge main into dev**

```bash
git checkout dev
git merge main
git push origin dev
```

**Step 7: Verify alignment**

```bash
git show-ref --heads
bd stats
```

All branches should now have aligned `.beads/` data.

---

## Best Practices

### Do's

✅ **Always run the three-way sync** at session end
✅ **Use `--ff-only` for main merges** to catch divergence early
✅ **Verify with `bd stats`** after merging
✅ **Document this workflow** in your project's `.claude/CLAUDE.md`
✅ **Keep daemon enabled** for automatic beads sync

### Don'ts

❌ **Don't disable daemon** (breaks auto-sync)
❌ **Don't remove beads-sync worktree** (daemon needs it)
❌ **Don't skip "land the plane"** workflow
❌ **Don't work directly on beads-sync** (daemon's branch)
❌ **Don't force-push beads-sync** (can corrupt tracking)

---

## Troubleshooting

### Q: Why can't I checkout to main?

**A:** Another worktree has `main` checked out. Run:

```bash
git worktree list
```

If beads-sync worktree is on `main`, switch it back:

```bash
git -C .git/beads-worktrees/beads-sync checkout beads-sync
```

### Q: Should `.beads/` be in .gitignore?

**A:** **NO!** Beads data should be committed and shared across the team. Only `.beads/` entries marked as local-only should be gitignored (none by default).

### Q: What if `--ff-only` fails?

**A:** Branches have diverged. This is a warning! Don't force it. Instead:

1. Check what diverged: `git log main..beads-sync` and `git log beads-sync..main`
2. Decide: merge or rebase (usually merge for beads data)
3. Run without `--ff-only`: `git merge beads-sync`
4. Resolve conflicts, preferring beads-sync's `.beads/issues.jsonl`

### Q: Can I use this with feature branches?

**A:** Yes! Merge `main` into your feature branch regularly:

```bash
git checkout feature/my-feature
git merge main  # Brings beads data from main
```

When landing feature branch:

```bash
git checkout main
git merge feature/my-feature
git merge beads-sync --ff-only
git push origin main
```

---

## Why This Architecture?

### Daemon Isolation

**Problem:** If daemon commits to your working branch, you'd get:
- Unexpected commits appearing during your work
- Merge conflicts with your uncommitted changes
- Interrupted workflow

**Solution:** Daemon gets its own worktree and branch (`beads-sync`)
- You work on `dev`/`main` without interruption
- Daemon works on `beads-sync` in isolation
- Manual merge brings changes together cleanly

### Three-Branch Model

```
beads-sync (daemon)  →  main (production)  →  dev (working)
```

- **beads-sync**: Daemon's playground, auto-commits
- **main**: Stable, production-ready (after review)
- **dev**: Active development, merged from main

This mirrors standard git-flow with beads integration.

---

## Integration with BMAD Workflows

### Phase 4: Implementation

During implementation phase, your workflow is:

```bash
# Session start
bd ready --limit 3
bd update {id} --status in_progress

# Work on story
@_bmad/bmm/agents/dev.md
# ... implement, test, commit ...

# Session end (land the plane)
bd close {id} --reason "completed story X"
git checkout main && git merge beads-sync --ff-only && git push
git checkout dev && git merge main && git push
bd ready --limit 3
```

### Sprint Boundaries

At sprint end, ensure all branches synced:

```bash
# Verify no divergence
git log --oneline --graph --all -20
bd sync --status

# Sync if needed
git checkout main && git merge beads-sync --ff-only && git push
git checkout dev && git merge main && git push
```

---

## Quick Reference

### Daily Workflow

```bash
# Start
git pull && bd ready

# Work
bd update {id} --status in_progress
# ... code ...

# End
bd close {id}
git checkout main && git merge beads-sync --ff-only && git push
git checkout dev && git merge main && git push
```

### Emergency Recovery

```bash
# If stuck with "already used by worktree":
git worktree list
git stash
git checkout dev
git -C .git/beads-worktrees/beads-sync checkout beads-sync
git checkout main
```

---

## See Also

- `.claude/CLAUDE.md` - Session protocol with "land the plane" workflow
- `.beads/config.yaml` - Beads daemon configuration
- `CLAUDE.md` - Project overview and tech stack
- Beads docs: <https://github.com/steveyegge/beads> (if applicable)

---

**Questions or issues?** File a beads issue:

```bash
bd create "beads-git-workflow: [your issue]" -t bug -p 1
```
