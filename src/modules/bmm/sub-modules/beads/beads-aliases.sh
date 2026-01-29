#!/bin/bash
# BMAD + Beads Integration Aliases
# Source this file in your ~/.bashrc or ~/.zshrc:
#   source ~/.bmad/beads-aliases.sh

# ============================================
# QUICK STATUS COMMANDS
# ============================================

# See ready work + active blockers
alias bd-status='bd ready --pretty && echo "---" && bd list --type blocker --status open'

# See ready work only
alias bd-next='bd ready --pretty --limit 10'

# See all blockers
alias bd-blockers='bd list --type blocker --status open'

# See all decisions
alias bd-decisions='bd list --type decision --status open'

# See HALTs (priority 0)
alias bd-halts='bd list --type blocker --priority 0 --status open'

# See who's working on what
alias bd-who='bd list --type task --status in_progress'

# ============================================
# WORK CLAIMING
# ============================================

# Claim a story before starting work
# Usage: bd-claim "1-2-user-auth"
bd-claim() {
  local story="$1"
  if [ -z "$story" ]; then
    echo "Usage: bd-claim <story-key>"
    return 1
  fi

  # Check if already claimed
  local existing=$(bd list --type task --status in_progress --title "Working: $story" 2>/dev/null | head -1)
  if [ -n "$existing" ]; then
    echo "Story already claimed: $existing"
    return 1
  fi

  # Create claim
  local id=$(bd q "Working: $story" --type task --priority 1 --silent 2>/dev/null)
  if [ -z "$id" ]; then
    echo "Failed to create claim"
    return 1
  fi

  # Update status
  bd update "$id" --status in_progress --notes "AGENT: $(whoami) | STARTED: $(date +%Y-%m-%dT%H:%M:%S%z)" >/dev/null
  echo "Claimed: $id ($story)"
}

# Release a claim when done
# Usage: bd-release <id>
bd-release() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "Usage: bd-release <id>"
    return 1
  fi
  bd close "$id" --reason "Done"
}

# Mark work as done (syncs BMAD completion to Beads)
# Usage: bd-done "1-2-user-auth" or bd-done "epic-2"
bd-done() {
  local key="$1"
  [ -z "$key" ] && echo "Usage: bd-done <story-key|epic-key>" && return 1

  # Close all open tasks containing this key
  bd search "$key" --status open --type task --format '{{.ID}}' --limit 0 2>/dev/null | \
    while read -r id; do
      [ -n "$id" ] && bd close "$id" --reason "Completed: $key" 2>/dev/null && echo "  Closed: $id"
    done

  # Create completion marker
  local marker=$(bd q "Done: $key" --type task --priority 3 --silent 2>/dev/null)
  [ -n "$marker" ] && bd close "$marker" --reason "Completed per BMAD workflow" 2>/dev/null
  echo "✅ Marked done: $key"
}

# ============================================
# QUICK CREATE COMMANDS
# ============================================

# Create a HALT (priority 0 blocker)
# Usage: bd-halt "3 consecutive test failures"
bd-halt() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd-halt <reason>"
    return 1
  fi
  local id=$(bd q "HALT: $title" --type blocker --priority 0 --silent)
  echo "Created HALT: $id"
  echo "Add notes with: bd update $id --notes \"STORY: X | WORKFLOW: Y | DETAILS: Z\""
}

# Create a runtime decision
# Usage: bd-decision "Use Redis for sessions"
bd-decision() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd-decision <title>"
    return 1
  fi
  local id=$(bd q "Runtime: $title" --type decision --priority 2 --silent)
  echo "Created decision: $id"
  echo "Add notes with: bd update $id --notes \"WHO: X | WHAT: Y | WHY: Z | DOC: path\""
}

# Create a blocker
# Usage: bd-blocker "Waiting on API credentials"
bd-blocker() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd-blocker <title>"
    return 1
  fi
  local id=$(bd q "Blocked: $title" --type blocker --priority 1 --silent)
  echo "Created blocker: $id"
  echo "Add notes with: bd update $id --notes \"AFFECTS: X | OWNER: Y | ETA: Z\""
}

