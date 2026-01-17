#!/bin/bash
# =============================================================================
# PRE-PHASE HOOK v3.0
# =============================================================================
# Enforces mandatory skill invocation before each phase.
# This hook reads the state machine and outputs required skills that Claude
# MUST invoke before proceeding.
# =============================================================================

set -euo pipefail

STATE_MACHINE_FILE=".claude/auto-state-machine.yaml"
CONTEXT_FILE=".claude/auto-context.yaml"

# Exit early if no state machine (not in autonomous mode)
if [[ ! -f "$STATE_MACHINE_FILE" ]]; then
    exit 0
fi

# Check for yq
if ! command -v yq &>/dev/null; then
    exit 0
fi

# Get current state and work type
CURRENT_STATE=$(yq -r '.current_state // "IDLE"' "$STATE_MACHINE_FILE")
WORK_TYPE=$(yq -r '.work_type // ""' "$STATE_MACHINE_FILE")
MANDATORY_SKILLS=$(yq -r '.mandatory_skills | join(",")' "$STATE_MACHINE_FILE" 2>/dev/null || echo "")
CONFIDENCE=$(yq -r '.classification_confidence // 1.0' "$STATE_MACHINE_FILE")

# If in IDLE state, nothing to enforce
if [[ "$CURRENT_STATE" == "IDLE" || "$CURRENT_STATE" == "COMPLETE" ]]; then
    exit 0
fi

# Build enforcement message
OUTPUT=""

# Check if work type is set with low confidence
if [[ -n "$WORK_TYPE" ]] && (( $(echo "$CONFIDENCE < 0.7" | bc -l 2>/dev/null || echo 0) )); then
    OUTPUT+="CLASSIFICATION_UNCERTAIN: Work type '$WORK_TYPE' detected with confidence ${CONFIDENCE}. "
    OUTPUT+="Consider asking user to confirm.\n"
fi

# Output mandatory skills
if [[ -n "$MANDATORY_SKILLS" && "$MANDATORY_SKILLS" != "null" ]]; then
    OUTPUT+="MANDATORY_SKILLS_FOR_${CURRENT_STATE}: $MANDATORY_SKILLS\n"
    OUTPUT+="You MUST invoke these skills before proceeding to the next phase.\n"
fi

# Phase-specific reminders
case "$CURRENT_STATE" in
    "PLAN")
        if [[ "$WORK_TYPE" == "FRONTEND" ]]; then
            OUTPUT+="REMINDER: This is a FRONTEND task. frontend-design skill is MANDATORY to avoid generic AI aesthetics.\n"
        elif [[ "$WORK_TYPE" == "RESEARCH" ]]; then
            OUTPUT+="REMINDER: This is a RESEARCH task. Follow R1-R4 workflow, not implementation phases.\n"
        fi
        ;;
    "EXECUTE")
        OUTPUT+="REMINDER: TDD is mandatory. Write failing test BEFORE implementation code.\n"
        ;;
    "REVIEW")
        OUTPUT+="REMINDER: Run FRESH verification. Do not rely on cached results.\n"
        ;;
esac

# Token usage check
TOKEN_ESTIMATED=$(yq -r '.token_usage.estimated // 0' "$STATE_MACHINE_FILE")
TOKEN_BUDGET=$(yq -r '.token_usage.budget // 200000' "$STATE_MACHINE_FILE")
WARNING_THRESHOLD=$(yq -r '.token_usage.warning_threshold // 0.80' "$STATE_MACHINE_FILE")

if [[ "$TOKEN_ESTIMATED" -gt 0 && "$TOKEN_BUDGET" -gt 0 ]]; then
    USAGE_PCT=$(echo "scale=2; $TOKEN_ESTIMATED / $TOKEN_BUDGET" | bc 2>/dev/null || echo "0")
    if (( $(echo "$USAGE_PCT >= $WARNING_THRESHOLD" | bc -l 2>/dev/null || echo 0) )); then
        OUTPUT+="TOKEN_WARNING: Context usage at approximately ${USAGE_PCT}%. Consider summarizing context.\n"
    fi
fi

# Output if we have anything to say
if [[ -n "$OUTPUT" ]]; then
    echo -e "$OUTPUT"
fi
