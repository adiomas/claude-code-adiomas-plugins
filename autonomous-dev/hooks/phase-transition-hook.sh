#!/usr/bin/env bash
# phase-transition-hook.sh - Progressive Skill Loading on Phase Transitions
# Anthropic Best Practice: Load skills only when entering their phase
#
# This hook is called by state-transition.sh when phase changes.
# It outputs which skills should be loaded for the new phase.

set -euo pipefail

SKILL_CONFIG="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}/skills/skill-loading-config.yaml"
STATE_FILE=".claude/auto-state-machine.yaml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get new phase from argument or state file
NEW_PHASE="${1:-}"
if [[ -z "$NEW_PHASE" && -f "$STATE_FILE" ]]; then
    NEW_PHASE=$(yq -r '.current_state // "IDLE"' "$STATE_FILE" 2>/dev/null || echo "IDLE")
fi

if [[ -z "$NEW_PHASE" ]]; then
    echo "Usage: $0 <new_phase>"
    echo "Or ensure .claude/auto-state-machine.yaml exists"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Progressive Skill Loading - Phase: ${NEW_PHASE}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if config exists
if [[ ! -f "$SKILL_CONFIG" ]]; then
    echo -e "${YELLOW}Warning: Skill loading config not found at $SKILL_CONFIG${NC}"
    echo "Proceeding without progressive loading..."
    exit 0
fi

# Get always-loaded skills
echo -e "\n${GREEN}Always Loaded Skills:${NC}"
ALWAYS_LOADED=$(yq -r '.always_loaded[]' "$SKILL_CONFIG" 2>/dev/null || echo "")
if [[ -n "$ALWAYS_LOADED" ]]; then
    echo "$ALWAYS_LOADED" | while read -r skill; do
        echo "  ✓ $skill"
    done
else
    echo "  (none configured)"
fi

# Get phase-specific skills
echo -e "\n${GREEN}Phase-Specific Skills for $NEW_PHASE:${NC}"
PHASE_SKILLS=$(yq -r ".phase_specific.${NEW_PHASE}.skills[]?" "$SKILL_CONFIG" 2>/dev/null || echo "")
if [[ -n "$PHASE_SKILLS" ]]; then
    echo "$PHASE_SKILLS" | while read -r skill; do
        echo "  ✓ $skill"
    done
else
    echo "  (none for this phase)"
fi

# Check on-demand conditions
echo -e "\n${GREEN}Checking On-Demand Conditions:${NC}"

# Check for frontend work
if [[ -f ".claude/auto-context.yaml" ]]; then
    WORK_TYPE=$(yq -r '.work_type // ""' ".claude/auto-context.yaml" 2>/dev/null || echo "")
    if [[ "$WORK_TYPE" == "FRONTEND" ]]; then
        echo "  ✓ Frontend detected - loading e2e-validator"
    fi
fi

# Check for database
if [[ -f ".claude/project-profile.yaml" ]]; then
    HAS_DB=$(grep -c "database:" ".claude/project-profile.yaml" 2>/dev/null || echo "0")
    if [[ "$HAS_DB" -gt 0 ]]; then
        echo "  ✓ Database detected - schema-validator agent available"
    fi
fi

# Suggest skills to unload based on completed phases
echo -e "\n${GREEN}Skills to Unload (no longer needed):${NC}"
case "$NEW_PHASE" in
    EXECUTE)
        echo "  - task-decomposer (plan is written)"
        ;;
    INTEGRATE)
        echo "  - mutation-tester (tests are complete)"
        ;;
    REVIEW)
        echo "  - conflict-resolver (merge is complete)"
        ;;
    *)
        echo "  (none)"
        ;;
esac

# Calculate approximate token usage
echo -e "\n${GREEN}Estimated Token Usage:${NC}"
TOTAL=0

# Always loaded ~1000
ALWAYS_COUNT=$(echo "$ALWAYS_LOADED" | grep -c . || echo "0")
ALWAYS_TOKENS=$((ALWAYS_COUNT * 500))
TOTAL=$((TOTAL + ALWAYS_TOKENS))
echo "  Always loaded: ~${ALWAYS_TOKENS} tokens"

# Phase specific
PHASE_COUNT=$(echo "$PHASE_SKILLS" | grep -c . || echo "0")
PHASE_TOKENS=$((PHASE_COUNT * 700))
TOTAL=$((TOTAL + PHASE_TOKENS))
echo "  Phase-specific: ~${PHASE_TOKENS} tokens"

echo "  ─────────────────────"
echo "  Total: ~${TOTAL} tokens (budget: 7000)"

if [[ $TOTAL -gt 7000 ]]; then
    echo -e "\n${YELLOW}Warning: Token usage exceeds budget!${NC}"
fi

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