# Create an action item
# Usage: bd-action "Refactor auth module"
bd-action() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd-action <title>"
    return 1
  fi
  local id=$(bd q "Action: $title" --type task --priority 2 --silent)
  echo "Created action: $id"
  echo "Add notes with: bd update $id --notes \"FROM: Epic X | OWNER: Y | DUE: Z\""
}

# ============================================
# QUICK COMMIT (Human-Agent Mixed Workflow)
# ============================================

# Quick commit - skips heavy tests, runs lint-staged + beads sync only
# Usage: bd-quick "wip: iteration message"
bd-quick() {
  local msg="$1"
  if [ -z "$msg" ]; then
    echo "Usage: bd-quick <commit-message>"
    echo "  Runs lint-staged + beads sync, skips full test suite"
    return 1
  fi
  BMAD_QUICK=1 git commit -m "$msg"
}

# Quick add and commit
# Usage: bd-qadd "wip: iteration"
bd-qadd() {
  local msg="$1"
  if [ -z "$msg" ]; then
    echo "Usage: bd-qadd <commit-message>"
    echo "  Stages all changes, then quick commits"
    return 1
  fi
  git add -A && BMAD_QUICK=1 git commit -m "$msg"
}

# ============================================
# SESSION HELPERS
# ============================================

# Full session start check
bd-session-start() {
  echo "=== BEADS SESSION STATUS ==="
  echo ""
  echo "HALTs (must resolve first):"
  bd list --type blocker --priority 0 --status open 2>/dev/null || echo "  None"
  echo ""
  echo "Active blockers:"
  bd list --type blocker --status open 2>/dev/null || echo "  None"
  echo ""
  echo "Pending decisions:"
  bd list --type decision --status open 2>/dev/null || echo "  None"
  echo ""
  echo "Currently claimed work:"
  bd list --type task --status in_progress 2>/dev/null || echo "  None"
  echo ""
  echo "Ready work:"
  bd ready --pretty --limit 5 2>/dev/null || echo "  None"
  echo ""
  echo "==========================="
}

# Land the plane - session end helper with branch sync
bd-land() {
  echo "=== LANDING THE PLANE ==="
  echo ""

  local current_branch=$(git branch --show-current)

  # Detect default branch (main or master)
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  default_branch=${default_branch:-main}

  # 1. Check open claims
  echo "1. Checking for open claims..."
  local claims=$(bd list --type task --status in_progress 2>/dev/null)
  if [ -n "$claims" ]; then
    echo "$claims"
    echo ""
    echo "⚠️  You have open claims. Release them with: bd-release <id>"
    echo ""
  else
    echo "  None"
    echo ""
  fi

  # 2. Check if we're in a git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    return 1
  fi

  # 3. Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  You have uncommitted changes. Commit first:"
    echo "  git add . && git commit -m '...'"
    echo ""
    echo "Note: Pre-commit hook will auto-sync beads on commit"
    return 1
  fi

  # 4. Sync branches (beads-sync → default → current)
  echo "2. Syncing branches (beads-sync → $default_branch → $current_branch)..."
  echo ""

  # Fetch latest
  git fetch origin 2>/dev/null || true

  # Check if beads-sync exists
  if ! git rev-parse --verify beads-sync >/dev/null 2>&1; then
    echo "⚠️  beads-sync branch not found. Skipping branch sync."
    echo "  (This is normal if beads daemon isn't running)"
    return 0
  fi

  # Sync to default branch (main/master)
  git checkout "$default_branch" || { echo "❌ Can't checkout $default_branch"; return 1; }

  if git merge beads-sync --no-ff -m "merge: sync beads tracking" 2>/dev/null; then
    echo "  ✅ $default_branch synced with beads-sync"
  else
    echo "  ℹ️  $default_branch already up to date"
  fi

  git push origin "$default_branch" 2>/dev/null || echo "  ⚠️  Can't push to origin/$default_branch (maybe protected?)"

  # Sync to current branch
  if [ "$current_branch" != "$default_branch" ]; then
    git checkout "$current_branch" || { echo "❌ Can't checkout $current_branch"; return 1; }

    if git merge "$default_branch" --no-ff -m "merge: sync from $default_branch" 2>/dev/null; then
      echo "  ✅ $current_branch synced with $default_branch"
    else
      echo "  ℹ️  $current_branch already up to date"
    fi

    git push origin "$current_branch" 2>/dev/null || echo "  ⚠️  Can't push to origin/$current_branch"
  fi

  echo ""
  echo "✅ All synced. Ready to continue working."
}

