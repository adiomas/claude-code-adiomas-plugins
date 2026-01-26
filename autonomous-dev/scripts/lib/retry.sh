#!/usr/bin/env bash
# retry.sh - Retry logic with exponential backoff
# Part of autonomous-dev v4.0 improvements
#
# Usage:
#   source scripts/lib/retry.sh
#   retry git push origin main
#   retry_with_options --max-attempts 5 --delay 2 -- curl https://api.example.com

set -euo pipefail

# Default configuration
RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-3}"
RETRY_INITIAL_DELAY="${RETRY_INITIAL_DELAY:-1}"
RETRY_MULTIPLIER="${RETRY_MULTIPLIER:-2}"
RETRY_MAX_DELAY="${RETRY_MAX_DELAY:-60}"
RETRY_JITTER="${RETRY_JITTER:-true}"

# Source logger if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/logger.sh" ]]; then
    source "$SCRIPT_DIR/logger.sh"
else
    # Fallback logging
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

# Add jitter to delay (0-25% of delay)
_add_jitter() {
    local delay="$1"
    if [[ "$RETRY_JITTER" == "true" ]]; then
        local jitter=$((RANDOM % (delay / 4 + 1)))
        echo $((delay + jitter))
    else
        echo "$delay"
    fi
}

# Simple retry function
# Usage: retry command [args...]
retry() {
    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local delay="$RETRY_INITIAL_DELAY"
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        # Execute the command
        if "$@"; then
            return 0
        fi

        exit_code=$?

        if [[ $attempt -lt $max_attempts ]]; then
            local sleep_time
            sleep_time=$(_add_jitter "$delay")

            log_warn "Attempt $attempt/$max_attempts failed (exit code: $exit_code). Retrying in ${sleep_time}s..."
            sleep "$sleep_time"

            # Exponential backoff with cap
            delay=$((delay * RETRY_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_error "All $max_attempts attempts failed for command: $*"
    return "$exit_code"
}

# Retry with custom options
# Usage: retry_with_options --max-attempts 5 --delay 2 -- command [args...]
retry_with_options() {
    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local initial_delay="$RETRY_INITIAL_DELAY"
    local multiplier="$RETRY_MULTIPLIER"
    local max_delay="$RETRY_MAX_DELAY"
    local jitter="$RETRY_JITTER"
    local on_retry=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --max-attempts)
                max_attempts="$2"
                shift 2
                ;;
            --delay)
                initial_delay="$2"
                shift 2
                ;;
            --multiplier)
                multiplier="$2"
                shift 2
                ;;
            --max-delay)
                max_delay="$2"
                shift 2
                ;;
            --no-jitter)
                jitter="false"
                shift
                ;;
            --on-retry)
                on_retry="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    local delay="$initial_delay"
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi

        exit_code=$?

        if [[ $attempt -lt $max_attempts ]]; then
            local sleep_time="$delay"
            if [[ "$jitter" == "true" ]]; then
                sleep_time=$(_add_jitter "$delay")
            fi

            log_warn "Attempt $attempt/$max_attempts failed (exit code: $exit_code). Retrying in ${sleep_time}s..."

            # Run on_retry callback if provided
            if [[ -n "$on_retry" ]]; then
                eval "$on_retry" || true
            fi

            sleep "$sleep_time"

            delay=$((delay * multiplier))
            if [[ $delay -gt $max_delay ]]; then
                delay=$max_delay
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_error "All $max_attempts attempts failed"
    return "$exit_code"
}

# Retry only on specific exit codes
# Usage: retry_on_codes "1,2,5" command [args...]
retry_on_codes() {
    local codes="$1"
    shift

    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local delay="$RETRY_INITIAL_DELAY"
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi

        exit_code=$?

        # Check if exit code is in the retry list
        if [[ ! ",$codes," == *",$exit_code,"* ]]; then
            log_error "Exit code $exit_code is not retryable"
            return "$exit_code"
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            local sleep_time
            sleep_time=$(_add_jitter "$delay")

            log_warn "Attempt $attempt/$max_attempts failed (exit code: $exit_code). Retrying in ${sleep_time}s..."
            sleep "$sleep_time"

            delay=$((delay * RETRY_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_error "All $max_attempts attempts failed"
    return "$exit_code"
}

# Retry with timeout for each attempt
# Usage: retry_with_timeout 30 command [args...]
retry_with_timeout() {
    local timeout="$1"
    shift

    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local delay="$RETRY_INITIAL_DELAY"
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        # Use timeout command if available
        if command -v timeout &> /dev/null; then
            if timeout "$timeout" "$@"; then
                return 0
            fi
            exit_code=$?
        elif command -v gtimeout &> /dev/null; then
            # macOS with GNU coreutils
            if gtimeout "$timeout" "$@"; then
                return 0
            fi
            exit_code=$?
        else
            # Fallback: run without timeout
            log_warn "timeout command not available, running without timeout"
            if "$@"; then
                return 0
            fi
            exit_code=$?
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            local sleep_time
            sleep_time=$(_add_jitter "$delay")

            if [[ $exit_code -eq 124 ]]; then
                log_warn "Attempt $attempt/$max_attempts timed out. Retrying in ${sleep_time}s..."
            else
                log_warn "Attempt $attempt/$max_attempts failed (exit code: $exit_code). Retrying in ${sleep_time}s..."
            fi

            sleep "$sleep_time"

            delay=$((delay * RETRY_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_error "All $max_attempts attempts failed"
    return "$exit_code"
}

# Wait for a condition to become true
# Usage: wait_for "curl -s http://localhost:8080/health" --timeout 60
wait_for() {
    local condition="$1"
    shift

    local timeout=60
    local interval=2

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --interval)
                interval="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local elapsed=0

    log_info "Waiting for condition: $condition"

    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition" > /dev/null 2>&1; then
            log_info "Condition met after ${elapsed}s"
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_error "Timeout waiting for condition after ${timeout}s"
    return 1
}

# Retry a function that outputs to a file
# Usage: retry_to_file output.txt command [args...]
retry_to_file() {
    local output_file="$1"
    shift

    local max_attempts="$RETRY_MAX_ATTEMPTS"
    local delay="$RETRY_INITIAL_DELAY"
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@" > "$output_file" 2>&1; then
            return 0
        fi

        local exit_code=$?

        if [[ $attempt -lt $max_attempts ]]; then
            local sleep_time
            sleep_time=$(_add_jitter "$delay")

            log_warn "Attempt $attempt/$max_attempts failed. Output saved to $output_file. Retrying in ${sleep_time}s..."
            sleep "$sleep_time"

            delay=$((delay * RETRY_MULTIPLIER))
            if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                delay=$RETRY_MAX_DELAY
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_error "All $max_attempts attempts failed. Last output in: $output_file"
    return 1
}
