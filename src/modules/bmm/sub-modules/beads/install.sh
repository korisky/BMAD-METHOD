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

# 3. Install aliases to project-local .beads/lib/
echo "Installing BMAD aliases..."
mkdir -p .beads/lib .beads/logs .beads/tmp
cp "$SCRIPT_DIR/beads-aliases.sh" .beads/lib/aliases.sh
echo "  ✅ Installed to .beads/lib/aliases.sh"
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

# 5. Install hooks (if in git repo)
if [ -n "$HOOK_DIR" ]; then
  # Pre-commit: bd sync
  echo ""
  echo "Installing pre-commit hook..."
  HOOK_FILE="$HOOK_DIR/pre-commit"
  if [ -f "$HOOK_FILE" ] && grep -q "bd sync" "$HOOK_FILE" 2>/dev/null; then
    echo "  ✅ Pre-commit hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads: Auto-sync on commit

# Skip in CI
[ -n "$CI" ] && exit 0

# Sync beads
if [ -d ".beads" ] && command -v bd >/dev/null 2>&1; then
  bd sync 2>/dev/null || true
fi
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Pre-commit hook created"
  fi

  # Pre-push: bd_auto_land
  echo ""
  echo "Installing pre-push hook..."
  HOOK_FILE="$HOOK_DIR/pre-push"
  if [ -f "$HOOK_FILE" ] && grep -q "bd_auto_land" "$HOOK_FILE" 2>/dev/null; then
    echo "  ✅ Pre-push hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads: Auto-sync check before push

# Skip in CI
[ -n "$CI" ] && exit 0

# Check if aliases loaded
if [ -f .beads/lib/aliases.sh ]; then
  source .beads/lib/aliases.sh
  bd_auto_land || exit 1
fi
EOF
    chmod +x "$HOOK_FILE"
    echo "  ✅ Pre-push hook created"
  fi

  # Post-commit: bd_auto_sync (background)
  echo ""
  echo "Installing post-commit hook..."
  HOOK_FILE="$HOOK_DIR/post-commit"
  if [ -f "$HOOK_FILE" ] && grep -q "bd_auto_sync" "$HOOK_FILE" 2>/dev/null; then
    echo "  ✅ Post-commit hook already configured"
  else
    cat >> "$HOOK_FILE" << 'EOF'
#!/usr/bin/env bash
# BMAD + Beads: Background sync after commit

# Skip in CI
[ -n "$CI" ] && exit 0

# Run background sync
if [ -f .beads/lib/aliases.sh ]; then
  source .beads/lib/aliases.sh
  (bd_auto_sync &) 2>/dev/null
fi
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
echo "  1. Add to your shell RC (~/.bashrc or ~/.zshrc):"
echo "     echo '[ -f .beads/lib/aliases.sh ] && source .beads/lib/aliases.sh' >> ~/.bashrc"
echo ""
echo "  2. Reload shell:"
echo "     exec \$SHELL"
echo ""
echo "  3. Verify installation:"
echo "     bd_help"
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
