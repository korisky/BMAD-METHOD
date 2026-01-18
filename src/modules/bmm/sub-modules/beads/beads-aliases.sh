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

  # 4. Sync branches (beads-sync → main → current)
  echo "2. Syncing branches (beads-sync → main → $current_branch)..."
  echo ""

  # Fetch latest
  git fetch origin 2>/dev/null || true

  # Check if beads-sync exists
  if ! git rev-parse --verify beads-sync >/dev/null 2>&1; then
    echo "⚠️  beads-sync branch not found. Skipping branch sync."
    echo "  (This is normal if beads daemon isn't running)"
    return 0
  fi

  # Sync to main
  git checkout main || { echo "❌ Can't checkout main"; return 1; }

  if git merge beads-sync --no-ff -m "merge: sync beads tracking" 2>/dev/null; then
    echo "  ✅ main synced with beads-sync"
  else
    echo "  ℹ️  main already up to date"
  fi

  git push origin main 2>/dev/null || echo "  ⚠️  Can't push to origin/main (maybe protected?)"

  # Sync to current branch
  if [ "$current_branch" != "main" ]; then
    git checkout "$current_branch" || { echo "❌ Can't checkout $current_branch"; return 1; }

    if git merge main --no-ff -m "merge: sync from main" 2>/dev/null; then
      echo "  ✅ $current_branch synced with main"
    else
      echo "  ℹ️  $current_branch already up to date"
    fi

    git push origin "$current_branch" 2>/dev/null || echo "  ⚠️  Can't push to origin/$current_branch"
  fi

  echo ""
  echo "✅ All synced. Ready to continue working."
}

# ============================================
# HELP
# ============================================

bd-help() {
  echo "BMAD + Beads Integration Commands"
  echo ""
  echo "📋 SIMPLE WORKFLOW:"
  echo "  1. git add . && git commit -m '...' (auto-syncs beads)"
  echo "  2. bd-land (syncs branches: beads-sync → main → current)"
  echo "  3. git push"
  echo ""
  echo "STATUS:"
  echo "  bd-status        - Ready work + blockers"
  echo "  bd-next          - Ready work only"
  echo "  bd-blockers      - All blockers"
  echo "  bd-decisions     - All decisions"
  echo "  bd-halts         - Critical issues (P0)"
  echo "  bd-who           - Who's working on what"
  echo ""
  echo "CLAIMING:"
  echo "  bd-claim <story> - Claim a story"
  echo "  bd-release <id>  - Release a claim"
  echo ""
  echo "CREATE:"
  echo "  bd-halt <reason> - Create HALT (P0)"
  echo "  bd-decision <t>  - Create decision"
  echo "  bd-blocker <t>   - Create blocker"
  echo "  bd-action <t>    - Create action item"
  echo ""
  echo "SESSION:"
  echo "  bd-session-start - Full status check"
  echo "  bd-land          - Sync branches (run before push)"
  echo ""
  echo "📚 Documentation:"
  echo "  docs/beads-git-workflow.md (or ~/.bmad/beads-git-workflow.md)"
  echo ""
}

echo "BMAD+Beads aliases loaded. Run 'bd-help' for commands."
