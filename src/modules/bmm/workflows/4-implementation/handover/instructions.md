# Handover Workflow Instructions

> **Purpose:** End-of-session procedure to sync all branches, release claims, and ensure work is safely pushed.
> For complex git recovery scenarios, see `docs/beads-git-workflow.md`.

---

## Prerequisites

Before running handover:
- All work for this session should be complete or at a stable stopping point
- Tests should pass (if applicable)
- Changes should be staged and ready to commit (or already committed)

---

## Handover Procedure

### Step 1: Release Beads Claims

If you claimed a story during this session:

```bash
bd-release <claim-id>
```

Or release all your claims:

```bash
bd list --status in_progress --assigned @me | xargs -I {} bd-release {}
```

### Step 2: Check for Uncommitted Changes

```bash
git status
```

**If uncommitted changes exist:**

```bash
git add <files>
git commit -m "type: description

- Bullet point 1
- Bullet point 2"
```

### Step 3: Run bd-land (Three-Way Branch Sync)

This syncs `beads-sync -> main -> current branch` in one command:

```bash
bd-land
```

**What bd-land does:**
1. Merges `beads-sync` into `main` (brings Beads tracking data)
2. Pushes `main` to remote
3. Merges `main` into your current branch
4. Syncs Beads and pushes current branch

### Step 4: Push to Remote

If bd-land didn't push your branch (e.g., you're on a feature branch):

```bash
git push origin HEAD
```

### Step 5: Verify Sync Status

```bash
bd sync --status
git log --oneline -5
```

### Step 6: Report Next Ready Work

```bash
bd-next
```

Or for more detail:

```bash
bd-status
```

---

## Quick Reference (Copy-Paste)

**Full handover sequence:**

```bash
# 1. Release claims (if any)
bd-release <claim-id>

# 2. Commit any remaining changes
git add . && git commit -m "wip: session end checkpoint"

# 3. Sync all branches
bd-land

# 4. Push if needed
git push origin HEAD

# 5. Report status
bd-status
```

---

## When bd-land Fails

If `bd-land` fails due to merge conflicts or worktree issues:

1. **Check worktree status:**
   ```bash
   git worktree list
   ```

2. **Free up branches if needed:**
   ```bash
   git -C .git/beads-worktrees/beads-sync checkout beads-sync
   ```

3. **Manual three-way sync:**
   ```bash
   git checkout main
   git merge beads-sync --no-ff
   git push origin main
   git checkout <your-branch>
   git merge main
   git push origin <your-branch>
   ```

For complex recovery, see `docs/beads-git-workflow.md`.

---

## Handover Complete

After successful handover:
- All branches are synced
- Claims are released
- Changes are pushed to remote
- Next ready work is identified

**Session can now safely end.**
