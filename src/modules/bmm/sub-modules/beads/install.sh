#!/usr/bin/env bash
# BMAD + Beads Integration Installer (v3.0)
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
echo "0.0.2" > .beads/.bmad-version
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
if [ -z "$CI" ]; then
    if [ -f .beads/lib/bmad-aliases.sh ]; then
        source .beads/lib/bmad-aliases.sh
    fi
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

if [ -f .beads/lib/bmad-aliases.sh ]; then
    source .beads/lib/bmad-aliases.sh
fi

# Run in background, non-blocking
(bd-auto-sync &) 2>/dev/null

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
echo "📦 Configuration:"
echo "  Project-local: .beads/lib/bmad-aliases.sh"
echo "  Version: $(cat .beads/.bmad-version 2>/dev/null || echo 'unknown')"
echo ""
echo "📋 Next Steps:"
echo ""
echo "  Aliases work automatically in git hooks."
echo "  To use in shell, manually source when needed:"
echo "    source .beads/lib/bmad-aliases.sh"
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
