#!/bin/bash
# BMAD + Beads Integration Aliases
# Installed to: .beads/lib/bmad-aliases.sh (project-local)
# Available in git hooks automatically
# For shell usage, manually source:
#   source .beads/lib/bmad-aliases.sh

# ============================================
# QUICK STATUS COMMANDS
# ============================================

# See ready work + active blockers
alias bd_status='bd ready --pretty && echo "---" && bd list --type blocker --status open'

# See ready work only
alias bd_next='bd ready --pretty --limit 10'

# See all blockers
alias bd_blockers='bd list --type blocker --status open'

# See all decisions
alias bd_decisions='bd list --type decision --status open'

# See HALTs (priority 0)
alias bd_halts='bd list --type blocker --priority 0 --status open'

# See who's working on what
alias bd_who='bd list --type task --status in_progress'

# ============================================
# INTERNAL HELPER FUNCTIONS
# ============================================

# Get the default branch (main/master)
# Used by: bd_land, bd_auto_land, bd_auto_sync, bd_health
_bmad_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
}

# Check divergence between branches
# Args: from_branch to_branch
# Returns: number of commits ahead
_bmad_check_divergence() {
  local from_branch="${1:-main}"
  local to_branch="${2:-beads-sync}"
  git rev-list --count "$from_branch..$to_branch" 2>/dev/null || echo 0
}

# Check if a branch exists
# Args: branch_name
# Returns: 0 if exists, 1 if not
_bmad_branch_exists() {
  git rev-parse --verify "$1" >/dev/null 2>&1
}

# ============================================
# WORK CLAIMING
# ============================================

# Claim a story before starting work
# Usage: bd_claim "1-2-user-auth"
bd_claim() {
  local story="$1"
  if [ -z "$story" ]; then
    echo "Usage: bd_claim <story-key>"
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
# Usage: bd_release <id>
bd_release() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "Usage: bd_release <id>"
    return 1
  fi
  bd close "$id" --reason "Done"
}

# Mark work as done (syncs BMAD completion to Beads)
# Usage: bd_done "1-2-user-auth" or bd_done "epic-2"
bd_done() {
  local key="$1"
  [ -z "$key" ] && echo "Usage: bd_done <story-key|epic-key>" && return 1

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
# Usage: bd_halt "3 consecutive test failures"
bd_halt() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd_halt <reason>"
    return 1
  fi
  local id=$(bd q "HALT: $title" --type blocker --priority 0 --silent)
  echo "Created HALT: $id"
  echo "Add notes with: bd update $id --notes \"STORY: X | WORKFLOW: Y | DETAILS: Z\""
}

# Create a runtime decision
# Usage: bd_decision "Use Redis for sessions"
bd_decision() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd_decision <title>"
    return 1
  fi
  local id=$(bd q "Runtime: $title" --type decision --priority 2 --silent)
  echo "Created decision: $id"
  echo "Add notes with: bd update $id --notes \"WHO: X | WHAT: Y | WHY: Z | DOC: path\""
}

# Create a blocker
# Usage: bd_blocker "Waiting on API credentials"
bd_blocker() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd_blocker <title>"
    return 1
  fi
  local id=$(bd q "Blocked: $title" --type blocker --priority 1 --silent)
  echo "Created blocker: $id"
  echo "Add notes with: bd update $id --notes \"AFFECTS: X | OWNER: Y | ETA: Z\""
}

