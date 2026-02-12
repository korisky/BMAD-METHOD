# Handover Workflow Instructions

> **Purpose:** End-of-session procedure to sync all branches, release claims, and ensure work is safely pushed.
> For complex git recovery scenarios, see `docs/beads-reference.md`.

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
bd_release <claim-id>
```

### Step 2: Commit Any Remaining Changes

```bash
git status
# If changes exist:
git add <files>
git commit -m "type: description"
```

### Step 3: Sync All Branches

Always sync branches during handover to prevent divergence:

```bash
bd_land        # Sync: beads-sync → main → current branch
```

This ensures all branches stay in sync even if no divergence warning appeared.

### Step 4: Verify Ready to Push

```bash
bd_preflight
```

This checks:

- ✅ Working tree clean
- ✅ Branches synced (beads-sync → main)
- ✅ No open claims

### Step 5: Push When Ready

When `bd_preflight` shows ✅:

```bash
git push
```

### Step 6: Report Next Ready Work (Optional)

```bash
bd_session_start
```

---

## Quick Reference (Copy-Paste)

**Full handover sequence:**

```bash
# 1. Release claims
bd_release <claim-id>

# 2. Commit changes
git add . && git commit -m "wip: session checkpoint"

# 3. Sync branches (always run)
bd_land

# 4. Verify ready
bd_preflight

# 5. Push
git push
```

**Something broke?** Run `bd_fix`

---

## When Things Go Wrong

**First, try auto-fix:**

```bash
bd_fix
```

This handles common issues like:

- Worktree on wrong branch
- Branch sync needed

**Note:** With auto-sync enabled (default), branches should stay in sync automatically:

- Post-commit hook: Background sync after commits
- Pre-push hook: Prompts to sync before push
- Configure with: `bd_config_sync <mode>` (warning/block/auto/off)

**If bd_fix doesn't work, manual recovery:**

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

For complex recovery, see `docs/beads-reference.md`.

---

## Handover Complete

After successful handover:

- All branches are synced
- Claims are released
- Changes are pushed to remote
- Next ready work is identified

**Session can now safely end.**
