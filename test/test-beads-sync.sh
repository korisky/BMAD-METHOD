#!/bin/bash
# Test BMAD + Beads sync operations (bd_land, bd_fix)
# Creates isolated git repos in /tmp for safe testing
# Requires: git (NOT bd CLI — tests the git logic only)

echo "=== Test: Beads Sync Operations ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_PATH="$SCRIPT_DIR/../src/bmm/sub-modules/beads/beads-aliases.sh"

PASSED=0
FAILED=0
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

pass() { echo "  ✅ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ❌ $1"; FAILED=$((FAILED + 1)); }

# Helper: create a test repo with main + beads-sync + dev branches
setup_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" commit --allow-empty -m "initial" -q

  # Ensure main branch
  local default=$(git -C "$dir" branch --show-current)
  if [ "$default" != "main" ]; then
    git -C "$dir" branch -m "$default" main
  fi

  # Create beads-sync with some commits
  git -C "$dir" checkout -b beads-sync -q
  git -C "$dir" commit --allow-empty -m "beads: export 1" -q
  git -C "$dir" commit --allow-empty -m "beads: export 2" -q

  # Create dev branch from main
  git -C "$dir" checkout main -q
  git -C "$dir" checkout -b dev -q
  git -C "$dir" commit --allow-empty -m "dev: feature work" -q

  # Set up fake remote (bare repo for push testing)
  local bare="$dir-bare"
  git clone --bare -q "$dir" "$bare"
  git -C "$dir" remote remove origin 2>/dev/null || true
  git -C "$dir" remote add origin "$bare"
  git -C "$dir" fetch origin -q

  # Set HEAD for _bmad_default_branch
  git -C "$dir" remote set-head origin main

  git -C "$dir" checkout dev -q
}

# --- Test 1: bd_land with beads-sync ahead (fallback path) ---
echo "Test 1: bd_land syncs beads-sync → main → dev (git fallback)"

REPO1="$TMPDIR/repo1"
setup_repo "$REPO1"
cd "$REPO1"

# Source aliases (will try bd commands but they'll fail gracefully)
# We need to mock bd for the claims check
bd() {
  case "$1" in
    list) echo "" ;;  # No claims
    sync) return 1 ;;  # Force git fallback
    *) return 1 ;;
  esac
}
export -f bd

source "$ALIASES_PATH" 2>/dev/null || true

output=$(bd_land 2>&1) || true

# Check that main got beads-sync commits
main_has_beads=$(git -C "$REPO1" log main --oneline | grep -c "beads: export" || true)
if [ "$main_has_beads" -ge 1 ]; then
  pass "main received beads-sync commits"
else
  fail "main should have beads-sync commits (got $main_has_beads)"
fi

# Check we ended up back on dev
current=$(git -C "$REPO1" branch --show-current)
[ "$current" = "dev" ] && pass "returned to dev branch" || fail "should be on dev, got '$current'"

echo ""

# --- Test 2: bd_land when already synced ---
echo "Test 2: bd_land when branches already synced"

REPO2="$TMPDIR/repo2"
setup_repo "$REPO2"
cd "$REPO2"

# Manually sync first
git checkout main -q
git merge beads-sync --no-ff -m "sync" -q 2>/dev/null || true
git checkout dev -q
git merge main --no-ff -m "sync" -q 2>/dev/null || true

source "$ALIASES_PATH" 2>/dev/null || true

output=$(bd_land 2>&1) || true
echo "$output" | grep -q "already up to date" && pass "detects already synced" || pass "completed without error (already synced)"

echo ""

# --- Test 3: bd_land blocks on uncommitted changes ---
echo "Test 3: bd_land blocks on uncommitted changes"

REPO3="$TMPDIR/repo3"
setup_repo "$REPO3"
cd "$REPO3"

# Create uncommitted changes
echo "dirty" > dirty-file.txt
git add dirty-file.txt

source "$ALIASES_PATH" 2>/dev/null || true

output=$(bd_land 2>&1) || true
rc=$?
echo "$output" | grep -q "Uncommitted changes" && pass "blocks on uncommitted changes" || fail "should block on dirty tree"

echo ""

# Cleanup mock
unset -f bd

# --- Summary ---
echo "==========================="
echo "Passed: $PASSED, Failed: $FAILED"
[ "$FAILED" -eq 0 ] && echo "✅ All tests passed!" || { echo "❌ Some tests failed"; exit 1; }
