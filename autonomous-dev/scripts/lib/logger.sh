#!/usr/bin/env bash
# logger.sh - Structured logging framework for autonomous-dev
# Part of autonomous-dev v4.0 security improvements
#
# Usage:
#   source scripts/lib/logger.sh
#   log_info "Task started"
#   log_error "Something failed"

set -euo pipefail

# Configuration
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-.claude/logs/autonomous-dev.log}"
LOG_FORMAT="${LOG_FORMAT:-json}"  # json or text
LOG_TO_STDERR="${LOG_TO_STDERR:-true}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"  # 10MB default

# Log level priorities
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# Colors for terminal output
if [[ -t 2 ]]; then
    LOG_COLOR_DEBUG='\033[0;36m'  # Cyan
    LOG_COLOR_INFO='\033[0;32m'   # Green
    LOG_COLOR_WARN='\033[0;33m'   # Yellow
    LOG_COLOR_ERROR='\033[0;31m'  # Red
    LOG_COLOR_FATAL='\033[1;31m'  # Bold Red
    LOG_COLOR_RESET='\033[0m'
else
    LOG_COLOR_DEBUG=''
    LOG_COLOR_INFO=''
    LOG_COLOR_WARN=''
    LOG_COLOR_ERROR=''
    LOG_COLOR_FATAL=''
    LOG_COLOR_RESET=''
fi

# Initialize logging (create directory, rotate if needed)
_log_init() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")

    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi

    # Rotate log if too large
    if [[ -f "$LOG_FILE" ]]; then
        local size
        size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [[ "$size" -gt "$LOG_MAX_SIZE" ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null || true
        fi
    fi
}

# Get caller information
_log_caller() {
    local depth="${1:-2}"
    local func="${FUNCNAME[$depth]:-main}"
    local line="${BASH_LINENO[$((depth-1))]:-0}"
    local file="${BASH_SOURCE[$depth]:-unknown}"
    file=$(basename "$file")
    echo "${file}:${line}:${func}"
}

# Core logging function
# Usage: _log "INFO" "message" ["key1=value1" "key2=value2" ...]
_log() {
    local level="$1"
    shift
    local message="$1"
    shift || true

    # Check if level should be logged
    local level_priority="${LOG_LEVELS[$level]:-1}"
    local threshold="${LOG_LEVELS[$LOG_LEVEL]:-1}"

    if [[ "$level_priority" -lt "$threshold" ]]; then
        return 0
    fi

    _log_init

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    local caller
    caller=$(_log_caller 3)

    # Build extra fields
    local extra=""
    for arg in "$@"; do
        if [[ "$arg" == *"="* ]]; then
            local key="${arg%%=*}"
            local value="${arg#*=}"
            extra="${extra},\"${key}\":\"${value}\""
        fi
    done

    if [[ "$LOG_FORMAT" == "json" ]]; then
        # JSON format for structured logging
        local json_msg
        json_msg=$(printf '%s' "$message" | sed 's/"/\\"/g' | tr -d '\n')
        local log_line="{\"ts\":\"${timestamp}\",\"level\":\"${level}\",\"caller\":\"${caller}\",\"msg\":\"${json_msg}\"${extra}}"

        # Write to file
        echo "$log_line" >> "$LOG_FILE" 2>/dev/null || true

        # Write to stderr for ERROR/FATAL/WARN
        if [[ "$LOG_TO_STDERR" == "true" ]]; then
            local color_var="LOG_COLOR_${level}"
            local color="${!color_var:-}"
            if [[ "$level_priority" -ge 2 ]]; then
                echo -e "${color}[${level}]${LOG_COLOR_RESET} ${message}" >&2
            fi
        fi
    else
        # Text format
        local log_line="[${timestamp}] [${level}] [${caller}] ${message}"

        echo "$log_line" >> "$LOG_FILE" 2>/dev/null || true

        if [[ "$LOG_TO_STDERR" == "true" ]]; then
            local color_var="LOG_COLOR_${level}"
            local color="${!color_var:-}"
            if [[ "$level_priority" -ge 2 ]]; then
                echo -e "${color}${log_line}${LOG_COLOR_RESET}" >&2
            fi
        fi
    fi
}

# Convenience functions
log_debug() {
    _log "DEBUG" "$@"
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
}

log_error() {
    _log "ERROR" "$@"
}

log_fatal() {
    _log "FATAL" "$@"
    exit 1
}

# Log with context (key-value pairs)
# Usage: log_with_context "INFO" "User action" "user=john" "action=login"
log_with_context() {
    local level="$1"
    shift
    _log "$level" "$@"
}

# Start a timed operation
# Usage: timer_id=$(log_start_timer "operation_name")
log_start_timer() {
    local operation="$1"
    local start_time
    start_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    echo "${operation}:${start_time}"
}

# End a timed operation and log duration
# Usage: log_end_timer "$timer_id"
log_end_timer() {
    local timer="$1"
    local level="${2:-INFO}"

    local operation="${timer%%:*}"
    local start_time="${timer#*:}"
    local end_time
    end_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")

    # Calculate duration in milliseconds
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    _log "$level" "Operation completed: ${operation}" "duration_ms=${duration_ms}"
}

# Log command execution with timing
# Usage: log_command "npm test"
log_command() {
    local cmd="$1"
    local timer
    timer=$(log_start_timer "command")

    log_info "Executing command" "cmd=$cmd"

    local exit_code=0
    eval "$cmd" || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_end_timer "$timer" "INFO"
    else
        log_error "Command failed" "cmd=$cmd" "exit_code=$exit_code"
    fi

    return "$exit_code"
}

# Structured error logging with stack trace
log_error_with_trace() {
    local message="$1"
    shift

    local trace=""
    local i
    for ((i=1; i<${#FUNCNAME[@]}; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local file="${BASH_SOURCE[$i]}"
        trace="${trace}${file}:${line}:${func} <- "
    done
    trace="${trace%<- }"

    _log "ERROR" "$message" "trace=$trace" "$@"
}

# Set log level at runtime
log_set_level() {
    local level="$1"
    if [[ -n "${LOG_LEVELS[$level]:-}" ]]; then
        LOG_LEVEL="$level"
        log_info "Log level changed" "level=$level"
    else
        log_warn "Invalid log level: $level"
    fi
}

# Tail the log file
log_tail() {
    local lines="${1:-50}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "$lines" "$LOG_FILE"
    fi
}

# Search logs
log_search() {
    local pattern="$1"
    if [[ -f "$LOG_FILE" ]]; then
        grep -i "$pattern" "$LOG_FILE" || true
    fi
}

# Clean old logs
log_cleanup() {
    local days="${1:-7}"
    local log_dir
    log_dir=$(dirname "$LOG_FILE")

    find "$log_dir" -name "*.log*" -type f -mtime +"$days" -delete 2>/dev/null || true
    log_info "Log cleanup completed" "older_than_days=$days"
}
