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
  bd update "$id" --status in_progress --notes "AGENT: $(whoami) | STARTED: $(date -Iseconds)" >/dev/null
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

# Land the plane - session end helper
bd-land() {
  echo "=== LANDING THE PLANE ==="
  echo ""
  echo "1. Checking for open claims..."
  bd list --type task --status in_progress
  echo ""
  echo "2. Syncing Beads..."
  bd sync
  echo ""
  echo "3. Now run: git add -A && git commit && git push"
  echo ""
}

# ============================================
# HELP
# ============================================

bd-help() {
  echo "BMAD + Beads Integration Commands"
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
  echo "  bd-land          - Land the plane helper"
  echo ""
}

echo "BMAD+Beads aliases loaded. Run 'bd-help' for commands."
