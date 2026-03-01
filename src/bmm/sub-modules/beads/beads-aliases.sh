#!/bin/bash
# BMAD + Beads Integration Aliases (Agent-First v0.2.0)
# Installed to: .beads/lib/bmad-aliases.sh (project-local)
# Available in git hooks automatically
# For shell usage, manually source:
#   source .beads/lib/bmad-aliases.sh
#
# Agent-first: Human wrapper functions (bd_claim, bd_decision, etc.)
# removed. Agents use native bd commands directly. This file provides
# git-sync infrastructure that has no native bd equivalent.

# ============================================
# AGENT MODE DETECTION
# ============================================

# When BMAD_AGENT_MODE=1, functions output JSON instead of pretty text
BMAD_AGENT_MODE="${BMAD_AGENT_MODE:-0}"

_bmad_output() {
  if [ "$BMAD_AGENT_MODE" = "1" ]; then
    # JSON output for agent consumption
    local status="$1"
    local message="$2"
    local data="${3:-{}}"
    printf '{"status":"%s","message":"%s","data":%s}\n' "$status" "$message" "$data"
  else
    echo "$2"
  fi
}

# ============================================
# INTERNAL HELPER FUNCTIONS
# ============================================

# Get the configured remote (default: origin)
# Override: git config beads.remote <name>
_bmad_remote() {
  git config beads.remote 2>/dev/null || echo "origin"
}

# Get the default branch (main/master)
_bmad_default_branch() {
  local remote=$(_bmad_remote)
  git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s@^refs/remotes/$remote/@@" || echo "main"
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
_bmad_branch_exists() {
  git rev-parse --verify "$1" >/dev/null 2>&1
}

# Trim leading/trailing whitespace and collapse internal runs
_bmad_trim_and_collapse() {
  tr -s ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Pre-check: git repo + .beads dir + bd CLI
# Args: [--quiet] — suppress output, just return exit code
_bmad_check_repo_and_beads() {
  local quiet=false
  [ "$1" = "--quiet" ] && quiet=true
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    $quiet || _bmad_output "error" "Not a git repository"
    return 1
  fi
  if [ ! -d ".beads" ]; then
    $quiet || _bmad_output "error" "Beads not initialized — run: bd init"
    return 1
  fi
  if ! command -v bd >/dev/null 2>&1; then
    $quiet || _bmad_output "error" "bd CLI not found"
    return 1
  fi
  return 0
}

# Check open in-progress tasks
# Args: [--verbose] — show tasks + hint, [--warn] — show warning only if tasks exist
# Returns: 0 if no in-progress tasks, 1 if tasks exist
_bmad_check_open_claims() {
  local mode="${1:---verbose}"
  local claims=$(bd list --type task --status in_progress 2>/dev/null | grep -v "^$")
  if [ -n "$claims" ]; then
    if [ "$mode" = "--verbose" ]; then
      echo "$claims"
      echo "  Close when done: bd close <id> --reason \"summary\""
    elif [ "$mode" = "--warn" ]; then
      _bmad_output "warning" "In-progress tasks exist (close with: bd close <id>)"
    fi
    return 1
  else
    if [ "$mode" = "--verbose" ]; then
      echo "  No in-progress tasks"
    elif [ "$mode" = "--warn" ]; then
      _bmad_output "ok" "No in-progress tasks"
    fi
    return 0
  fi
}

# Detect workflow mode from git config
# Returns: agent, human, mixed, or auto
_bmad_detect_workflow_mode() {
  local configured_mode=$(git config beads.workflow-mode 2>/dev/null || echo "mixed")

  case "$configured_mode" in
    agent|human|mixed)
      echo "$configured_mode"
      ;;
    auto)
      # Auto-detect: daemon running + beads-sync exists = agent mode
      if bd stats >/dev/null 2>&1 && _bmad_branch_exists beads-sync; then
        echo "agent"
      else
        echo "human"
      fi
      ;;
    *)
      echo "mixed"  # Safe default
      ;;
  esac
}

# Check if beads-sync sync is needed in current workflow
# Returns: 0 if sync needed, 1 if skip
_bmad_should_sync_beads() {
  local mode=$(_bmad_detect_workflow_mode)
  case "$mode" in
    human) return 1 ;;
    agent) _bmad_branch_exists beads-sync ;;
    mixed|*)
      _bmad_branch_exists beads-sync || return 1
      bd stats >/dev/null 2>&1 || return 1
      [ "$(_bmad_check_divergence "$(_bmad_default_branch)" beads-sync)" -gt 0 ]
      ;;
  esac
}

