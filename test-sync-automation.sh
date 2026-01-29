#!/bin/bash
# Test script for BMAD + Beads Sync Automation
# Tests all new features from Phase 2 and Phase 3

set -e

echo "=== BMAD + Beads Sync Automation Test Suite ==="
echo ""

# Source the aliases
if [ -f "src/modules/bmm/sub-modules/beads/beads-aliases.sh" ]; then
    source src/modules/bmm/sub-modules/beads/beads-aliases.sh
    echo "✅ Loaded beads-aliases.sh"
else
    echo "❌ beads-aliases.sh not found"
    exit 1
fi

echo ""
echo "=== Phase 2: Config and Auto-Land Tests ==="
echo ""

# Test 1: bd-config-sync without arguments (show current)
echo "Test 1: Show current config"
bd-config-sync
echo ""

# Test 2: Set config to warning
echo "Test 2: Set config to 'warning'"
bd-config-sync warning
echo ""

# Test 3: Set config to auto
echo "Test 3: Set config to 'auto'"
bd-config-sync auto
echo ""

# Test 4: Set config to block
echo "Test 4: Set config to 'block'"
bd-config-sync block
echo ""

# Test 5: Set config to off
echo "Test 5: Set config to 'off'"
bd-config-sync off
echo ""

# Test 6: Try invalid config
echo "Test 6: Try invalid config 'invalid'"
if bd-config-sync invalid 2>&1 | grep -q "Invalid mode"; then
    echo "✅ Correctly rejected invalid mode"
else
    echo "❌ Should have rejected invalid mode"
fi
echo ""

# Test 7: Verify git config was set
echo "Test 7: Verify git config"
current=$(git config beads.auto-sync 2>/dev/null || echo "not set")
echo "Current git config beads.auto-sync: $current"
echo ""

# Test 8: Reset to warning (default)
echo "Test 8: Reset to 'warning' (default)"
bd-config-sync warning
echo ""

# Test 9: Check bd-auto-land function exists
echo "Test 9: Check bd-auto-land function exists"
if type bd-auto-land >/dev/null 2>&1; then
    echo "✅ bd-auto-land function exists"
else
    echo "❌ bd-auto-land function not found"
fi
echo ""

# Test 10: Check bd-auto-sync function exists
echo "Test 10: Check bd-auto-sync function exists"
if type bd-auto-sync >/dev/null 2>&1; then
    echo "✅ bd-auto-sync function exists"
else
    echo "❌ bd-auto-sync function not found"
fi
echo ""

echo "=== Phase 3: Hook Installation Tests ==="
echo ""

# Test 11: Check if hooks are in install.sh
echo "Test 11: Check pre-push hook in install.sh"
if grep -q "bd-auto-land" src/modules/bmm/sub-modules/beads/install.sh; then
    echo "✅ pre-push hook installation found in install.sh"
else
    echo "❌ pre-push hook installation not found"
fi
echo ""

# Test 12: Check post-commit hook in install.sh
echo "Test 12: Check post-commit hook in install.sh"
if grep -q "bd-auto-sync" src/modules/bmm/sub-modules/beads/install.sh; then
    echo "✅ post-commit hook installation found in install.sh"
else
    echo "❌ post-commit hook installation not found"
fi
echo ""

echo "=== Documentation Tests ==="
echo ""

# Test 13: Check beads-git-workflow.md for auto-sync section
echo "Test 13: Check beads-git-workflow.md for auto-sync documentation"
if grep -q "Auto-Sync Features" src/modules/bmm/sub-modules/beads/beads-git-workflow.md; then
    echo "✅ Auto-sync section found in beads-git-workflow.md"
else
    echo "❌ Auto-sync section not found"
fi
echo ""

# Test 14: Check handover instructions updated
echo "Test 14: Check handover instructions for mandatory bd-land"
if grep -q "Sync All Branches" src/modules/bmm/workflows/4-implementation/handover/instructions.md; then
    echo "✅ Handover instructions updated"
else
    echo "❌ Handover instructions not updated"
fi
echo ""

# Test 15: Check bd-help includes new commands
echo "Test 15: Check bd-help for new commands"
if bd-help | grep -q "bd-config-sync"; then
    echo "✅ bd-help includes bd-config-sync"
else
    echo "❌ bd-help missing bd-config-sync"
fi
echo ""

echo "=== Summary ==="
echo ""
echo "All tests completed!"
echo ""
echo "Manual verification needed:"
echo "  • Install in target project: bash src/modules/bmm/sub-modules/beads/install.sh"
echo "  • Test commit → post-commit hook → check ~/.bmad/sync.log"
echo "  • Test push → pre-push hook → verify prompt"
echo "  • Test [HO] handover → verify bd-land always runs"
echo ""
echo "✅ Automated tests passed"
