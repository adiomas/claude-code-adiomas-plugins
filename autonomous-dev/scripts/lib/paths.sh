#!/usr/bin/env bash
# paths.sh - Cross-platform path handling utilities
# Part of autonomous-dev v4.0 improvements
#
# Usage:
#   source scripts/lib/paths.sh
#   real_path=$(get_realpath "./some/path")
#   temp_dir=$(get_temp_base)

set -euo pipefail

# Get the real/absolute path (cross-platform)
# Usage: get_realpath "./relative/path"
get_realpath() {
    local path="$1"

    # Try realpath first (Linux, newer macOS)
    if command -v realpath &> /dev/null; then
        realpath "$path" 2>/dev/null && return 0
    fi

    # Try grealpath (macOS with GNU coreutils)
    if command -v grealpath &> /dev/null; then
        grealpath "$path" 2>/dev/null && return 0
    fi

    # Try Python as fallback
    if command -v python3 &> /dev/null; then
        python3 -c "import os; print(os.path.realpath('$path'))" 2>/dev/null && return 0
    fi

    if command -v python &> /dev/null; then
        python -c "import os; print(os.path.realpath('$path'))" 2>/dev/null && return 0
    fi

    # Manual fallback
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        local dir
        dir=$(dirname "$path")
        local base
        base=$(basename "$path")
        echo "$(cd "$dir" && pwd)/$base"
    else
        # Path doesn't exist, try to resolve parent
        local dir
        dir=$(dirname "$path")
        local base
        base=$(basename "$path")
        if [[ -d "$dir" ]]; then
            echo "$(cd "$dir" && pwd)/$base"
        else
            echo "$path"
        fi
    fi
}

# Get safe temporary directory base for worktrees
# Usage: get_temp_base
# Returns path like /tmp/auto-worktrees-1000 (with user ID for isolation)
get_temp_base() {
    local base="${AUTO_WORKTREE_BASE:-}"

    if [[ -z "$base" ]]; then
        # Use TMPDIR if set (macOS sets this), otherwise /tmp
        local tmp_root="${TMPDIR:-/tmp}"
        # Remove trailing slash if present
        tmp_root="${tmp_root%/}"

        # Add user ID for multi-user isolation
        local user_id
        user_id=$(id -u 2>/dev/null || echo "unknown")

        base="${tmp_root}/auto-worktrees-${user_id}"
    fi

    # Ensure directory exists with proper permissions
    if [[ ! -d "$base" ]]; then
        mkdir -p "$base" 2>/dev/null || {
            echo "ERROR: Cannot create temp directory: $base" >&2
            return 1
        }
        chmod 700 "$base" 2>/dev/null || true
    fi

    echo "$base"
}

# Get the project root (where .git is)
# Usage: get_project_root
get_project_root() {
    local dir="${1:-$(pwd)}"

    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    # Not in a git repo, return current directory
    pwd
}

# Get the .claude directory path
# Usage: get_claude_dir
get_claude_dir() {
    local project_root
    project_root=$(get_project_root)
    echo "${project_root}/.claude"
}

