#!/bin/bash
# =============================================================================
# STATE TRANSITION ENGINE v3.0
# =============================================================================
# Manages state machine transitions for autonomous-dev plugin.
# Provides automated skill invocation and checkpoint management.
# =============================================================================

set -euo pipefail

STATE_MACHINE_FILE=".claude/auto-state-machine.yaml"
MEMORY_DIR=".claude/auto-memory"

# =============================================================================
# STATE DEFINITIONS
# =============================================================================

VALID_STATES=("IDLE" "DETECT" "CLASSIFY" "PLAN" "EXECUTE" "INTEGRATE" "REVIEW" "COMPLETE" "RESEARCH")
VALID_WORK_TYPES=("FRONTEND" "BACKEND" "FULLSTACK" "DOCUMENTATION" "DOCUMENTS" "INTEGRATION" "TESTING" "CREATIVE" "RESEARCH")

# =============================================================================
# SKILL MAPPINGS BY STATE AND WORK TYPE
# =============================================================================

get_mandatory_skills() {
    local state="$1"
    local work_type="$2"

    case "$state" in
        "DETECT")
            echo "project-detector,work-type-classifier"
            ;;
        "CLASSIFY")
            echo ""
            ;;
        "PLAN")
            case "$work_type" in
                "FRONTEND")
                    echo "superpowers:brainstorming,superpowers:writing-plans,frontend-design"
                    ;;
                "BACKEND")
                    echo "superpowers:brainstorming,superpowers:writing-plans,architecture-patterns"
                    ;;
                "FULLSTACK")
                    echo "superpowers:brainstorming,superpowers:writing-plans,frontend-design,architecture-patterns"
                    ;;
                "RESEARCH")
                    echo "superpowers:brainstorming"
                    ;;
                *)
                    echo "superpowers:brainstorming,superpowers:writing-plans"
                    ;;
            esac
            ;;
        "EXECUTE")
            case "$work_type" in
                "FRONTEND")
                    echo "superpowers:test-driven-development,frontend-design"
                    ;;
                "RESEARCH")
                    echo ""
                    ;;
                *)
                    echo "superpowers:test-driven-development"
                    ;;
            esac
            ;;
        "REVIEW")
            case "$work_type" in
                "FRONTEND")
                    echo "superpowers:verification-before-completion,superpowers:requesting-code-review,webapp-testing"
                    ;;
                "RESEARCH")
                    echo ""
                    ;;
                *)
                    echo "superpowers:verification-before-completion,superpowers:requesting-code-review"
                    ;;
            esac
            ;;
        "RESEARCH")
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# =============================================================================
# STATE MACHINE FUNCTIONS
# =============================================================================

init_state_machine() {
    local initial_state="${1:-IDLE}"

    mkdir -p "$(dirname "$STATE_MACHINE_FILE")"
    mkdir -p "$MEMORY_DIR"

    cat > "$STATE_MACHINE_FILE" << EOF
# Autonomous-Dev State Machine v3.0
# Auto-generated - tracks execution state for resume capability

version: "3.0"
current_state: "$initial_state"
previous_state: ""
work_type: ""
focus: []
mandatory_skills: []
completed_phases: []
checkpoint_files: []
session_id: "auto-$(date +%Y%m%d-%H%M%S)"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
token_usage:
  estimated: 0
  budget: 200000
  warning_threshold: 0.80
  checkpoint_threshold: 0.95
EOF

    echo "State machine initialized at $STATE_MACHINE_FILE"
}

get_current_state() {
    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo "IDLE"
        return
    fi
    yq -r '.current_state // "IDLE"' "$STATE_MACHINE_FILE"
}

get_work_type() {
    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo ""
        return
    fi
    yq -r '.work_type // ""' "$STATE_MACHINE_FILE"
}

