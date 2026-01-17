#!/bin/bash
# Continuous rebase hook - keeps worktree branches fresh with main
# Runs periodically during execution to minimize merge conflicts

set -euo pipefail

# Configuration
REBASE_INTERVAL=${REBASE_INTERVAL:-300}  # 5 minutes default
WORKTREE_MARKER=".claude/auto-worktree.marker"
LAST_REBASE_FILE=".claude/last-rebase-time"
STATE_FILE=".claude/auto-progress.yaml"

# Only run in worktree (not main workspace)
if [[ ! -f "$WORKTREE_MARKER" ]]; then
    exit 0
fi

# Only run in autonomous mode
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

# Check time since last rebase
NOW=$(date +%s)
LAST_REBASE=0
if [[ -f "$LAST_REBASE_FILE" ]]; then
    LAST_REBASE=$(cat "$LAST_REBASE_FILE" 2>/dev/null || echo 0)
fi

# Skip if too soon
if (( NOW - LAST_REBASE < REBASE_INTERVAL )); then
    exit 0
fi

# Get the main branch name
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Check if we have uncommitted changes
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    # Stash changes
    STASH_MSG="auto-rebase-stash-$(date +%s)"
    git stash push -m "$STASH_MSG" --quiet 2>/dev/null || exit 0
    STASHED=true
else
    STASHED=false
fi

# Attempt rebase
REBASE_OUTPUT=""
REBASE_SUCCESS=false

if git fetch origin "$MAIN_BRANCH" --quiet 2>/dev/null; then
    if git rebase "origin/$MAIN_BRANCH" --quiet 2>/dev/null; then
        REBASE_SUCCESS=true
        REBASE_OUTPUT="✅ Rebased on latest $MAIN_BRANCH"
    else
        # Rebase failed - abort and continue
        git rebase --abort 2>/dev/null || true
        REBASE_OUTPUT="⚠️ Rebase conflict detected. Deferred to integration phase."
    fi
else
    REBASE_OUTPUT="⚠️ Could not fetch origin/$MAIN_BRANCH"
fi

# Restore stashed changes
if [[ "$STASHED" == "true" ]]; then
    git stash pop --quiet 2>/dev/null || {
        # Stash pop failed - this is a conflict scenario
        REBASE_OUTPUT="⚠️ Stash conflict after rebase. Manual resolution may be needed."
    }
fi

# Update last rebase time
echo "$NOW" > "$LAST_REBASE_FILE"

# Check how far behind main we are
BEHIND_COUNT=$(git rev-list HEAD.."origin/$MAIN_BRANCH" --count 2>/dev/null || echo "0")

# Output status (only if something notable happened)
if [[ "$REBASE_SUCCESS" == "true" ]] || [[ "$BEHIND_COUNT" -gt 10 ]]; then
    if [[ "$BEHIND_COUNT" -gt 10 ]]; then
        echo "$REBASE_OUTPUT"
        echo "ℹ️ Main branch is $BEHIND_COUNT commits ahead. Consider completing task soon."
    fi
fi

exit 0
