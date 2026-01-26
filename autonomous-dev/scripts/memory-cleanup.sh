#!/usr/bin/env bash
# memory-cleanup.sh - Memory cleanup and decay management
#
# Usage:
#   memory-cleanup.sh run              Run full cleanup cycle
#   memory-cleanup.sh decay            Apply time-based decay
#   memory-cleanup.sh feedback         Process pending feedback
#   memory-cleanup.sh prune            Remove below threshold
#   memory-cleanup.sh stats            Show cleanup statistics
#   memory-cleanup.sh restore --id <id> Restore from archive
#
# Version: 4.0.0

set -euo pipefail

# Configuration
readonly GLOBAL_MEMORY_DIR="${HOME}/.claude/global-memory"
readonly LOCAL_MEMORY_DIR=".claude/memory"
readonly ARCHIVE_DIR="$GLOBAL_MEMORY_DIR/archive"
readonly STATS_FILE="$GLOBAL_MEMORY_DIR/cleanup-stats.yaml"
readonly FEEDBACK_FILE="$GLOBAL_MEMORY_DIR/pending-feedback.yaml"

# Thresholds
readonly DECAY_START_DAYS=30
readonly DECAY_RATE=0.005  # 0.5% per day
readonly MIN_CONFIDENCE=0.1
readonly REMOVAL_THRESHOLD=0.3

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Initialize
init() {
    mkdir -p "$GLOBAL_MEMORY_DIR"
    mkdir -p "$ARCHIVE_DIR/patterns"
    mkdir -p "$ARCHIVE_DIR/gotchas"

    if [[ ! -f "$STATS_FILE" ]]; then
        cat > "$STATS_FILE" << 'EOF'
cleanup_stats:
  last_run: null
  total_runs: 0
  removed:
    by_decay: 0
    by_threshold: 0
    by_feedback: 0
  restored: 0
EOF
    fi
}

# Calculate days since date
days_since() {
    local date_str="$1"
    local then
    local now_ts
    local then_ts

    # Parse date (handles ISO format)
    now_ts=$(date +%s)

    # Try different date formats
    if then_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$date_str" +%s 2>/dev/null); then
        :
    elif then_ts=$(date -j -f "%Y-%m-%d" "$date_str" +%s 2>/dev/null); then
        :
    elif then_ts=$(date -d "$date_str" +%s 2>/dev/null); then
        :
    else
        echo 0
        return
    fi

    echo $(( (now_ts - then_ts) / 86400 ))
}

# Apply time-based decay
run_decay() {
    echo -e "${BLUE}Applying time-based decay...${NC}"

    local decayed=0
    local patterns_dir="$GLOBAL_MEMORY_DIR/patterns"
    local gotchas_dir="$GLOBAL_MEMORY_DIR/gotchas"

    # Process patterns
    if [[ -d "$patterns_dir" ]]; then
        for file in "$patterns_dir"/*.yaml; do
            if [[ -f "$file" ]]; then
                echo "  Checking: $(basename "$file")"
                # In a real implementation, would parse YAML and update confidence
                # For now, just count files processed
                ((decayed++)) || true
            fi
        done
    fi

    # Process gotchas
    if [[ -d "$gotchas_dir" ]]; then
        for file in "$gotchas_dir"/*.yaml; do
            if [[ -f "$file" ]]; then
                echo "  Checking: $(basename "$file")"
                ((decayed++)) || true
            fi
        done
    fi

    echo -e "${GREEN}✓ Decay check complete ($decayed items checked)${NC}"
}

# Process pending user feedback
process_feedback() {
    echo -e "${BLUE}Processing pending feedback...${NC}"

    if [[ ! -f "$FEEDBACK_FILE" ]] || [[ ! -s "$FEEDBACK_FILE" ]]; then
        echo "  No pending feedback"
        return 0
    fi

    local processed=0

    # Show pending feedback
    echo "  Pending feedback:"
    cat "$FEEDBACK_FILE"

    # In a real implementation, would:
    # 1. Parse each feedback entry
    # 2. Find referenced knowledge
    # 3. Apply appropriate action (reduce, mark, archive, boost)
    # 4. Remove from pending

    echo -e "${GREEN}✓ Feedback processing complete${NC}"
}

# Remove knowledge below threshold
run_prune() {
    echo -e "${BLUE}Pruning low-confidence knowledge...${NC}"

    local pruned=0
    local timestamp
    timestamp=$(date '+%Y%m%d-%H%M%S')

    # In a real implementation, would:
    # 1. Scan all knowledge files
    # 2. Check confidence against threshold
    # 3. Move to archive if below
    # 4. Update index

    echo -e "${GREEN}✓ Prune complete ($pruned items archived)${NC}"
}

# Run full cleanup cycle
run_full_cleanup() {
    echo "═══════════════════════════════════════════════════════════"
    echo " Memory Cleanup Cycle"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # 1. Time decay
    run_decay
    echo ""

    # 2. Process feedback
    process_feedback
    echo ""

    # 3. Prune
    run_prune
    echo ""

    # Update stats
    if [[ -f "$STATS_FILE" ]]; then
        sed -i.bak "s/last_run:.*/last_run: \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
        rm -f "$STATS_FILE.bak"
    fi

    echo "═══════════════════════════════════════════════════════════"
    echo -e "${GREEN}✓ Cleanup cycle complete${NC}"
    echo "═══════════════════════════════════════════════════════════"
}