set_work_type() {
    local work_type="$1"
    local focus="${2:-}"
    local confidence="${3:-1.0}"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        init_state_machine
    fi

    yq -i ".work_type = \"$work_type\"" "$STATE_MACHINE_FILE"
    yq -i ".classification_confidence = $confidence" "$STATE_MACHINE_FILE"

    if [[ -n "$focus" ]]; then
        # Parse comma-separated focus items into array
        IFS=',' read -ra FOCUS_ITEMS <<< "$focus"
        yq -i '.focus = []' "$STATE_MACHINE_FILE"
        for item in "${FOCUS_ITEMS[@]}"; do
            yq -i ".focus += [\"$item\"]" "$STATE_MACHINE_FILE"
        done
    fi

    # Update mandatory skills based on current state and new work type
    local current_state
    current_state=$(get_current_state)
    local skills
    skills=$(get_mandatory_skills "$current_state" "$work_type")

    yq -i '.mandatory_skills = []' "$STATE_MACHINE_FILE"
    if [[ -n "$skills" ]]; then
        IFS=',' read -ra SKILL_ITEMS <<< "$skills"
        for skill in "${SKILL_ITEMS[@]}"; do
            yq -i ".mandatory_skills += [\"$skill\"]" "$STATE_MACHINE_FILE"
        done
    fi

    echo "Work type set to: $work_type (confidence: $confidence)"
}

transition_to() {
    local new_state="$1"

    # Validate state
    local valid=false
    for state in "${VALID_STATES[@]}"; do
        if [[ "$state" == "$new_state" ]]; then
            valid=true
            break
        fi
    done

    if [[ "$valid" != "true" ]]; then
        echo "ERROR: Invalid state '$new_state'. Valid states: ${VALID_STATES[*]}" >&2
        return 1
    fi

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        init_state_machine "$new_state"
        return 0
    fi

    local current_state
    current_state=$(get_current_state)
    local work_type
    work_type=$(get_work_type)

    # Update state
    yq -i ".previous_state = \"$current_state\"" "$STATE_MACHINE_FILE"
    yq -i ".current_state = \"$new_state\"" "$STATE_MACHINE_FILE"
    yq -i ".last_transition = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$STATE_MACHINE_FILE"

    # Mark previous state as completed
    yq -i ".completed_phases += [\"$current_state\"]" "$STATE_MACHINE_FILE"

    # Update mandatory skills for new state
    local skills
    skills=$(get_mandatory_skills "$new_state" "$work_type")

    yq -i '.mandatory_skills = []' "$STATE_MACHINE_FILE"
    if [[ -n "$skills" ]]; then
        IFS=',' read -ra SKILL_ITEMS <<< "$skills"
        for skill in "${SKILL_ITEMS[@]}"; do
            yq -i ".mandatory_skills += [\"$skill\"]" "$STATE_MACHINE_FILE"
        done
    fi

    echo "Transitioned: $current_state -> $new_state"

    # Output mandatory skills for Claude to invoke
    if [[ -n "$skills" ]]; then
        echo "MANDATORY_SKILLS: $skills"
    fi
}

add_checkpoint() {
    local checkpoint_file="$1"
    local description="${2:-}"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo "ERROR: State machine not initialized" >&2
        return 1
    fi

    yq -i ".checkpoint_files += [\"$checkpoint_file\"]" "$STATE_MACHINE_FILE"

    # Also write to memory summary
    local current_state
    current_state=$(get_current_state)
    local memory_file="$MEMORY_DIR/${current_state,,}-checkpoint.md"

    echo "## Checkpoint: $checkpoint_file" >> "$memory_file"
    echo "- Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$memory_file"
    [[ -n "$description" ]] && echo "- Description: $description" >> "$memory_file"
    echo "" >> "$memory_file"

    echo "Checkpoint added: $checkpoint_file"
}