# ============================================
# OPTIONAL AUTOMATION
# ============================================

# Configure auto-sync behavior
# Usage: bd-config-sync <mode>
# Modes: warning (default), block, auto, off
bd-config-sync() {
  local mode="$1"
  if [ -z "$mode" ]; then
    local current=$(git config beads.auto-sync 2>/dev/null || echo "warning")
    echo "Current auto-sync mode: $current"
    echo ""
    echo "Usage: bd-config-sync <mode>"
    echo ""
    echo "Available modes:"
    echo "  warning  - Ask before syncing (default)"
    echo "  block    - Refuse push until synced"
    echo "  auto     - Auto-sync without asking"
    echo "  off      - Disable auto-sync checks"
    return 0
  fi

  case "$mode" in
    warning|block|auto|off)
      git config beads.auto-sync "$mode"
      echo "✅ Auto-sync mode set to: $mode"
      ;;
    *)
      echo "❌ Invalid mode: $mode"
      echo "   Valid modes: warning, block, auto, off"
      return 1
      ;;
  esac
}

# Smart pre-push sync with config support
# Returns 0 if safe to push, 1 if blocked
bd-auto-land() {
  # Check if beads-sync exists
  if ! git rev-parse --verify beads-sync >/dev/null 2>&1; then
    return 0  # No beads-sync = no sync needed
  fi

  # Detect default branch
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  default_branch=${default_branch:-main}

  # Check divergence
  local ahead=$(git rev-list --count ${default_branch}..beads-sync 2>/dev/null || echo 0)

  if [ "$ahead" -eq 0 ]; then
    return 0  # Already synced
  fi

  # Get config mode
  local mode=$(git config beads.auto-sync 2>/dev/null || echo "warning")

  case "$mode" in
    off)
      # Skip check entirely
      return 0
      ;;
    auto)
      # Auto-sync without asking
      echo "🔄 Auto-syncing branches (beads-sync is $ahead commits ahead)..."
      bd-land
      return $?
      ;;
    block)
      # Refuse push until synced
      echo "❌ Push blocked: beads-sync is $ahead commits ahead of $default_branch"
      echo "   Run: bd-land"
      echo "   Or change mode: bd-config-sync warning"
      return 1
      ;;
    warning|*)
      # Ask before syncing (default)
      echo "⚠️  beads-sync is $ahead commit(s) ahead of $default_branch"
      echo ""
      read -p "Run bd-land to sync branches? [y/N] " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        bd-land
        return $?
      else
        echo "Push cancelled. Run 'bd-land' manually when ready."
        return 1
      fi
      ;;
  esac
}

# Silent background sync wrapper (for post-commit hook)
# Logs to ~/.bmad/sync.log for debugging
bd-auto-sync() {
  local log_file="$HOME/.bmad/sync.log"
  mkdir -p "$(dirname "$log_file")"

  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="

    # Only sync if beads-sync exists
    if ! git rev-parse --verify beads-sync >/dev/null 2>&1; then
      echo "Skip: beads-sync branch not found"
      return 0
    fi

    # Check divergence
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    default_branch=${default_branch:-main}
    local ahead=$(git rev-list --count ${default_branch}..beads-sync 2>/dev/null || echo 0)

    if [ "$ahead" -eq 0 ]; then
      echo "Skip: branches already synced"
      return 0
    fi

    echo "Syncing: beads-sync is $ahead commits ahead"
    bd-land 2>&1
    echo "Complete: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$log_file" 2>&1
}

