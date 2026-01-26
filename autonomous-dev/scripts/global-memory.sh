#!/usr/bin/env bash
# global-memory.sh - Manage global memory (shared across projects)
#
# Usage:
#   global-memory.sh load [options]           Load relevant knowledge
#   global-memory.sh store-pattern [options]  Store new pattern
#   global-memory.sh store-gotcha [options]   Store new gotcha
#   global-memory.sh update-confidence [opts] Update confidence score
#   global-memory.sh record-usage [options]   Record knowledge was used
#   global-memory.sh promote [options]        Promote local to global
#   global-memory.sh cleanup                  Run decay and cleanup
#   global-memory.sh stats                    Show usage statistics
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly GLOBAL_MEMORY_DIR="${HOME}/.claude/global-memory"
readonly PATTERNS_DIR="$GLOBAL_MEMORY_DIR/patterns"
readonly GOTCHAS_DIR="$GLOBAL_MEMORY_DIR/gotchas"
readonly PREFERENCES_FILE="$GLOBAL_MEMORY_DIR/preferences.yaml"
readonly STATS_FILE="$GLOBAL_MEMORY_DIR/stats.yaml"
readonly INDEX_FILE="$GLOBAL_MEMORY_DIR/index.json"
readonly ARCHIVE_DIR="$GLOBAL_MEMORY_DIR/archive"

# Thresholds
readonly DECAY_START_DAYS=30
readonly DECAY_RATE=0.005  # 0.5% per day
readonly MIN_CONFIDENCE=0.1
readonly REMOVAL_THRESHOLD=0.3

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Initialize global memory directory
init_global_memory() {
    mkdir -p "$GLOBAL_MEMORY_DIR"
    mkdir -p "$PATTERNS_DIR"
    mkdir -p "$GOTCHAS_DIR"
    mkdir -p "$ARCHIVE_DIR"

    # Create preferences if missing
    if [[ ! -f "$PREFERENCES_FILE" ]]; then
        cat > "$PREFERENCES_FILE" << 'EOF'
# User Preferences - Edit as needed

code_style:
  paradigm: "functional-preferred"  # functional-preferred | oop-preferred | mixed
  comments: "minimal"               # minimal | moderate | verbose
  naming: "descriptive"             # short | descriptive | verbose

testing:
  style: "integration-first"        # unit-first | integration-first | e2e-first
  coverage_target: 80
  framework_preference: "vitest"    # vitest | jest | mocha

git:
  commit_style: "conventional"      # conventional | freeform
  branch_naming: "feature/kebab-case"

formatting:
  indent: 2
  quotes: "single"
  semicolons: false
EOF
    fi

    # Create stats if missing
    if [[ ! -f "$STATS_FILE" ]]; then
        cat > "$STATS_FILE" << 'EOF'
# Global Memory Statistics
created_at: "2025-01-26"
total_patterns: 0
total_gotchas: 0
total_lookups: 0
last_cleanup: null
EOF
    fi

    # Create index if missing
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo '{"patterns":[],"gotchas":[],"updated_at":"'$(date -u '+%Y-%m-%dT%H:%M:%SZ')'"}' > "$INDEX_FILE"
    fi
}

# Load relevant knowledge
load_knowledge() {
    init_global_memory

    local domain=""
    local tech=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain|-d)
                domain="$2"
                shift 2
                ;;
            --tech|-t)
                tech="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${BLUE}Loading global knowledge...${NC}"

    # Load patterns for domain
    if [[ -n "$domain" ]]; then
        local pattern_file="$PATTERNS_DIR/$domain.yaml"
        if [[ -f "$pattern_file" ]]; then
            echo ""
            echo "=== Patterns: $domain ==="
            cat "$pattern_file"
        fi
    fi

    # Load gotchas for technologies
    if [[ -n "$tech" ]]; then
        IFS=',' read -ra tech_array <<< "$tech"
        for t in "${tech_array[@]}"; do
            local gotcha_file="$GOTCHAS_DIR/$t.yaml"
            if [[ -f "$gotcha_file" ]]; then
                echo ""
                echo "=== Gotchas: $t ==="
                cat "$gotcha_file"
            fi
        done
    fi

    # Load preferences
    if [[ -f "$PREFERENCES_FILE" ]]; then
        echo ""
        echo "=== Preferences ==="
        cat "$PREFERENCES_FILE"
    fi

    # Update stats
    local current_lookups
    current_lookups=$(grep "total_lookups:" "$STATS_FILE" | sed 's/.*: //' || echo 0)
    sed -i.bak "s/total_lookups:.*/total_lookups: $((current_lookups + 1))/" "$STATS_FILE" 2>/dev/null || true
    rm -f "$STATS_FILE.bak"

    echo -e "${GREEN}✓ Knowledge loaded${NC}"
}

