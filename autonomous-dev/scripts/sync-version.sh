#!/usr/bin/env bash
# sync-version.sh - Syncs version from plugin.json to auto-version.md
# Run manually or via pre-commit hook

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
AUTO_VERSION_MD="$PLUGIN_DIR/commands/auto-version.md"
CHANGELOG_MD="$PLUGIN_DIR/references/CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from plugin.json
get_plugin_version() {
    if [[ ! -f "$PLUGIN_JSON" ]]; then
        echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
        exit 1
    fi
    # Use grep and sed for portability (no jq dependency)
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Get version from auto-version.md
get_displayed_version() {
    if [[ ! -f "$AUTO_VERSION_MD" ]]; then
        echo "0.0.0"
        return
    fi
    grep '^\*\*Version:' "$AUTO_VERSION_MD" | sed 's/.*Version:[[:space:]]*\([0-9.]*\).*/\1/' || echo "0.0.0"
}

# Check if version is documented in CHANGELOG
is_version_in_changelog() {
    local version="$1"
    grep -q "^\## \[$version\]" "$CHANGELOG_MD" 2>/dev/null
}

# Update auto-version.md with new version
update_auto_version() {
    local new_version="$1"
    local old_version
    old_version=$(get_displayed_version)

    if [[ "$old_version" == "$new_version" ]]; then
        echo -e "${GREEN}✓${NC} auto-version.md already at version $new_version"
        return 0
    fi

    # Update the version line
    sed -i.bak "s/\*\*Version: $old_version\*\*/\*\*Version: $new_version\*\*/" "$AUTO_VERSION_MD"

    # Update "What's New in X.X.X" heading
    sed -i.bak "s/What's New in $old_version/What's New in $new_version/" "$AUTO_VERSION_MD"

    # Clean up backup
    rm -f "$AUTO_VERSION_MD.bak"

    echo -e "${GREEN}✓${NC} Updated auto-version.md: $old_version → $new_version"
}

# Main sync function
sync_version() {
    local plugin_version
    plugin_version=$(get_plugin_version)

    echo "Plugin version: $plugin_version"
    echo ""

    # Sync auto-version.md
    update_auto_version "$plugin_version"

    # Warn if version not in CHANGELOG
    if ! is_version_in_changelog "$plugin_version"; then
        echo -e "${YELLOW}⚠${NC}  Version $plugin_version not documented in CHANGELOG.md"
        echo "   Consider adding release notes for this version."
    else
        echo -e "${GREEN}✓${NC} Version $plugin_version documented in CHANGELOG.md"
    fi
}

# Run
echo "=== Autonomous-Dev Version Sync ==="
echo ""
sync_version
echo ""
echo "Done!"
