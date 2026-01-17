#!/bin/bash
# =============================================================================
# TOKEN BUDGET CONTROLLER v3.0
# =============================================================================
# Monitors and manages token usage across phases.
# Triggers graceful degradation when limits approach.
# =============================================================================

set -euo pipefail

STATE_MACHINE_FILE=".claude/auto-state-machine.yaml"
MEMORY_DIR=".claude/auto-memory"

# =============================================================================
# TOKEN BUDGETS BY PHASE
# =============================================================================

get_phase_budget() {
    local phase="$1"
    case "$phase" in
        "DETECT")    echo 10000 ;;
        "CLASSIFY")  echo 5000 ;;
        "PLAN")      echo 30000 ;;
        "EXECUTE")   echo 100000 ;;
        "INTEGRATE") echo 20000 ;;
        "REVIEW")    echo 15000 ;;
        "RESEARCH")  echo 80000 ;;
        *)           echo 50000 ;;
    esac
}

# =============================================================================
# TOKEN ESTIMATION
# =============================================================================

# Rough estimates for common operations (tokens)
estimate_tool_tokens() {
    local tool="$1"
    local size="${2:-medium}"

    case "$tool:$size" in
        "Read:small")       echo 500 ;;
        "Read:medium")      echo 2000 ;;
        "Read:large")       echo 5000 ;;
        "Write:small")      echo 300 ;;
        "Write:medium")     echo 1000 ;;
        "Write:large")      echo 3000 ;;
        "Edit:small")       echo 200 ;;
        "Edit:medium")      echo 500 ;;
        "Edit:large")       echo 1500 ;;
        "Grep:*")           echo 1000 ;;
        "Glob:*")           echo 500 ;;
        "Bash:small")       echo 200 ;;
        "Bash:medium")      echo 500 ;;
        "Bash:large")       echo 2000 ;;
        "Task:*")           echo 5000 ;;
        "Skill:*")          echo 3000 ;;
        *)                  echo 500 ;;
    esac
}

estimate_response_tokens() {
    local response_type="$1"

    case "$response_type" in
        "planning")         echo 3000 ;;
        "implementation")   echo 2000 ;;
        "explanation")      echo 1500 ;;
        "error")            echo 500 ;;
        "simple")           echo 300 ;;
        *)                  echo 1000 ;;
    esac
}

# =============================================================================
# BUDGET TRACKING
# =============================================================================

init_budget() {
    local total_budget="${1:-200000}"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo "ERROR: State machine not initialized" >&2
        return 1
    fi

    yq -i ".token_usage.budget = $total_budget" "$STATE_MACHINE_FILE"
    yq -i ".token_usage.estimated = 0" "$STATE_MACHINE_FILE"
    yq -i ".token_usage.warning_threshold = 0.80" "$STATE_MACHINE_FILE"
    yq -i ".token_usage.checkpoint_threshold = 0.95" "$STATE_MACHINE_FILE"
    yq -i ".token_usage.phase_usage = {}" "$STATE_MACHINE_FILE"

    echo "Token budget initialized: $total_budget"
}

add_usage() {
    local tokens="$1"
    local phase="${2:-}"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        return 0
    fi

    # Get current values
    local current_total
    current_total=$(yq -r '.token_usage.estimated // 0' "$STATE_MACHINE_FILE")
    local budget
    budget=$(yq -r '.token_usage.budget // 200000' "$STATE_MACHINE_FILE")
    local warning_threshold
    warning_threshold=$(yq -r '.token_usage.warning_threshold // 0.80' "$STATE_MACHINE_FILE")
    local checkpoint_threshold
    checkpoint_threshold=$(yq -r '.token_usage.checkpoint_threshold // 0.95' "$STATE_MACHINE_FILE")

    # Update total
    local new_total=$((current_total + tokens))
    yq -i ".token_usage.estimated = $new_total" "$STATE_MACHINE_FILE"

    # Update phase usage if provided
    if [[ -n "$phase" ]]; then
        local phase_current
        phase_current=$(yq -r ".token_usage.phase_usage.$phase // 0" "$STATE_MACHINE_FILE")
        yq -i ".token_usage.phase_usage.$phase = $((phase_current + tokens))" "$STATE_MACHINE_FILE"
    fi

    # Calculate usage percentage
    local usage_pct
    usage_pct=$(echo "scale=4; $new_total / $budget" | bc 2>/dev/null || echo "0")

    # Check thresholds and return appropriate code
    if (( $(echo "$usage_pct >= $checkpoint_threshold" | bc -l 2>/dev/null || echo 0) )); then
        local pct_display
        pct_display=$(echo "scale=0; $usage_pct * 100 / 1" | bc 2>/dev/null || echo "95")
        echo "TOKEN_CHECKPOINT: Usage at ${pct_display}% ($new_total / $budget tokens)"
        echo "ACTION: Trigger handoff procedure"
        return 2
    elif (( $(echo "$usage_pct >= $warning_threshold" | bc -l 2>/dev/null || echo 0) )); then
        local pct_display
        pct_display=$(echo "scale=0; $usage_pct * 100 / 1" | bc 2>/dev/null || echo "80")
        echo "TOKEN_WARNING: Usage at ${pct_display}% ($new_total / $budget tokens)"
        echo "ACTION: Start context summarization"
        return 1
    fi

    return 0
}

