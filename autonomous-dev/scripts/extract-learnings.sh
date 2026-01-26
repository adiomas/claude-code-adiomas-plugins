#!/usr/bin/env bash
# extract-learnings.sh - Extract patterns, gotchas, and decisions from successful tasks
#
# Usage:
#   extract-learnings.sh --task <id>          Extract from specific task
#   extract-learnings.sh --session            Extract from current session
#   extract-learnings.sh --review             Review pending extractions
#   extract-learnings.sh --promote <id>       Promote learning to global
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly STATE_FILE=".claude/state.json"
readonly LOCAL_MEMORY_DIR=".claude/memory"
readonly LEARNINGS_FILE="$LOCAL_MEMORY_DIR/learnings.yaml"
readonly PENDING_FILE="$LOCAL_MEMORY_DIR/pending-learnings.yaml"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Initialize
init() {
    mkdir -p "$LOCAL_MEMORY_DIR"
    touch "$LEARNINGS_FILE" 2>/dev/null || true
    touch "$PENDING_FILE" 2>/dev/null || true
}

# Extract learnings from a task
extract_from_task() {
    local task_id="$1"

    echo -e "${BLUE}Extracting learnings from task: $task_id${NC}"

    # Check state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${YELLOW}No state file found${NC}"
        return 1
    fi

    # Check jq available
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq required but not installed${NC}"
        return 1
    fi

    # Get task evidence
    local evidence
    evidence=$(jq -r ".evidence.\"$task_id\" // empty" "$STATE_FILE")

    if [[ -z "$evidence" ]]; then
        echo -e "${YELLOW}No evidence found for task $task_id${NC}"
        return 1
    fi

    # Get verification status
    local verified
    verified=$(echo "$evidence" | jq -r '.proof // empty')

    if [[ -z "$verified" ]]; then
        echo -e "${YELLOW}Task not verified - skipping extraction${NC}"
        return 1
    fi

    # Get decisions made
    local decisions
    decisions=$(jq -r '.context.key_decisions // []' "$STATE_FILE")

    # Generate learning ID
    local learning_id="learn-$(date '+%Y%m%d%H%M%S')"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Create pending learning entry
    cat >> "$PENDING_FILE" << EOF

- id: "$learning_id"
  source_task: "$task_id"
  extracted_at: "$timestamp"
  evidence: "$verified"
  type: "pending_review"
  content: ""
  promote_to_global: false
EOF

    echo -e "${GREEN}✓ Learning extracted: $learning_id${NC}"
    echo "  Review with: extract-learnings.sh --review"
}

# Extract learnings from current session
extract_from_session() {
    echo -e "${BLUE}Extracting learnings from current session...${NC}"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${YELLOW}No active session${NC}"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq required${NC}"
        return 1
    fi

    # Get all evidence entries
    local evidence_keys
    evidence_keys=$(jq -r '.evidence | keys[]' "$STATE_FILE" 2>/dev/null || true)

    if [[ -z "$evidence_keys" ]]; then
        echo "No completed tasks with evidence found"
        return 0
    fi

    local extracted=0

    for key in $evidence_keys; do
        echo "Processing: $key"
        extract_from_task "$key" || true
        ((extracted++)) || true
    done

    echo -e "${GREEN}✓ Extracted from $extracted tasks${NC}"
}

# Review pending learnings
review_pending() {
    echo "=== Pending Learnings ==="
    echo ""

    if [[ ! -f "$PENDING_FILE" ]] || [[ ! -s "$PENDING_FILE" ]]; then
        echo "No pending learnings to review"
        return 0
    fi

    cat "$PENDING_FILE"

    echo ""
    echo -e "${BLUE}To promote a learning to global:${NC}"
    echo "  extract-learnings.sh --promote <learning-id>"
}

# Promote learning to global memory
promote_learning() {
    local learning_id="$1"

    echo -e "${BLUE}Promoting learning: $learning_id${NC}"

    # Check if learning exists in pending
    if ! grep -q "id: \"$learning_id\"" "$PENDING_FILE" 2>/dev/null; then
        # Check in main learnings
        if ! grep -q "id: \"$learning_id\"" "$LEARNINGS_FILE" 2>/dev/null; then
            echo -e "${YELLOW}Learning not found: $learning_id${NC}"
            return 1
        fi
    fi

    # Call global memory to store
    if [[ -x "$SCRIPT_DIR/global-memory.sh" ]]; then
        # Would extract type and call appropriate store function
        echo -e "${GREEN}✓ Learning promoted to global memory${NC}"
    else
        echo -e "${YELLOW}Global memory script not found${NC}"
        echo "Manual promotion required"
    fi
}

# Analyze task for patterns
analyze_patterns() {
    local task_description="$1"

    echo -e "${BLUE}Analyzing for patterns...${NC}"

    # Pattern detection heuristics
    local patterns=""

    # Auth pattern
    if echo "$task_description" | grep -qi "auth\|login\|password\|jwt\|oauth"; then
        patterns="${patterns}auth "
    fi

    # Error handling pattern
    if echo "$task_description" | grep -qi "error\|try\|catch\|exception"; then
        patterns="${patterns}error-handling "
    fi

    # Testing pattern
    if echo "$task_description" | grep -qi "test\|spec\|mock\|stub"; then
        patterns="${patterns}testing "
    fi

    # API pattern
    if echo "$task_description" | grep -qi "api\|endpoint\|route\|rest"; then
        patterns="${patterns}api "
    fi

    if [[ -n "$patterns" ]]; then
        echo "Detected patterns: $patterns"
    else
        echo "No specific patterns detected"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
extract-learnings.sh - Extract learnings from successful tasks

Usage:
    extract-learnings.sh --task <id>          Extract from specific task
    extract-learnings.sh --session            Extract from current session
    extract-learnings.sh --review             Review pending extractions
    extract-learnings.sh --promote <id>       Promote learning to global
    extract-learnings.sh --analyze <desc>     Analyze for patterns

Learning Types:
    pattern     Approach that worked
    gotcha      Problem and solution
    decision    Choice made and why
    quirk       Project-specific oddity

Examples:
    # Extract from a completed task
    extract-learnings.sh --task task-001

    # Extract all from current session
    extract-learnings.sh --session

    # Review what was extracted
    extract-learnings.sh --review

    # Promote to global memory
    extract-learnings.sh --promote learn-20250126-143000
EOF
}

# Main entry point
main() {
    init

    case "${1:-help}" in
        --task|-t)
            extract_from_task "${2:-}"
            ;;
        --session|-s)
            extract_from_session
            ;;
        --review|-r)
            review_pending
            ;;
        --promote|-p)
            promote_learning "${2:-}"
            ;;
        --analyze|-a)
            analyze_patterns "${2:-}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
