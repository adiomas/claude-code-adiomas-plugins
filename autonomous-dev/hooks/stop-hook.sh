#!/bin/bash
# =============================================================================
# STOP HOOK v3.0
# =============================================================================
# Enhanced stop hook with graceful degradation and state machine integration.
# Handles completion promises, iteration limits, and token budget exhaustion.
# =============================================================================

set -euo pipefail

STATE_FILE=".claude/auto-progress.yaml"
STATE_MACHINE_FILE=".claude/auto-state-machine.yaml"
MEMORY_DIR=".claude/auto-memory"
TRANSCRIPT="${1:-}"

# =============================================================================
# EARLY EXIT CONDITIONS
# =============================================================================

# Exit early if no autonomous session active
if [[ ! -f "$STATE_FILE" ]] && [[ ! -f "$STATE_MACHINE_FILE" ]]; then
    exit 0
fi

# Check if yq is available
if ! command -v yq &>/dev/null; then
    echo "Warning: yq not installed, stop hook disabled" >&2
    exit 0
fi

# =============================================================================
# STATE DETECTION
# =============================================================================

# Get status from progress file
ACTIVE=""
if [[ -f "$STATE_FILE" ]]; then
    ACTIVE=$(yq -r '.status' "$STATE_FILE" 2>/dev/null || echo "")
fi

# Get state from state machine
CURRENT_STATE="IDLE"
if [[ -f "$STATE_MACHINE_FILE" ]]; then
    CURRENT_STATE=$(yq -r '.current_state // "IDLE"' "$STATE_MACHINE_FILE" 2>/dev/null || echo "IDLE")
fi

# If not in progress, allow exit
if [[ "$ACTIVE" != "in_progress" ]] && [[ "$CURRENT_STATE" == "IDLE" || "$CURRENT_STATE" == "COMPLETE" ]]; then
    exit 0
fi

# =============================================================================
# COMPLETION PROMISE CHECK
# =============================================================================

if [[ -n "$TRANSCRIPT" ]]; then
    # Check for standard completion
    if grep -q '<promise>AUTO_COMPLETE</promise>' "$TRANSCRIPT" 2>/dev/null; then
        # Mark as complete
        [[ -f "$STATE_FILE" ]] && yq -i '.status = "done"' "$STATE_FILE"
        [[ -f "$STATE_FILE" ]] && yq -i ".completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_FILE"

        # Update state machine
        if [[ -f "$STATE_MACHINE_FILE" ]]; then
            yq -i '.current_state = "COMPLETE"' "$STATE_MACHINE_FILE"
            yq -i ".completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_MACHINE_FILE"
        fi

        # Send notification
        SCRIPT_DIR="$(dirname "$0")/.."
        if [[ -x "$SCRIPT_DIR/scripts/notify.sh" ]]; then
            "$SCRIPT_DIR/scripts/notify.sh" "Autonomous Dev Complete" "All tasks finished successfully!"
        fi

        # Cleanup memory files
        if [[ -x "$SCRIPT_DIR/scripts/checkpoint-manager.sh" ]]; then
            "$SCRIPT_DIR/scripts/checkpoint-manager.sh" cleanup
        fi

        exit 0
    fi

    # Check for audit completion
    if grep -q '<promise>AUDIT_COMPLETE</promise>' "$TRANSCRIPT" 2>/dev/null; then
        [[ -f "$STATE_FILE" ]] && yq -i '.status = "done"' "$STATE_FILE"
        if [[ -f "$STATE_MACHINE_FILE" ]]; then
            yq -i '.current_state = "COMPLETE"' "$STATE_MACHINE_FILE"
        fi
        exit 0
    fi

    # Check for task completion (for parallel tasks)
    if grep -qE '<promise>TASK_DONE: [a-zA-Z0-9_-]+</promise>' "$TRANSCRIPT" 2>/dev/null; then
        # Extract task ID and mark as done
        TASK_ID=$(grep -oE '<promise>TASK_DONE: [a-zA-Z0-9_-]+</promise>' "$TRANSCRIPT" | sed 's/<promise>TASK_DONE: //; s/<\/promise>//')
        if [[ -n "$TASK_ID" && -f "$STATE_FILE" ]]; then
            yq -i ".tasks[\"$TASK_ID\"].status = \"done\"" "$STATE_FILE" 2>/dev/null || true
            yq -i ".tasks[\"$TASK_ID\"].completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_FILE" 2>/dev/null || true
        fi
        # Don't exit - there may be more tasks
    fi
fi

# =============================================================================
# ITERATION LIMIT CHECK
# =============================================================================

ITERATION=$(yq -r '.iteration // 0' "$STATE_FILE" 2>/dev/null || echo "0")
MAX_ITERATIONS=$(yq -r '.max_iterations // 50' "$STATE_FILE" 2>/dev/null || echo "50")

