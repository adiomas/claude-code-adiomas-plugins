#!/usr/bin/env bash
#
# session-end-learning.sh - Extract learnings when session ends successfully
#
# Part of autonomous-dev v4.0 AGI-like interface
# Called by Stop hook to capture learnings from successful sessions
#

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_DIR="${PWD}/.claude/auto-execution"
MEMORY_DIR="${PWD}/.claude/memory"
LOCAL_MEMORY="${MEMORY_DIR}/local"
GLOBAL_MEMORY="${HOME}/.claude/global-memory"

# Check if we're in an autonomous execution
is_autonomous_session() {
    [[ -f "${STATE_DIR}/state.yaml" ]] && return 0
    return 1
}

# Check if session was successful
was_session_successful() {
    local state_file="${STATE_DIR}/state.yaml"

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    local status
    status=$(grep "^status:" "$state_file" 2>/dev/null | awk '{print $2}' || echo "")

    # Consider successful if completed or in_progress (partial success)
    case "$status" in
        completed|in_progress|ready_for_execution)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Extract learnings from successful execution
extract_learnings() {
    local session_file="$1"

    # Create learnings directory
    mkdir -p "${LOCAL_MEMORY}/learnings"

    local today
    today=$(date +%Y-%m-%d)
    local learning_file="${LOCAL_MEMORY}/learnings/${today}.yaml"

    # Extract patterns from git commits
    local recent_commits
    recent_commits=$(git log --oneline -10 2>/dev/null || echo "")

    # Extract file patterns
    local modified_files
    modified_files=$(git diff --name-only HEAD~5 HEAD 2>/dev/null || echo "")

    # Build learning entry
    cat >> "$learning_file" << EOF

- session_end: "$(date -Iseconds)"
  files_modified:
$(echo "$modified_files" | while read -r f; do echo "    - $f"; done)
  commits:
$(echo "$recent_commits" | while read -r c; do echo "    - $c"; done)
  project: "$(basename "$PWD")"

EOF

    echo "Learning extracted to $learning_file"
}

# Store session outcome for pattern learning
store_session_outcome() {
    local outcome="$1"
    local sessions_file="${LOCAL_MEMORY}/sessions.yaml"

    mkdir -p "$LOCAL_MEMORY"

    # Append session info
    cat >> "$sessions_file" << EOF
- date: "$(date -Iseconds)"
  project: "$(basename "$PWD")"
  outcome: "$outcome"
  duration_estimate: "session"
EOF
}

# Promote patterns to global if high confidence
maybe_promote_patterns() {
    # Check if we have the promote script
    local promote_script="${PLUGIN_ROOT}/scripts/extract-learnings.sh"

    if [[ -x "$promote_script" ]]; then
        "$promote_script" --session 2>/dev/null || true
    fi
}

# Cleanup old learnings (keep last 90 days)
cleanup_old_learnings() {
    local learnings_dir="${LOCAL_MEMORY}/learnings"

    if [[ -d "$learnings_dir" ]]; then
        # Find and delete files older than 90 days
        find "$learnings_dir" -name "*.yaml" -mtime +90 -delete 2>/dev/null || true
    fi
}

# Main
main() {
    # Skip if not in autonomous session
    if ! is_autonomous_session; then
        exit 0
    fi

    # Determine outcome
    if was_session_successful; then
        store_session_outcome "success"
        extract_learnings ""
        maybe_promote_patterns
    else
        store_session_outcome "incomplete"
    fi

    # Periodic cleanup
    cleanup_old_learnings

    exit 0
}

main "$@"
