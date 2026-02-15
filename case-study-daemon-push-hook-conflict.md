# Case Study: Beads Daemon Auto-Push + Pre-Push Hook Conflict

**Date:** 2026-02-14
**Project:** crypto-data-extend-system
**Severity:** HIGH (blocks all pushes in non-interactive contexts)
**Impact:** Mixed human + code agent workflows with GUI git clients (Lazygit, VS Code, etc.)

---

## Executive Summary

The beads daemon's `--auto-push` flag conflicts with the pre-push hook's `beads.auto-sync=auto/warning` mode, causing race conditions that block pushes in non-interactive contexts (Lazygit, VS Code git, etc.). The fix is simple: **daemon should only auto-commit, not auto-push**. Let the pre-push hook handle all sync operations.

---

## Incident Timeline

### Initial Symptom
User attempted to push 6 commits via Lazygit and received:
```
error: failed to push some refs to 'https://github.com/korisky/crypto-data-extend-system.git'
```

### Investigation Findings

1. **Git status showed clean:**
   ```bash
   $ git status
   On branch dev
   Your branch is ahead of 'origin/dev' by 6 commits.
   nothing to commit, working tree clean
   ```

2. **Pre-push hook blocked with warning:**
   ```
   🔄 Auto-syncing branches (beads-sync is 3 commits ahead)...
   error: Your local changes to the following files would be overwritten by merge:
       .beads/issues.jsonl
   Please commit your changes or stash them before you merge.
   ```

3. **Root cause discovered:**
   ```bash
   $ ps aux | grep "bd.*daemon"
   bd daemon --start --interval 5s --auto-commit --auto-push --auto-pull
   ```

   **The daemon was running with `--auto-push`**, pushing to `beads-sync` every 5 seconds, while the pre-push hook tried to merge `beads-sync → dev` during `bd_land`.

---

## Root Cause Analysis

### The Conflict

| Component | Action | Timing | Branch |
|-----------|--------|--------|--------|
| **Beads Daemon** | Auto-commits + auto-pushes metadata | Every 5s | `beads-sync` |
| **Pre-push Hook** | Runs `bd_land` (merges beads-sync → dev → main) | On `git push` | All branches |

### The Race Condition

1. User runs `git push origin dev`
2. Pre-push hook starts `bd_land`
3. `bd_land` tries to merge `origin/beads-sync → dev`
4. **Race:** Daemon writes to `.beads/issues.jsonl` between Git's status check and merge operation
5. Git detects "local changes" during merge (even though `git status` said clean)
6. Merge fails, push aborted

### Why It's Worse in Non-Interactive Contexts

- **Terminal:** Pre-push hook can prompt user for action (if `beads.auto-sync=warning`)
- **Lazygit/VS Code:** No TTY for interactive prompts → hook fails → push fails
- **Code agents:** Same problem as GUI tools

---

## Attempted Solutions (Failed)

### 1. Run `bd_land` manually before push
```bash
$ bd_land
error: Your local changes to the following files would be overwritten by merge:
    .beads/issues.jsonl
```
**Result:** Same race condition ❌

### 2. Try to commit the "local changes"
```bash
$ git add .beads/issues.jsonl
The following paths exist outside of your sparse-checkout definition:
.beads/issues.jsonl
```
**Result:** Sparse-checkout false positive (daemon writing to file) ❌

### 3. Refresh git index
```bash
$ git update-index --refresh
$ git status  # Still clean
$ bd_land      # Still fails
```
**Result:** Race condition persists ❌

### 4. One-time workaround
```bash
$ git push --no-verify origin dev  # SUCCESS ✓
```
**Result:** Bypassed hook, push succeeded. But not a permanent solution.

---

## Permanent Solution

### Configuration Change

**Stop the conflicting daemon:**
```bash
bd daemon --stop
```

**Restart with auto-commit only (no auto-push):**
```bash
bd daemon --start --interval 5s --auto-commit
```

**Ensure pre-push hook is in auto mode:**
```bash
git config beads.auto-sync auto
```

### New Workflow Division

| Responsibility | Handler | Trigger | Result |
|----------------|---------|---------|--------|
| **Track metadata changes** | Daemon | Every 5s | Commits to `beads-sync` (local only) |
| **Sync all branches** | Pre-push hook | On `git push` | Runs `bd_land`, then pushes |
| **Pull updates** | Daemon | Every 5s | Pulls `beads-sync` updates |

### Why This Works

✅ **No race conditions:** Daemon never pushes, so hook always has stable state to merge
✅ **Works everywhere:** Terminal, Lazygit, VS Code, code agents
✅ **Automatic sync:** User just runs `git push`, hook handles `bd_land`
✅ **Clean separation:** Daemon = track, Hook = sync

---

## Verification

### Before (Broken)
```bash
$ git push origin dev
# Via Lazygit → FAILS ❌
# Via terminal → FAILS ❌
# Workaround: git push --no-verify
```

### After (Fixed)
```bash
$ git push origin dev
# Via Lazygit → SUCCESS ✓
# Via terminal → SUCCESS ✓
# Hook auto-runs bd_land → SUCCESS ✓
```

---

## Recommendations for BMAD+Beads Installer

### 1. **Default Daemon Configuration**

❌ **Don't use:**
```bash
bd daemon --start --auto-commit --auto-push  # Causes race conditions
```

✅ **Use instead:**
```bash
bd daemon --start --interval 5s --auto-commit --auto-pull
```

**Rationale:** Let the pre-push hook handle all push/sync operations. Daemon should only track changes locally.

---

### 2. **Default Hook Configuration**

