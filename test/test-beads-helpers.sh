#!/bin/bash
# Test BMAD + Beads internal helper functions
# These tests run without the bd CLI — they test pure bash logic

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_PATH="$SCRIPT_DIR/../src/modules/bmm/sub-modules/beads/beads-aliases.sh"

echo "=== Test: Beads Helper Functions ==="
echo ""

# Mock bd CLI so sourcing doesn't fail
bd() { return 1; }
export -f bd

# Source entire aliases file (aliases + functions)
source "$ALIASES_PATH" 2>/dev/null || true

PASSED=0
FAILED=0

pass() { echo "  ✅ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ❌ $1"; FAILED=$((FAILED + 1)); }

# --- Test 1: _bmad_trim_and_collapse ---
echo "Test 1: _bmad_trim_and_collapse"
result=$(echo "  hello   world  " | _bmad_trim_and_collapse)
[ "$result" = "hello world" ] && pass "trims and collapses whitespace" || fail "expected 'hello world', got '$result'"

result2=$(echo "single" | _bmad_trim_and_collapse)
[ "$result2" = "single" ] && pass "passes through single word" || fail "expected 'single', got '$result2'"

result3=$(echo "   " | _bmad_trim_and_collapse)
[ -z "$result3" ] && pass "empty for whitespace-only" || fail "expected empty, got '$result3'"
echo ""

# --- Test 2: _bmad_branch_exists ---
echo "Test 2: _bmad_branch_exists"

TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

git -C "$TMPDIR" init -q
git -C "$TMPDIR" commit --allow-empty -m "init" -q

cd "$TMPDIR"

# Detect whichever default branch git init created
default_branch=$(git -C "$TMPDIR" branch --show-current)
_bmad_branch_exists "$default_branch" && pass "detects default branch ($default_branch)" || fail "should detect $default_branch"
_bmad_branch_exists nonexistent-branch-xyz && fail "should not find nonexistent branch" || pass "rejects nonexistent branch"
echo ""

# --- Test 3: _bmad_check_divergence ---
echo "Test 3: _bmad_check_divergence"

git checkout -b test-branch -q
git commit --allow-empty -m "test commit 1" -q
git commit --allow-empty -m "test commit 2" -q

ahead=$(_bmad_check_divergence "$default_branch" test-branch)
[ "$ahead" = "2" ] && pass "detects 2 commits ahead" || fail "expected 2, got '$ahead'"

behind=$(_bmad_check_divergence test-branch "$default_branch")
[ "$behind" = "0" ] && pass "detects 0 commits behind" || fail "expected 0, got '$behind'"
echo ""

# --- Test 4: _bmad_check_repo_and_beads ---
echo "Test 4: _bmad_check_repo_and_beads"

# In temp git repo without .beads — should fail on .beads check
result=$(_bmad_check_repo_and_beads 2>&1) || true
echo "$result" | grep -q "Beads not initialized" && pass "detects missing .beads" || fail "should warn about missing .beads"

mkdir -p .beads
# Now should fail on bd CLI (our mock returns 1, but command -v finds the function)
# Re-mock bd as a real command check will find our function
result2=$(_bmad_check_repo_and_beads 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  pass "passes with git + .beads + bd function"
else
  fail "should pass with git repo + .beads dir + bd function available"
fi
echo ""

# Cleanup mock
unset -f bd

# --- Summary ---
echo "==========================="
echo "Passed: $PASSED, Failed: $FAILED"
[ "$FAILED" -eq 0 ] && echo "✅ All tests passed!" || { echo "❌ Some tests failed"; exit 1; }