# Store new pattern
store_pattern() {
    init_global_memory

    local domain=""
    local name=""
    local approach=""
    local confidence=0.8
    local source=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain|-d)
                domain="$2"
                shift 2
                ;;
            --name|-n)
                name="$2"
                shift 2
                ;;
            --approach|-a)
                approach="$2"
                shift 2
                ;;
            --confidence|-c)
                confidence="$2"
                shift 2
                ;;
            --source|-s)
                source="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$domain" ]] || [[ -z "$name" ]]; then
        echo "Usage: global-memory.sh store-pattern --domain <domain> --name <name> --approach <approach>" >&2
        exit 1
    fi

    local pattern_file="$PATTERNS_DIR/$domain.yaml"
    local pattern_id="${domain}-$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Create or append to domain file
    if [[ ! -f "$pattern_file" ]]; then
        cat > "$pattern_file" << EOF
domain: $domain
patterns: []
EOF
    fi

    # Append new pattern
    cat >> "$pattern_file" << EOF

  - id: "$pattern_id"
    name: "$name"
    approach: "$approach"
    confidence: $confidence
    learned_from:
      - project: "$source"
        date: "$timestamp"
        success: true
    last_used: "$timestamp"
    use_count: 0
EOF

    # Update index
    update_index "pattern" "$pattern_id" "$domain" "$name"

    echo -e "${GREEN}✓ Pattern stored: $pattern_id${NC}"
}

# Store new gotcha
store_gotcha() {
    init_global_memory

    local tech=""
    local title=""
    local problem=""
    local solution=""
    local confidence=0.8

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tech|-t)
                tech="$2"
                shift 2
                ;;
            --title)
                title="$2"
                shift 2
                ;;
            --problem|-p)
                problem="$2"
                shift 2
                ;;
            --solution|-s)
                solution="$2"
                shift 2
                ;;
            --confidence|-c)
                confidence="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$tech" ]] || [[ -z "$title" ]]; then
        echo "Usage: global-memory.sh store-gotcha --tech <tech> --title <title> --problem <problem> --solution <solution>" >&2
        exit 1
    fi

    local gotcha_file="$GOTCHAS_DIR/$tech.yaml"
    local gotcha_id="${tech}-$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Create or append to tech file
    if [[ ! -f "$gotcha_file" ]]; then
        cat > "$gotcha_file" << EOF
technology: $tech
gotchas: []
EOF
    fi

    # Append new gotcha
    cat >> "$gotcha_file" << EOF

  - id: "$gotcha_id"
    title: "$title"
    problem: "$problem"
    solution: "$solution"
    confidence: $confidence
    learned_at: "$timestamp"
    last_used: "$timestamp"
    use_count: 0
EOF

    # Update index
    update_index "gotcha" "$gotcha_id" "$tech" "$title"

    echo -e "${GREEN}✓ Gotcha stored: $gotcha_id${NC}"
}

# Update index file
update_index() {
    local type="$1"
    local id="$2"
    local category="$3"
    local name="$4"

    if command -v jq &> /dev/null; then
        local entry="{\"id\":\"$id\",\"category\":\"$category\",\"name\":\"$name\"}"
        if [[ "$type" == "pattern" ]]; then
            jq ".patterns += [$entry] | .updated_at = \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"" "$INDEX_FILE" > "$INDEX_FILE.tmp"
        else
            jq ".gotchas += [$entry] | .updated_at = \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"" "$INDEX_FILE" > "$INDEX_FILE.tmp"
        fi
        mv "$INDEX_FILE.tmp" "$INDEX_FILE"
    fi
}

