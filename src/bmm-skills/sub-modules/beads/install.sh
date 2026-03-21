#!/usr/bin/env bash
# BMAD + Beads Integration Installer (v4.0 — v6.2.0 skills architecture)
# Project-local configuration with opt-in shell integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

echo "=== BMAD + Beads Integration Installer ==="
echo ""

# 1. Check if bd CLI exists
if ! command -v bd >/dev/null 2>&1; then
  echo "❌ Beads CLI (bd) not found"
  echo "   Install Beads first: https://github.com/steveyegge/beads"
  exit 1
fi

echo "✅ Found Beads CLI: $(bd --version 2>/dev/null || echo 'installed')"
echo ""

# 2. Initialize beads in project (uses Beads built-in)
cd "$PROJECT_ROOT"
echo "Initializing Beads..."
if [ -d ".beads" ]; then
  echo "  ✅ Beads already initialized"
else
  bd init || echo "  ⚠️  Failed to initialize, but continuing..."
  echo "  ✅ Beads initialized"
fi
echo ""

# 3. Install aliases to project-local .beads/lib/
echo "Installing BMAD aliases..."
mkdir -p .beads/lib .beads/logs .beads/tmp
cp "$SCRIPT_DIR/beads-aliases.sh" .beads/lib/bmad-aliases.sh
BEADS_VERSION=$(awk -F': ' '/^version:/{gsub(/["'"'"']/,"",$2); print $2}' "$SCRIPT_DIR/config.yaml")
echo "${BEADS_VERSION:-0.2.0}" > .beads/.bmad-version
echo "  ✅ Installed to .beads/lib/bmad-aliases.sh"
echo ""

echo "  ℹ️  To use aliases in shell, manually source when needed:"
echo "     source .beads/lib/bmad-aliases.sh"

echo ""

# 4. Detect hook system (Husky or .git/hooks)
echo "Setting up git hooks..."
HOOK_DIR=""
if [ -d ".husky" ]; then
  HOOK_DIR=".husky"
  echo "  Detected: Husky"
elif [ -d ".git" ]; then
  HOOK_DIR=".git/hooks"
  echo "  Detected: .git/hooks"
else
  echo "  ⚠️  Not a git repository, skipping hooks"
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
    echo "  ✅ Extended existing Beads hook"
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
    echo "  ✅ Created new hook with Beads shim check"
  fi
}

# 5. Install hooks (if in git repo)
if [ -n "$HOOK_DIR" ]; then
  # Pre-commit: Minimal Beads shim (fallback for when bd hooks install hasn't run)
  echo ""
  echo "Installing pre-commit hook..."
  HOOK_FILE="$HOOK_DIR/pre-commit"

  if _has_beads_shim "$HOOK_FILE"; then
    echo "  ✅ Beads native pre-commit already installed"
  else
    cat > "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# Fallback Beads shim — prefer: bd hooks install
command -v bd >/dev/null 2>&1 && exec bd hooks run pre-commit "$@"
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Pre-commit fallback shim installed"
    echo "  ℹ️  For full native hooks: bd hooks install"
  fi

  # Pre-push: Beads shim + BMAD auto-land extension
  echo ""
  echo "Installing pre-push hook..."
  HOOK_FILE="$HOOK_DIR/pre-push"

  BMAD_EXTENSION='
# BMAD + Beads auto-sync check (added by beads sync automation)
# Skip in CI environment
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
    echo "  ✅ Post-commit hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads post-commit background sync

# Skip BMAD auto-sync in CI environment
[ -n "$CI" ] && exit 0

if [ -f .beads/lib/bmad-aliases.sh ]; then
    source .beads/lib/bmad-aliases.sh
fi

# Run in background, non-blocking
(bd_auto_sync &) 2>/dev/null

exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Post-commit hook created"
  fi
fi

# 6. Set safe defaults for mixed human/agent workflow
echo ""
echo "Configuring workflow defaults..."
if [ -z "$(git config beads.auto-sync 2>/dev/null)" ]; then
  git config beads.auto-sync warning
  echo "  ✅ Auto-sync: warning (change with: bd_config_sync <mode>)"
fi

if [ -z "$(git config beads.workflow-mode 2>/dev/null)" ]; then
  git config beads.workflow-mode mixed
  echo "  ✅ Workflow mode: mixed (change with: bd_config_workflow <mode>)"
