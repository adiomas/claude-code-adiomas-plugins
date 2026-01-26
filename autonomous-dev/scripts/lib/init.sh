#!/usr/bin/env bash
# init.sh - Initialize all library functions for autonomous-dev scripts
# Part of autonomous-dev v4.0
#
# Usage:
#   source scripts/lib/init.sh
#
# This will load all helper libraries:
#   - logger.sh     → log_info, log_error, log_warn, log_debug
#   - yaml-helper.sh → yaml_read, yaml_write, yaml_validate
#   - retry.sh      → retry, retry_with_options, wait_for
#   - id-generator.sh → generate_id, generate_session_id
#   - paths.sh      → get_realpath, get_temp_base, get_project_root
#   - validation.sh → validate_command, safe_exec, sanitize_filename

set -euo pipefail

# Get the directory where this script is located
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Track loaded libraries to avoid double-loading
declare -g _AUTODEV_LIBS_LOADED="${_AUTODEV_LIBS_LOADED:-}"

_load_lib() {
    local lib="$1"
    local lib_path="${LIB_DIR}/${lib}.sh"

    # Skip if already loaded
    if [[ "$_AUTODEV_LIBS_LOADED" == *":${lib}:"* ]]; then
        return 0
    fi

    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
        _AUTODEV_LIBS_LOADED="${_AUTODEV_LIBS_LOADED}:${lib}:"
    else
        echo "WARNING: Library not found: $lib_path" >&2
    fi
}

# Load libraries in dependency order
# 1. logger (no dependencies, used by others)
_load_lib "logger"

# 2. paths (used by yaml-helper)
_load_lib "paths"

# 3. yaml-helper (depends on logger)
_load_lib "yaml-helper"

# 4. id-generator (no dependencies)
_load_lib "id-generator"

# 5. retry (depends on logger)
_load_lib "retry"

# 6. validation (depends on logger)
_load_lib "validation"

# Export library directory for other scripts
export AUTODEV_LIB_DIR="$LIB_DIR"

# Initialize common directories
if type ensure_claude_dirs &>/dev/null; then
    ensure_claude_dirs
fi

# Log initialization (only if LOG_INIT is set)
if [[ "${LOG_INIT:-false}" == "true" ]]; then
    log_info "autonomous-dev libraries initialized" "version=4.0"
fi