# Ensure .claude directory structure exists
# Usage: ensure_claude_dirs
ensure_claude_dirs() {
    local claude_dir
    claude_dir=$(get_claude_dir)

    local dirs=(
        "$claude_dir"
        "$claude_dir/logs"
        "$claude_dir/checkpoints"
        "$claude_dir/memory"
        "$claude_dir/memory/local"
        "$claude_dir/plans"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || true
        fi
    done
}

# Get relative path from one path to another
# Usage: get_relative_path "/a/b/c" "/a/b/d/e" → "../d/e"
get_relative_path() {
    local from="$1"
    local to="$2"

    # Try Python (most reliable)
    if command -v python3 &> /dev/null; then
        python3 -c "import os.path; print(os.path.relpath('$to', '$from'))" 2>/dev/null && return 0
    fi

    # Try realpath --relative-to (GNU coreutils)
    if command -v realpath &> /dev/null; then
        realpath --relative-to="$from" "$to" 2>/dev/null && return 0
    fi

    # Fallback: just return absolute path
    get_realpath "$to"
}

# Check if path is inside another path
# Usage: is_path_inside "/a/b/c" "/a/b" → 0 (true)
is_path_inside() {
    local child="$1"
    local parent="$2"

    local real_child
    real_child=$(get_realpath "$child")
    local real_parent
    real_parent=$(get_realpath "$parent")

    [[ "$real_child" == "$real_parent"* ]]
}

# Safely join paths (handles trailing slashes)
# Usage: join_paths "/a/b/" "c/d" → "/a/b/c/d"
join_paths() {
    local base="$1"
    local path="$2"

    # Remove trailing slash from base
    base="${base%/}"
    # Remove leading slash from path
    path="${path#/}"

    echo "${base}/${path}"
}

# Get script's own directory (useful in scripts)
# Usage: script_dir=$(get_script_dir)
get_script_dir() {
    local source="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local dir

    # Resolve symlinks
    while [[ -L "$source" ]]; do
        dir=$(dirname "$source")
        source=$(readlink "$source")
        [[ "$source" != /* ]] && source="$dir/$source"
    done

    dir=$(dirname "$source")
    get_realpath "$dir"
}

# Create a temporary file safely
# Usage: temp_file=$(create_temp_file "prefix")
create_temp_file() {
    local prefix="${1:-auto}"
    local temp_base
    temp_base=$(get_temp_base)

    if command -v mktemp &> /dev/null; then
        mktemp "${temp_base}/${prefix}.XXXXXX"
    else
        local random
        random=$(head -c 100 /dev/urandom 2>/dev/null | LC_ALL=C tr -dc 'a-z0-9' | head -c 6 || echo "$$")
        local file="${temp_base}/${prefix}.${random}"
        touch "$file"
        echo "$file"
    fi
}

# Create a temporary directory safely
# Usage: temp_dir=$(create_temp_dir "prefix")
create_temp_dir() {
    local prefix="${1:-auto}"
    local temp_base
    temp_base=$(get_temp_base)

    if command -v mktemp &> /dev/null; then
        mktemp -d "${temp_base}/${prefix}.XXXXXX"
    else
        local random
        random=$(head -c 100 /dev/urandom 2>/dev/null | LC_ALL=C tr -dc 'a-z0-9' | head -c 6 || echo "$$")
        local dir="${temp_base}/${prefix}.${random}"
        mkdir -p "$dir"
        echo "$dir"
    fi
}

# Clean up old temporary files/directories
# Usage: cleanup_temp_files 24 → removes files older than 24 hours
cleanup_temp_files() {
    local hours="${1:-24}"
    local temp_base
    temp_base=$(get_temp_base)

    if [[ -d "$temp_base" ]]; then
        find "$temp_base" -mindepth 1 -mmin +$((hours * 60)) -delete 2>/dev/null || true
    fi
}

# Check if running on Windows (WSL/Git Bash/Cygwin)
is_windows() {
    case "$(uname -s)" in
        CYGWIN*|MINGW*|MSYS*) return 0 ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                return 0  # WSL
            fi
            return 1
            ;;
        *) return 1 ;;
    esac
}

# Check if running on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Check if running on Linux (not WSL)
is_linux() {
    if [[ "$(uname -s)" == "Linux" ]]; then
        if ! grep -qi microsoft /proc/version 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Convert path to native format (for Windows compatibility)
# Usage: native_path=$(to_native_path "/c/Users/foo")
to_native_path() {
    local path="$1"

    if is_windows; then
        # Convert /c/... to C:\...
        if [[ "$path" =~ ^/([a-zA-Z])/ ]]; then
            path="${BASH_REMATCH[1]}:${path:2}"
            path="${path//\//\\}"
        fi
    fi

    echo "$path"
}

# Convert native path to Unix format
# Usage: unix_path=$(to_unix_path "C:\Users\foo")
to_unix_path() {
    local path="$1"

    # Convert C:\... to /c/...
    if [[ "$path" =~ ^([a-zA-Z]):\\ ]]; then
        path="/${path:0:1}${path:2}"
        path="${path//\\//}"
    fi

    echo "$path"
}
