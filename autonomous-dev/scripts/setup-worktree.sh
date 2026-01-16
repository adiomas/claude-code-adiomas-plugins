#!/bin/bash
set -euo pipefail

TASK_ID="${1:-task-$(date +%s)}"
BASE_BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")}"
WORKTREE_BASE="${WORKTREE_BASE:-/tmp/auto-worktrees}"

# Ensure we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo "ERROR: Not in a git repository" >&2
    exit 1
fi

mkdir -p "$WORKTREE_BASE"

WORKTREE_DIR="$WORKTREE_BASE/$TASK_ID"
BRANCH_NAME="auto/$TASK_ID"

# Clean up if exists
if [[ -d "$WORKTREE_DIR" ]]; then
    git worktree remove -f "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
fi

# Delete branch if exists
git branch -D "$BRANCH_NAME" 2>/dev/null || true

# Create new worktree with branch
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "$BASE_BRANCH"

# Copy project profile to worktree
if [[ -f ".claude/project-profile.yaml" ]]; then
    mkdir -p "$WORKTREE_DIR/.claude"
    cp ".claude/project-profile.yaml" "$WORKTREE_DIR/.claude/"
fi

# Output worktree info (pipe-separated for easy parsing)
echo "$WORKTREE_DIR|$BRANCH_NAME"
