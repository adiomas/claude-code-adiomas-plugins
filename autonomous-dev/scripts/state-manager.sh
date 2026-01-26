#!/usr/bin/env bash
# state-manager.sh - Unified state management for AGI-like execution
# Single source of truth for all execution state
#
# Usage:
#   state-manager.sh init <input>              Initialize new state
#   state-manager.sh get <field>               Get field value
#   state-manager.sh set <field> <value>       Set field value
#   state-manager.sh status                    Show current status
#   state-manager.sh phase start <name>        Start a phase
#   state-manager.sh phase complete <evidence> Complete current phase
#   state-manager.sh checkpoint [reason]       Create checkpoint
#   state-manager.sh validate                  Validate state against schema
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly STATE_DIR=".claude"
readonly STATE_FILE="$STATE_DIR/state.json"
readonly CHECKPOINT_DIR="$STATE_DIR/checkpoints"
readonly SCHEMA_FILE="$(dirname "$0")/../schemas/state.schema.json"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Check for jq
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}ERROR: jq is required but not installed${NC}" >&2
        echo "Install with: brew install jq" >&2
        exit 1
    fi
}

# Initialize new state
init_state() {
    local input="$1"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    mkdir -p "$STATE_DIR"

    cat > "$STATE_FILE" << EOF
{
  "version": "2.0",
  "task": {
    "input": $(echo "$input" | jq -Rs .),
    "intent": "FEATURE",
    "complexity": 3,
    "work_type": "FULLSTACK",
    "started_at": "$timestamp",
    "entities": [],
    "references": []
  },
  "project": {
    "stack": "",
    "test_cmd": "npm test",
    "build_cmd": "npm run build",
    "lint_cmd": "npm run lint",
    "quirks": []
  },
  "execution": {
    "strategy": "DIRECT",
    "status": "pending",
    "current_phase": 0,
    "phases": [],
    "files_created": [],
    "files_modified": []
  },
  "evidence": {},
  "context": {
    "tokens_used": 0,
    "key_decisions": [],
    "checkpoint_ready": true,
    "session_number": 1
  },
  "recovery": {
    "last_checkpoint": null,
    "can_resume": true,
    "resume_from": null,
    "stuck_reason": null
  },
  "memory": {
    "local_patterns": [],
    "global_patterns": [],
    "gotchas": []
  }
}
EOF

    echo -e "${GREEN}✓ State initialized${NC}"
}

# Get field value
get_field() {
    local field="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    jq -r ".$field // empty" "$STATE_FILE"
}

# Set field value
set_field() {
    local field="$1"
    local value="$2"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    # Determine if value is JSON or string
    if [[ "$value" =~ ^[\[\{] ]] || [[ "$value" =~ ^(true|false|null|[0-9]+)$ ]]; then
        # JSON value
        jq ".$field = $value" "$STATE_FILE" > "$STATE_FILE.tmp"
    else
        # String value
        jq ".$field = \"$value\"" "$STATE_FILE" > "$STATE_FILE.tmp"
    fi

    mv "$STATE_FILE.tmp" "$STATE_FILE"
    echo -e "${GREEN}✓ Set $field${NC}"
}

# Show current status
show_status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${YELLOW}No active execution${NC}"
        return
    fi

    local status
    local input
    local intent
    local complexity
    local strategy
    local current_phase
    local total_phases

    status=$(jq -r '.execution.status' "$STATE_FILE")
    input=$(jq -r '.task.input' "$STATE_FILE" | head -c 50)
    intent=$(jq -r '.task.intent' "$STATE_FILE")
    complexity=$(jq -r '.task.complexity' "$STATE_FILE")
    strategy=$(jq -r '.execution.strategy' "$STATE_FILE")
    current_phase=$(jq -r '.execution.current_phase' "$STATE_FILE")
    total_phases=$(jq '.execution.phases | length' "$STATE_FILE")

    echo "═══════════════════════════════════════════════════════════"
    echo " AGI State"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo " Task: $input..."
    echo " Intent: $intent | Complexity: $complexity/5"
    echo " Strategy: $strategy"
    echo ""
    echo " Status: $status"

    if [[ "$total_phases" -gt 0 ]]; then
        echo " Progress: Phase $current_phase of $total_phases"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
}

# Start a phase
start_phase() {
    local name="$1"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    # Get current phase count
    local phase_count
    phase_count=$(jq '.execution.phases | length' "$STATE_FILE")

    # Create new phase
    local new_phase
    new_phase=$(cat << EOF
{
  "id": "phase-$((phase_count + 1))",
  "name": "$name",
  "status": "in_progress",
  "started_at": "$timestamp",
  "files": [],
  "verification": null,
  "completed_at": null,
  "evidence": null
}
EOF
)

    # Add phase and update current_phase
    jq ".execution.phases += [$new_phase] | .execution.current_phase = $phase_count | .execution.status = \"running\"" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo -e "${BLUE}→ Started phase: $name${NC}"
}

# Complete current phase
complete_phase() {
    local evidence="$1"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    local current_phase
    current_phase=$(jq -r '.execution.current_phase' "$STATE_FILE")

    # Update phase status
    jq ".execution.phases[$current_phase].status = \"done\" |
        .execution.phases[$current_phase].completed_at = \"$timestamp\" |
        .execution.phases[$current_phase].evidence = $(echo "$evidence" | jq -Rs .) |
        .execution.current_phase = $((current_phase + 1))" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo -e "${GREEN}✓ Phase completed${NC}"
}

# Create checkpoint
create_checkpoint() {
    local reason="${1:-manual}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local checkpoint_id="chk-$(date '+%Y%m%d-%H%M%S')"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    mkdir -p "$CHECKPOINT_DIR"

    # Copy current state with checkpoint metadata
    jq ". + {
      \"checkpoint\": {
        \"id\": \"$checkpoint_id\",
        \"created_at\": \"$timestamp\",
        \"reason\": \"$reason\",
        \"git_ref\": \"$(git rev-parse HEAD 2>/dev/null || echo 'none')\"
      }
    }" "$STATE_FILE" > "$CHECKPOINT_DIR/$checkpoint_id.json"

    # Update recovery in main state
    jq ".recovery.last_checkpoint = \"$checkpoint_id\" |
        .recovery.can_resume = true" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    echo -e "${GREEN}✓ Checkpoint created: $checkpoint_id${NC}"
}

