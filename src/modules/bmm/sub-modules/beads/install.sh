#!/usr/bin/env bash
# BMAD + Beads Integration Installer (v2.0)
# Simplified project-local installation

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

# 3. Install aliases to global ~/.bmad/
echo "Installing BMAD aliases..."
mkdir -p ~/.bmad ~/.bmad/logs ~/.bmad/tmp
cp "$SCRIPT_DIR/beads-aliases.sh" ~/.bmad/beads-aliases.sh
echo "  ✅ Installed to ~/.bmad/beads-aliases.sh"

# Keep project-local dirs for logs
mkdir -p .beads/logs .beads/tmp
echo ""

# 3b. Add to shell profile (if not already present)
echo "Configuring shell profile..."

# Detect shell
USER_SHELL=$(basename "$SHELL")
PROFILE_FILE=""

case "$USER_SHELL" in
  bash)
    if [ -f ~/.bash_profile ]; then
      PROFILE_FILE=~/.bash_profile
    elif [ -f ~/.bashrc ]; then
      PROFILE_FILE=~/.bashrc
    fi
    ;;
  zsh)
    PROFILE_FILE=~/.zshrc
    ;;
  *)
    echo "  ⚠️  Unknown shell: $USER_SHELL"
    echo "     Add manually to your shell profile:"
    echo "     source ~/.bmad/beads-aliases.sh"
    PROFILE_FILE=""
    ;;
esac

if [ -n "$PROFILE_FILE" ]; then
  SOURCING_LINE="[ -f ~/.bmad/beads-aliases.sh ] && source ~/.bmad/beads-aliases.sh"

  if grep -qF "$SOURCING_LINE" "$PROFILE_FILE" 2>/dev/null; then
    echo "  ✅ Shell profile already configured ($PROFILE_FILE)"
  else
    echo "" >> "$PROFILE_FILE"
    echo "# BMAD + Beads Integration (added by installer)" >> "$PROFILE_FILE"
    echo "$SOURCING_LINE" >> "$PROFILE_FILE"
    echo "  ✅ Added to $PROFILE_FILE"
    echo "     Run: exec \$SHELL (to reload)"
  fi
fi
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
  # Pre-commit: Beads shim only (no BMAD extension needed)
  echo ""
  echo "Installing pre-commit hook..."
  HOOK_FILE="$HOOK_DIR/pre-commit"

  if _has_beads_shim "$HOOK_FILE"; then
    echo "  ✅ Beads native pre-commit hook already installed"
  else
    cat > "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# bd-shim v1
# BMAD + Beads Integration pre-commit hook

# Check if bd is available
if ! command -v bd >/dev/null 2>&1; then
    echo "Warning: bd command not found in PATH, skipping pre-commit hook" >&2
    exit 0
fi

# Run bd's built-in pre-commit hook
exec bd hooks run pre-commit "$@"
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Pre-commit hook created"
  fi

  # Pre-push: Beads shim + BMAD auto-land extension
  echo ""
  echo "Installing pre-push hook..."
  HOOK_FILE="$HOOK_DIR/pre-push"

  BMAD_EXTENSION='
# BMAD + Beads auto-sync check (added by beads sync automation)
# Skip in CI environment
if [ -z "$CI" ] && [ -f ~/.bmad/beads-aliases.sh ]; then
    source ~/.bmad/beads-aliases.sh
    bd-auto-land || exit 1
fi
'

  _install_hook "pre-push" "$HOOK_FILE" "$BMAD_EXTENSION"

  # Post-commit: BMAD background sync only
  echo ""
  echo "Installing post-commit hook..."
  HOOK_FILE="$HOOK_DIR/post-commit"

  if [ -f "$HOOK_FILE" ] && grep -q "bd-auto-sync" "$HOOK_FILE" 2>/dev/null; then
    echo "  ✅ Post-commit hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads post-commit background sync

# Skip BMAD auto-sync in CI environment
[ -n "$CI" ] && exit 0

if [ -f ~/.bmad/beads-aliases.sh ]; then
    source ~/.bmad/beads-aliases.sh
    # Run in background, non-blocking
    (bd-auto-sync &) 2>/dev/null
fi

exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Post-commit hook created"
  fi
fi

# 6. Install workflow documentation
echo ""
echo "Installing documentation..."
mkdir -p "$PROJECT_ROOT/docs"

if [ -f "$SCRIPT_DIR/beads-git-workflow.md" ]; then
  cp "$SCRIPT_DIR/beads-git-workflow.md" "$PROJECT_ROOT/docs/beads-git-workflow.md"
  echo "  ✅ beads-git-workflow.md → docs/"
fi

if [ -f "$SCRIPT_DIR/bmad-workflow-guide.md" ]; then
  cp "$SCRIPT_DIR/bmad-workflow-guide.md" "$PROJECT_ROOT/docs/bmad-workflow-guide.md"
  echo "  ✅ bmad-workflow-guide.md → docs/"
fi

# 7. Summary
echo ""
echo "=== Installation Complete ==="
echo ""
echo "📋 Next Steps:"
echo ""
echo "  1. Reload shell (if shell profile was updated):"
echo "     exec \$SHELL"
echo ""
echo "  2. Verify installation:"
echo "     bd-help"
echo ""
echo "  Note: Aliases automatically sourced from ~/.bmad/beads-aliases.sh"
echo ""
echo "🔧 Key Commands:"
echo "  bd_preflight  - Check if ready to push"
echo "  bd_health     - System health check"
echo "  bd_land       - Sync branches"
echo "  bd_help       - Show all commands"
echo ""
echo "📚 Documentation:"
echo "  docs/bmad-workflow-guide.md   - Workflow guide"
echo "  docs/beads-git-workflow.md    - Git workflow & recovery"
echo ""