fi

# Check daemon configuration and warn about common issues
if command -v bd >/dev/null 2>&1; then
  daemon_pid=$(pgrep -f "bd.*daemon" 2>/dev/null | head -1)
  if [ -n "$daemon_pid" ]; then
    daemon_cmd=$(ps -p "$daemon_pid" -o args= 2>/dev/null)

    # Warn if daemon using --auto-push (conflicts with pre-push hook)
    if echo "$daemon_cmd" | grep -q -- "--auto-push"; then
      echo ""
      echo "  ⚠️  WARNING: Daemon is using --auto-push"
      echo "     This conflicts with pre-push hook and causes race conditions."
      echo "     Fix: bd daemon --stop && bd daemon --start --interval 5s --auto-commit --auto-pull"
      echo ""
    fi
  fi
fi

# 7. Update AGENTS.md with managed Beads integration guidance (idempotent)
_update_agents_md() {
  local agents_md=".beads/AGENTS.md"
  local template_file="$SCRIPT_DIR/AGENTS.md.template"

  # If template doesn't exist, skip (shouldn't happen, but be defensive)
  if [ ! -f "$template_file" ]; then
    echo "  ⚠️  AGENTS.md template not found, skipping"
    return
  fi

  # Extract the managed block content from template
  local managed_content
  managed_content=$(sed -n '/<!-- BMAD-BEADS:START -->/,/<!-- BMAD-BEADS:END -->/p' "$template_file")

  if [ ! -f "$agents_md" ]; then
    # File doesn't exist - create from template
    echo "  Creating .beads/AGENTS.md..."
    cp "$template_file" "$agents_md"
    echo "  ✅ Created .beads/AGENTS.md"
  else
    # File exists - update managed block (idempotent)
    if grep -q "<!-- BMAD-BEADS:START -->" "$agents_md" 2>/dev/null; then
      # Managed block exists - replace it
      echo "  Updating Beads integration guidance in .beads/AGENTS.md..."

      # Create temp file with updated content
      local temp_block="/tmp/bmad_managed_$$.txt"
      echo "$managed_content" > "$temp_block"

      # Use sed to read temp file instead of inline replacement
      sed '/<!-- BMAD-BEADS:START -->/,/<!-- BMAD-BEADS:END -->/{
        /<!-- BMAD-BEADS:START -->/{
          r '"$temp_block"'
          d
        }
        /<!-- BMAD-BEADS:END -->/!d
      }' "$agents_md" > "$agents_md.tmp" && mv "$agents_md.tmp" "$agents_md"

      rm -f "$temp_block"
      echo "  ✅ Updated managed block in .beads/AGENTS.md"
    else
      # No managed block - append it
      echo "  Adding Beads integration guidance to .beads/AGENTS.md..."
      echo "" >> "$agents_md"
      echo "$managed_content" >> "$agents_md"
      echo "  ✅ Added managed block to .beads/AGENTS.md"
    fi
  fi
}

echo ""
echo "Updating agent guidance..."
_update_agents_md

# 8. Install workflow documentation
echo ""
echo "Installing documentation..."
mkdir -p "$PROJECT_ROOT/docs"

if [ -f "$SCRIPT_DIR/beads-reference.md" ]; then
  cp "$SCRIPT_DIR/beads-reference.md" "$PROJECT_ROOT/docs/beads-reference.md"
  echo "  ✅ beads-reference.md → docs/"
fi

# 9. Summary
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Configuration:"
echo "  Project-local: .beads/lib/bmad-aliases.sh"
echo "  Version: $(cat .beads/.bmad-version 2>/dev/null || echo 'unknown')"
echo ""
echo "Next Steps:"
echo ""
echo "  Aliases work automatically in git hooks."
echo "  To use in shell, manually source when needed:"
echo "    source .beads/lib/bmad-aliases.sh"
echo ""
echo "Key Commands:"
echo "  bd_preflight  - Check if ready to push"
echo "  bd_health     - System health check"
echo "  bd_land       - Sync branches"
echo "  bd list       - Show all Beads items (native)"
echo "  bd ready      - Show ready work (native)"
echo ""
echo "Documentation:"
echo "  docs/beads-reference.md       - Full reference (sync, troubleshooting)"
echo "  .beads/AGENTS.md              - Agent guidance"
echo ""