# ============================================
# AGENT SESSION BOOTSTRAP
# ============================================

# Agent session initialization — reads BMAD_MANIFEST.md and runs bd prime
# Sets BMAD_AGENT_MODE=1 for JSON output
bd_agent_init() {
  export BMAD_AGENT_MODE=1

  _bmad_check_repo_and_beads || return 1

  local manifest="BMAD_MANIFEST.md"
  if [ ! -f "$manifest" ]; then
    _bmad_output "warning" "BMAD_MANIFEST.md not found — run installer to generate"
  fi

  local skill=".bmad/SKILL.md"
  if [ ! -f "$skill" ]; then
    _bmad_output "warning" ".bmad/SKILL.md not found — run installer to generate"
  fi

  # Check for HALTs
  local halts=$(bd list --type blocker --priority 0 --status open --json 2>/dev/null)
  if [ -n "$halts" ] && [ "$halts" != "[]" ]; then
    _bmad_output "halt" "Priority 0 blockers exist — resolve before proceeding" "$halts"
    return 1
  fi

  # Run bd prime for full context
  bd prime --json 2>/dev/null

  _bmad_output "ok" "Agent session initialized"
}

# Session start check — validates environment and shows state
bd_session_start() {
  if [ "$BMAD_AGENT_MODE" = "1" ]; then
    bd_agent_init
    return $?
  fi

  echo "=== BEADS SESSION CHECK ==="

  _bmad_check_repo_and_beads || return 1
  if ! bd stats >/dev/null 2>&1; then
    echo "  Daemon not running — run: bd daemon start"
  fi
  if _bmad_branch_exists beads-sync; then
    local behind=$(_bmad_check_divergence "$(_bmad_default_branch)" beads-sync)
    [ "$behind" -gt 0 ] && echo "  Branches out of sync — run bd_land"
  fi
  echo ""

  echo "HALTs (priority 0):"
  bd list --type blocker --priority 0 --status open 2>/dev/null || echo "  None"
  echo ""
  echo "Ready work:"
  bd ready --pretty --limit 5 2>/dev/null || echo "  None"
  echo ""
  echo "In-progress tasks:"
  bd list --type task --status in_progress 2>/dev/null || echo "  None"
  echo ""
  echo "Active blockers:"
  bd list --type blocker --status open 2>/dev/null || echo "  None"
  echo ""
  echo "==========================="
  echo "Next: bd update <id> --status in_progress --claim"

  export BMAD_SESSION_ACTIVE=1
}

# ============================================
# BRANCH SYNC (Three-Way Sync)
# ============================================

# Land the plane — session end with branch sync
# Three-way: beads-sync → default → current
bd_land() {
  echo "=== LANDING THE PLANE ==="
  echo ""

  local current_branch=$(git branch --show-current)
  local default_branch=$(_bmad_default_branch)

  # 1. Check in-progress tasks
  echo "1. Checking for in-progress tasks..."
  local claims=$(bd list --type task --status in_progress 2>/dev/null)
  if [ -n "$claims" ]; then
    echo "$claims"
    echo "  Close with: bd close <id> --reason \"summary\""
    echo ""
  else
    echo "  None"; echo ""
  fi

  # 2. Check for uncommitted changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "Uncommitted changes. Commit first."
    return 1
  fi

  # 3. Sync beads-sync → default (ONLY if workflow mode requires it)
  if _bmad_branch_exists beads-sync; then
    if _bmad_should_sync_beads; then
      echo "2. Syncing beads-sync → $default_branch..."

      # Try native bd sync --merge first, fall back to raw git
      if bd sync --merge --dry-run >/dev/null 2>&1; then
        if bd sync --merge 2>&1; then
          echo "  $default_branch synced with beads-sync"
        else
          echo "  bd sync --merge failed. Recovery: bd_fix"
          git checkout "$current_branch" 2>/dev/null
          return 1
        fi
      else
        # Fallback: raw git (older Beads without bd sync --merge)
        echo "  (using git merge fallback)"
        local remote=$(_bmad_remote)
        git fetch "$remote" 2>/dev/null || true
        git checkout "$default_branch" || { echo "Can't checkout $default_branch"; return 1; }

        if git merge beads-sync --no-ff -m "merge: beads-sync into $default_branch" 2>&1; then
          echo "  $default_branch synced with beads-sync"
        else
          if git merge-base --is-ancestor beads-sync "$default_branch" 2>/dev/null; then
            echo "  $default_branch already up to date"
          else
            echo "  Cannot merge beads-sync. Recovery: bd_fix"
            git checkout "$current_branch" 2>/dev/null
            return 1
          fi
        fi

        git push "$remote" "$default_branch" 2>/dev/null || echo "  Can't push to $remote/$default_branch"
      fi
    else
      local mode=$(_bmad_detect_workflow_mode)
      echo "2. Skipping beads-sync sync (workflow-mode=$mode, daemon not active)"
    fi
  else
    echo "2. beads-sync not found (daemon not running — OK for human-only workflow)"
  fi

  # 4. Sync default → current branch (three-way sync)
  if [ "$current_branch" != "$default_branch" ]; then
    git checkout "$current_branch" || { echo "Can't checkout $current_branch"; return 1; }

    if git merge "$default_branch" --no-ff -m "merge: sync from $default_branch" 2>/dev/null; then
      echo "  $current_branch synced with $default_branch"
    else
      if git merge-base --is-ancestor "$default_branch" "$current_branch" 2>/dev/null; then
        echo "  $current_branch already up to date"
      else
        echo "  Cannot merge $default_branch into $current_branch"
        echo "  Recovery: bd_fix"
        return 1
      fi
    fi
    git push "$(_bmad_remote)" "$current_branch" 2>/dev/null || echo "  Can't push $current_branch"
  fi

  echo ""
  echo "All synced. Ready to continue working."
}

