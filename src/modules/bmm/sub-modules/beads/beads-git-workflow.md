# Beads Git Workflow Guide

> **For BMAD + Beads integrated projects**
> Last Updated: 2026-01-17

## Overview

This document explains the git workflow for projects using both BMAD (Build, Measure, Adapt, Deliver) and Beads issue tracking with daemon mode enabled. It covers a critical integration pattern that prevents branch divergence issues.

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

> **Note:** The `bd-land` command uses `--no-ff` for convenience (always creates a merge commit).
> Use `--ff-only` manually when you want early divergence detection—it will fail if branches have diverged, alerting you to investigate before proceeding.

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
- Beads docs: https://github.com/beadkit/beads (if applicable)

---

**Questions or issues?** File a beads issue:

```bash
bd create "beads-git-workflow: [your issue]" -t bug -p 1
```
