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
# STORY → BEADS SYNC
# ============================================

# ============================================
# STORY SYNC HELPERS (Internal)
# ============================================

# Normalize checkbox line for hashing
# Input: "  -  [ ]  [AI-Review][HIGH]  Description  "
# Output: "[AI-Review][HIGH] Description"
_normalize_line() {
  local line="$1"
  echo "$line" | sed -e 's/^[[:space:]]*//' \
                      -e 's/^-[[:space:]]*\[[[:space:]]\][[:space:]]*//' \
                      -e 's/[[:space:]]*$//' | \
                 tr -s ' ' | \
                 sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Generate short hash (first 16 chars of SHA-256)
_generate_hash() {
  local normalized="$1"
  echo "$normalized" | shasum -a 256 | cut -c1-16
}

# Check if task already exists in Beads
# Returns: 0 (exists), 1 (not exists)
_task_exists() {
  local story_key="$1"
  local hash="$2"
  local description="$3"

  # Method 1: Check by hash (new method)
  local query="Story: $story_key | Hash: $hash"
  local found=$(bd search "$query" --status open --type task --limit 1 2>/dev/null)

  if [ -n "$found" ]; then
    return 0  # Exists (hash match)
  fi

  # Method 2: Fallback for legacy tasks (no hash in notes)
  # This provides backward compatibility with existing tasks
  found=$(bd search "$description" --status open --type task 2>/dev/null | \
          grep "Story: $story_key" | head -1)

  if [ -n "$found" ]; then
    # Found legacy task - auto-upgrade with hash
    local task_id=$(echo "$found" | awk '{print $1}')
    bd update "$task_id" --notes "Story: $story_key | Hash: $hash" 2>/dev/null
    return 0  # Exists (upgraded)
  fi

  return 1  # Not exists
}

# Extract priority from checkbox line (refactored)
_extract_priority() {
  local line="$1"
  local priority=2  # Default: LOW

  if echo "$line" | grep -q '\[HIGH\]'; then
    priority=0
  elif echo "$line" | grep -q '\[MEDIUM\]'; then
    priority=1
  fi

  echo "$priority"
}

# Extract description from checkbox line (refactored)
_extract_description() {
  local line="$1"
  echo "$line" | sed -e 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]\][[:space:]]*//' \
                     -e 's/\[AI-Review\][[:space:]]*//' \
                     -e 's/\[HIGH\][[:space:]]*//' \
                     -e 's/\[MEDIUM\][[:space:]]*//' \
                     -e 's/\[LOW\][[:space:]]*//' \
                     -e 's/^[[:space:]]*//' \
                     -e 's/[[:space:]]*$//' | \
                 tr -s ' ' | \
                 sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Sync story file AI-Review items to Beads tasks
# Usage: bd_sync_story <story-file>
# Parses: - [ ] [AI-Review][HIGH|MEDIUM|LOW] Description
# Creates matching Beads tasks with correct priorities
bd_sync_story() {
  local file="$1"

  # Validate file exists
  if [ -z "$file" ]; then
    echo "Usage: bd_sync_story <story-file>"
    echo "  Parses AI-Review checkboxes and creates Beads tasks"
    echo "  Example: bd_sync_story implementation_artifacts/story-1-2-auth.md"
    return 1
  fi

  if [ ! -f "$file" ]; then
    echo "Error: File not found: $file"
    return 1
  fi

  # Extract story key from filename (e.g., story-1-2-auth.md → 1-2-auth)
  local story_key=$(basename "$file" .md | sed 's/^story-//')
  local count_created=0
  local count_skipped=0

  echo "Syncing story: $story_key"

  # Parse file for AI-Review checkboxes only
  while IFS= read -r line; do
    # Match: - [ ] [AI-Review][SEVERITY] Description
    if echo "$line" | grep -qE '^\s*-\s+\[ \]\s+\[AI-Review\]'; then

      # Extract priority and description using helper functions
      local priority=$(_extract_priority "$line")
      local desc=$(_extract_description "$line")

      # Generate hash for idempotency
      local normalized=$(_normalize_line "$line")
      local short_hash=$(_generate_hash "$normalized")

      # Check if already synced
      if _task_exists "$story_key" "$short_hash" "$desc"; then
        echo "  [skip] $desc"
        ((count_skipped++))
        continue
      fi

      # Create Beads task with hash in notes
      local notes="Story: $story_key | Hash: $short_hash"
      local task_id=$(bd create "$desc" --type task --priority "$priority" \
        --notes "$notes" --silent 2>/dev/null)

      if [ -n "$task_id" ]; then
        echo "  [new] $task_id: $desc"
        ((count_created++))
      fi
    fi
  done < "$file"

  echo ""
  echo "Summary: Created $count_created, Skipped $count_skipped tasks from $story_key"
  echo "Verify: bd ready"
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
      echo "     Recovery: bd_fix divergence"
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
        echo "     Recovery: bd_fix divergence"
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

  # Check if another sync is running (inspired by bd_claim pattern)
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

echo "BMAD+Beads aliases loaded. Run 'bd_help' for commands."