# ============================================
# PRE-PUSH CHECK
# ============================================

# Health diagnostic - check project + beads status
bd-health() {
  echo "=== BEADS HEALTH CHECK ==="
  local issues=0

  # 1. Check if in git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    return 1
  fi

  # 2. Check if beads initialized
  if [ ! -d ".beads" ]; then
    echo "⚠️  Beads not initialized in this project"
    echo "   Run: bd init"
    return 1
  fi

  # 3. Check daemon status
  echo ""
  echo "Daemon Status:"
  if command -v bd >/dev/null 2>&1; then
    if bd stats 2>/dev/null; then
      echo "  ✅ Daemon running"
    else
      echo "  ⚠️  Daemon not running or not responding"
      echo "     Run: bd daemon start"
      ((issues++))
    fi
  else
    echo "  ❌ bd CLI not found"
    return 1
  fi

  # 4. Check branch divergence (if beads-sync exists)
  echo ""
  echo "Branch Sync Status:"
  if git rev-parse --verify beads-sync >/dev/null 2>&1; then
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    default_branch=${default_branch:-main}

    local ahead=$(git rev-list --count ${default_branch}..beads-sync 2>/dev/null || echo 0)
    local behind=$(git rev-list --count beads-sync..${default_branch} 2>/dev/null || echo 0)

    if [ "$ahead" -gt 0 ]; then
      echo "  ⚠️  beads-sync is $ahead commit(s) ahead of $default_branch"
      echo "     Run: bd-land (to sync branches)"
      ((issues++))
    elif [ "$behind" -gt 0 ]; then
      echo "  ⚠️  beads-sync is $behind commit(s) behind $default_branch"
      echo "     (This is unusual - beads-sync should be auto-updated)"
      ((issues++))
    else
      echo "  ✅ Branches in sync"
    fi
  else
    echo "  ⚠️  beads-sync branch not found"
    echo "     (Normal if daemon hasn't created it yet)"
  fi

  # 5. Check active claims
  echo ""
  echo "Active Work Claims:"
  if command -v bd >/dev/null 2>&1; then
    local claims=$(bd list --type task --status in_progress 2>/dev/null | grep -v "^$")
    if [ -n "$claims" ]; then
      echo "$claims"
      echo "  ℹ️  Remember to release claims when done: bd-release <id>"
    else
      echo "  ✅ No active claims"
    fi
  fi

  # 6. Check for open HALTs
  echo ""
  echo "Critical Issues (HALTs):"
  if command -v bd >/dev/null 2>&1; then
    local halts=$(bd list --type blocker --priority 0 --status open 2>/dev/null | grep -v "^$")
    if [ -n "$halts" ]; then
      echo "$halts"
      echo "  ⚠️  HALTs must be resolved before proceeding"
      ((issues++))
    else
      echo "  ✅ No HALTs"
    fi
  fi

  # Summary
  echo ""
  echo "==========================="
  if [ "$issues" -eq 0 ]; then
    echo "✅ System healthy"
    return 0
  else
    echo "⚠️  Found $issues issue(s) - review above"
    return 1
  fi
}