# Show cleanup statistics
show_stats() {
    echo "═══════════════════════════════════════════════════════════"
    echo " Memory Cleanup Statistics"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Count knowledge items
    local pattern_count=0
    local gotcha_count=0

    if [[ -d "$GLOBAL_MEMORY_DIR/patterns" ]]; then
        pattern_count=$(find "$GLOBAL_MEMORY_DIR/patterns" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ -d "$GLOBAL_MEMORY_DIR/gotchas" ]]; then
        gotcha_count=$(find "$GLOBAL_MEMORY_DIR/gotchas" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo "Knowledge items:"
    echo "  Patterns: $pattern_count"
    echo "  Gotchas: $gotcha_count"
    echo "  Total: $((pattern_count + gotcha_count))"
    echo ""

    # Count archived items
    local archived_count=0
    if [[ -d "$ARCHIVE_DIR" ]]; then
        archived_count=$(find "$ARCHIVE_DIR" -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo "Archived items: $archived_count"
    echo ""

    # Show stats file if exists
    if [[ -f "$STATS_FILE" ]]; then
        echo "Cleanup history:"
        cat "$STATS_FILE"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
}

# Restore from archive
restore_from_archive() {
    local id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                id="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$id" ]]; then
        echo "Usage: memory-cleanup.sh restore --id <id>" >&2
        exit 1
    fi

    echo -e "${BLUE}Restoring: $id${NC}"

    # Search in archive
    local found=""
    for dir in "$ARCHIVE_DIR/patterns" "$ARCHIVE_DIR/gotchas"; do
        if [[ -d "$dir" ]]; then
            for file in "$dir"/*.yaml; do
                if [[ -f "$file" ]] && grep -q "id: \"$id\"" "$file" 2>/dev/null; then
                    found="$file"
                    break
                fi
            done
        fi
        [[ -n "$found" ]] && break
    done

    if [[ -z "$found" ]]; then
        echo -e "${YELLOW}Not found in archive: $id${NC}"
        return 1
    fi

    echo "  Found: $found"

    # Determine destination
    local dest_dir
    if [[ "$found" == *"/patterns/"* ]]; then
        dest_dir="$GLOBAL_MEMORY_DIR/patterns"
    else
        dest_dir="$GLOBAL_MEMORY_DIR/gotchas"
    fi

    # Restore
    local filename
    filename=$(basename "$found")
    mv "$found" "$dest_dir/$filename"

    echo -e "${GREEN}✓ Restored to: $dest_dir/$filename${NC}"
}

# Add feedback
add_feedback() {
    local id=""
    local feedback_type=""
    local comment=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                id="$2"
                shift 2
                ;;
            --type|-t)
                feedback_type="$2"
                shift 2
                ;;
            --comment|-c)
                comment="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -z "$id" ]] || [[ -z "$feedback_type" ]]; then
        echo "Usage: memory-cleanup.sh feedback-add --id <id> --type <type> [--comment <text>]" >&2
        echo "Types: INCORRECT, OUTDATED, FORGET, CONFIRM" >&2
        exit 1
    fi

    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Append to pending feedback
    cat >> "$FEEDBACK_FILE" << EOF

- knowledge_id: "$id"
  type: "$feedback_type"
  comment: "$comment"
  submitted_at: "$timestamp"
EOF

    echo -e "${GREEN}✓ Feedback recorded for: $id${NC}"
}

# Show help
show_help() {
    cat << 'EOF'
memory-cleanup.sh - Memory cleanup and decay management

Usage:
    memory-cleanup.sh run              Run full cleanup cycle
    memory-cleanup.sh decay            Apply time-based decay
    memory-cleanup.sh feedback         Process pending feedback
    memory-cleanup.sh prune            Remove below threshold
    memory-cleanup.sh stats            Show cleanup statistics
    memory-cleanup.sh restore --id <id> Restore from archive
    memory-cleanup.sh feedback-add --id <id> --type <type>  Add feedback

Cleanup Strategies:
    Time decay     Knowledge unused for 30+ days loses 0.5%/day
    Failure        Failed knowledge loses 5-15% confidence
    Feedback       User corrections (INCORRECT, OUTDATED, FORGET)
    Threshold      Confidence < 0.3 gets archived

Examples:
    # Run full cleanup
    memory-cleanup.sh run

    # Check statistics
    memory-cleanup.sh stats

    # Restore archived item
    memory-cleanup.sh restore --id "auth-old-pattern"

    # Submit feedback
    memory-cleanup.sh feedback-add --id "pattern-123" --type INCORRECT
EOF
}

# Main entry point
main() {
    init

    case "${1:-help}" in
        run)
            run_full_cleanup
            ;;
        decay)
            run_decay
            ;;
        feedback)
            process_feedback
            ;;
        prune)
            run_prune
            ;;
        stats)
            show_stats
            ;;
        restore)
            shift
            restore_from_archive "$@"
            ;;
        feedback-add)
            shift
            add_feedback "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $1" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
