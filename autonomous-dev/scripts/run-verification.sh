#!/bin/bash
# run-verification.sh - Run project verification commands safely
# Part of autonomous-dev v4.0
#
# Usage:
#   ./run-verification.sh [all|required|<command_name>]
#
# Examples:
#   ./run-verification.sh all       # Run typecheck, lint, test, build
#   ./run-verification.sh required  # Run only required verifications
#   ./run-verification.sh test      # Run only test command

set -euo pipefail

# Load helper libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/init.sh" ]]; then
    source "$SCRIPT_DIR/lib/init.sh"
else
    # Fallback if libs not available
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    yaml_read() { yq -r ".$2 // \"\"" "$1" 2>/dev/null; }
    validate_command() { return 0; }  # Allow all if validation not available
fi

PROFILE_FILE=".claude/project-profile.yaml"
VERIFICATION_TYPE="${1:-all}"

# Check prerequisites
if [[ ! -f "$PROFILE_FILE" ]]; then
    log_error "No project profile found at $PROFILE_FILE"
    echo "Run the project-detector skill first or create the profile manually."
    exit 1
fi

if ! command -v yq &>/dev/null; then
    log_error "yq is required. Install with: brew install yq"
    exit 1
fi

# Run a single verification command safely
run_command() {
    local name="$1"
    local cmd

    # Read command from profile
    cmd=$(yaml_read "$PROFILE_FILE" "commands.$name")

    if [[ -z "$cmd" || "$cmd" == "null" ]]; then
        echo "SKIP: No $name command configured"
        return 0
    fi

    echo "RUNNING: $name ($cmd)"

    # Validate command before execution (security check)
    if ! validate_command "$cmd"; then
        log_error "Command validation failed for: $cmd"
        echo "BLOCKED: $name (security policy)"
        return 1
    fi

    # Execute command safely (not using eval!)
    local exit_code=0
    local timer
    timer=$(log_start_timer "$name" 2>/dev/null || echo "")

    # Use bash -c instead of eval for safer execution
    if bash -c "$cmd"; then
        echo "PASS: $name"
        [[ -n "$timer" ]] && log_end_timer "$timer" 2>/dev/null || true
        return 0
    else
        exit_code=$?
        echo "FAIL: $name (exit code: $exit_code)"
        log_error "Verification failed" "command=$name" "exit_code=$exit_code"
        return 1
    fi
}

# Run verification with retry for flaky tests
run_command_with_retry() {
    local name="$1"
    local max_retries="${2:-1}"

    if [[ $max_retries -gt 1 ]] && type retry &>/dev/null; then
        RETRY_MAX_ATTEMPTS=$max_retries retry run_command "$name"
    else
        run_command "$name"
    fi
}

# Main execution
case "$VERIFICATION_TYPE" in
    all)
        FAILED=0
        PASSED=0

        for check in typecheck lint test build; do
            if run_command "$check"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
        done

        echo ""
        if [[ $FAILED -gt 0 ]]; then
            echo "SUMMARY: $FAILED verification(s) failed, $PASSED passed"
            log_warn "Verification incomplete" "failed=$FAILED" "passed=$PASSED"
            exit 1
        else
            echo "SUMMARY: All $PASSED verifications passed"
            log_info "Verification complete" "passed=$PASSED"
            exit 0
        fi
        ;;

    required)
        FAILED=0
        PASSED=0

        REQUIRED=$(yaml_read "$PROFILE_FILE" "verification.required[]" 2>/dev/null || echo "")

        if [[ -z "$REQUIRED" ]]; then
            echo "No required verifications configured"
            exit 0
        fi

        for check in $REQUIRED; do
            if run_command "$check"; then
                ((PASSED++)) || true
            else
                ((FAILED++)) || true
            fi
        done

        echo ""
        if [[ $FAILED -gt 0 ]]; then
            echo "SUMMARY: $FAILED required verification(s) failed, $PASSED passed"
            log_warn "Required verification incomplete" "failed=$FAILED" "passed=$PASSED"
            exit 1
        else
            echo "SUMMARY: All $PASSED required verifications passed"
            log_info "Required verification complete" "passed=$PASSED"
            exit 0
        fi
        ;;

    *)
        # Run specific verification
        run_command "$VERIFICATION_TYPE"
        ;;
esac