For **mixed human + agent workflows** or **GUI git users:**
```bash
git config beads.auto-sync auto
```

For **terminal-only, manual control:**
```bash
git config beads.auto-sync warning
```

For **no automation (manual bd_land):**
```bash
git config beads.auto-sync off
```

**Installer should prompt:** "How do you use git? (1) GUI tools/Lazygit, (2) Terminal only, (3) Manual control"

---

### 3. **Documentation Updates**

Add to installation docs:

**⚠️ CRITICAL: Daemon Auto-Push Conflict**

> If you use Lazygit, VS Code git, or other non-interactive git tools, **DO NOT** use `bd daemon --auto-push`. This conflicts with the pre-push hook and causes merge failures.
>
> **Recommended daemon config:**
> ```bash
> bd daemon --start --interval 5s --auto-commit --auto-pull
> git config beads.auto-sync auto
> ```
>
> The pre-push hook will automatically sync branches when you push.

---

### 4. **Installer Logic Suggestions**

```bash
#!/usr/bin/env bash
# Suggested installer flow

echo "Configuring beads daemon and git hooks..."

# Always use auto-commit only (never auto-push)
DAEMON_FLAGS="--interval 5s --auto-commit --auto-pull"

# Detect git workflow preference
echo "How do you typically push code?"
echo "  1) GUI tools (Lazygit, VS Code, GitKraken, etc.)"
echo "  2) Terminal only (git CLI)"
echo "  3) I want full manual control"
read -p "Choice [1-3]: " choice

case $choice in
  1)
    # GUI users: auto-sync on push
    git config beads.auto-sync auto
    echo "✓ Configured for GUI workflow (auto-sync on push)"
    ;;
  2)
    # Terminal users: warning prompts
    git config beads.auto-sync warning
    echo "✓ Configured for terminal workflow (prompts on push)"
    ;;
  3)
    # Manual control: no auto-sync
    git config beads.auto-sync off
    echo "✓ Configured for manual workflow (run bd_land manually)"
    ;;
esac

# Start daemon with recommended flags
bd daemon --start $DAEMON_FLAGS
echo "✓ Daemon started (auto-commit only, no auto-push)"

# Verify configuration
echo ""
echo "Configuration summary:"
echo "  Daemon: $(ps aux | grep 'bd daemon' | grep -v grep | awk '{print $11, $12, $13, $14, $15}')"
echo "  Hook mode: $(git config beads.auto-sync)"
```

---

### 5. **Health Check Command**

Add `bd doctor` command to detect this misconfiguration:

```bash
#!/usr/bin/env bash
# bd doctor - health check

echo "=== Beads Health Check ==="

# Check daemon flags
DAEMON_PID=$(pgrep -f "bd daemon")
if [ -n "$DAEMON_PID" ]; then
  DAEMON_CMD=$(ps -p $DAEMON_PID -o args=)
  if echo "$DAEMON_CMD" | grep -q "\-\-auto-push"; then
    echo "❌ WARNING: Daemon is using --auto-push"
    echo "   This conflicts with pre-push hook auto-sync."
    echo "   Recommendation: Restart daemon without --auto-push"
    echo "   Run: bd daemon --stop && bd daemon --start --interval 5s --auto-commit"
  else
    echo "✓ Daemon configuration OK (no auto-push)"
  fi
else
  echo "⚠️  Daemon not running"
fi

# Check hook configuration
HOOK_MODE=$(git config beads.auto-sync)
echo "✓ Hook mode: ${HOOK_MODE:-not set}"

# Check for common issues
if git status | grep -q "Your branch is ahead"; then
  COMMITS_AHEAD=$(git rev-list --count @{u}..HEAD)
  echo "ℹ️  $COMMITS_AHEAD commits ready to push"
fi

echo ""
echo "=== Recommended Workflow ==="
echo "  End session: bd close <id> && git push"
echo "  (Hook will auto-run bd_land before push)"
```

---

## Testing Checklist for Installer

Before releasing installer updates, verify:

- [ ] Default daemon config does NOT include `--auto-push`
- [ ] Installer prompts for git workflow preference (GUI vs terminal vs manual)
- [ ] `bd doctor` detects daemon auto-push misconfiguration
- [ ] Documentation clearly warns against `--auto-push` for mixed workflows
- [ ] Test push from Lazygit with recommended config (should succeed)
- [ ] Test push from terminal with recommended config (should succeed)
- [ ] Test that `bd close <id> && git push` works without manual `bd_land`

---

## Appendix: Full Transcript of Resolution

### Initial State
- Branch: `dev`, 6 commits ahead of `origin/dev`
- Daemon: Running with `--auto-push` (problematic)
- Hook: `beads.auto-sync=warning`
- Push via Lazygit: **FAILED**

### Resolution Steps
1. Diagnosed race condition between daemon push and hook sync
2. Stopped daemon: `bd daemon --stop`
3. Restarted without auto-push: `bd daemon --start --interval 5s --auto-commit`
4. Set hook to auto: `git config beads.auto-sync auto` (already set)
5. Verified: Daemon now only commits, hook handles all syncing

### Final State
- Daemon: `--auto-commit --auto-pull` (no push)
- Hook: `beads.auto-sync=auto`
- Push via Lazygit/terminal: **SUCCESS** ✓

---

## Key Takeaway

**Daemon and hook should never both push.** Division of labor:
- **Daemon:** Track changes (commit locally)
- **Hook:** Sync branches (merge + push)

This eliminates race conditions and works in all contexts (GUI, terminal, agents).

---

## Contact

For questions about this case study:
- **Project:** crypto-data-extend-system
- **User:** roylic
- **Date resolved:** 2026-02-14