# Create an action item
# Usage: bd_action "Refactor auth module"
bd_action() {
  local title="$1"
  if [ -z "$title" ]; then
    echo "Usage: bd_action <title>"
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
# Usage: bd_quick "wip: iteration message"
bd_quick() {
  local msg="$1"
  if [ -z "$msg" ]; then
    echo "Usage: bd_quick <commit-message>"
    echo "  Runs lint-staged + beads sync, skips full test suite"
    return 1
  fi
  BMAD_QUICK=1 git commit -m "$msg"
}

# Quick add and commit
# Usage: bd_qadd "wip: iteration"
bd_qadd() {
  local msg="$1"
  if [ -z "$msg" ]; then
    echo "Usage: bd_qadd <commit-message>"
    echo "  Stages all changes, then quick commits"
    return 1
  fi
  git add -A && BMAD_QUICK=1 git commit -m "$msg"
}

# ============================================
# SESSION HELPERS
# ============================================

# Full session start check
bd_session_start() {
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
bd_land() {
  echo "=== LANDING THE PLANE ==="
  echo ""

  local current_branch=$(git branch --show-current)

  # Detect default branch (main or master)
  local default_branch=$(_bmad_default_branch)

  # 1. Check open claims
  echo "1. Checking for open claims..."
  local claims=$(bd list --type task --status in_progress 2>/dev/null)
  if [ -n "$claims" ]; then
    echo "$claims"
    echo ""
    echo "⚠️  You have open claims. Release them with: bd_release <id>"
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
  if ! _bmad_branch_exists beads-sync; then
    echo "⚠️  beads-sync branch not found. Skipping branch sync."
    echo "  (This is normal if beads daemon isn't running)"
    return 0
  fi

  # Sync to default branch (main/master)
  git checkout "$default_branch" || { echo "❌ Can't checkout $default_branch"; return 1; }

  if git merge beads-sync --ff-only 2>&1; then
    echo "  ✅ $default_branch synced with beads-sync"
  else
    # Check if up-to-date or actual error (divergence)
    if git merge-base --is-ancestor beads-sync "$default_branch" 2>/dev/null; then
      echo "  ℹ️  $default_branch already up to date"
    else
      echo "  ❌ Cannot fast-forward. Branches diverged."
      echo "     Diagnosis: git log $default_branch..beads-sync"
      echo "     Recovery: bd-fix divergence"
      return 1
    fi
  fi

  git push origin "$default_branch" 2>/dev/null || echo "  ⚠️  Can't push to origin/$default_branch (maybe protected?)"

  # Sync to current branch
  if [ "$current_branch" != "$default_branch" ]; then
    git checkout "$current_branch" || { echo "❌ Can't checkout $current_branch"; return 1; }

    if git merge "$default_branch" --no-ff -m "merge: sync from $default_branch" 2>/dev/null; then
      echo "  ✅ $current_branch synced with $default_branch"
    else
      # Check if up-to-date or actual error
      if git merge-base --is-ancestor "$default_branch" "$current_branch" 2>/dev/null; then
        echo "  ℹ️  $current_branch already up to date"
      else
        echo "  ⚠️  Cannot merge $default_branch into $current_branch"
        echo "     This may indicate merge conflicts or divergence"
        echo "     Recovery: bd-fix divergence"
        return 1
      fi
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
# Usage: bd_config_sync <mode>
# Modes: warning (default), block, auto, off
bd_config_sync() {
  local mode="$1"
  if [ -z "$mode" ]; then
    local current=$(git config beads.auto-sync 2>/dev/null || echo "warning")
    echo "Current auto-sync mode: $current"
    echo ""
    echo "Usage: bd_config_sync <mode>"
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
bd_auto_land() {
  # Check if beads-sync exists
  if ! _bmad_branch_exists beads-sync; then
    return 0  # No beads-sync = no sync needed
  fi

  # Detect default branch
  local default_branch=$(_bmad_default_branch)

  # Check divergence
  local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)

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
      bd_land
      return $?
      ;;
    block)
      # Refuse push until synced
      echo "❌ Push blocked: beads-sync is $ahead commits ahead of $default_branch"
      echo "   Run: bd_land"
      echo "   Or change mode: bd_config_sync warning"
      return 1
      ;;
    warning|*)
      # Ask before syncing (default)
      echo "⚠️  beads-sync is $ahead commit(s) ahead of $default_branch"
      echo ""
      read -p "Run bd_land to sync branches? [y/N] " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        bd_land
        return $?
      else
        echo "Push cancelled. Run 'bd_land' manually when ready."
        return 1
      fi
      ;;
  esac
}

# Silent background sync wrapper (for post-commit hook)
# Logs to .beads/logs/sync.log for debugging
bd_auto_sync() {
  local log_file=".beads/logs/sync.log"
  local pid_file=".beads/tmp/.sync.pid"
  mkdir -p .beads/logs .beads/tmp

  # Check if another sync is running (inspired by bd-claim pattern)
  if [ -f "$pid_file" ]; then
    local existing_pid=$(cat "$pid_file" 2>/dev/null)
    if [ -n "$existing_pid" ] && ps -p "$existing_pid" > /dev/null 2>&1; then
      {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Skip: sync already running (PID: $existing_pid)"
      } >> "$log_file" 2>&1
      return 0
    fi
  fi

  # Create PID file
  echo $$ > "$pid_file"
  trap "rm -f '$pid_file'" EXIT INT TERM

  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="

    # Only sync if beads-sync exists
    if ! _bmad_branch_exists beads-sync; then
      echo "Skip: beads-sync branch not found"
      return 0
    fi

    # Check divergence
    local default_branch=$(_bmad_default_branch)
    local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)

    if [ "$ahead" -eq 0 ]; then
      echo "Skip: branches already synced"
      return 0
    fi

    echo "Syncing: beads-sync is $ahead commits ahead"
    bd_land 2>&1
    echo "Complete: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$log_file" 2>&1

  # Rotate log if too large (keep last 1000 lines)
  if [ -f "$log_file" ] && [ $(wc -l < "$log_file") -gt 1500 ]; then
    tail -1000 "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
  fi
}