# Ensure numeric values
[[ "$ITERATION" =~ ^[0-9]+$ ]] || ITERATION=0
[[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || MAX_ITERATIONS=50

if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
    # ==========================================================================
    # GRACEFUL DEGRADATION: Max iterations reached
    # ==========================================================================

    echo "Max iterations ($MAX_ITERATIONS) reached. Initiating graceful handoff..."

    # Create checkpoint before exiting
    SCRIPT_DIR="$(dirname "$0")/.."
    if [[ -x "$SCRIPT_DIR/scripts/checkpoint-manager.sh" ]]; then
        "$SCRIPT_DIR/scripts/checkpoint-manager.sh" handoff
    fi

    # Update status
    [[ -f "$STATE_FILE" ]] && yq -i '.status = "max_iterations_reached"' "$STATE_FILE"
    if [[ -f "$STATE_MACHINE_FILE" ]]; then
        yq -i '.graceful_exit = "max_iterations"' "$STATE_MACHINE_FILE"
        yq -i ".exit_time = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_MACHINE_FILE"
    fi

    cat << 'EOF'
{
  "decision": "allow",
  "reason": "Max iterations reached - graceful handoff",
  "message": "Session limit reached. State saved to .claude/auto-memory/. Run /auto-continue in a new session to resume."
}
EOF
    exit 0
fi

# =============================================================================
# TOKEN BUDGET CHECK
# =============================================================================

if [[ -f "$STATE_MACHINE_FILE" ]]; then
    TOKEN_ESTIMATED=$(yq -r '.token_usage.estimated // 0' "$STATE_MACHINE_FILE" 2>/dev/null || echo "0")
    TOKEN_BUDGET=$(yq -r '.token_usage.budget // 200000' "$STATE_MACHINE_FILE" 2>/dev/null || echo "200000")
    CHECKPOINT_THRESHOLD=$(yq -r '.token_usage.checkpoint_threshold // 0.95' "$STATE_MACHINE_FILE" 2>/dev/null || echo "0.95")

    if [[ "$TOKEN_ESTIMATED" -gt 0 && "$TOKEN_BUDGET" -gt 0 ]]; then
        USAGE_PCT=$(awk "BEGIN {printf \"%.4f\", $TOKEN_ESTIMATED / $TOKEN_BUDGET}")

        if awk "BEGIN {exit !($USAGE_PCT >= $CHECKPOINT_THRESHOLD)}"; then
            # ==========================================================================
            # GRACEFUL DEGRADATION: Token budget exhausted
            # ==========================================================================
            USAGE_DISPLAY=$(awk "BEGIN {printf \"%.0f\", $USAGE_PCT * 100}")
            echo "Token budget at ${USAGE_DISPLAY}%. Initiating graceful handoff..."

            SCRIPT_DIR="$(dirname "$0")/.."
            if [[ -x "$SCRIPT_DIR/scripts/checkpoint-manager.sh" ]]; then
                "$SCRIPT_DIR/scripts/checkpoint-manager.sh" handoff
            fi

            [[ -f "$STATE_FILE" ]] && yq -i '.status = "token_limit_reached"' "$STATE_FILE"
            if [[ -f "$STATE_MACHINE_FILE" ]]; then
                yq -i '.graceful_exit = "token_budget"' "$STATE_MACHINE_FILE"
            fi

            cat << 'EOF'
{
  "decision": "allow",
  "reason": "Token budget exhausted - graceful handoff",
  "message": "Context limit approaching. State saved. Run /auto-continue in a new session to resume without losing progress."
}
EOF
            exit 0
        fi
    fi
fi

# =============================================================================
# CONTINUE EXECUTION
# =============================================================================

# Increment iteration
yq -i ".iteration = $((ITERATION + 1))" "$STATE_FILE"

# Get current task info
PLAN_FILE=$(yq -r '.plan_file // ""' "$STATE_FILE" 2>/dev/null || echo "")
CURRENT_TASK=$(yq -r '.current_task // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")

# Get mandatory skills from state machine
MANDATORY_SKILLS=""
if [[ -f "$STATE_MACHINE_FILE" ]]; then
    MANDATORY_SKILLS=$(yq -r '.mandatory_skills | join(", ")' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")
fi

# Build continuation message
MESSAGE="Continue with the autonomous execution plan."
MESSAGE="$MESSAGE Current iteration: $((ITERATION + 1))."
MESSAGE="$MESSAGE Current task: $CURRENT_TASK."
[[ -n "$PLAN_FILE" ]] && MESSAGE="$MESSAGE Refer to plan at: $PLAN_FILE."
[[ -n "$MANDATORY_SKILLS" ]] && MESSAGE="$MESSAGE Mandatory skills: $MANDATORY_SKILLS."

# Block exit and continue
cat << EOF
{
  "decision": "block",
  "reason": "Autonomous execution in progress",
  "message": "$MESSAGE"
}
EOF
