#!/bin/bash
# Cross-platform notification script for autonomous-dev
set -euo pipefail

TITLE="${1:-Autonomous Dev}"
MESSAGE="${2:-Task completed}"

# macOS notification
if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true
fi

# macOS sound
if command -v afplay &>/dev/null; then
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
fi

# Linux notification (notify-send)
if command -v notify-send &>/dev/null; then
    notify-send "$TITLE" "$MESSAGE" 2>/dev/null || true
fi

# Linux sound (paplay)
if command -v paplay &>/dev/null; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
fi

# Windows (WSL) notification
if command -v powershell.exe &>/dev/null; then
    powershell.exe -Command "[System.Media.SystemSounds]::Asterisk.Play()" 2>/dev/null || true
fi

# Also print to stdout for logging
echo "[$TITLE] $MESSAGE"
