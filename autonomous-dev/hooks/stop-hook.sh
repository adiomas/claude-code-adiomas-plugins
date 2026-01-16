#!/bin/bash
set -euo pipefail

STATE_FILE=".claude/auto-progress.yaml"
TRANSCRIPT="${1:-}"

# Exit early if no autonomous session active
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Check if yq is available
if ! command -v yq &>/dev/null; then
    echo "Warning: yq not installed, stop hook disabled" >&2
    exit 0
fi

# Check if active
ACTIVE=$(yq -r '.status' "$STATE_FILE" 2>/dev/null || echo "")
if [[ "$ACTIVE" != "in_progress" ]]; then
    exit 0
fi

# Check for completion promise
if [[ -n "$TRANSCRIPT" ]] && grep -q '<promise>AUTO_COMPLETE</promise>' "$TRANSCRIPT" 2>/dev/null; then
    yq -i '.status = "done"' "$STATE_FILE"
    yq -i ".completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_FILE"

    # Send notification
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]] && [[ -x "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh" ]]; then
        "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh" "Autonomous Dev Complete" "All tasks finished successfully!"
    fi
    exit 0
fi

# Check iteration limit
ITERATION=$(yq -r '.iteration // 0' "$STATE_FILE")
MAX_ITERATIONS=$(yq -r '.max_iterations // 50' "$STATE_FILE")

# Ensure numeric values
[[ "$ITERATION" =~ ^[0-9]+$ ]] || ITERATION=0
[[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || MAX_ITERATIONS=50

if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
    yq -i '.status = "max_iterations_reached"' "$STATE_FILE"
    echo '{"decision": "allow", "reason": "Max iterations reached"}'
    exit 0
fi

# Increment iteration
yq -i ".iteration = $((ITERATION + 1))" "$STATE_FILE"

# Get current task info
PLAN_FILE=$(yq -r '.plan_file // ""' "$STATE_FILE")
CURRENT_TASK=$(yq -r '.current_task // "unknown"' "$STATE_FILE")

# Block exit and continue
cat << EOF
{
  "decision": "block",
  "reason": "Autonomous execution in progress",
  "message": "Continue with the autonomous execution plan. Current iteration: $((ITERATION + 1)). Current task: $CURRENT_TASK. Refer to plan at: $PLAN_FILE"
}
EOF