get_status() {
    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo "NO_STATE_MACHINE"
        return 1
    fi

    local estimated budget warning_pct checkpoint_pct
    estimated=$(yq -r '.token_usage.estimated // 0' "$STATE_MACHINE_FILE")
    budget=$(yq -r '.token_usage.budget // 200000' "$STATE_MACHINE_FILE")
    warning_pct=$(yq -r '.token_usage.warning_threshold // 0.80' "$STATE_MACHINE_FILE")
    checkpoint_pct=$(yq -r '.token_usage.checkpoint_threshold // 0.95' "$STATE_MACHINE_FILE")

    local usage_pct
    usage_pct=$(echo "scale=2; $estimated * 100 / $budget" | bc 2>/dev/null || echo "0")
    local warning_tokens
    warning_tokens=$(echo "scale=0; $budget * $warning_pct / 1" | bc 2>/dev/null || echo "160000")
    local checkpoint_tokens
    checkpoint_tokens=$(echo "scale=0; $budget * $checkpoint_pct / 1" | bc 2>/dev/null || echo "190000")
    local remaining
    remaining=$((budget - estimated))

    cat << EOF
Token Budget Status
===================
Estimated Used:    $estimated tokens
Total Budget:      $budget tokens
Usage:             ${usage_pct}%
Remaining:         $remaining tokens

Thresholds:
  Warning at:      $warning_tokens tokens (${warning_pct}%)
  Checkpoint at:   $checkpoint_tokens tokens (${checkpoint_pct}%)

Phase Breakdown:
$(yq -r '.token_usage.phase_usage | to_entries | .[] | "  " + .key + ": " + (.value | tostring) + " tokens"' "$STATE_MACHINE_FILE" 2>/dev/null || echo "  No phase data")
EOF
}

check_phase_budget() {
    local phase="$1"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        return 0
    fi

    local phase_budget
    phase_budget=$(get_phase_budget "$phase")
    local phase_used
    phase_used=$(yq -r ".token_usage.phase_usage.$phase // 0" "$STATE_MACHINE_FILE")

    if [[ "$phase_used" -gt "$phase_budget" ]]; then
        echo "PHASE_BUDGET_EXCEEDED: $phase used $phase_used / $phase_budget tokens"
        return 1
    fi

    local remaining=$((phase_budget - phase_used))
    echo "Phase $phase: $phase_used / $phase_budget tokens (remaining: $remaining)"
    return 0
}

# =============================================================================
# GRACEFUL DEGRADATION
# =============================================================================

trigger_summarization() {
    echo "Initiating context summarization..."

    # Call checkpoint manager to create context summary
    local script_dir
    script_dir="$(dirname "$0")"
    if [[ -x "$script_dir/checkpoint-manager.sh" ]]; then
        "$script_dir/checkpoint-manager.sh" context
    fi

    echo "Context summarized. Consider removing verbose history from conversation."
}

trigger_handoff() {
    echo "Initiating session handoff..."

    # Call checkpoint manager to prepare handoff
    local script_dir
    script_dir="$(dirname "$0")"
    if [[ -x "$script_dir/checkpoint-manager.sh" ]]; then
        "$script_dir/checkpoint-manager.sh" handoff
    fi

    cat << 'EOF'

SESSION HANDOFF REQUIRED
========================
Token limit approaching. State has been saved.

To continue in a new session:
1. Start a new Claude Code session
2. Run: /auto-continue
3. The session will resume from the current phase

Do NOT continue in this session - risk of context degradation.
EOF
}

# =============================================================================
# MAIN COMMAND HANDLER
# =============================================================================

case "${1:-help}" in
    "init")
        init_budget "${2:-200000}"
        ;;
    "add")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 add <tokens> [phase]" >&2
            exit 1
        fi
        add_usage "$2" "${3:-}"
        ;;
    "estimate")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 estimate <tool> [size]" >&2
            exit 1
        fi
        estimate_tool_tokens "$2" "${3:-medium}"
        ;;
    "status")
        get_status
        ;;
    "check-phase")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 check-phase <phase>" >&2
            exit 1
        fi
        check_phase_budget "$2"
        ;;
    "summarize")
        trigger_summarization
        ;;
    "handoff")
        trigger_handoff
        ;;
    "help"|*)
        cat << 'EOF'
Token Budget Controller v3.0

Usage:
  token-monitor.sh init [budget]              Initialize with total budget
  token-monitor.sh add <tokens> [phase]       Add token usage
  token-monitor.sh estimate <tool> [size]     Estimate tokens for operation
  token-monitor.sh status                     Show current status
  token-monitor.sh check-phase <phase>        Check phase budget
  token-monitor.sh summarize                  Trigger context summarization
  token-monitor.sh handoff                    Trigger session handoff

Phase Budgets:
  DETECT:    10,000 tokens
  CLASSIFY:   5,000 tokens
  PLAN:      30,000 tokens
  EXECUTE:  100,000 tokens
  INTEGRATE: 20,000 tokens
  REVIEW:    15,000 tokens
  RESEARCH:  80,000 tokens

Thresholds:
  Warning:    80% - Start summarization
  Checkpoint: 95% - Prepare handoff
EOF
        ;;
esac
