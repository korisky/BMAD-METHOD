#!/bin/bash
# BMAD + Beads Integration Installer
# Run this after BMAD installation to set up Beads integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"

echo "=== BMAD + Beads Integration Setup ==="
echo ""

# 1. Check if bd CLI is available
if ! command -v bd &> /dev/null; then
    echo "ERROR: Beads CLI (bd) not found."
    echo "Install Beads first: https://github.com/steveyegge/beads"
    exit 1
fi

echo "Found Beads CLI: $(bd --version 2>/dev/null || echo 'installed')"

# 2. Initialize Beads in project
echo ""
echo "Initializing Beads in project..."
cd "$PROJECT_ROOT"
if [ -d ".beads" ]; then
    echo "  Beads already initialized"
else
    bd init
    echo "  Beads initialized"
fi

# 3. Install git pre-commit hook for beads auto-sync
echo ""
echo "Checking git hooks setup..."
if [ -d ".git" ]; then
    # Check if Husky is managing hooks (preferred)
    if [ -d ".husky" ] && grep -q "bd sync" ".husky/pre-commit" 2>/dev/null; then
        echo "  ✅ Husky pre-commit hook already has beads sync"
        echo "  (Husky manages git hooks for this project)"
    elif [ -d ".husky" ]; then
        echo "  ⚠️  Husky detected but pre-commit doesn't have beads sync"
        echo "  Add this to .husky/pre-commit:"
        echo "    if [ -d \".beads\" ] && command -v bd >/dev/null 2>&1; then"
        echo "      bd sync 2>/dev/null || true"
        echo "    fi"
    else
        # No Husky - install to .git/hooks/
        HOOK_FILE=".git/hooks/pre-commit"
        if [ -f "$HOOK_FILE" ] && grep -q "bd sync" "$HOOK_FILE" 2>/dev/null; then
            echo "  ✅ Pre-commit hook already configured"
        elif [ -f "$HOOK_FILE" ]; then
            echo "  Existing pre-commit hook found, appending beads sync..."
            cat >> "$HOOK_FILE" << 'EOF'

# BMAD + Beads auto-sync (added by beads installer)
if [ -d ".beads" ] && command -v bd &> /dev/null; then
    bd sync 2>/dev/null || true
fi
EOF
            echo "  ✅ Beads sync appended to existing hook"
        else
            cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# BMAD + Beads auto-sync

if [ -d ".beads" ] && command -v bd &> /dev/null; then
    bd sync 2>/dev/null || true
fi

exit 0
EOF
            chmod +x "$HOOK_FILE"
            echo "  ✅ Pre-commit hook created"
        fi
    fi
else
    echo "  ⚠️  Not a git repository, skipping hook installation"
fi

# 4. Replace AGENTS.md with BMAD-integrated version
echo ""
echo "Installing BMAD-integrated AGENTS.md..."
if [ -f "$SCRIPT_DIR/AGENTS.md.template" ]; then
    cp "$SCRIPT_DIR/AGENTS.md.template" "$PROJECT_ROOT/AGENTS.md"
    echo "  AGENTS.md updated with BMAD+Beads integration"
else
    echo "  WARNING: AGENTS.md.template not found, keeping Beads default"
fi

# 5. Install shell aliases
echo ""
echo "Installing shell aliases..."
ALIASES_DIR="$HOME/.bmad"
mkdir -p "$ALIASES_DIR"
cp "$SCRIPT_DIR/beads-aliases.sh" "$ALIASES_DIR/beads-aliases.sh"
echo "  Aliases installed to $ALIASES_DIR/beads-aliases.sh"

# 6. Copy workflow documentation
echo ""
echo "Installing workflow documentation..."
mkdir -p "$PROJECT_ROOT/docs"

# Copy beads-git-workflow.md
if [ -f "$SCRIPT_DIR/beads-git-workflow.md" ]; then
    cp "$SCRIPT_DIR/beads-git-workflow.md" "$PROJECT_ROOT/docs/beads-git-workflow.md"
    echo "  ✅ beads-git-workflow.md installed to $PROJECT_ROOT/docs/"

    # Also copy to ~/.bmad/ for quick reference
    cp "$SCRIPT_DIR/beads-git-workflow.md" "$ALIASES_DIR/beads-git-workflow.md"
    echo "  ✅ Reference copy installed to $ALIASES_DIR/"
else
    echo "  ⚠️  beads-git-workflow.md not found in installer, skipping"
fi

# Copy bmad-workflow-guide.md
if [ -f "$SCRIPT_DIR/bmad-workflow-guide.md" ]; then
    cp "$SCRIPT_DIR/bmad-workflow-guide.md" "$PROJECT_ROOT/docs/bmad-workflow-guide.md"
    echo "  ✅ bmad-workflow-guide.md installed to $PROJECT_ROOT/docs/"

    # Also copy to ~/.bmad/ for quick reference
    cp "$SCRIPT_DIR/bmad-workflow-guide.md" "$ALIASES_DIR/bmad-workflow-guide.md"
    echo "  ✅ Reference copy installed to $ALIASES_DIR/"
else
    echo "  ⚠️  bmad-workflow-guide.md not found in installer, skipping"
fi

# 7. Detect shell and add source line
SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "beads-aliases.sh" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# BMAD + Beads Integration" >> "$SHELL_RC"
        echo "source ~/.bmad/beads-aliases.sh" >> "$SHELL_RC"
        echo "  Added source line to $SHELL_RC"
    else
        echo "  Source line already in $SHELL_RC"
    fi
fi

# 8. Summary
echo ""
echo "=== Setup Complete ==="
echo ""
echo "✅ Beads integration installed"
echo ""
echo "📋 Simple Workflow (Human or Agent):"
echo "  1. Work & commit normally (hook auto-syncs beads)"
echo "  2. Ready to push? Run: bd-preflight"
echo "  3. If ❌: Run bd-land, then bd-preflight again"
echo "  4. If ✅: git push"
echo ""
echo "🔧 Key Commands:"
echo "  bd-preflight  - Check if ready to push"
echo "  bd-land       - Sync branches (beads-sync → main → current)"
echo "  bd-fix        - Auto-fix common issues"
echo "  bd-status     - See ready work and blockers"
echo "  bd-help       - Show all commands"
echo ""
echo "📚 Documentation:"
echo "  docs/bmad-workflow-guide.md   - Strategic workflow guide"
echo "  docs/beads-git-workflow.md    - Git workflow & recovery"
echo ""
echo "⚡ Next Steps:"
echo "  1. Restart terminal or run: source ~/.bmad/beads-aliases.sh"
echo "  2. Run 'bd-help' to see all commands"
echo ""
