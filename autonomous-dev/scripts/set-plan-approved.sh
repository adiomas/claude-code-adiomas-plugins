#!/usr/bin/env bash
# set-plan-approved.sh - Set plan approval state
# Part of autonomous-dev v4.2
#
# Usage:
#   ./set-plan-approved.sh true    # Mark plan as approved
#   ./set-plan-approved.sh false   # Mark plan as not approved
#   ./set-plan-approved.sh check   # Check current approval status

set -euo pipefail

STATE_FILE=".claude/state.json"
DO_ACTIVE_FILE=".claude/.do-active"

# Ensure state directory exists
mkdir -p .claude

action="${1:-check}"

case "$action" in
    true|approve|yes)
        # Set plan_approved to true
        if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
            # Use jq to update
            tmp=$(mktemp)
            jq '.plan_approved = true | .approved_at = now | .approval_status = "approved"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        else
            # Create minimal state if doesn't exist
            echo '{"plan_approved":true,"approved_at":"'"$(date -Iseconds)"'","approval_status":"approved"}' > "$STATE_FILE"
        fi
        echo "✅ Plan marked as APPROVED"
        ;;

    false|reject|no)
        # Set plan_approved to false
        if [[ -f "$STATE_FILE" ]] && command -v jq &>/dev/null; then
            tmp=$(mktemp)
            jq '.plan_approved = false | .approval_status = "rejected"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        else
            echo '{"plan_approved":false,"approval_status":"rejected"}' > "$STATE_FILE"
        fi
        echo "❌ Plan marked as NOT APPROVED"
        ;;

    check|status)
        # Check current status
        if [[ ! -f "$STATE_FILE" ]]; then
            echo "No state file found"
            exit 0
        fi

        if command -v jq &>/dev/null; then
            approved=$(jq -r '.plan_approved // "not set"' "$STATE_FILE")
            strategy=$(jq -r '.execution.strategy // "unknown"' "$STATE_FILE")
            complexity=$(jq -r '.task.complexity // "unknown"' "$STATE_FILE")
        else
            approved="unknown (jq not installed)"
            strategy="unknown"
            complexity="unknown"
        fi

        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  Plan Approval Status                                          ║"
        echo "╠═══════════════════════════════════════════════════════════════╣"
        echo "║  Approved:    $approved"
        echo "║  Strategy:    $strategy"
        echo "║  Complexity:  $complexity"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        ;;

    start-do)
        # Mark /do session as active
        touch "$DO_ACTIVE_FILE"
        echo "DO_SESSION_STARTED"
        ;;

    end-do)
        # Mark /do session as ended
        rm -f "$DO_ACTIVE_FILE"
        echo "DO_SESSION_ENDED"
        ;;

    *)
        echo "Usage: $0 {true|false|check|start-do|end-do}"
        exit 1
        ;;
esac