# ============================================
# PRE-PUSH CHECK
# ============================================

# Health diagnostic - check project + beads status
bd_health() {
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
  if _bmad_branch_exists beads-sync; then
    local default_branch=$(_bmad_default_branch)

    local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)
    local behind=$(_bmad_check_divergence beads-sync "$default_branch")

    if [ "$ahead" -gt 0 ]; then
      echo "  ⚠️  beads-sync is $ahead commit(s) ahead of $default_branch"
      echo "     Run: bd_land (to sync branches)"
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
      echo "  ℹ️  Remember to release claims when done: bd_release <id>"
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

  # 7. Check config location
  echo ""
  echo "Configuration:"
  if [ -f .beads/lib/bmad-aliases.sh ]; then
    echo "  ✅ Using project-local config (.beads/lib/)"
    if [ -f .beads/.bmad-version ]; then
      local version=$(cat .beads/.bmad-version)
      echo "     Version: $version"
    fi
  else
    echo "  ❌ No config found"
    echo "     Run installer: bash <path>/install.sh"
    ((issues++))
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
bd_preflight() {
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
  if _bmad_branch_exists beads-sync; then
    git fetch origin 2>/dev/null || true
    local default_branch=$(_bmad_default_branch)
    local behind=$(_bmad_check_divergence "$default_branch" beads-sync)
    if [ "$behind" -gt 0 ]; then
      echo "❌ beads-sync has $behind commits not in $default_branch (run bd_land)"
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
      echo "⚠️  Open claims exist (consider releasing with bd_release)"
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
    echo "   Then run: bd_preflight"
    return 1
  fi
}

# ============================================
# AUTO-RECOVERY
# ============================================

