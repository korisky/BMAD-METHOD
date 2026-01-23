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

### Step 2: Commit Any Remaining Changes

```bash
git status
# If changes exist:
git add <files>
git commit -m "type: description"
```

### Step 3: Check If Ready to Push

```bash
bd-preflight
```

This checks:
- ✅ Working tree clean
- ✅ Branches synced (beads-sync → main)
- ✅ No open claims

### Step 4: If Not Ready, Sync Branches

If `bd-preflight` shows ❌:

```bash
bd-land        # Sync: beads-sync → main → current branch
bd-preflight   # Verify again
```

### Step 5: Push When Ready

When `bd-preflight` shows ✅:

```bash
git push
```

### Step 6: Report Next Ready Work (Optional)

```bash
bd-status
```

---

## Quick Reference (Copy-Paste)

**Full handover sequence:**

```bash
# 1. Release claims
bd-release <claim-id>

# 2. Commit changes
git add . && git commit -m "wip: session checkpoint"

# 3. Check if ready
bd-preflight

# 4. If ❌: sync branches
bd-land && bd-preflight

# 5. If ✅: push
git push
```

**Something broke?** Run `bd-fix`

---

## When Things Go Wrong

**First, try auto-fix:**

```bash
bd-fix
```

This handles common issues like:
- Worktree on wrong branch
- Branch sync needed

**If bd-fix doesn't work, manual recovery:**

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
