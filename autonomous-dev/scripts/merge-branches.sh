#!/bin/bash
set -euo pipefail

BASE_BRANCH="${1:-}"
shift || true
BRANCHES="${*:-}"

# Ensure we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo "ERROR: Not in a git repository" >&2
    exit 1
fi

# Default base branch
if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi

# Auto-detect auto/ branches if none specified
if [[ -z "$BRANCHES" ]]; then
    BRANCHES=$(git branch | grep 'auto/' | sed 's/^[ *]*//' || true)
fi

if [[ -z "$BRANCHES" ]]; then
    echo "No branches to merge"
    exit 0
fi

echo "Merging branches into $BASE_BRANCH:"
echo "$BRANCHES" | tr ' ' '\n' | sed 's/^/  - /'
echo ""

# Checkout base branch
git checkout "$BASE_BRANCH"

FAILED=()
MERGED=()

for branch in $BRANCHES; do
    echo "Merging $branch..."
    if git merge --no-ff "$branch" -m "feat: Merge $branch"; then
        MERGED+=("$branch")
        # Delete merged branch
        git branch -d "$branch" 2>/dev/null || true
        echo "  ✓ Merged successfully"
    else
        echo "  ⚠ Conflict detected, attempting auto-resolution..."

        # Get conflicted files
        CONFLICTED=$(git diff --name-only --diff-filter=U 2>/dev/null || true)

        if [[ -z "$CONFLICTED" ]]; then
            # No actual conflicts, maybe already resolved
            git add -A
            git commit --no-edit 2>/dev/null || true
            MERGED+=("$branch")
            echo "  ✓ Resolved automatically"
        else
            # Real conflicts - abort and add to failed
            git merge --abort 2>/dev/null || true
            FAILED+=("$branch")
            echo "  ✗ Conflicts in: $CONFLICTED"
        fi
    fi
    echo ""
done

echo "=== MERGE SUMMARY ==="
if [[ ${#MERGED[@]} -gt 0 ]]; then
    echo "Merged: ${MERGED[*]}"
else
    echo "Merged: none"
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed: ${FAILED[*]}"
    echo ""
    echo "To resolve conflicts manually:"
    for branch in "${FAILED[@]}"; do
        echo "  git merge $branch"
    done
    exit 1
else
    echo "Failed: none"
fi
