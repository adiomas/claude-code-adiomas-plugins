#!/usr/bin/env bash
# local-memory.sh - Manage project-specific memory (90 day retention)
#
# Usage:
#   local-memory.sh load                      Load all local memory
#   local-memory.sh store-session [options]   Store session results
#   local-memory.sh find-similar <query>      Find similar past work
#   local-memory.sh learn [options]           Store new learning
#   local-memory.sh get-quirks                Get project quirks
#   local-memory.sh cleanup                   Remove old data (90+ days)
#   local-memory.sh export                    Export for debugging
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly MEMORY_DIR=".claude/memory"
readonly SESSIONS_DIR="$MEMORY_DIR/sessions"
readonly PROJECT_CONTEXT="$MEMORY_DIR/project-context.yaml"
readonly LEARNINGS_FILE="$MEMORY_DIR/learnings.yaml"
readonly REFERENCES_FILE="$MEMORY_DIR/references.yaml"
readonly RETENTION_DAYS=90

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Initialize memory directory
init_memory() {
    mkdir -p "$MEMORY_DIR"
    mkdir -p "$SESSIONS_DIR"

    # Create project context if missing
    if [[ ! -f "$PROJECT_CONTEXT" ]]; then
        cat > "$PROJECT_CONTEXT" << 'EOF'
# Project Context - Auto-generated
# Edit as needed

project:
  name: ""
  type: ""

stack:
  language: ""
  framework: ""
  version: ""

commands:
  test: "npm test"
  build: "npm run build"
  lint: "npm run lint"

quirks: []
conventions: {}
EOF
    fi

    # Create learnings file if missing
    if [[ ! -f "$LEARNINGS_FILE" ]]; then
        echo "learnings: []" > "$LEARNINGS_FILE"
    fi
}