# ============================================
# CONFIGURATION
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
    echo "  warning  - Ask before syncing (default)"
    echo "  block    - Refuse push until synced"
    echo "  auto     - Auto-sync without asking"
    echo "  off      - Disable auto-sync checks"
    return 0
  fi

  case "$mode" in
    warning|block|auto|off)
      git config beads.auto-sync "$mode"
      echo "Auto-sync mode set to: $mode"
      ;;
    *)
      echo "Invalid mode: $mode (valid: warning, block, auto, off)"
      return 1
      ;;
  esac
}

# Configure workflow mode
# Usage: bd_config_workflow <mode>
# Modes: agent, human, mixed (default), auto
bd_config_workflow() {
  local mode="$1"
  if [ -z "$mode" ]; then
    local current=$(git config beads.workflow-mode 2>/dev/null || echo "mixed")
    echo "Current workflow mode: $current"
    echo ""
    echo "Usage: bd_config_workflow <mode>"
    echo "  mixed  - Smart detection (default)"
    echo "  agent  - Always sync beads-sync"
    echo "  human  - Never sync beads-sync"
    echo "  auto   - Automatic detection"
    return 0
  fi

  case "$mode" in
    agent|human|mixed|auto)
      git config beads.workflow-mode "$mode"
      echo "Workflow mode set to: $mode"
      ;;
    *)
      echo "Invalid mode: $mode (valid: agent, human, mixed, auto)"
      return 1
      ;;
  esac
}

# ============================================
# AUTOMATION (Git Hooks)
# ============================================

# Smart pre-push sync with config support
# Returns 0 if safe to push, 1 if blocked
bd_auto_land() {
  # Skip daemon push check for agents (BEADS_NO_DAEMON=1)
  if [ "$BEADS_NO_DAEMON" != "1" ]; then
    if pgrep -f "bd.*daemon.*--auto-push" >/dev/null 2>&1; then
      echo "Push blocked: daemon using --auto-push flag"
      echo "Fix: bd daemon --stop && bd daemon --start --interval 5s --auto-commit --auto-pull"
      return 1
    fi
  fi

  # Check if beads-sync sync is needed in current workflow
  if ! _bmad_should_sync_beads; then
    return 0
  fi

  local default_branch=$(_bmad_default_branch)
  local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)

  if [ "$ahead" -eq 0 ]; then
    return 0  # Already synced
  fi

  local mode=$(git config beads.auto-sync 2>/dev/null || echo "warning")

  case "$mode" in
    off)
      return 0
      ;;
    auto)
      echo "Auto-syncing branches (beads-sync is $ahead commits ahead)..."
      bd_land
      return $?
      ;;
    block)
      echo "Push blocked: beads-sync is $ahead commits ahead of $default_branch"
      echo "Run: bd_land"
      return 1
      ;;
    warning|*)
      if [ -t 0 ]; then
        echo "beads-sync is $ahead commit(s) ahead of $default_branch"
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
      else
        # No TTY (GUI git client, code agent) — auto-sync
        echo "Auto-syncing branches (beads-sync is $ahead commits ahead)..."
        bd_land
        return $?
      fi
      ;;
  esac
}

