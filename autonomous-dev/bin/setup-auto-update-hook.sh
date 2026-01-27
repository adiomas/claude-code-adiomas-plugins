#!/bin/bash
# =============================================================================
# SETUP AUTO-UPDATE HOOK
# =============================================================================
# Instalira git post-push hook koji automatski updatea claude-agi nakon pusha.
#
# Usage:
#   ./setup-auto-update-hook.sh          # Instaliraj hook
#   ./setup-auto-update-hook.sh --remove # Ukloni hook
#
# Version: 4.2.2
# =============================================================================

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Find git root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
}

HOOK_PATH="$GIT_ROOT/.git/hooks/post-push"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# REMOVE HOOK
# =============================================================================
if [[ "${1:-}" == "--remove" ]]; then
    if [[ -f "$HOOK_PATH" ]]; then
        rm "$HOOK_PATH"
        echo -e "${GREEN}Hook removed: $HOOK_PATH${NC}"
    else
        echo -e "${YELLOW}Hook not found: $HOOK_PATH${NC}"
    fi
    exit 0
fi

# =============================================================================
# INSTALL HOOK
# =============================================================================

# Create hooks directory if needed
mkdir -p "$(dirname "$HOOK_PATH")"

# Create the hook
cat > "$HOOK_PATH" << 'HOOK_EOF'
#!/bin/bash
# =============================================================================
# POST-PUSH HOOK: Auto-update claude-agi
# =============================================================================
# Automatically reinstalls claude-agi after pushing changes to the plugin repo.
# Installed by: autonomous-dev/bin/setup-auto-update-hook.sh
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find plugin directory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
PLUGIN_DIR="$GIT_ROOT/autonomous-dev"
INSTALLER="$PLUGIN_DIR/bin/install-claude-agi.sh"

# Check if this is the plugin repo
if [[ ! -x "$INSTALLER" ]]; then
    # Not the plugin repo, skip silently
    exit 0
fi

echo -e "${YELLOW}Updating claude-agi after push...${NC}"

# Run installer
if "$INSTALLER" 2>/dev/null; then
    echo -e "${GREEN}claude-agi updated successfully${NC}"
else
    echo -e "${YELLOW}Warning: claude-agi update failed (non-critical)${NC}"
fi

exit 0
HOOK_EOF

# Make executable
chmod +x "$HOOK_PATH"

echo -e "${GREEN}Hook installed: $HOOK_PATH${NC}"
echo ""
echo "claude-agi will now auto-update after each 'git push' in this repo."
echo ""
echo -e "To remove: ${YELLOW}$0 --remove${NC}"