# Attempt to auto-fix common beads issues
bd_fix() {
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

  # 3. Try bd_land to sync branches
  echo "Running bd_land to sync branches..."
  if bd_land; then
    echo ""
    echo "✅ Fixed! Run bd_preflight to verify."
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

bd_help() {
  echo "BMAD + Beads Integration Commands"
  echo ""
  echo "📋 SIMPLE WORKFLOW:"
  echo "  1. Work & commit normally (hook auto-syncs beads)"
  echo "  2. bd_preflight  → check if ready to push"
  echo "  3. If ❌: bd_land → sync branches, then bd_preflight again"
  echo "  4. If ✅: git push"
  echo ""
  echo "🔧 CORE COMMANDS:"
  echo "  bd_preflight     - Check if ready to push (run this!)"
  echo "  bd_health        - Comprehensive health check (daemon, branches, claims)"
  echo "  bd_land          - Sync branches (beads-sync → main → current)"
  echo "  bd_fix           - Auto-fix common issues"
  echo ""
  echo "🩹 TROUBLESHOOTING / RECOVERY:"
  echo "  When bd_land fails with '❌ Cannot fast-forward. Branches diverged':"
  echo "    1. bd_health           → Diagnose divergence (see commit counts)"
  echo "    2. bd_fix divergence   → Auto-recovery (recommended)"
  echo "    3. Manual recovery     → See docs/beads-git-workflow.md"
  echo ""
  echo "  Common recovery commands:"
  echo "    bd_health              → Check branch sync status"
  echo "    bd_fix                 → Auto-fix common issues"
  echo "    git log main..beads-sync       → See what's ahead"
  echo "    git merge beads-sync --no-ff  → Manual merge (if auto-fix fails)"
  echo ""
  echo "⚙️  AUTO-SYNC CONFIG:"
  echo "  bd_config_sync <mode>  - Configure auto-sync behavior"
  echo "    Modes: warning (ask), block (refuse), auto (always), off (disable)"
  echo "  Current: $(git config beads.auto-sync 2>/dev/null || echo 'warning')"
  echo ""
  echo "⚡ QUICK COMMITS (human-agent mixed workflow):"
  echo "  bd_quick <msg>   - Commit with lint-staged only (skip tests)"
  echo "  bd_qadd <msg>    - Stage all + quick commit"
  echo ""
  echo "STATUS:"
  echo "  bd_status        - Ready work + blockers"
  echo "  bd_next          - Ready work only"
  echo "  bd_blockers      - All blockers"
  echo "  bd_halts         - Critical issues (P0)"
  echo ""
  echo "CLAIMING:"
  echo "  bd_claim <story> - Claim a story before starting"
  echo "  bd_release <id>  - Release a claim when done"
  echo ""
  echo "CREATE:"
  echo "  bd_halt <reason> - Create HALT (P0 blocker)"
  echo "  bd_decision <t>  - Create runtime decision"
  echo "  bd_blocker <t>   - Create blocker"
  echo "  bd_action <t>    - Create action item"
  echo ""
  echo "📚 Documentation:"
  echo "  docs/beads-git-workflow.md"
  echo ""
}

# ============================================
# DEPRECATED: Backward Compatibility Aliases
# ============================================
# Support for old hyphenated names (will be removed in v3.0)

alias bd-status='bd_status'
alias bd-next='bd_next'
alias bd-blockers='bd_blockers'
alias bd-decisions='bd_decisions'
alias bd-halts='bd_halts'
alias bd-who='bd_who'
alias bd-claim='bd_claim'
alias bd-release='bd_release'
alias bd-done='bd_done'
alias bd-halt='bd_halt'
alias bd-decision='bd_decision'
alias bd-blocker='bd_blocker'
alias bd-action='bd_action'
alias bd-quick='bd_quick'
alias bd-qadd='bd_qadd'
alias bd-session-start='bd_session_start'
alias bd-land='bd_land'
alias bd-config-sync='bd_config_sync'
alias bd-auto-land='bd_auto_land'
alias bd-auto-sync='bd_auto_sync'
alias bd-health='bd_health'
alias bd-preflight='bd_preflight'
alias bd-fix='bd_fix'
alias bd-help='bd_help'

echo "BMAD+Beads aliases loaded. Run 'bd_help' for commands."
