#!/bin/bash
# setup-worktree.sh - Create isolated git worktree for parallel task execution
# Part of autonomous-dev v4.0
#
# Usage:
#   ./setup-worktree.sh [task_id] [base_branch]
#
# Output:
#   worktree_path|branch_name (pipe-separated for easy parsing)
#
# Examples:
#   ./setup-worktree.sh task-login-form main
#   ./setup-worktree.sh  # Auto-generates task ID

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
    get_temp_base() {
        local base="${TMPDIR:-/tmp}/auto-worktrees-$(id -u)"
        mkdir -p "$base" 2>/dev/null
        echo "$base"
    }
fi

# Generate unique task ID if not provided (collision-resistant)
TASK_ID="${1:-$(generate_id "task")}"
BASE_BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")}"

# Use safe temp directory (not hardcoded /tmp)
WORKTREE_BASE=$(get_temp_base)

# Ensure we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not in a git repository"
    exit 1
fi

# Create worktree base directory with proper permissions
if [[ ! -d "$WORKTREE_BASE" ]]; then
    mkdir -p "$WORKTREE_BASE"
    chmod 700 "$WORKTREE_BASE" 2>/dev/null || true
fi

WORKTREE_DIR="$WORKTREE_BASE/$TASK_ID"
BRANCH_NAME="auto/$TASK_ID"

log_info "Setting up worktree" "task_id=$TASK_ID" "base_branch=$BASE_BRANCH"

# Clean up existing worktree if it exists
if [[ -d "$WORKTREE_DIR" ]]; then
    log_warn "Removing existing worktree: $WORKTREE_DIR"

    # Try git worktree remove first, then fallback to rm
    if ! git worktree remove -f "$WORKTREE_DIR" 2>/dev/null; then
        log_warn "git worktree remove failed, using rm -rf"
        rm -rf "$WORKTREE_DIR"
    fi
fi

# Delete branch if exists (from previous failed run)
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    log_warn "Deleting existing branch: $BRANCH_NAME"
    git branch -D "$BRANCH_NAME" 2>/dev/null || true
fi

# Verify base branch exists
if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH" 2>/dev/null; then
    # Try remote
    if git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH" 2>/dev/null; then
        log_info "Base branch is remote, fetching"
        git fetch origin "$BASE_BRANCH" 2>/dev/null || true
    else
        log_error "Base branch does not exist: $BASE_BRANCH"
        exit 1
    fi
fi

# Create new worktree with branch
log_info "Creating worktree at $WORKTREE_DIR"
if ! git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "$BASE_BRANCH" 2>&1; then
    log_error "Failed to create worktree"
    exit 1
fi

# Copy project configuration to worktree
if [[ -f ".claude/project-profile.yaml" ]]; then
    mkdir -p "$WORKTREE_DIR/.claude"
    cp ".claude/project-profile.yaml" "$WORKTREE_DIR/.claude/"
    log_info "Copied project profile to worktree"
fi

# Copy other essential .claude files if they exist
for file in .claude/auto-context.yaml .claude/auto-state-machine.yaml; do
    if [[ -f "$file" ]]; then
        cp "$file" "$WORKTREE_DIR/.claude/" 2>/dev/null || true
    fi
done

# Verify worktree was created successfully
if [[ ! -d "$WORKTREE_DIR/.git" ]] && [[ ! -f "$WORKTREE_DIR/.git" ]]; then
    log_error "Worktree creation verification failed"
    exit 1
fi

log_info "Worktree ready" "path=$WORKTREE_DIR" "branch=$BRANCH_NAME"

# Output worktree info (pipe-separated for easy parsing by calling scripts)
echo "$WORKTREE_DIR|$BRANCH_NAME"
