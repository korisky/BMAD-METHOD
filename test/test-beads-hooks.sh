#!/bin/bash
# Test BMAD + Beads hook behavior
# Tests: post-commit background sync safety, pre-push mode handling
# Creates isolated git repos in /tmp

echo "=== Test: Beads Hook Behavior ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_PATH="$SCRIPT_DIR/../src/bmm/sub-modules/beads/beads-aliases.sh"

PASSED=0
FAILED=0
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

pass() { echo "  ✅ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ❌ $1"; FAILED=$((FAILED + 1)); }

# --- Test 1: bd_auto_sync uses bd sync (not bd_land) ---
echo "Test 1: bd_auto_sync calls bd sync (not bd_land)"

# Check source code directly — bd_auto_sync should NOT call bd_land
if grep -A5 "echo.*Syncing.*beads-sync.*commits ahead" "$ALIASES_PATH" | grep -q "bd sync 2>&1"; then
  pass "bd_auto_sync calls 'bd sync' (safe for background)"
else
  fail "bd_auto_sync should call 'bd sync', not 'bd_land'"
fi

# Verify bd_land is NOT called in bd_auto_sync (excluding comments)
auto_sync_body=$(sed -n '/^bd_auto_sync/,/^}/p' "$ALIASES_PATH")
if echo "$auto_sync_body" | grep -v '^\s*#' | grep -q "bd_land"; then
  fail "bd_auto_sync still calls bd_land (unsafe branch switching in background)"
else
  pass "bd_auto_sync does not call bd_land"
fi
echo ""

# --- Test 2: Pre-push off mode allows push ---
echo "Test 2: bd_auto_land respects 'off' mode"

REPO1="$TMPDIR/hook-repo1"
mkdir -p "$REPO1"
git -C "$REPO1" init -q
git -C "$REPO1" commit --allow-empty -m "init" -q

local_default=$(git -C "$REPO1" branch --show-current)
[ "$local_default" != "main" ] && git -C "$REPO1" branch -m "$local_default" main

git -C "$REPO1" checkout -b beads-sync -q
git -C "$REPO1" commit --allow-empty -m "beads data" -q
git -C "$REPO1" checkout main -q

# Set up bare remote
git clone --bare -q "$REPO1" "$REPO1-bare"
git -C "$REPO1" remote remove origin 2>/dev/null || true
git -C "$REPO1" remote add origin "$REPO1-bare"
git -C "$REPO1" fetch origin -q
git -C "$REPO1" remote set-head origin main

cd "$REPO1"

# Mock bd to avoid CLI dependency
bd() { return 1; }
export -f bd

source "$ALIASES_PATH" 2>/dev/null || true

# Set mode to off
git config beads.auto-sync off

result=$(bd_auto_land 2>&1)
rc=$?
[ $rc -eq 0 ] && pass "off mode returns 0 (allows push)" || fail "off mode should return 0, got $rc"
echo ""

# --- Test 3: Pre-push block mode blocks push ---
echo "Test 3: bd_auto_land respects 'block' mode"

git config beads.auto-sync block

result=$(bd_auto_land 2>&1)
rc=$?
[ $rc -eq 1 ] && pass "block mode returns 1 (blocks push)" || fail "block mode should return 1, got $rc"
echo "$result" | grep -q "Push blocked" && pass "block mode shows blocked message" || fail "should show 'Push blocked'"
echo ""

# Cleanup mock
unset -f bd

# --- Summary ---
echo "==========================="
echo "Passed: $PASSED, Failed: $FAILED"
[ "$FAILED" -eq 0 ] && echo "✅ All tests passed!" || { echo "❌ Some tests failed"; exit 1; }