# Silent background sync wrapper (for post-commit hook)
bd_auto_sync() {
  local log_file=".beads/logs/sync.log"
  local pid_file=".beads/tmp/.sync.pid"
  mkdir -p .beads/logs .beads/tmp

  # Check if another sync is running
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

  echo $$ > "$pid_file"
  trap "rm -f '$pid_file'" EXIT INT TERM

  {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="

    if ! _bmad_branch_exists beads-sync; then
      echo "Skip: beads-sync branch not found"
      return 0
    fi

    local default_branch=$(_bmad_default_branch)
    local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)

    if [ "$ahead" -eq 0 ]; then
      echo "Skip: branches already synced"
      return 0
    fi

    echo "Syncing: beads-sync is $ahead commits ahead"
    bd sync 2>&1
    echo "Complete: $(date '+%Y-%m-%d %H:%M:%S')"
  } >> "$log_file" 2>&1

  # Rotate log if too large (keep last 1000 lines)
  if [ -f "$log_file" ] && [ $(wc -l < "$log_file") -gt 1500 ]; then
    tail -1000 "$log_file" > "${log_file}.tmp"
    mv "${log_file}.tmp" "$log_file"
  fi
}

# ============================================
# HEALTH & DIAGNOSTICS
# ============================================

# Health diagnostic — check project + beads status
bd_health() {
  echo "=== BEADS HEALTH CHECK ==="
  local issues=0

  _bmad_check_repo_and_beads || return 1

  # Daemon status
  echo ""
  echo "Daemon Status:"
  if bd stats 2>/dev/null; then
    echo "  Daemon running"

    # Check for --auto-push misconfiguration
    local daemon_pid=$(pgrep -f "bd.*daemon" 2>/dev/null | head -1)
    if [ -n "$daemon_pid" ]; then
      local daemon_cmd=$(ps -p "$daemon_pid" -o args= 2>/dev/null)
      if echo "$daemon_cmd" | grep -q -- "--auto-push"; then
        echo "  WARNING: Daemon using --auto-push (conflicts with pre-push hook)"
        echo "  Fix: bd daemon --stop && bd daemon --start --interval 5s --auto-commit --auto-pull"
        ((issues++))
      fi
    fi
  else
    echo "  Daemon not running or not responding"
    echo "  Run: bd daemon start"
    ((issues++))
  fi

  # Branch divergence
  echo ""
  echo "Branch Sync Status:"
  if _bmad_branch_exists beads-sync; then
    if bd sync --status 2>/dev/null; then
      true
    else
      local default_branch=$(_bmad_default_branch)
      local ahead=$(_bmad_check_divergence "$default_branch" beads-sync)
      local behind=$(_bmad_check_divergence beads-sync "$default_branch")

      if [ "$ahead" -gt 0 ]; then
        echo "  beads-sync is $ahead commit(s) ahead of $default_branch"
        echo "  Run: bd_land"
        ((issues++))
      elif [ "$behind" -gt 0 ]; then
        echo "  beads-sync is $behind commit(s) behind $default_branch"
        ((issues++))
      else
        echo "  Branches in sync"
      fi
    fi
  else
    echo "  beads-sync branch not found (normal if daemon hasn't created it)"
  fi

  # In-progress tasks
  echo ""
  echo "In-Progress Tasks:"
  _bmad_check_open_claims --verbose

  # HALTs
  echo ""
  echo "Critical Issues (HALTs):"
  local halts=$(bd list --type blocker --priority 0 --status open 2>/dev/null | grep -v "^$")
  if [ -n "$halts" ]; then
    echo "$halts"
    echo "  HALTs must be resolved before proceeding"
    ((issues++))
  else
    echo "  No HALTs"
  fi

  # BMAD methodology check
  echo ""
  echo "BMAD Methodology:"
  if [ -f ".bmad/SKILL.md" ]; then
    echo "  .bmad/SKILL.md present"
  else
    echo "  .bmad/SKILL.md missing — run installer"
    ((issues++))
  fi
  if [ -f "BMAD_MANIFEST.md" ]; then
    echo "  BMAD_MANIFEST.md present"
  else
    echo "  BMAD_MANIFEST.md missing — run installer"
    ((issues++))
  fi

  # Configuration
  echo ""
  echo "Configuration:"
  if [ -f .beads/lib/bmad-aliases.sh ]; then
    echo "  Using project-local config (.beads/lib/)"
    if [ -f .beads/.bmad-version ]; then
      echo "  Version: $(cat .beads/.bmad-version)"
    fi
  else
    echo "  No config found — run installer"
    ((issues++))
  fi

  # Summary
  echo ""
  echo "==========================="
  if [ "$issues" -eq 0 ]; then
    echo "System healthy"
    return 0
  else
    echo "Found $issues issue(s) — review above"
    return 1
  fi
}

