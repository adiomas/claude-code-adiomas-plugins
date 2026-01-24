#!/usr/bin/env bash
# bump-version.sh - Bump version in plugin.json and sync everywhere
# Usage: ./bump-version.sh [major|minor|patch]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get current version
get_current_version() {
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Parse semver into components
parse_version() {
    local version="$1"
    echo "$version" | awk -F. '{print $1, $2, $3}'
}

# Bump version
bump_version() {
    local current="$1"
    local bump_type="${2:-patch}"

    read -r major minor patch <<< "$(parse_version "$current")"

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}Error: Invalid bump type '$bump_type'. Use major, minor, or patch.${NC}" >&2
            exit 1
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Update plugin.json
update_plugin_json() {
    local old_version="$1"
    local new_version="$2"

    sed -i.bak "s/\"version\": \"$old_version\"/\"version\": \"$new_version\"/" "$PLUGIN_JSON"
    rm -f "$PLUGIN_JSON.bak"
}

# Main
main() {
    local bump_type="${1:-patch}"

    echo -e "${CYAN}=== Autonomous-Dev Version Bump ===${NC}"
    echo ""

    local current_version
    current_version=$(get_current_version)
    echo "Current version: $current_version"

    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")
    echo "New version:     $new_version ($bump_type bump)"
    echo ""

    # Update plugin.json
    update_plugin_json "$current_version" "$new_version"
    echo -e "${GREEN}✓${NC} Updated plugin.json"

    # Run sync to update all other files
    echo ""
    "$SCRIPT_DIR/sync-version.sh"

    echo ""
    echo -e "${GREEN}Version bumped to $new_version!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Update CHANGELOG.md with release notes"
    echo "  2. Commit changes: git add -A && git commit -m 'Release v$new_version'"
}

# Show help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [major|minor|patch]"
    echo ""
    echo "Bump types:"
    echo "  major  - Breaking changes (1.0.0 → 2.0.0)"
    echo "  minor  - New features (1.0.0 → 1.1.0)"
    echo "  patch  - Bug fixes (1.0.0 → 1.0.1) [default]"
    exit 0
fi

main "${1:-patch}"
