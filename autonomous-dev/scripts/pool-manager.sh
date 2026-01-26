#!/usr/bin/env bash
# pool-manager.sh - Dynamic Agent Pool Management
# Part of autonomous-dev v4.2
#
# Manages a pool of git worktrees for parallel task execution.
# Supports dynamic allocation, status tracking, and automatic cleanup.
#
# Usage:
#   ./pool-manager.sh init [pool_size]     - Initialize pool (default: 8)
#   ./pool-manager.sh acquire <task_id>    - Acquire worktree for task
#   ./pool-manager.sh release <wt_id>      - Release worktree back to pool
#   ./pool-manager.sh status               - Show pool status
#   ./pool-manager.sh cleanup              - Clean up all worktrees
#   ./pool-manager.sh reset                - Full reset of pool
#
# Environment:
#   POOL_SIZE       - Max pool size (default: 8)
#   POOL_DIR        - Pool directory (default: .claude/worktree-pool)
#   POOL_STATE_FILE - State file (default: .claude/pool-state.json)

set -euo pipefail

# Load helper libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/init.sh" ]]; then
    source "$SCRIPT_DIR/lib/init.sh"
else
    # Fallback functions
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    generate_id() { echo "${1:-id}-$(date +%s)-$$-$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 4)"; }
fi

# Configuration
POOL_SIZE="${POOL_SIZE:-8}"
POOL_DIR="${POOL_DIR:-.claude/worktree-pool}"
POOL_STATE_FILE="${POOL_STATE_FILE:-.claude/pool-state.json}"

# Ensure jq is available (or use basic JSON handling)
if ! command -v jq &>/dev/null; then
    log_warn "jq not found, using basic JSON handling"
    HAS_JQ=false
else
    HAS_JQ=true
fi

# ========================================
# STATE MANAGEMENT
# ========================================

init_state() {
    local size="${1:-$POOL_SIZE}"

    mkdir -p "$(dirname "$POOL_STATE_FILE")"
    mkdir -p "$POOL_DIR"

    # Initialize state JSON
    local worktrees="[]"
    for i in $(seq 1 "$size"); do
        local wt_id="wt-$i"
        local wt_entry="{\"id\":\"$wt_id\",\"status\":\"idle\",\"task_id\":null,\"path\":\"$POOL_DIR/$wt_id\",\"branch\":null,\"acquired_at\":null}"
        if [[ "$worktrees" == "[]" ]]; then
            worktrees="[$wt_entry"
        else
            worktrees="$worktrees,$wt_entry"
        fi
    done
    worktrees="$worktrees]"

    local state="{\"version\":\"1.0\",\"pool_size\":$size,\"created_at\":\"$(date -Iseconds)\",\"worktrees\":$worktrees}"

    echo "$state" > "$POOL_STATE_FILE"
    log_info "Pool initialized with $size worktrees"
}

load_state() {
    if [[ ! -f "$POOL_STATE_FILE" ]]; then
        log_error "Pool not initialized. Run: ./pool-manager.sh init"
        exit 1
    fi
    cat "$POOL_STATE_FILE"
}

save_state() {
    local state="$1"
    echo "$state" > "$POOL_STATE_FILE"
}

# ========================================
# POOL OPERATIONS
# ========================================

pool_init() {
    local size="${1:-$POOL_SIZE}"

    # Clean up any existing worktrees
    if [[ -d "$POOL_DIR" ]]; then
        log_info "Cleaning up existing pool..."
        for wt_dir in "$POOL_DIR"/wt-*; do
            if [[ -d "$wt_dir" ]]; then
                git worktree remove -f "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"
            fi
        done
    fi

    init_state "$size"

    log_info "Pool ready"
    echo "Pool initialized: $size slots available"
}