# Pre-push checklist
bd_preflight() {
  echo "=== Pre-Push Checklist ==="
  local ok=true

  if [ -n "$(git status --porcelain)" ]; then
    echo "FAIL: Uncommitted changes (commit first)"
    ok=false
  else
    echo "OK: Working tree clean"
  fi

  if _bmad_branch_exists beads-sync; then
    git fetch "$(_bmad_remote)" 2>/dev/null || true
    local default_branch=$(_bmad_default_branch)
    local behind=$(_bmad_check_divergence "$default_branch" beads-sync)
    if [ "$behind" -gt 0 ]; then
      echo "FAIL: beads-sync has $behind commits not in $default_branch (run bd_land)"
      ok=false
    else
      echo "OK: Branches synced"
    fi
  else
    local mode=$(_bmad_detect_workflow_mode)
    echo "OK: No beads-sync branch (workflow-mode=$mode)"
  fi

  _bmad_check_open_claims --warn

  echo ""
  if [ "$ok" = true ]; then
    echo "Ready to push: git push"
    return 0
  else
    echo "Not ready. Fix issues above, then: bd_preflight"
    return 1
  fi
}

# Auto-recovery for common issues
bd_fix() {
  echo "=== Auto-Fix Attempt ==="
  local fixed=false

  # Check if beads-sync worktree is on wrong branch
  if [ -d ".git/beads-worktrees/beads-sync" ]; then
    local wt_branch=$(git -C .git/beads-worktrees/beads-sync branch --show-current 2>/dev/null)
    if [ -n "$wt_branch" ] && [ "$wt_branch" != "beads-sync" ]; then
      echo "Fixing: worktree on wrong branch ($wt_branch → beads-sync)"
      git -C .git/beads-worktrees/beads-sync checkout beads-sync 2>/dev/null && fixed=true
    fi
  fi

  if [ -n "$(git status --porcelain)" ]; then
    echo "You have uncommitted changes. Commit them first:"
    echo "  git add . && git commit -m 'your message'"
    return 1
  fi

  echo "Running bd_land to sync branches..."
  if bd_land; then
    echo ""
    echo "Fixed! Run bd_preflight to verify."
    return 0
  else
    echo ""
    echo "Auto-fix couldn't resolve all issues."
    echo "See: docs/beads-reference.md for manual recovery"
    return 1
  fi
}

# ============================================
# HELP
# ============================================

bd_help() {
  echo "BMAD + Beads Integration (Agent-First v0.2.0)"
  echo ""
  echo "SESSION:"
  echo "  bd_session_start     - Check HALTs, ready work, branch sync"
  echo "  bd_agent_init        - Agent bootstrap (JSON output, BMAD_AGENT_MODE=1)"
  echo ""
  echo "NATIVE BD COMMANDS (use directly):"
  echo "  bd ready --json      - Available work"
  echo "  bd update <id> --status in_progress --claim  - Claim task"
  echo "  bd create \"title\" -t <type>  - Create task/blocker/decision/gate"
  echo "  bd close <id> --reason \"...\"  - Close task"
  echo "  bd sync              - Sync beads state"
  echo ""
  echo "GIT SYNC (no native bd equivalent):"
  echo "  bd_land              - Three-way sync (beads-sync → default → current)"
  echo "  bd_preflight         - Pre-push safety check"
  echo "  bd_auto_land         - Pre-push hook integration"
  echo "  bd_auto_sync         - Post-commit hook integration"
  echo ""
  echo "TROUBLESHOOTING:"
  echo "  bd_health            - Full diagnostic"
  echo "  bd_fix               - Auto-fix common issues"
  echo "  bd_config_sync       - Configure auto-sync mode"
  echo "  bd_config_workflow   - Configure workflow mode"
  echo ""
  echo "Docs: docs/beads-reference.md"
}

echo "BMAD+Beads aliases loaded (v0.2.0). Run 'bd_help' for commands."
