#!/bin/bash
# Test BMAD + Beads v0.2.0 Agent-First Integration
# Tests: .bmad/ directory, SKILL.md size, persona sizes, formulas, agent-mode
# Requires: The beads sub-module source at src/bmm/sub-modules/beads/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BEADS_SRC="$REPO_ROOT/src/bmm/sub-modules/beads"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

echo "=== BMAD + Beads v0.2.0 Tests ==="
echo ""

# ============================================
# Test 1: Source directory structure exists
# ============================================
echo "1. Source directory structure"

[ -d "$BEADS_SRC" ] && pass "beads sub-module exists" || fail "beads sub-module missing"
[ -d "$BEADS_SRC/formulas" ] && pass "formulas/ exists" || fail "formulas/ missing"
[ -d "$BEADS_SRC/personas" ] && pass "personas/ exists" || fail "personas/ missing"
[ -d "$BEADS_SRC/templates" ] && pass "templates/ exists" || fail "templates/ missing"
[ -d "$BEADS_SRC/methodology" ] && pass "methodology/ exists" || fail "methodology/ missing"

echo ""

# ============================================
# Test 2: SKILL.md.template under 300 tokens
# ============================================
echo "2. SKILL.md size check (<300 tokens)"

SKILL_FILE="$BEADS_SRC/SKILL.md.template"
if [ -f "$SKILL_FILE" ]; then
  # Approximate token count: words * 1.3 (rough estimate)
  WORD_COUNT=$(wc -w < "$SKILL_FILE" | tr -d ' ')
  APPROX_TOKENS=$((WORD_COUNT * 13 / 10))
  if [ "$APPROX_TOKENS" -lt 300 ]; then
    pass "SKILL.md ~${APPROX_TOKENS} tokens (${WORD_COUNT} words)"
  else
    fail "SKILL.md ~${APPROX_TOKENS} tokens (${WORD_COUNT} words) — exceeds 300"
  fi
else
  fail "SKILL.md.template not found"
fi

echo ""

# ============================================
# Test 3: Persona files under 200 tokens each
# ============================================
echo "3. Persona size checks (<200 tokens each)"

for persona in analyst pm architect dev qa sm; do
  PERSONA_FILE="$BEADS_SRC/personas/${persona}.md"
  if [ -f "$PERSONA_FILE" ]; then
    WORD_COUNT=$(wc -w < "$PERSONA_FILE" | tr -d ' ')
    APPROX_TOKENS=$((WORD_COUNT * 13 / 10))
    if [ "$APPROX_TOKENS" -lt 200 ]; then
      pass "${persona}.md ~${APPROX_TOKENS} tokens"
    else
      fail "${persona}.md ~${APPROX_TOKENS} tokens — exceeds 200"
    fi
  else
    fail "${persona}.md not found"
  fi
done

echo ""

# ============================================
# Test 4: Key files exist
# ============================================
echo "4. Required files exist"

for f in config.yaml install.sh beads-aliases.sh injections.yaml AGENTS.md.template \
         beads-reference.md EXISTING-PROJECTS-HANDOFF.md BMAD_MANIFEST.md.template \
         SKILL.md.template README.md; do
  [ -f "$BEADS_SRC/$f" ] && pass "$f" || fail "$f missing"
done

echo ""

# ============================================
# Test 5: No human wrapper functions in beads-aliases.sh
# ============================================
echo "5. No human wrapper functions in beads-aliases.sh"

ALIASES_FILE="$BEADS_SRC/beads-aliases.sh"
HUMAN_WRAPPERS="bd_claim bd_release bd_done bd_decision bd_blocker bd_halt bd_action bd_quick bd_qadd bd_sync_story"

for wrapper in $HUMAN_WRAPPERS; do
  if grep -q "^${wrapper}()" "$ALIASES_FILE" 2>/dev/null; then
    fail "Found human wrapper: ${wrapper}()"
  else
    pass "No ${wrapper}()"
  fi
done

echo ""

# ============================================
# Test 6: Agent-first functions present in beads-aliases.sh
# ============================================
echo "6. Agent-first functions present"

AGENT_FUNCTIONS="bd_agent_init bd_session_start bd_land bd_auto_land bd_auto_sync bd_health bd_preflight bd_fix bd_help"

for func in $AGENT_FUNCTIONS; do
  if grep -q "^${func}()" "$ALIASES_FILE" 2>/dev/null; then
    pass "${func}() present"
  else
    fail "${func}() missing"
  fi
