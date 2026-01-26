#!/usr/bin/env bash
# id-generator.sh - Collision-resistant unique ID generation
# Part of autonomous-dev v4.0 improvements
#
# Usage:
#   source scripts/lib/id-generator.sh
#   task_id=$(generate_id "task")
#   session_id=$(generate_session_id)

set -euo pipefail

# Generate a unique ID with timestamp, PID, and random component
# Usage: generate_id [prefix]
# Output: prefix-timestamp-pid-random (e.g., task-1706270400-12345-a1b2c3)
generate_id() {
    local prefix="${1:-id}"
    local timestamp
    local pid=$$
    local random

    # Get timestamp (seconds since epoch)
    timestamp=$(date +%s)

    # Generate random string (6 alphanumeric chars)
    if [[ -r /dev/urandom ]]; then
        random=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
    else
        # Fallback using $RANDOM
        random=$(printf '%06x' $((RANDOM * RANDOM)))
    fi

    echo "${prefix}-${timestamp}-${pid}-${random}"
}

# Generate a short unique ID (for display purposes)
# Usage: generate_short_id [prefix]
# Output: prefix-random (e.g., task-a1b2c3)
generate_short_id() {
    local prefix="${1:-id}"
    local random

    if [[ -r /dev/urandom ]]; then
        random=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8)
    else
        random=$(printf '%08x' $((RANDOM * RANDOM * RANDOM)))
    fi

    echo "${prefix}-${random}"
}

# Generate a UUID v4 compatible ID
# Usage: generate_uuid
# Output: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Manual UUID v4 generation
        local hex
        if [[ -r /dev/urandom ]]; then
            hex=$(head -c 16 /dev/urandom | xxd -p 2>/dev/null || od -An -tx1 /dev/urandom | head -1 | tr -d ' ')
        else
            hex=$(printf '%032x' $((RANDOM * RANDOM * RANDOM * RANDOM)))
        fi

        # Format as UUID and set version (4) and variant bits
        printf '%s-%s-4%s-%s-%s\n' \
            "${hex:0:8}" \
            "${hex:8:4}" \
            "${hex:13:3}" \
            "$(printf '%x' $(( (0x${hex:16:2} & 0x3f) | 0x80 )))${hex:18:2}" \
            "${hex:20:12}"
    fi
}

# Generate a session ID (date-based for easy sorting)
# Usage: generate_session_id
# Output: auto-YYYYMMDD-HHMMSS-random (e.g., auto-20260126-143022-a1b2)
generate_session_id() {
    local date_part
    local random

    date_part=$(date +%Y%m%d-%H%M%S)

    if [[ -r /dev/urandom ]]; then
        random=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 4)
    else
        random=$(printf '%04x' $RANDOM)
    fi

    echo "auto-${date_part}-${random}"
}

# Generate a checkpoint ID
# Usage: generate_checkpoint_id [phase]
# Output: chk-phase-timestamp-random (e.g., chk-PLAN-1706270400-a1b2)
generate_checkpoint_id() {
    local phase="${1:-unknown}"
    local timestamp
    local random

    timestamp=$(date +%s)

    if [[ -r /dev/urandom ]]; then
        random=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 4)
    else
        random=$(printf '%04x' $RANDOM)
    fi

    echo "chk-${phase}-${timestamp}-${random}"
}

# Generate a worktree branch name
# Usage: generate_worktree_branch [task_name]
# Output: auto/task-name-timestamp (e.g., auto/login-form-1706270400)
generate_worktree_branch() {
    local task_name="${1:-task}"
    local timestamp

    # Sanitize task name (lowercase, replace spaces with dashes, remove special chars)
    task_name=$(echo "$task_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 30)

    timestamp=$(date +%s)

    echo "auto/${task_name}-${timestamp}"
}

# Generate a learning ID (for memory system)
# Usage: generate_learning_id
# Output: learn-YYYYMMDD-random (e.g., learn-20260126-a1b2c3d4)
generate_learning_id() {
    local date_part
    local random

    date_part=$(date +%Y%m%d)

    if [[ -r /dev/urandom ]]; then
        random=$(head -c 100 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8)
    else
        random=$(printf '%08x' $((RANDOM * RANDOM)))
    fi

    echo "learn-${date_part}-${random}"
}

# Validate an ID format
# Usage: validate_id "task-1706270400-12345-a1b2c3" "task"
# Returns: 0 if valid, 1 if invalid
validate_id() {
    local id="$1"
    local expected_prefix="${2:-}"

    # Check basic format: prefix-timestamp-pid-random
    if [[ ! "$id" =~ ^[a-z]+-[0-9]+-[0-9]+-[a-z0-9]+$ ]]; then
        return 1
    fi

    # Check prefix if specified
    if [[ -n "$expected_prefix" ]]; then
        if [[ ! "$id" == "${expected_prefix}-"* ]]; then
            return 1
        fi
    fi

    return 0
}

# Extract timestamp from ID
# Usage: get_id_timestamp "task-1706270400-12345-a1b2c3"
# Output: 1706270400
get_id_timestamp() {
    local id="$1"
    echo "$id" | cut -d'-' -f2
}

# Check if ID is older than N seconds
# Usage: is_id_older_than "task-1706270400-12345-a1b2c3" 3600
# Returns: 0 if older, 1 if newer
is_id_older_than() {
    local id="$1"
    local seconds="$2"

    local id_timestamp
    id_timestamp=$(get_id_timestamp "$id")

    local current_timestamp
    current_timestamp=$(date +%s)

    local age=$((current_timestamp - id_timestamp))

    [[ $age -gt $seconds ]]
}

# Generate a deterministic ID from input (for idempotency)
# Usage: generate_deterministic_id "some stable input"
# Output: hash-based ID (same input = same output)
generate_deterministic_id() {
    local input="$1"
    local prefix="${2:-det}"

    local hash
    if command -v sha256sum &> /dev/null; then
        hash=$(echo -n "$input" | sha256sum | cut -c1-12)
    elif command -v shasum &> /dev/null; then
        hash=$(echo -n "$input" | shasum -a 256 | cut -c1-12)
    else
        # Fallback: use md5
        hash=$(echo -n "$input" | md5sum 2>/dev/null | cut -c1-12 || echo -n "$input" | md5 2>/dev/null | cut -c1-12)
    fi

    echo "${prefix}-${hash}"
}