update_token_usage() {
    local tokens="$1"

    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        return 0
    fi

    local current
    current=$(yq -r '.token_usage.estimated // 0' "$STATE_MACHINE_FILE")
    local new_total=$((current + tokens))
    local budget
    budget=$(yq -r '.token_usage.budget // 200000' "$STATE_MACHINE_FILE")
    local warning_threshold
    warning_threshold=$(yq -r '.token_usage.warning_threshold // 0.80' "$STATE_MACHINE_FILE")
    local checkpoint_threshold
    checkpoint_threshold=$(yq -r '.token_usage.checkpoint_threshold // 0.95' "$STATE_MACHINE_FILE")

    yq -i ".token_usage.estimated = $new_total" "$STATE_MACHINE_FILE"

    # Calculate usage percentage
    local usage_pct
    usage_pct=$(echo "scale=2; $new_total / $budget" | bc)

    # Check thresholds
    if (( $(echo "$usage_pct >= $checkpoint_threshold" | bc -l) )); then
        echo "TOKEN_CHECKPOINT: Usage at ${usage_pct}% - checkpoint required"
        return 2
    elif (( $(echo "$usage_pct >= $warning_threshold" | bc -l) )); then
        echo "TOKEN_WARNING: Usage at ${usage_pct}% - start summarization"
        return 1
    fi

    return 0
}

get_resume_info() {
    if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
        echo "NO_SESSION"
        return 1
    fi

    local state
    state=$(get_current_state)
    local work_type
    work_type=$(get_work_type)
    local session_id
    session_id=$(yq -r '.session_id // ""' "$STATE_MACHINE_FILE")
    local completed
    completed=$(yq -r '.completed_phases | join(",")' "$STATE_MACHINE_FILE")

    echo "SESSION_ID: $session_id"
    echo "CURRENT_STATE: $state"
    echo "WORK_TYPE: $work_type"
    echo "COMPLETED_PHASES: $completed"

    # List available memory files
    if [[ -d "$MEMORY_DIR" ]]; then
        echo "MEMORY_FILES:"
        ls -1 "$MEMORY_DIR" 2>/dev/null | while read -r f; do
            echo "  - $MEMORY_DIR/$f"
        done
    fi
}

# =============================================================================
# MAIN COMMAND HANDLER
# =============================================================================

case "${1:-help}" in
    "init")
        init_state_machine "${2:-IDLE}"
        ;;
    "state")
        get_current_state
        ;;
    "work-type")
        if [[ -n "${2:-}" ]]; then
            set_work_type "$2" "${3:-}" "${4:-1.0}"
        else
            get_work_type
        fi
        ;;
    "transition")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 transition <new_state>" >&2
            exit 1
        fi
        transition_to "$2"
        ;;
    "checkpoint")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 checkpoint <file_path> [description]" >&2
            exit 1
        fi
        add_checkpoint "$2" "${3:-}"
        ;;
    "tokens")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 tokens <amount>" >&2
            exit 1
        fi
        update_token_usage "$2"
        ;;
    "resume")
        get_resume_info
        ;;
    "skills")
        state="${2:-$(get_current_state)}"
        work_type="${3:-$(get_work_type)}"
        get_mandatory_skills "$state" "$work_type"
        ;;
    "help"|*)
        cat << 'EOF'
State Transition Engine v3.0

Usage:
  state-transition.sh init [initial_state]     Initialize state machine
  state-transition.sh state                    Get current state
  state-transition.sh work-type [type] [focus] Set/get work type
  state-transition.sh transition <new_state>   Transition to new state
  state-transition.sh checkpoint <file> [desc] Add checkpoint file
  state-transition.sh tokens <amount>          Update token usage
  state-transition.sh resume                   Get resume information
  state-transition.sh skills [state] [type]    Get mandatory skills

Valid States:
  IDLE, DETECT, CLASSIFY, PLAN, EXECUTE, INTEGRATE, REVIEW, COMPLETE, RESEARCH

Valid Work Types:
  FRONTEND, BACKEND, FULLSTACK, DOCUMENTATION, DOCUMENTS, INTEGRATION, TESTING, CREATIVE, RESEARCH
EOF
        ;;
esac
