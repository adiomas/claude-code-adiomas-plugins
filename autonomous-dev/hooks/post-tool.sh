#!/bin/bash
# Auto-run typecheck/lint after edits (optional, can be disabled)
set -euo pipefail

STATE_FILE=".claude/auto-progress.yaml"
PROFILE_FILE=".claude/project-profile.yaml"

# Only run in autonomous mode
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Check if yq is available
if ! command -v yq &>/dev/null; then
    exit 0
fi

AUTO_VERIFY=$(yq -r '.auto_verify // false' "$STATE_FILE" 2>/dev/null)
if [[ "$AUTO_VERIFY" != "true" ]]; then
    exit 0
fi

# Get typecheck command from profile
if [[ -f "$PROFILE_FILE" ]]; then
    TYPECHECK_CMD=$(yq -r '.commands.typecheck // ""' "$PROFILE_FILE")
    if [[ -n "$TYPECHECK_CMD" && "$TYPECHECK_CMD" != "null" ]]; then
        # Run typecheck silently, just to catch errors early
        $TYPECHECK_CMD 2>/dev/null || true
    fi
fi
