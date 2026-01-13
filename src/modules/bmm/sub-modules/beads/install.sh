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

# 3. Install Beads git hooks
echo ""
echo "Installing Beads git hooks..."
bd hooks install 2>/dev/null || echo "  Hooks already installed or not in git repo"

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

# 6. Detect shell and add source line
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

# 7. Summary
echo ""
echo "=== Setup Complete ==="
echo ""
echo "To start using Beads integration:"
echo "  1. Restart your terminal or run: source ~/.bmad/beads-aliases.sh"
echo "  2. Run 'bd-help' to see available commands"
echo "  3. Run 'bd-status' to check current state"
echo ""
echo "Key commands:"
echo "  bd-status     - See ready work and blockers"
echo "  bd-claim X    - Claim a story before starting"
echo "  bd-decision X - Record a runtime decision"
echo "  bd-halt X     - Record a HALT condition"
echo ""
