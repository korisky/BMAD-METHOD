#!/bin/bash
# Test idempotency of bd_sync_story
# This test verifies that running bd_sync_story multiple times doesn't create duplicates

set -e

echo "=== Test: bd_sync_story Idempotency ==="
echo ""

# Check if we're in a test environment or have beads available
if ! command -v bd >/dev/null 2>&1; then
  echo "⚠️  Skipping: bd CLI not found (install beads first)"
  echo "   This test requires beads daemon to be available"
  exit 0
fi

# Check if beads is initialized
if ! bd stats >/dev/null 2>&1; then
  echo "⚠️  Skipping: beads daemon not running"
  echo "   Run: bd daemon start"
  exit 0
fi

# Source the beads-aliases.sh to get bd_sync_story function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_PATH="$SCRIPT_DIR/../src/modules/bmm/sub-modules/beads/beads-aliases.sh"

if [ ! -f "$ALIASES_PATH" ]; then
  echo "❌ Error: beads-aliases.sh not found at $ALIASES_PATH"
  exit 1
fi

source "$ALIASES_PATH"

# Setup test story file
TEST_FILE="test-story-idempotency.md"
STORY_KEY="test-story-idempotency"

# Cleanup function
cleanup() {
  echo ""
  echo "Cleaning up..."
  rm -f "$TEST_FILE" 2>/dev/null || true

  # Delete all test tasks
  bd search "Story: $STORY_KEY" --status open 2>/dev/null | \
    awk '{print $1}' | \
    while read -r id; do
      [ -n "$id" ] && [ "$id" != "ID" ] && bd delete "$id" 2>/dev/null || true
    done

  echo "Cleanup complete"
}

# Register cleanup on exit
trap cleanup EXIT INT TERM

# Create test story file
cat > "$TEST_FILE" <<'EOF'
# Test Story for Idempotency

## AI-Review Follow-ups

- [ ] [AI-Review][HIGH] Fix authentication bug
- [ ] [AI-Review][MEDIUM] Add input validation
- [x] [AI-Review][LOW] Already completed (should skip)
- [ ] Regular task (should skip - no AI-Review tag)
- [ ] [AI-Review] No priority tag (defaults to LOW)
EOF

echo "Test story file created: $TEST_FILE"
echo ""

# Test 1: First sync creates tasks
echo "=== Test 1: Initial sync (should create tasks) ==="
output1=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output1"
echo ""

# Verify: Should create 3 tasks (HIGH + MEDIUM + no-priority)
if echo "$output1" | grep -q "Created 3"; then
  echo "✅ Test 1 passed: Created 3 tasks"
else
  echo "❌ Test 1 failed: Expected 'Created 3'"
  echo "   Output: $output1"
  exit 1
fi

echo ""

# Test 2: Second sync skips existing
echo "=== Test 2: Re-run sync (should skip all) ==="
output2=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output2"
echo ""

if echo "$output2" | grep -q "Skipped 3"; then
  echo "✅ Test 2 passed: Skipped 3 tasks (no duplicates)"
else
  echo "❌ Test 2 failed: Expected 'Skipped 3'"
  echo "   Output: $output2"
  exit 1
fi

echo ""

# Test 3: Add new item (partial update)
echo "=== Test 3: Add new item (partial update) ==="
echo "- [ ] [AI-Review][LOW] New item added" >> "$TEST_FILE"
output3=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output3"
echo ""

if echo "$output3" | grep -q "Created 1" && echo "$output3" | grep -q "Skipped 3"; then
  echo "✅ Test 3 passed: Created 1 new, skipped 3 existing"
else
  echo "❌ Test 3 failed: Expected 'Created 1, Skipped 3'"
  echo "   Output: $output3"
  exit 1
fi

echo ""

# Test 4: Verify no duplicates in Beads
echo "=== Test 4: Verify task count in Beads ==="
task_count=$(bd search "Story: $STORY_KEY" --status open 2>/dev/null | grep -v "^$" | grep -v "^ID" | wc -l | tr -d ' ')
expected=4

echo "Tasks found: $task_count (expected: $expected)"

if [ "$task_count" -eq "$expected" ]; then
  echo "✅ Test 4 passed: Exactly $expected tasks in Beads (no duplicates)"
else
  echo "❌ Test 4 failed: Expected $expected tasks, found $task_count"
  echo ""
  echo "All tasks for story:"
  bd search "Story: $STORY_KEY" --status open 2>/dev/null || true
  exit 1
fi

echo ""

# Test 5: Whitespace normalization
echo "=== Test 5: Whitespace normalization ==="
# Add same task with different whitespace
echo "  -   [ ]   [AI-Review][HIGH]   Fix authentication bug  " >> "$TEST_FILE"
output5=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output5"
echo ""

# Should skip the duplicate (normalized to same hash)
if echo "$output5" | grep -q "Skipped 5"; then
  echo "✅ Test 5 passed: Whitespace differences normalized (same hash)"
else
  echo "❌ Test 5 failed: Expected whitespace to be normalized"
  echo "   Output: $output5"
  exit 1
fi

echo ""

# Test 6: Description change creates new task
echo "=== Test 6: Description change (should create new task) ==="
echo "- [ ] [AI-Review][HIGH] Fix authentication bug - with extra detail" >> "$TEST_FILE"
output6=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output6"
echo ""

if echo "$output6" | grep -q "Created 1"; then
  echo "✅ Test 6 passed: Description change creates new task"
else
  echo "❌ Test 6 failed: Expected new task for changed description"
  echo "   Output: $output6"
  exit 1
fi

echo ""

# Test 7: Priority change creates new task
echo "=== Test 7: Priority change (should create new task) ==="
echo "- [ ] [AI-Review][LOW] Add input validation" >> "$TEST_FILE"
output7=$(bd_sync_story "$TEST_FILE" 2>&1)
echo "$output7"
echo ""

# Priority changed from MEDIUM to LOW for "Add input validation"
if echo "$output7" | grep -q "Created 1"; then
  echo "✅ Test 7 passed: Priority change creates new task"
else
  echo "❌ Test 7 failed: Expected new task for changed priority"
  echo "   Output: $output7"
  exit 1
fi

echo ""

# Final verification
echo "=== Final Verification ==="
final_count=$(bd search "Story: $STORY_KEY" --status open 2>/dev/null | grep -v "^$" | grep -v "^ID" | wc -l | tr -d ' ')
echo "Total tasks in Beads: $final_count"
echo ""
echo "Task list:"
bd search "Story: $STORY_KEY" --status open 2>/dev/null | head -10 || true

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "Summary:"
echo "  ✅ Idempotency works (no duplicates)"
echo "  ✅ Partial updates work (only new items synced)"
echo "  ✅ Whitespace normalization works"
echo "  ✅ Description changes detected"
echo "  ✅ Priority changes detected"
echo "  ✅ Hash-based tracking operational"