pool_acquire() {
    local task_id="$1"
    local base_branch="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")}"

    if [[ -z "$task_id" ]]; then
        log_error "Task ID required"
        exit 1
    fi

    local state
    state=$(load_state)

    # Find first idle worktree
    local wt_id=""
    local wt_index=-1

    if [[ "$HAS_JQ" == "true" ]]; then
        wt_index=$(echo "$state" | jq -r '.worktrees | to_entries[] | select(.value.status == "idle") | .key' | head -1)
        if [[ -n "$wt_index" && "$wt_index" != "null" ]]; then
            wt_id=$(echo "$state" | jq -r ".worktrees[$wt_index].id")
        fi
    else
        # Basic parsing without jq
        for i in $(seq 1 "$POOL_SIZE"); do
            local check_id="wt-$i"
            if grep -q "\"id\":\"$check_id\",\"status\":\"idle\"" "$POOL_STATE_FILE"; then
                wt_id="$check_id"
                wt_index=$((i - 1))
                break
            fi
        done
    fi

    if [[ -z "$wt_id" || "$wt_id" == "null" ]]; then
        log_error "No available worktrees in pool"
        echo "POOL_EXHAUSTED"
        exit 1
    fi

    local wt_path="$POOL_DIR/$wt_id"
    local branch_name="auto/$task_id"

    # Create the worktree
    log_info "Acquiring $wt_id for task $task_id"

    # Clean up if exists
    if [[ -d "$wt_path" ]]; then
        git worktree remove -f "$wt_path" 2>/dev/null || rm -rf "$wt_path"
    fi

    # Delete branch if exists
    if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
        git branch -D "$branch_name" 2>/dev/null || true
    fi

    # Create worktree
    if ! git worktree add "$wt_path" -b "$branch_name" "$base_branch" 2>&1; then
        log_error "Failed to create worktree"
        exit 1
    fi

    # Copy project config
    if [[ -f ".claude/project-profile.yaml" ]]; then
        mkdir -p "$wt_path/.claude"
        cp ".claude/project-profile.yaml" "$wt_path/.claude/"
    fi

    # Update state
    local timestamp
    timestamp=$(date -Iseconds)

    if [[ "$HAS_JQ" == "true" ]]; then
        state=$(echo "$state" | jq ".worktrees[$wt_index].status = \"busy\" | .worktrees[$wt_index].task_id = \"$task_id\" | .worktrees[$wt_index].branch = \"$branch_name\" | .worktrees[$wt_index].acquired_at = \"$timestamp\"")
    else
        # Basic replacement without jq
        sed -i.bak "s/\"id\":\"$wt_id\",\"status\":\"idle\"/\"id\":\"$wt_id\",\"status\":\"busy\",\"task_id\":\"$task_id\"/" "$POOL_STATE_FILE"
    fi

    save_state "$state"

    log_info "Worktree acquired" "wt_id=$wt_id" "path=$wt_path" "branch=$branch_name"

    # Output for parsing
    echo "$wt_id|$wt_path|$branch_name"
}

pool_release() {
    local wt_id="$1"

    if [[ -z "$wt_id" ]]; then
        log_error "Worktree ID required"
        exit 1
    fi

    local state
    state=$(load_state)

    local wt_path="$POOL_DIR/$wt_id"

    # Get current branch name before release
    local branch_name=""
    if [[ "$HAS_JQ" == "true" ]]; then
        branch_name=$(echo "$state" | jq -r ".worktrees[] | select(.id == \"$wt_id\") | .branch")
    fi

    # Remove worktree
    if [[ -d "$wt_path" ]]; then
        log_info "Removing worktree $wt_id"
        git worktree remove -f "$wt_path" 2>/dev/null || rm -rf "$wt_path"
    fi

    # Delete branch
    if [[ -n "$branch_name" && "$branch_name" != "null" ]]; then
        git branch -D "$branch_name" 2>/dev/null || true
    fi

    # Update state
    if [[ "$HAS_JQ" == "true" ]]; then
        state=$(echo "$state" | jq "(.worktrees[] | select(.id == \"$wt_id\")) |= {id: .id, status: \"idle\", task_id: null, path: .path, branch: null, acquired_at: null}")
    else
        sed -i.bak "s/\"id\":\"$wt_id\",\"status\":\"busy\"/\"id\":\"$wt_id\",\"status\":\"idle\"/" "$POOL_STATE_FILE"
    fi

    save_state "$state"

    log_info "Worktree released: $wt_id"
    echo "RELEASED:$wt_id"
}

pool_status() {
    local state
    state=$(load_state)

    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    AGENT POOL STATUS                           ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║                                                                 ║"

    local total=0
    local busy=0
    local idle=0
    local error=0

    if [[ "$HAS_JQ" == "true" ]]; then
        total=$(echo "$state" | jq '.pool_size')
        busy=$(echo "$state" | jq '[.worktrees[] | select(.status == "busy")] | length')
        idle=$(echo "$state" | jq '[.worktrees[] | select(.status == "idle")] | length')
        error=$(echo "$state" | jq '[.worktrees[] | select(.status == "error")] | length')

        echo "║  Pool Size: $total | Busy: $busy | Idle: $idle | Error: $error"
        echo "║                                                                 ║"
        echo "║  ┌───────┬──────────┬─────────────────────────────────────┐   ║"
        echo "║  │  ID   │  Status  │  Task ID                            │   ║"
        echo "║  ├───────┼──────────┼─────────────────────────────────────┤   ║"

        echo "$state" | jq -r '.worktrees[] | "║  │ \(.id) │ \(.status | if . == "idle" then "  idle  " elif . == "busy" then "  BUSY  " else " ERROR  " end) │ \(.task_id // "-")"' | while read -r line; do
            printf "%-66s │   ║\n" "$line"
        done

        echo "║  └───────┴──────────┴─────────────────────────────────────┘   ║"
    else
        echo "║  (Install jq for detailed status)                             ║"
        echo "║  State file: $POOL_STATE_FILE                                 ║"
    fi

    echo "║                                                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
}