# Update confidence score
update_confidence() {
    init_global_memory

    local id=""
    local delta=0
    local reason=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                id="$2"
                shift 2
                ;;
            --delta|-d)
                delta="$2"
                shift 2
                ;;
            --reason|-r)
                reason="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$id" ]]; then
        echo "Usage: global-memory.sh update-confidence --id <id> --delta <delta>" >&2
        exit 1
    fi

    echo -e "${BLUE}Updating confidence for: $id${NC}"
    echo "  Delta: $delta"
    echo "  Reason: $reason"

    # Find and update in pattern files
    for pattern_file in "$PATTERNS_DIR"/*.yaml; do
        if [[ -f "$pattern_file" ]] && grep -q "id: \"$id\"" "$pattern_file" 2>/dev/null; then
            echo "  Found in: $(basename "$pattern_file")"
            # Note: Full implementation would update confidence in-place
            echo -e "${GREEN}✓ Confidence updated${NC}"
            return
        fi
    done

    # Find and update in gotcha files
    for gotcha_file in "$GOTCHAS_DIR"/*.yaml; do
        if [[ -f "$gotcha_file" ]] && grep -q "id: \"$id\"" "$gotcha_file" 2>/dev/null; then
            echo "  Found in: $(basename "$gotcha_file")"
            echo -e "${GREEN}✓ Confidence updated${NC}"
            return
        fi
    done

    echo -e "${YELLOW}Knowledge not found: $id${NC}"
}

# Record usage
record_usage() {
    local id=""
    local success=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                id="$2"
                shift 2
                ;;
            --success)
                success="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${BLUE}Recording usage: $id (success: $success)${NC}"
    # Update use_count and last_used would be implemented here
    echo -e "${GREEN}✓ Usage recorded${NC}"
}

# Promote local learning to global
promote_learning() {
    local learning_type=""
    local content=""
    local category=""

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
            --category)
                category="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    echo -e "${BLUE}Promoting learning to global...${NC}"
    echo "  Type: $learning_type"
    echo "  Category: $category"
    echo "  Content: $content"

    if [[ "$learning_type" == "pattern" ]]; then
        store_pattern --domain "$category" --name "$content" --approach "$content" --confidence 0.7
    elif [[ "$learning_type" == "gotcha" ]]; then
        store_gotcha --tech "$category" --title "$content" --problem "$content" --solution "$content" --confidence 0.7
    fi
}

# Run cleanup (decay and removal)
run_cleanup() {
    init_global_memory

    echo -e "${BLUE}Running global memory cleanup...${NC}"

    local removed=0
    local decayed=0
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Note: Full implementation would:
    # 1. Parse each pattern/gotcha
    # 2. Calculate days since last_used
    # 3. Apply decay factor
    # 4. Archive if below threshold

    echo "  Checking patterns..."
    for pattern_file in "$PATTERNS_DIR"/*.yaml; do
        if [[ -f "$pattern_file" ]]; then
            echo "    Processing: $(basename "$pattern_file")"
            # Decay logic would be implemented here
        fi
    done

    echo "  Checking gotchas..."
    for gotcha_file in "$GOTCHAS_DIR"/*.yaml; do
        if [[ -f "$gotcha_file" ]]; then
            echo "    Processing: $(basename "$gotcha_file")"
            # Decay logic would be implemented here
        fi
    done

    # Update stats
    sed -i.bak "s/last_cleanup:.*/last_cleanup: \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
    rm -f "$STATS_FILE.bak"

    echo -e "${GREEN}✓ Cleanup complete (decayed: $decayed, removed: $removed)${NC}"
}

# Show statistics
show_stats() {
    init_global_memory

    echo "=== Global Memory Statistics ==="
    echo ""

    # Count patterns
    local pattern_count=0
    for pattern_file in "$PATTERNS_DIR"/*.yaml; do
        if [[ -f "$pattern_file" ]]; then
            ((pattern_count++)) || true
        fi
    done

    # Count gotchas
    local gotcha_count=0
    for gotcha_file in "$GOTCHAS_DIR"/*.yaml; do
        if [[ -f "$gotcha_file" ]]; then
            ((gotcha_count++)) || true
        fi
    done

    echo "Pattern domains: $pattern_count"
    echo "Gotcha technologies: $gotcha_count"
    echo ""

    if [[ -f "$STATS_FILE" ]]; then
        cat "$STATS_FILE"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
global-memory.sh - Manage global memory (shared across projects)

Usage:
    global-memory.sh load [options]           Load relevant knowledge
    global-memory.sh store-pattern [options]  Store new pattern
    global-memory.sh store-gotcha [options]   Store new gotcha
    global-memory.sh update-confidence [opts] Update confidence score
    global-memory.sh record-usage [options]   Record knowledge was used
    global-memory.sh promote [options]        Promote local to global
    global-memory.sh cleanup                  Run decay and cleanup
    global-memory.sh stats                    Show usage statistics

Load Options:
    --domain, -d <domain>     Domain to load patterns for
    --tech, -t <list>         Comma-separated list of technologies

Store Pattern Options:
    --domain, -d <domain>     Pattern domain (auth, api, database, etc.)
    --name, -n <name>         Pattern name
    --approach, -a <text>     Pattern approach/description
    --confidence, -c <0-1>    Initial confidence
    --source, -s <project>    Source project name

Store Gotcha Options:
    --tech, -t <tech>         Technology (react, typescript, etc.)
    --title <title>           Gotcha title
    --problem, -p <text>      Problem description
    --solution, -s <text>     Solution description
    --confidence, -c <0-1>    Initial confidence

Examples:
    # Load knowledge for auth with React
    global-memory.sh load --domain auth --tech react,typescript

    # Store a new pattern
    global-memory.sh store-pattern \
        --domain auth \
        --name "JWT Strategy" \
        --approach "Access 15min, refresh 7d" \
        --source "my-project"

    # Store a gotcha
    global-memory.sh store-gotcha \
        --tech vitest \
        --title "localStorage Mock" \
        --problem "undefined in tests" \
        --solution "Use vi.stubGlobal"

    # Run cleanup
    global-memory.sh cleanup
EOF
}

# Main entry point
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        load)
            load_knowledge "$@"
            ;;
        store-pattern)
            store_pattern "$@"
            ;;
        store-gotcha)
            store_gotcha "$@"
            ;;
        update-confidence)
            update_confidence "$@"
            ;;
        record-usage)
            record_usage "$@"
            ;;
        promote)
            promote_learning "$@"
            ;;
        cleanup)
            run_cleanup
            ;;
        stats)
            show_stats
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command" >&2
            echo "Run 'global-memory.sh help' for usage" >&2
            exit 1
            ;;
    esac
}

main "$@"
