#!/usr/bin/env bash
# BMAD + Beads Integration Installer (v0.2.0 — Agent-First)
# Project-local configuration with opt-in shell integration
#
# Installs:
#   .bmad/      — Agent methodology (personas, templates, methodology, SKILL.md)
#   .beads/     — Beads state + aliases + formulas
#   BMAD_MANIFEST.md — Universal agent discovery file
#   Git hooks   — Pre-push, post-commit automation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

echo "=== BMAD + Beads Integration Installer (v0.2.0) ==="
echo ""

# 1. Check if bd CLI exists
if ! command -v bd >/dev/null 2>&1; then
  echo "  Beads CLI (bd) not found"
  echo "  Install Beads first: https://github.com/steveyegge/beads"
  exit 1
fi

echo "Found Beads CLI: $(bd --version 2>/dev/null || echo 'installed')"
echo ""

# 2. Initialize beads in project
cd "$PROJECT_ROOT"
echo "Initializing Beads..."
if [ -d ".beads" ]; then
  echo "  Beads already initialized"
else
  bd init || echo "  Failed to initialize, but continuing..."
  echo "  Beads initialized"
fi
echo ""

# 3. Install aliases to project-local .beads/lib/
echo "Installing BMAD aliases..."
mkdir -p .beads/lib .beads/logs .beads/tmp
cp "$SCRIPT_DIR/beads-aliases.sh" .beads/lib/bmad-aliases.sh
BEADS_VERSION=$(awk -F': ' '/^version:/{gsub(/["'"'"']/,"",$2); print $2}' "$SCRIPT_DIR/config.yaml")
echo "${BEADS_VERSION:-0.2.0}" > .beads/.bmad-version
echo "  Installed to .beads/lib/bmad-aliases.sh"
echo ""

echo "  To use aliases in shell, manually source when needed:"
echo "    source .beads/lib/bmad-aliases.sh"
echo ""

# 4. Install .bmad/ directory (agent methodology)
echo "Installing BMAD methodology (.bmad/)..."
mkdir -p .bmad/personas .bmad/templates .bmad/methodology

# Copy SKILL.md
if [ -f "$SCRIPT_DIR/SKILL.md.template" ]; then
  cp "$SCRIPT_DIR/SKILL.md.template" .bmad/SKILL.md
  echo "  .bmad/SKILL.md installed"
fi

# Copy personas
if [ -d "$SCRIPT_DIR/personas" ]; then
  cp "$SCRIPT_DIR/personas/"*.md .bmad/personas/ 2>/dev/null || true
  echo "  .bmad/personas/ installed"
fi

# Copy templates
if [ -d "$SCRIPT_DIR/templates" ]; then
  cp "$SCRIPT_DIR/templates/"*.md .bmad/templates/ 2>/dev/null || true
  echo "  .bmad/templates/ installed"
fi

# Copy methodology
if [ -d "$SCRIPT_DIR/methodology" ]; then
  cp "$SCRIPT_DIR/methodology/"*.md .bmad/methodology/ 2>/dev/null || true
  echo "  .bmad/methodology/ installed"
fi
echo ""

# 5. Generate BMAD_MANIFEST.md
echo "Generating BMAD_MANIFEST.md..."
if [ -f "$SCRIPT_DIR/BMAD_MANIFEST.md.template" ]; then
  # Simple template rendering — replace {{BMAD_HOME}} placeholder
  local_bmad_home="${BMAD_HOME:-~/.bmad-v6}"
  sed "s|{{BMAD_HOME}}|${local_bmad_home}|g" "$SCRIPT_DIR/BMAD_MANIFEST.md.template" > BMAD_MANIFEST.md
  echo "  BMAD_MANIFEST.md generated at project root"
else
  echo "  Template not found, skipping"
fi
echo ""

# 6. Install molecule formulas
echo "Installing molecule formulas..."
mkdir -p .beads/formulas
if [ -d "$SCRIPT_DIR/formulas" ]; then
  cp "$SCRIPT_DIR/formulas/"*.formula.toml .beads/formulas/ 2>/dev/null || true
  echo "  Formulas installed to .beads/formulas/"