# Load all local memory
load_memory() {
    init_memory

    echo -e "${BLUE}Loading local memory...${NC}"

    # Output project context
    if [[ -f "$PROJECT_CONTEXT" ]]; then
        echo ""
        echo "=== Project Context ==="
        cat "$PROJECT_CONTEXT"
    fi

    # Output recent sessions (last 7 days)
    echo ""
    echo "=== Recent Sessions (7 days) ==="
    local cutoff_date
    cutoff_date=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d')

    for session_file in "$SESSIONS_DIR"/*.yaml; do
        if [[ -f "$session_file" ]]; then
            local file_date
            file_date=$(basename "$session_file" .yaml)
            if [[ "$file_date" > "$cutoff_date" ]] || [[ "$file_date" == "$cutoff_date" ]]; then
                echo "--- $file_date ---"
                cat "$session_file"
                echo ""
            fi
        fi
    done

    # Output active learnings
    if [[ -f "$LEARNINGS_FILE" ]]; then
        echo ""
        echo "=== Active Learnings ==="
        cat "$LEARNINGS_FILE"
    fi

    echo -e "${GREEN}✓ Local memory loaded${NC}"
}

# Store session results
store_session() {
    init_memory

    local task=""
    local task_type="FEATURE"
    local complexity=3
    local files=""
    local decisions=""
    local evidence=""
    local outcome="success"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task|-t)
                task="$2"
                shift 2
                ;;
            --type)
                task_type="$2"
                shift 2
                ;;
            --complexity|-c)
                complexity="$2"
                shift 2
                ;;
            --files|-f)
                files="$2"
                shift 2
                ;;
            --decisions|-d)
                decisions="$2"
                shift 2
                ;;
            --evidence|-e)
                evidence="$2"
                shift 2
                ;;
            --outcome|-o)
                outcome="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local today
    today=$(date '+%Y-%m-%d')
    local session_file="$SESSIONS_DIR/$today.yaml"
    local session_id="session-$(date '+%H%M%S')"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Convert files to YAML array
    local files_yaml=""
    if [[ -n "$files" ]]; then
        IFS=',' read -ra file_array <<< "$files"
        for f in "${file_array[@]}"; do
            files_yaml="${files_yaml}    - \"$f\"\n"
        done
    fi

    # Append to today's session file
    cat >> "$session_file" << EOF

  - id: "$session_id"
    started_at: "$timestamp"
    ended_at: "$timestamp"
    task:
      input: "$task"
      type: "$task_type"
      complexity: $complexity
    outcome:
      status: "$outcome"
      evidence: "$evidence"
      files:
$(echo -e "$files_yaml")
    decisions: []
EOF

    echo -e "${GREEN}✓ Session stored: $session_id${NC}"
}

# Find similar past work
find_similar() {
    init_memory

    local query="${1:-}"

    if [[ -z "$query" ]]; then
        echo "Usage: local-memory.sh find-similar <query>" >&2
        exit 1
    fi

    echo -e "${BLUE}Searching for: $query${NC}"
    echo ""

    local found=0

    for session_file in "$SESSIONS_DIR"/*.yaml; do
        if [[ -f "$session_file" ]]; then
            if grep -qi "$query" "$session_file" 2>/dev/null; then
                echo "=== $(basename "$session_file" .yaml) ==="
                # Extract matching sessions
                grep -A20 -B2 -i "$query" "$session_file" 2>/dev/null || true
                echo ""
                ((found++)) || true
            fi
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo -e "${YELLOW}No similar work found${NC}"
    else
        echo -e "${GREEN}Found $found matching session files${NC}"
    fi
}

# Store new learning
store_learning() {
    init_memory

    local learning_type="quirk"
    local content=""
    local applies_to=""
    local confidence=0.8

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                learning_type="$2"
                shift 2
                ;;
            --content|-c)
                content="$2"
                shift 2
                ;;
            --applies-to|-a)
                applies_to="$2"
                shift 2
                ;;
            --confidence)
                confidence="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$content" ]]; then
        echo "Usage: local-memory.sh learn --content <content> [options]" >&2
        exit 1
    fi

    local learning_id="learn-$(date '+%Y%m%d%H%M%S')"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Append to learnings file
    cat >> "$LEARNINGS_FILE" << EOF

  - id: "$learning_id"
    type: "$learning_type"
    content: "$content"
    applies_to: ["$applies_to"]
    confidence: $confidence
    learned_at: "$timestamp"
    last_used: "$timestamp"
    use_count: 0
EOF

    echo -e "${GREEN}✓ Learning stored: $learning_id${NC}"
}

# Get project quirks
get_quirks() {
    init_memory

    if [[ -f "$PROJECT_CONTEXT" ]]; then
        echo "=== Project Quirks ==="
        grep -A100 "^quirks:" "$PROJECT_CONTEXT" 2>/dev/null | head -50 || echo "No quirks defined"
    else
        echo "No project context found"
    fi
}

# Cleanup old data
cleanup_old_data() {
    init_memory

    local cutoff_date
    cutoff_date=$(date -v-${RETENTION_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${RETENTION_DAYS} days ago" '+%Y-%m-%d')

    local removed=0

    echo -e "${BLUE}Cleaning up sessions older than $cutoff_date...${NC}"

    for session_file in "$SESSIONS_DIR"/*.yaml; do
        if [[ -f "$session_file" ]]; then
            local file_date
            file_date=$(basename "$session_file" .yaml)
            if [[ "$file_date" < "$cutoff_date" ]]; then
                rm "$session_file"
                echo "  Removed: $file_date"
                ((removed++)) || true
            fi
        fi
    done

    if [[ $removed -eq 0 ]]; then
        echo -e "${GREEN}No old sessions to clean up${NC}"
    else
        echo -e "${GREEN}✓ Removed $removed old session files${NC}"
    fi
}

# Export memory for debugging
export_memory() {
    init_memory

    local export_file=".claude/memory-export-$(date '+%Y%m%d-%H%M%S').json"

    echo -e "${BLUE}Exporting local memory...${NC}"

    # Create JSON export
    cat > "$export_file" << EOF
{
  "exported_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "memory_dir": "$MEMORY_DIR",
  "files": {
EOF

    # Add each file
    local first=true
    for file in "$MEMORY_DIR"/*.yaml "$SESSIONS_DIR"/*.yaml; do
        if [[ -f "$file" ]]; then
            if [[ "$first" != "true" ]]; then
                echo "," >> "$export_file"
            fi
            first=false
            local filename
            filename=$(basename "$file")
            echo -n "    \"$filename\": " >> "$export_file"
            # Convert YAML to JSON-safe string
            cat "$file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk 'BEGIN{printf "\""} {printf "%s\\n", $0} END{printf "\""}' >> "$export_file"
        fi
    done

    echo "" >> "$export_file"
    echo "  }" >> "$export_file"
    echo "}" >> "$export_file"

    echo -e "${GREEN}✓ Exported to: $export_file${NC}"
}

# Show help
show_help() {
    cat << 'EOF'
local-memory.sh - Manage project-specific memory

Usage:
    local-memory.sh load                      Load all local memory
    local-memory.sh store-session [options]   Store session results
    local-memory.sh find-similar <query>      Find similar past work
    local-memory.sh learn [options]           Store new learning
    local-memory.sh get-quirks                Get project quirks
    local-memory.sh cleanup                   Remove old data (90+ days)
    local-memory.sh export                    Export for debugging

Store Session Options:
    --task, -t <text>       Task description
    --type <TYPE>           Task type (FEATURE, BUG_FIX, REFACTOR, etc.)
    --complexity, -c <1-5>  Task complexity
    --files, -f <list>      Comma-separated list of files
    --evidence, -e <text>   Verification evidence
    --outcome, -o <status>  Outcome (success, failure, partial)

Learning Options:
    --type, -t <type>       Learning type (quirk, pattern, gotcha)
    --content, -c <text>    Learning content
    --applies-to, -a <glob> File pattern this applies to
    --confidence <0-1>      Confidence score

Examples:
    # Load memory at session start
    local-memory.sh load

    # Store session after completion
    local-memory.sh store-session \
        --task "Implement OAuth" \
        --type FEATURE \
        --files "src/auth/oauth.ts,src/auth/oauth.test.ts" \
        --evidence "12/12 tests passed"

    # Find similar past work
    local-memory.sh find-similar "authentication"

    # Store a learning
    local-memory.sh learn \
        --type quirk \
        --content "Always await Supabase calls" \
        --applies-to "src/lib/**"

    # Cleanup old sessions
    local-memory.sh cleanup
EOF
}

# Main entry point
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        load)
            load_memory
            ;;
        store-session)
            store_session "$@"
            ;;
        find-similar|find|search)
            find_similar "$@"
            ;;
        learn)
            store_learning "$@"
            ;;
        get-quirks|quirks)
            get_quirks
            ;;
        cleanup)
            cleanup_old_data
            ;;
        export)
            export_memory
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command" >&2
            echo "Run 'local-memory.sh help' for usage" >&2
            exit 1
            ;;
    esac
}

main "$@"
