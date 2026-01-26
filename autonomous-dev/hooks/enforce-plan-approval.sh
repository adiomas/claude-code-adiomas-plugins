#!/usr/bin/env bash
# enforce-plan-approval.sh - Block Edit/Write if plan not approved
# Part of autonomous-dev v4.2
#
# This is a PreToolUse hook that ensures ORCHESTRATED tasks
# cannot proceed without explicit user approval.
#
# Exit codes:
#   0 = Allow tool execution
#   2 = Block tool execution (with message)

set -euo pipefail

# Get tool info from environment (set by Claude Code)
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# State file location
STATE_FILE=".claude/state.json"
DO_ACTIVE_FILE=".claude/.do-active"

# ========================================
# HELPER FUNCTIONS
# ========================================

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Check if we're in an active /do session
is_do_session_active() {
    # Check for .do-active marker file
    if [[ -f "$DO_ACTIVE_FILE" ]]; then
        return 0
    fi

    # Check state.json for active execution
    if [[ -f "$STATE_FILE" ]]; then
        local status
        if command -v jq &>/dev/null; then
            status=$(jq -r '.execution.status // "none"' "$STATE_FILE" 2>/dev/null || echo "none")
        else
            status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "none")
        fi

        if [[ "$status" == "running" || "$status" == "pending" ]]; then
            return 0
        fi
    fi

    return 1
}

# Check if strategy is ORCHESTRATED
is_orchestrated_mode() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    local strategy
    if command -v jq &>/dev/null; then
        strategy=$(jq -r '.execution.strategy // "DIRECT"' "$STATE_FILE" 2>/dev/null || echo "DIRECT")
    else
        strategy=$(grep -o '"strategy"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "DIRECT")
    fi

    [[ "$strategy" == "ORCHESTRATED" ]]
}

# Check if plan is approved
is_plan_approved() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    local approved
    if command -v jq &>/dev/null; then
        approved=$(jq -r '.plan_approved // false' "$STATE_FILE" 2>/dev/null || echo "false")
    else
        if grep -q '"plan_approved"[[:space:]]*:[[:space:]]*true' "$STATE_FILE" 2>/dev/null; then
            approved="true"
        else
            approved="false"
        fi
    fi

    [[ "$approved" == "true" ]]
}

# Get complexity from state
get_complexity() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "0"
        return
    fi

    if command -v jq &>/dev/null; then
        jq -r '.task.complexity // 0' "$STATE_FILE" 2>/dev/null || echo "0"
    else
        grep -o '"complexity"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/.*[[:space:]]//' || echo "0"
    fi
}

# ========================================
# MAIN LOGIC
# ========================================

main() {
    log_debug "Tool: $TOOL_NAME"

    # Only check Edit and Write tools
    if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
        log_debug "Not Edit/Write, allowing"
        exit 0
    fi

    # If not in a /do session, allow (might be manual editing)
    if ! is_do_session_active; then
        log_debug "No active /do session, allowing"
        exit 0
    fi

    # If DIRECT mode, allow (no approval needed for simple tasks)
    if ! is_orchestrated_mode; then
        log_debug "DIRECT mode, allowing"
        exit 0
    fi

    # Get complexity
    local complexity
    complexity=$(get_complexity)

    # If complexity < 3, allow (simple task threshold)
    if [[ "$complexity" -lt 3 ]]; then
        log_debug "Complexity $complexity < 3, allowing"
        exit 0
    fi

    # ORCHESTRATED mode with complexity >= 3: check approval
    if ! is_plan_approved; then
        # BLOCK! Plan not approved
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  ⛔ BLOCKED: Plan Not Approved                                 ║"
        echo "╠═══════════════════════════════════════════════════════════════╣"
        echo "║                                                                 ║"
        echo "║  This is an ORCHESTRATED task (complexity $complexity/5).              ║"
        echo "║  User approval is REQUIRED before implementation.              ║"
        echo "║                                                                 ║"
        echo "║  Action needed:                                                ║"
        echo "║  1. Write plan to .claude/plans/                               ║"
        echo "║  2. Use AskUserQuestion to get approval                        ║"
        echo "║  3. Set plan_approved: true in state                           ║"
        echo "║                                                                 ║"
        echo "║  DO NOT proceed without explicit user confirmation.            ║"
        echo "║                                                                 ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""

        # Exit code 2 = block with message
        exit 2
    fi

    log_debug "Plan approved, allowing"
    exit 0
}

main "$@"