done

echo ""

# ============================================
# Test 7: Agent mode detection in beads-aliases.sh
# ============================================
echo "7. Agent mode detection"

if grep -q "BMAD_AGENT_MODE" "$ALIASES_FILE"; then
  pass "BMAD_AGENT_MODE variable present"
else
  fail "BMAD_AGENT_MODE not found"
fi

if grep -q "_bmad_output" "$ALIASES_FILE"; then
  pass "_bmad_output helper present"
else
  fail "_bmad_output helper missing"
fi

echo ""

# ============================================
# Test 8: Injections use native bd commands
# ============================================
echo "8. Injections use native bd commands"

INJECTIONS_FILE="$BEADS_SRC/injections.yaml"

# Should NOT contain old wrapper calls
for old_cmd in bd_claim bd_decision bd_blocker bd_halt bd_release bd_sync_story; do
  if grep -q "\`${old_cmd}" "$INJECTIONS_FILE" 2>/dev/null; then
    fail "Injection uses deprecated: ${old_cmd}"
  else
    pass "No ${old_cmd} in injections"
  fi
done

# Should contain native bd commands
for new_cmd in "bd update" "bd create" "bd close" "bd ready"; do
  if grep -q "$new_cmd" "$INJECTIONS_FILE" 2>/dev/null; then
    pass "Uses native: $new_cmd"
  else
    fail "Missing native: $new_cmd"
  fi
done

echo ""

# ============================================
# Test 9: AGENTS.md.template has agent-first protocol
# ============================================
echo "9. AGENTS.md.template content"

AGENTS_FILE="$BEADS_SRC/AGENTS.md.template"

if grep -q "BMAD-BEADS:START" "$AGENTS_FILE"; then
  pass "Managed block markers present"
else
  fail "Missing managed block markers"
fi

if grep -q "bd prime" "$AGENTS_FILE"; then
  pass "Agent session protocol (bd prime)"
else
  fail "Missing agent session protocol"
fi

if grep -q "bd ready --json" "$AGENTS_FILE"; then
  pass "Agent work discovery (bd ready --json)"
else
  fail "Missing agent work discovery"
fi

# Should NOT contain old protocol
if grep -q "bd_session_start.*bd_claim" "$AGENTS_FILE" 2>/dev/null; then
  fail "Contains old human-centric protocol"
else
  pass "No old human-centric protocol"
fi

if grep -q "What NOT to Track" "$AGENTS_FILE" 2>/dev/null; then
  fail "Contains deprecated 'What NOT to Track' section"
else
  pass "No deprecated tracking guidance"
fi

echo ""

# ============================================
# Test 10: Formula files are valid TOML
# ============================================
echo "10. Formula files"

for formula in bmad-feature bmad-bugfix; do
  FORMULA_FILE="$BEADS_SRC/formulas/${formula}.formula.toml"
  if [ -f "$FORMULA_FILE" ]; then
    if grep -q '\[formula\]' "$FORMULA_FILE" && grep -q '\[molecule\]' "$FORMULA_FILE"; then
      pass "${formula}.formula.toml has required sections"
    else
      fail "${formula}.formula.toml missing required sections"
    fi
  else
    fail "${formula}.formula.toml not found"
  fi
done

echo ""

# ============================================
# Test 11: Methodology files
# ============================================
echo "11. Methodology files"

for doc in phases scale-levels triage quality-gates; do
  [ -f "$BEADS_SRC/methodology/${doc}.md" ] && pass "${doc}.md" || fail "${doc}.md missing"
done

echo ""

# ============================================
# Test 12: Config.yaml version and features
# ============================================
echo "12. Config validation"

CONFIG_FILE="$BEADS_SRC/config.yaml"

if grep -q 'version:.*0\.2\.0' "$CONFIG_FILE"; then
  pass "Version is 0.2.0"
else
  fail "Version is not 0.2.0"
fi

if grep -q "execution_modes:" "$CONFIG_FILE"; then
  pass "execution_modes present"
else
  fail "execution_modes missing"
fi

for feature in triage jit_loading molecules gates; do
  if grep -q "$feature" "$CONFIG_FILE"; then
    pass "Feature: $feature"
  else
    fail "Missing feature: $feature"
  fi
done

echo ""

# ============================================
# Summary
# ============================================
echo "==========================="
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED"
  exit 1
else
  echo "ALL PASSED"
  exit 0
fi
