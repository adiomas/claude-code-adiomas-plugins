#!/usr/bin/env bash
# filter-verification-output.sh - Filters verification output to reduce token usage
# Anthropic Best Practice: Result Filtering reduces token usage by 40%+
#
# Usage: ./filter-verification-output.sh <command>
# Exit codes:
#   0 - Command succeeded (returns summary)
#   Non-zero - Command failed (returns error lines only)

set -uo pipefail

# Configuration
MAX_ERROR_LINES=30
MAX_SUCCESS_TOKENS=50   # ~50 tokens for success
MAX_FAILURE_TOKENS=200  # ~200 tokens for failure

# Temporary files for output capture
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
COMBINED_FILE=$(mktemp)

# Cleanup on exit
cleanup() {
    rm -f "$STDOUT_FILE" "$STDERR_FILE" "$COMBINED_FILE"
}
trap cleanup EXIT

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <command>"
    echo "Example: $0 'npm test'"
    exit 2
fi

COMMAND="$*"

# Execute command and capture output
eval "$COMMAND" > "$STDOUT_FILE" 2> "$STDERR_FILE"
EXIT_CODE=$?

# Combine stdout and stderr for analysis
cat "$STDOUT_FILE" "$STDERR_FILE" > "$COMBINED_FILE"

# Function to extract test summary
extract_test_summary() {
    local output="$1"

    # Jest/Vitest summary pattern
    if grep -qE "(Tests?|Test Suites?):\s*\d+\s*(passed|failed)" "$output" 2>/dev/null; then
        grep -E "(Tests?|Test Suites?):\s*\d+" "$output" | tail -3
        grep -E "Time:\s*[0-9.]+" "$output" | tail -1
        return 0
    fi

    # pytest summary pattern
    if grep -qE "=+ (PASSED|passed|FAILED|failed)" "$output" 2>/dev/null; then
        grep -E "=+ .* =+$" "$output" | tail -1
        return 0
    fi

    # Go test summary
    if grep -qE "^(ok|FAIL)\s+" "$output" 2>/dev/null; then
        grep -E "^(ok|FAIL)\s+" "$output"
        return 0
    fi

    # TypeScript/tsc summary
    if grep -qE "Found \d+ error" "$output" 2>/dev/null; then
        grep -E "Found \d+ error" "$output" | tail -1
        return 0
    fi

    # ESLint summary
    if grep -qE "\d+ problem" "$output" 2>/dev/null; then
        grep -E "✖ \d+ problem" "$output" | tail -1
        return 0
    fi

    # Generic: count lines mentioning pass/fail
    local passed=$(grep -ciE "pass(ed)?" "$output" 2>/dev/null || echo 0)
    local failed=$(grep -ciE "fail(ed)?" "$output" 2>/dev/null || echo 0)
    echo "Passed: $passed, Failed: $failed"
}

# Function to extract error lines only
extract_errors() {
    local output="$1"
    local max_lines="$2"

    # Common error patterns
    {
        # Error messages
        grep -inE "^error:|error:|Error:|ERROR:" "$output" 2>/dev/null

        # TypeScript errors
        grep -nE "TS\d+:" "$output" 2>/dev/null

        # Failed test names
        grep -nE "^[[:space:]]*(✕|✗|×|FAIL)" "$output" 2>/dev/null

        # Stack trace first lines only (not full traces)
        grep -nE "^\s+at\s+" "$output" 2>/dev/null | head -5

        # Assertion failures
        grep -nE "(expect|assert|AssertionError)" "$output" 2>/dev/null

    } | head -n "$max_lines" | sort -t: -k1 -n | uniq
}

# Output based on exit code
if [[ $EXIT_CODE -eq 0 ]]; then
    # SUCCESS: Return summary only (~50 tokens)
    echo "✓ VERIFICATION PASSED"
    echo "─────────────────────"
    extract_test_summary "$COMBINED_FILE"
    echo "─────────────────────"
    echo "Exit code: 0"
else
    # FAILURE: Return error lines only (~200 tokens)
    echo "✗ VERIFICATION FAILED"
    echo "─────────────────────"

    ERRORS=$(extract_errors "$COMBINED_FILE" "$MAX_ERROR_LINES")

    if [[ -n "$ERRORS" ]]; then
        echo "$ERRORS"
    else
        # Fallback: last N lines if no specific errors found
        echo "Last $MAX_ERROR_LINES lines:"
        tail -n "$MAX_ERROR_LINES" "$COMBINED_FILE"
    fi

    echo "─────────────────────"
    echo "Exit code: $EXIT_CODE"

    # Include summary if available
    SUMMARY=$(extract_test_summary "$COMBINED_FILE")
    if [[ -n "$SUMMARY" ]]; then
        echo ""
        echo "Summary:"
        echo "$SUMMARY"
    fi
fi

exit $EXIT_CODE