else
  echo "  No formulas found, skipping"
fi
echo ""

# 7. Detect hook system (Husky or .git/hooks)
echo "Setting up git hooks..."
HOOK_DIR=""
if [ -d ".husky" ]; then
  HOOK_DIR=".husky"
  echo "  Detected: Husky"
elif [ -d ".git" ]; then
  HOOK_DIR=".git/hooks"
  echo "  Detected: .git/hooks"
else
  echo "  Not a git repository, skipping hooks"
  HOOK_DIR=""
fi

# Helper: Check if hook has Beads shim pattern
_has_beads_shim() {
  local hook_file="$1"
  [ -f "$hook_file" ] && grep -q "bd hooks run" "$hook_file" 2>/dev/null
}

# Helper: Install or extend hook
_install_hook() {
  local hook_name="$1"
  local hook_file="$2"
  local bmad_content="$3"

  if _has_beads_shim "$hook_file"; then
    echo "  Detected Beads native hook, extending..."
    echo "$bmad_content" >> "$hook_file"
    echo "  Extended existing Beads hook"
  else
    cat > "$hook_file" << EOF
#!/usr/bin/env bash
# BMAD + Beads Integration Hook

# Beads native hook (if available)
if command -v bd >/dev/null 2>&1; then
  bd hooks run $hook_name "\$@" || exit 1
fi

$bmad_content
EOF
    chmod +x "$hook_file"
    echo "  Created new hook with Beads shim check"
  fi
}

# 8. Install hooks (if in git repo)
if [ -n "$HOOK_DIR" ]; then
  # Pre-commit: Minimal Beads shim
  echo ""
  echo "Installing pre-commit hook..."
  HOOK_FILE="$HOOK_DIR/pre-commit"

  if _has_beads_shim "$HOOK_FILE"; then
    echo "  Beads native pre-commit already installed"
  else
    cat > "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# Fallback Beads shim — prefer: bd hooks install
command -v bd >/dev/null 2>&1 && exec bd hooks run pre-commit "$@"
EOF
    chmod +x "$HOOK_FILE"
    echo "  Pre-commit fallback shim installed"
  fi

  # Pre-push: Beads shim + BMAD auto-land extension
  echo ""
  echo "Installing pre-push hook..."
  HOOK_FILE="$HOOK_DIR/pre-push"

  BMAD_EXTENSION='
# BMAD + Beads auto-sync check
# Skip in CI environment and agent mode (BEADS_NO_DAEMON=1)
if [ -z "$CI" ]; then
    if [ -f .beads/lib/bmad-aliases.sh ]; then
        source .beads/lib/bmad-aliases.sh
    fi
    bd_auto_land || exit 1
fi
'

  _install_hook "pre-push" "$HOOK_FILE" "$BMAD_EXTENSION"

  # Post-commit: BMAD background sync only
  echo ""
  echo "Installing post-commit hook..."
  HOOK_FILE="$HOOK_DIR/post-commit"

  if [ -f "$HOOK_FILE" ] && grep -q "BMAD.*post-commit" "$HOOK_FILE" 2>/dev/null; then
    echo "  Post-commit hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads post-commit background sync

# Skip in CI environment
[ -n "$CI" ] && exit 0

if [ -f .beads/lib/bmad-aliases.sh ]; then
    source .beads/lib/bmad-aliases.sh
fi

# Run in background, non-blocking
(bd_auto_sync &) 2>/dev/null

exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "  Post-commit hook created"
  fi
fi

# 9. Set safe defaults
echo ""
echo "Configuring workflow defaults..."
if [ -z "$(git config beads.auto-sync 2>/dev/null)" ]; then
  git config beads.auto-sync warning
  echo "  Auto-sync: warning"
fi

if [ -z "$(git config beads.workflow-mode 2>/dev/null)" ]; then
  git config beads.workflow-mode mixed
  echo "  Workflow mode: mixed"