# Check if ready to push (for humans and agents)
bd-preflight() {
  echo "=== Pre-Push Checklist ==="
  local ok=true

  # 1. Uncommitted changes?
  if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Uncommitted changes (commit first)"
    ok=false
  else
    echo "✅ Working tree clean"
  fi

  # 2. Branch sync status (only if beads-sync exists)
  if git rev-parse --verify beads-sync >/dev/null 2>&1; then
    git fetch origin 2>/dev/null || true
    local behind=$(git rev-list --count main..beads-sync 2>/dev/null || echo 0)
    if [ "$behind" -gt 0 ]; then
      echo "❌ beads-sync has $behind commits not in main (run bd-land)"
      ok=false
    else
      echo "✅ Branches synced"
    fi
  else
    echo "⚠️  No beads-sync branch (daemon not running - this is OK for solo work)"
  fi

  # 3. Open claims?
  if command -v bd >/dev/null 2>&1; then
    local claims=$(bd list --type task --status in_progress 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$claims" ]; then
      echo "⚠️  Open claims exist (consider releasing with bd-release)"
    else
      echo "✅ No open claims"
    fi
  fi

  # Verdict
  echo ""
  if [ "$ok" = true ]; then
    echo "✅ Ready to push: git push"
    return 0
  else
    echo "❌ Not ready. Fix issues above."
    echo "   Then run: bd-preflight"
    return 1
  fi
}

# ============================================
# AUTO-RECOVERY
# ============================================

# Attempt to auto-fix common beads issues
bd-fix() {
  echo "=== Auto-Fix Attempt ==="
  local fixed=false

  # 1. Check if beads-sync worktree is on wrong branch
  if [ -d ".git/beads-worktrees/beads-sync" ]; then
    local wt_branch=$(git -C .git/beads-worktrees/beads-sync branch --show-current 2>/dev/null)
    if [ -n "$wt_branch" ] && [ "$wt_branch" != "beads-sync" ]; then
      echo "Fixing: worktree on wrong branch ($wt_branch → beads-sync)"
      git -C .git/beads-worktrees/beads-sync checkout beads-sync 2>/dev/null && fixed=true
    fi
  fi

  # 2. Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  You have uncommitted changes. Commit them first:"
    echo "   git add . && git commit -m 'your message'"
    return 1
  fi

  # 3. Try bd-land to sync branches
  echo "Running bd-land to sync branches..."
  if bd-land; then
    echo ""
    echo "✅ Fixed! Run bd-preflight to verify."
    return 0
  else
    echo ""
    echo "❌ Auto-fix couldn't resolve all issues."
    echo "   See: docs/beads-git-workflow.md for manual recovery"
    return 1
  fi
}

# ============================================
# HELP
# ============================================

bd-help() {
  echo "BMAD + Beads Integration Commands"
  echo ""
  echo "📋 SIMPLE WORKFLOW:"
  echo "  1. Work & commit normally (hook auto-syncs beads)"
  echo "  2. bd-preflight  → check if ready to push"
  echo "  3. If ❌: bd-land → sync branches, then bd-preflight again"
  echo "  4. If ✅: git push"
  echo ""
  echo "🔧 CORE COMMANDS:"
  echo "  bd-preflight     - Check if ready to push (run this!)"
  echo "  bd-health        - Comprehensive health check (daemon, branches, claims)"
  echo "  bd-land          - Sync branches (beads-sync → main → current)"
  echo "  bd-fix           - Auto-fix common issues"
  echo ""
  echo "⚙️  AUTO-SYNC CONFIG:"
  echo "  bd-config-sync <mode>  - Configure auto-sync behavior"
  echo "    Modes: warning (ask), block (refuse), auto (always), off (disable)"
  echo "  Current: $(git config beads.auto-sync 2>/dev/null || echo 'warning')"
  echo ""
  echo "⚡ QUICK COMMITS (human-agent mixed workflow):"
  echo "  bd-quick <msg>   - Commit with lint-staged only (skip tests)"
  echo "  bd-qadd <msg>    - Stage all + quick commit"
  echo ""
  echo "STATUS:"
  echo "  bd-status        - Ready work + blockers"
  echo "  bd-next          - Ready work only"
  echo "  bd-blockers      - All blockers"
  echo "  bd-halts         - Critical issues (P0)"
  echo ""
  echo "CLAIMING:"
  echo "  bd-claim <story> - Claim a story before starting"
  echo "  bd-release <id>  - Release a claim when done"
  echo ""
  echo "CREATE:"
  echo "  bd-halt <reason> - Create HALT (P0 blocker)"
  echo "  bd-decision <t>  - Create runtime decision"
  echo "  bd-blocker <t>   - Create blocker"
  echo "  bd-action <t>    - Create action item"
  echo ""
  echo "📚 Documentation:"
  echo "  docs/beads-git-workflow.md"
  echo ""
}

echo "BMAD+Beads aliases loaded. Run 'bd-help' for commands."
