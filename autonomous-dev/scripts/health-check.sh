#!/bin/bash
# health-check.sh - Diagnose autonomous-dev system health
# Part of autonomous-dev v4.0
#
# Usage:
#   ./health-check.sh [--json]
#
# Checks:
#   - State files integrity
#   - Git status
#   - Worktree status
#   - Memory usage
#   - Dependencies (yq, jq, flock)

set -euo pipefail

# Load helper libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/init.sh" ]]; then
    source "$SCRIPT_DIR/lib/init.sh"
fi

JSON_OUTPUT="${1:-}"
CLAUDE_DIR=".claude"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Results storage
declare -A CHECKS

# Helper to record check result
record_check() {
    local name="$1"
    local status="$2"  # ok, warn, error
    local detail="${3:-}"
    CHECKS["$name"]="$status:$detail"
}

# Check dependencies
check_dependencies() {
    local missing=()
    local optional_missing=()

    # Required
    for cmd in yq git bash; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    # Optional but recommended
    for cmd in jq flock realpath; do
        if ! command -v "$cmd" &>/dev/null; then
            optional_missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        record_check "dependencies" "error" "missing: ${missing[*]}"
        return 1
    elif [[ ${#optional_missing[@]} -gt 0 ]]; then
        record_check "dependencies" "warn" "optional missing: ${optional_missing[*]}"
        return 0
    else
        record_check "dependencies" "ok" "all present"
        return 0
    fi
}

# Check state files
check_state_files() {
    local issues=()

    # Check .claude directory exists
    if [[ ! -d "$CLAUDE_DIR" ]]; then
        record_check "state_files" "warn" ".claude directory missing"
        return 0
    fi

    # Check key files
    local files=(
        "project-profile.yaml"
        "auto-state-machine.yaml"
    )

    for file in "${files[@]}"; do
        local path="$CLAUDE_DIR/$file"
        if [[ -f "$path" ]]; then
            # Validate YAML syntax
            if ! yq '.' "$path" &>/dev/null; then
                issues+=("$file:corrupted")
            fi
        fi
    done

    # Check for lock files that might be stale
    local stale_locks
    stale_locks=$(find "$CLAUDE_DIR" -name "*.lock" -mmin +5 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$stale_locks" -gt 0 ]]; then
        issues+=("$stale_locks stale lock files")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        record_check "state_files" "warn" "${issues[*]}"
        return 0
    else
        record_check "state_files" "ok" "valid"
        return 0
    fi
}

# Check git status
check_git() {
    if ! git rev-parse --git-dir &>/dev/null; then
        record_check "git" "warn" "not a git repository"
        return 0
    fi

    local status
    status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    if [[ "$status" -eq 0 ]]; then
        record_check "git" "ok" "clean ($branch)"
    else
        record_check "git" "ok" "$status uncommitted changes ($branch)"
    fi
}

# Check worktrees
check_worktrees() {
    local worktree_base
    if type get_temp_base &>/dev/null; then
        worktree_base=$(get_temp_base)
    else
        worktree_base="${TMPDIR:-/tmp}/auto-worktrees-$(id -u)"
    fi

    if [[ ! -d "$worktree_base" ]]; then
        record_check "worktrees" "ok" "none (base dir not created)"
        return 0
    fi

    local count
    count=$(find "$worktree_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

    # Check for orphaned worktrees
    local orphaned=0
    if [[ "$count" -gt 0 ]]; then
        while IFS= read -r dir; do
            if [[ -n "$dir" ]] && ! git worktree list 2>/dev/null | grep -q "$dir"; then
                ((orphaned++)) || true
            fi
        done < <(find "$worktree_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi

    if [[ "$orphaned" -gt 0 ]]; then
        record_check "worktrees" "warn" "$count active, $orphaned orphaned"
    else
        record_check "worktrees" "ok" "$count active"
    fi
}

# Check memory usage
check_memory() {
    local memory_dir="$CLAUDE_DIR/memory"

    if [[ ! -d "$memory_dir" ]]; then
        record_check "memory" "ok" "not initialized"
        return 0
    fi

    local size
    size=$(du -sh "$memory_dir" 2>/dev/null | cut -f1 || echo "unknown")

    local file_count
    file_count=$(find "$memory_dir" -type f 2>/dev/null | wc -l | tr -d ' ')

    # Warn if memory is getting large (>50MB)
    local size_bytes
    size_bytes=$(du -s "$memory_dir" 2>/dev/null | cut -f1 || echo "0")

    if [[ "$size_bytes" -gt 51200 ]]; then  # 50MB in KB
        record_check "memory" "warn" "$size ($file_count files) - consider cleanup"
    else
        record_check "memory" "ok" "$size ($file_count files)"
    fi
}

# Check current execution state
check_execution_state() {
    local state_file="$CLAUDE_DIR/auto-state-machine.yaml"

    if [[ ! -f "$state_file" ]]; then
        record_check "execution" "ok" "no active execution"
        return 0
    fi

    local phase
    phase=$(yq -r '.phase // "unknown"' "$state_file" 2>/dev/null)

    local iteration
    iteration=$(yq -r '.iteration // 0' "$state_file" 2>/dev/null)

    if [[ "$phase" == "IDLE" || "$phase" == "COMPLETE" ]]; then
        record_check "execution" "ok" "idle"
    else
        record_check "execution" "ok" "active: $phase (iteration $iteration)"
    fi
}

# Check logs
check_logs() {
    local log_file="$CLAUDE_DIR/logs/autonomous-dev.log"

    if [[ ! -f "$log_file" ]]; then
        record_check "logs" "ok" "not initialized"
        return 0
    fi

    local size
    size=$(du -sh "$log_file" 2>/dev/null | cut -f1 || echo "unknown")

    local recent_errors
    recent_errors=$(tail -100 "$log_file" 2>/dev/null | grep -c '"level":"ERROR"' || echo "0")

    if [[ "$recent_errors" -gt 10 ]]; then
        record_check "logs" "warn" "$size ($recent_errors recent errors)"
    else
        record_check "logs" "ok" "$size"
    fi
}

# Run all checks
run_all_checks() {
    check_dependencies
    check_state_files
    check_git
    check_worktrees
    check_memory
    check_execution_state
    check_logs
}

# Output results
output_results() {
    local overall="healthy"

    for key in "${!CHECKS[@]}"; do
        local value="${CHECKS[$key]}"
        local status="${value%%:*}"
        if [[ "$status" == "error" ]]; then
            overall="unhealthy"
            break
        elif [[ "$status" == "warn" ]]; then
            overall="degraded"
        fi
    done

    if [[ "$JSON_OUTPUT" == "--json" ]]; then
        # JSON output
        echo "{"
        echo "  \"status\": \"$overall\","
        echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"checks\": {"

        local first=true
        for key in "${!CHECKS[@]}"; do
            local value="${CHECKS[$key]}"
            local status="${value%%:*}"
            local detail="${value#*:}"

            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi

            printf '    "%s": {"status": "%s", "detail": "%s"}' "$key" "$status" "$detail"
        done

        echo ""
        echo "  }"
        echo "}"
    else
        # Human-readable output
        echo "═══════════════════════════════════════════"
        echo "  autonomous-dev Health Check"
        echo "═══════════════════════════════════════════"
        echo ""

        case "$overall" in
            healthy)
                echo -e "  Status: ${GREEN}● HEALTHY${NC}"
                ;;
            degraded)
                echo -e "  Status: ${YELLOW}● DEGRADED${NC}"
                ;;
            unhealthy)
                echo -e "  Status: ${RED}● UNHEALTHY${NC}"
                ;;
        esac

        echo ""
        echo "  Checks:"

        for key in dependencies state_files git worktrees memory execution logs; do
            if [[ -n "${CHECKS[$key]:-}" ]]; then
                local value="${CHECKS[$key]}"
                local status="${value%%:*}"
                local detail="${value#*:}"

                case "$status" in
                    ok)
                        echo -e "    ${GREEN}✓${NC} $key: $detail"
                        ;;
                    warn)
                        echo -e "    ${YELLOW}!${NC} $key: $detail"
                        ;;
                    error)
                        echo -e "    ${RED}✗${NC} $key: $detail"
                        ;;
                esac
            fi
        done

        echo ""
        echo "═══════════════════════════════════════════"
    fi

    # Exit code based on status
    case "$overall" in
        healthy) return 0 ;;
        degraded) return 0 ;;
        unhealthy) return 1 ;;
    esac
}

# Main
run_all_checks
output_results