# Validate state against schema
validate_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    # Check if ajv-cli is available
    if command -v ajv &> /dev/null && [[ -f "$SCHEMA_FILE" ]]; then
        if ajv validate -s "$SCHEMA_FILE" -d "$STATE_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ State is valid${NC}"
        else
            echo -e "${RED}✗ State validation failed${NC}" >&2
            exit 1
        fi
    else
        # Basic validation without ajv
        if jq '.' "$STATE_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ State is valid JSON${NC}"
            echo -e "${YELLOW}  (Full schema validation requires ajv-cli)${NC}"
        else
            echo -e "${RED}✗ Invalid JSON${NC}" >&2
            exit 1
        fi
    fi
}

# Add file to created list
add_file_created() {
    local file="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    jq ".execution.files_created += [\"$file\"] | .execution.files_created |= unique" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Add file to modified list
add_file_modified() {
    local file="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    jq ".execution.files_modified += [\"$file\"] | .execution.files_modified |= unique" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Add decision
add_decision() {
    local question="$1"
    local decision="$2"
    local reason="${3:-}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    local new_decision
    new_decision=$(cat << EOF
{
  "question": $(echo "$question" | jq -Rs .),
  "decision": $(echo "$decision" | jq -Rs .),
  "reason": $(echo "$reason" | jq -Rs .),
  "decided_at": "$timestamp"
}
EOF
)

    jq ".context.key_decisions += [$new_decision]" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Update tokens used
update_tokens() {
    local tokens="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}ERROR: No state file found${NC}" >&2
        exit 1
    fi

    jq ".context.tokens_used = $tokens" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Main entry point
main() {
    check_jq

    local command="${1:-status}"
    shift || true

    case "$command" in
        init)
            init_state "${1:-}"
            ;;
        get)
            get_field "${1:-}"
            ;;
        set)
            set_field "${1:-}" "${2:-}"
            ;;
        status)
            show_status
            ;;
        phase)
            local subcommand="${1:-}"
            shift || true
            case "$subcommand" in
                start)
                    start_phase "${1:-Unnamed Phase}"
                    ;;
                complete)
                    complete_phase "${1:-No evidence provided}"
                    ;;
                *)
                    echo "Usage: state-manager.sh phase (start|complete) [args]" >&2
                    exit 1
                    ;;
            esac
            ;;
        checkpoint)
            create_checkpoint "${1:-manual}"
            ;;
        validate)
            validate_state
            ;;
        add-file-created)
            add_file_created "${1:-}"
            ;;
        add-file-modified)
            add_file_modified "${1:-}"
            ;;
        add-decision)
            add_decision "${1:-}" "${2:-}" "${3:-}"
            ;;
        update-tokens)
            update_tokens "${1:-0}"
            ;;
        *)
            echo "Usage: state-manager.sh <command> [args]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  init <input>              Initialize new state" >&2
            echo "  get <field>               Get field value" >&2
            echo "  set <field> <value>       Set field value" >&2
            echo "  status                    Show current status" >&2
            echo "  phase start <name>        Start a phase" >&2
            echo "  phase complete <evidence> Complete current phase" >&2
            echo "  checkpoint [reason]       Create checkpoint" >&2
            echo "  validate                  Validate state" >&2
            exit 1
            ;;
    esac
}

main "$@"