pool_cleanup() {
    log_info "Cleaning up all worktrees..."

    # Remove all worktrees in pool
    for wt_dir in "$POOL_DIR"/wt-*; do
        if [[ -d "$wt_dir" ]]; then
            local wt_id
            wt_id=$(basename "$wt_dir")
            log_info "Removing $wt_id"
            git worktree remove -f "$wt_dir" 2>/dev/null || rm -rf "$wt_dir"
        fi
    done

    # Delete auto/* branches
    git for-each-ref --format='%(refname:short)' refs/heads/auto/ 2>/dev/null | while read -r branch; do
        log_info "Deleting branch $branch"
        git branch -D "$branch" 2>/dev/null || true
    done

    # Prune worktree references
    git worktree prune 2>/dev/null || true

    log_info "Cleanup complete"
}

pool_reset() {
    log_info "Full pool reset..."
    pool_cleanup
    pool_init "${1:-$POOL_SIZE}"
}

# ========================================
# ADVANCED OPERATIONS
# ========================================

pool_merge_all() {
    local target_branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"

    log_info "Merging all busy worktrees to $target_branch"

    local state
    state=$(load_state)

    if [[ "$HAS_JQ" != "true" ]]; then
        log_error "jq required for merge operation"
        exit 1
    fi

    # Get all busy worktrees
    local busy_wts
    busy_wts=$(echo "$state" | jq -r '.worktrees[] | select(.status == "busy") | "\(.id)|\(.branch)"')

    local merge_order=()
    local failed=()

    while IFS='|' read -r wt_id branch; do
        if [[ -n "$branch" && "$branch" != "null" ]]; then
            log_info "Merging $branch..."

            if git merge --no-ff "$branch" -m "Merge $branch (Agent Pool)"; then
                merge_order+=("$wt_id:$branch:success")
                log_info "✓ Merged $branch"
            else
                failed+=("$wt_id:$branch")
                log_error "✗ Merge conflict in $branch"
                git merge --abort 2>/dev/null || true
            fi
        fi
    done <<< "$busy_wts"

    # Report results
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    MERGE RESULTS                               ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"

    if [[ ${#failed[@]} -eq 0 ]]; then
        echo "║  Status: ✅ ALL MERGED SUCCESSFULLY                           ║"
    else
        echo "║  Status: ⚠️  SOME MERGES FAILED                               ║"
        echo "║                                                                 ║"
        echo "║  Failed branches:                                              ║"
        for f in "${failed[@]}"; do
            echo "║    - $f"
        done
    fi

    echo "╚═══════════════════════════════════════════════════════════════╝"
}

pool_health_check() {
    log_info "Running pool health check..."

    local issues=0

    # Check state file
    if [[ ! -f "$POOL_STATE_FILE" ]]; then
        log_error "State file missing"
        ((issues++))
    fi

    # Check worktree consistency
    local state
    state=$(load_state 2>/dev/null) || state=""

    if [[ "$HAS_JQ" == "true" && -n "$state" ]]; then
        echo "$state" | jq -r '.worktrees[] | select(.status == "busy") | "\(.id)|\(.path)"' | while IFS='|' read -r wt_id wt_path; do
            if [[ ! -d "$wt_path" ]]; then
                log_warn "Worktree $wt_id marked busy but path doesn't exist: $wt_path"
                ((issues++))
            fi
        done
    fi

    # Check git worktree list consistency
    local git_wts
    git_wts=$(git worktree list 2>/dev/null | grep -c "$POOL_DIR" || echo "0")

    if [[ $issues -eq 0 ]]; then
        echo "✅ Pool health: OK"
        echo "   Git worktrees in pool: $git_wts"
    else
        echo "⚠️  Pool health: $issues issues found"
        echo "   Run './pool-manager.sh reset' to fix"
    fi
}

# ========================================
# MAIN
# ========================================

main() {
    local command="${1:-status}"
    shift || true

    case "$command" in
        init)
            pool_init "$@"
            ;;
        acquire)
            pool_acquire "$@"
            ;;
        release)
            pool_release "$@"
            ;;
        status)
            pool_status
            ;;
        cleanup)
            pool_cleanup
            ;;
        reset)
            pool_reset "$@"
            ;;
        merge)
            pool_merge_all "$@"
            ;;
        health)
            pool_health_check
            ;;
        *)
            echo "Usage: $0 {init|acquire|release|status|cleanup|reset|merge|health}"
            echo ""
            echo "Commands:"
            echo "  init [size]       Initialize pool (default: 8)"
            echo "  acquire <task>    Acquire worktree for task"
            echo "  release <wt_id>   Release worktree back to pool"
            echo "  status            Show pool status"
            echo "  cleanup           Remove all worktrees"
            echo "  reset [size]      Full pool reset"
            echo "  merge [branch]    Merge all busy worktrees"
            echo "  health            Check pool health"
            exit 1
            ;;
    esac
}

main "$@"
