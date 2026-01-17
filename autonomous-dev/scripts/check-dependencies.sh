#!/bin/bash
# =============================================================================
# DEPENDENCY CHECKER v1.0
# =============================================================================
# Validates that all required dependencies are available for autonomous-dev.
# Provides installation hints for missing dependencies.
# =============================================================================

set -euo pipefail

# Color codes for output (fallback to no color if not supported)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if colors are supported
if [[ ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

MISSING=0
OPTIONAL_MISSING=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

check_required() {
    local cmd="$1"
    local install_hint="$2"

    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is installed"
    else
        echo -e "${RED}✗${NC} $cmd is NOT installed"
        echo -e "  ${YELLOW}Install:${NC} $install_hint"
        ((MISSING++)) || true
    fi
}

check_optional() {
    local cmd="$1"
    local install_hint="$2"
    local purpose="$3"

    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is installed (optional)"
    else
        echo -e "${YELLOW}○${NC} $cmd is not installed (optional - $purpose)"
        echo -e "  ${YELLOW}Install:${NC} $install_hint"
        ((OPTIONAL_MISSING++)) || true
    fi
}

# =============================================================================
# DEPENDENCY CHECKS
# =============================================================================

echo "=== Autonomous-Dev Dependency Checker ==="
echo ""
echo "--- Required Dependencies ---"

# Git (essential for worktree management)
check_required "git" "Install Git from https://git-scm.com/downloads"

# yq (YAML processing - critical for state management)
check_required "yq" "brew install yq (macOS) OR pip install yq OR snap install yq"

# jq (JSON processing - critical for hooks.json and API responses)
check_required "jq" "brew install jq (macOS) OR apt install jq (Linux)"

# awk (arithmetic and text processing - used instead of bc)
check_required "awk" "Usually pre-installed. If missing: brew install gawk (macOS)"

# realpath (path resolution - used in scripts)
if command -v realpath &>/dev/null; then
    echo -e "${GREEN}✓${NC} realpath is installed"
elif command -v grealpath &>/dev/null; then
    echo -e "${GREEN}✓${NC} grealpath is installed (macOS alternative)"
else
    echo -e "${RED}✗${NC} realpath/grealpath is NOT installed"
    echo -e "  ${YELLOW}Install:${NC} brew install coreutils (macOS)"
    ((MISSING++)) || true
fi

echo ""
echo "--- Optional Dependencies ---"

# shellcheck (for script validation)
check_optional "shellcheck" "brew install shellcheck (macOS) OR apt install shellcheck (Linux)" "script validation"

# notify-send (Linux notifications)
if [[ "$(uname)" == "Linux" ]]; then
    check_optional "notify-send" "apt install libnotify-bin (Linux)" "desktop notifications"
fi

# osascript (macOS notifications - should be pre-installed)
if [[ "$(uname)" == "Darwin" ]]; then
    if command -v osascript &>/dev/null; then
        echo -e "${GREEN}✓${NC} osascript is installed (macOS notifications)"
    fi
fi

# tree (for directory visualization)
check_optional "tree" "brew install tree (macOS) OR apt install tree (Linux)" "directory visualization"

echo ""
echo "--- Version Information ---"
echo "Git version: $(git --version 2>/dev/null || echo "not found")"
echo "yq version: $(yq --version 2>/dev/null || echo "not found")"
echo "jq version: $(jq --version 2>/dev/null || echo "not found")"
echo "awk version: $(awk --version 2>/dev/null | head -1 || echo "not found")"

echo ""
echo "=== Summary ==="
if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}All required dependencies are installed!${NC}"
    if [[ $OPTIONAL_MISSING -gt 0 ]]; then
        echo -e "${YELLOW}$OPTIONAL_MISSING optional dependency/dependencies not installed.${NC}"
    fi
    exit 0
else
    echo -e "${RED}$MISSING required dependency/dependencies missing!${NC}"
    echo "Please install the missing dependencies before using autonomous-dev."
    exit 1
fi
