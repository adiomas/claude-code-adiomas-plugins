#!/usr/bin/env bash
# install-claude-agi.sh - Install claude-agi orchestrator to user's PATH
#
# Usage:
#   ./install-claude-agi.sh           Install to ~/.local/bin (default)
#   ./install-claude-agi.sh --global  Install to /usr/local/bin (requires sudo)
#   ./install-claude-agi.sh --uninstall Remove claude-agi from PATH
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly VERSION="4.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_FILE="$SCRIPT_DIR/claude-agi"
readonly LOCAL_BIN="$HOME/.local/bin"
readonly GLOBAL_BIN="/usr/local/bin"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Print usage
usage() {
    cat << EOF
install-claude-agi.sh v${VERSION} - Install claude-agi orchestrator

Usage:
    ./install-claude-agi.sh           Install to ~/.local/bin (default)
    ./install-claude-agi.sh --global  Install to /usr/local/bin (requires sudo)
    ./install-claude-agi.sh --uninstall Remove claude-agi from PATH
    ./install-claude-agi.sh --help    Show this help

After installation, you can use:
    claude-agi                Start autonomous execution
    claude-agi --overnight    Start overnight mode
    claude-agi --status       Check execution status
EOF
}

# Check if directory is in PATH
is_in_path() {
    local dir="$1"
    echo "$PATH" | tr ':' '\n' | grep -q "^$dir$"
}

# Add directory to PATH in shell config
add_to_path() {
    local dir="$1"
    local shell_config=""

    # Determine shell config file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
        if [[ -f "$HOME/.bash_profile" ]]; then
            shell_config="$HOME/.bash_profile"
        else
            shell_config="$HOME/.bashrc"
        fi
    fi

    if [[ -n "$shell_config" ]] && [[ -f "$shell_config" ]]; then
        if ! grep -q "export PATH=\"$dir:\$PATH\"" "$shell_config" 2>/dev/null; then
            echo "" >> "$shell_config"
            echo "# Added by claude-agi installer" >> "$shell_config"
            echo "export PATH=\"$dir:\$PATH\"" >> "$shell_config"
            echo -e "${YELLOW}Added $dir to PATH in $shell_config${NC}"
            echo -e "${YELLOW}Run 'source $shell_config' or restart your terminal${NC}"
        fi
    fi
}

# Install to local bin
install_local() {
    echo -e "${BLUE}Installing claude-agi to $LOCAL_BIN...${NC}"

    # Create directory if needed
    mkdir -p "$LOCAL_BIN"

    # Copy script
    cp "$SOURCE_FILE" "$LOCAL_BIN/claude-agi"
    chmod +x "$LOCAL_BIN/claude-agi"

    # Check if in PATH
    if ! is_in_path "$LOCAL_BIN"; then
        echo -e "${YELLOW}$LOCAL_BIN is not in your PATH${NC}"
        add_to_path "$LOCAL_BIN"
    fi

    echo -e "${GREEN}✓ claude-agi installed successfully!${NC}"
    echo ""
    echo "Usage:"
    echo "  claude-agi                Start autonomous execution"
    echo "  claude-agi --overnight    Start overnight mode"
    echo "  claude-agi --status       Check execution status"
    echo "  claude-agi --help         Show all options"
}

# Install to global bin
install_global() {
    echo -e "${BLUE}Installing claude-agi to $GLOBAL_BIN...${NC}"

    # Check for sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Global installation requires sudo${NC}"
        sudo cp "$SOURCE_FILE" "$GLOBAL_BIN/claude-agi"
        sudo chmod +x "$GLOBAL_BIN/claude-agi"
    else
        cp "$SOURCE_FILE" "$GLOBAL_BIN/claude-agi"
        chmod +x "$GLOBAL_BIN/claude-agi"
    fi

    echo -e "${GREEN}✓ claude-agi installed globally!${NC}"
    echo ""
    echo "Usage:"
    echo "  claude-agi                Start autonomous execution"
    echo "  claude-agi --overnight    Start overnight mode"
    echo "  claude-agi --status       Check execution status"
}

# Uninstall
uninstall() {
    echo -e "${BLUE}Uninstalling claude-agi...${NC}"

    local removed=0

    # Check local bin
    if [[ -f "$LOCAL_BIN/claude-agi" ]]; then
        rm "$LOCAL_BIN/claude-agi"
        echo "  Removed from $LOCAL_BIN"
        ((removed++))
    fi

    # Check global bin
    if [[ -f "$GLOBAL_BIN/claude-agi" ]]; then
        if [[ $EUID -ne 0 ]]; then
            sudo rm "$GLOBAL_BIN/claude-agi"
        else
            rm "$GLOBAL_BIN/claude-agi"
        fi
        echo "  Removed from $GLOBAL_BIN"
        ((removed++))
    fi

    if [[ $removed -eq 0 ]]; then
        echo -e "${YELLOW}claude-agi was not found in PATH${NC}"
    else
        echo -e "${GREEN}✓ claude-agi uninstalled${NC}"
    fi
}

# Check source file exists
check_source() {
    if [[ ! -f "$SOURCE_FILE" ]]; then
        echo -e "${RED}ERROR: claude-agi not found at $SOURCE_FILE${NC}" >&2
        echo "Make sure you're running this from the plugin directory" >&2
        exit 1
    fi
}

# Main
main() {
    case "${1:-}" in
        --global|-g)
            check_source
            install_global
            ;;
        --uninstall|-u)
            uninstall
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --version|-v)
            echo "install-claude-agi v${VERSION}"
            exit 0
            ;;
        "")
            check_source
            install_local
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