fi

# 10. Update AGENTS.md with managed block (idempotent)
_update_agents_md() {
  local agents_md=".beads/AGENTS.md"
  local template_file="$SCRIPT_DIR/AGENTS.md.template"

  if [ ! -f "$template_file" ]; then
    echo "  AGENTS.md template not found, skipping"
    return
  fi

  local managed_content
  managed_content=$(sed -n '/<!-- BMAD-BEADS:START -->/,/<!-- BMAD-BEADS:END -->/p' "$template_file")

  if [ ! -f "$agents_md" ]; then
    echo "  Creating .beads/AGENTS.md..."
    cp "$template_file" "$agents_md"
    echo "  Created .beads/AGENTS.md"
  else
    if grep -q "<!-- BMAD-BEADS:START -->" "$agents_md" 2>/dev/null; then
      echo "  Updating Beads integration guidance in .beads/AGENTS.md..."

      local temp_block="/tmp/bmad_managed_$$.txt"
      echo "$managed_content" > "$temp_block"

      sed '/<!-- BMAD-BEADS:START -->/,/<!-- BMAD-BEADS:END -->/{
        /<!-- BMAD-BEADS:START -->/{
          r '"$temp_block"'
          d
        }
        /<!-- BMAD-BEADS:END -->/!d
      }' "$agents_md" > "$agents_md.tmp" && mv "$agents_md.tmp" "$agents_md"

      rm -f "$temp_block"
      echo "  Updated managed block in .beads/AGENTS.md"
    else
      echo "  Adding Beads integration guidance to .beads/AGENTS.md..."
      echo "" >> "$agents_md"
      echo "$managed_content" >> "$agents_md"
      echo "  Added managed block to .beads/AGENTS.md"
    fi
  fi
}

echo ""
echo "Updating agent guidance..."
_update_agents_md

# 11. Install documentation
echo ""
echo "Installing documentation..."
mkdir -p "$PROJECT_ROOT/docs"

if [ -f "$SCRIPT_DIR/beads-reference.md" ]; then
  cp "$SCRIPT_DIR/beads-reference.md" "$PROJECT_ROOT/docs/beads-reference.md"
  echo "  beads-reference.md → docs/"
fi

# 12. Validation
echo ""
echo "Validating installation..."
local_ok=true

[ ! -f ".bmad/SKILL.md" ] && echo "  WARN: .bmad/SKILL.md missing" && local_ok=false
[ ! -f "BMAD_MANIFEST.md" ] && echo "  WARN: BMAD_MANIFEST.md missing" && local_ok=false
[ ! -f ".beads/lib/bmad-aliases.sh" ] && echo "  WARN: aliases not installed" && local_ok=false
[ ! -d ".beads/formulas" ] && echo "  WARN: formulas not installed" && local_ok=false

if [ "$local_ok" = true ]; then
  echo "  All components validated"
fi

# 13. Summary
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed:"
echo "  .bmad/              — Agent methodology (SKILL.md, personas, templates)"
echo "  .beads/lib/         — BMAD aliases (v${BEADS_VERSION:-0.2.0})"
echo "  .beads/formulas/    — Molecule templates"
echo "  .beads/AGENTS.md    — Agent-first protocol reference"
echo "  BMAD_MANIFEST.md    — Universal agent discovery"
echo ""
echo "Agent Quick Start:"
echo "  1. Read BMAD_MANIFEST.md for project context"
echo "  2. Run: bd prime"
echo "  3. Run: bd ready --json"
echo "  4. Claim: bd update <id> --status in_progress --claim"
echo "  5. Work following .bmad/personas/ and .bmad/templates/"
echo "  6. Close: bd close <id> --reason \"summary\""
echo "  7. Sync: bd sync"
echo ""
echo "Shell Usage (optional):"
echo "  source .beads/lib/bmad-aliases.sh"
echo "  bd_help"
echo ""
echo "Docs: docs/beads-reference.md"
echo ""
