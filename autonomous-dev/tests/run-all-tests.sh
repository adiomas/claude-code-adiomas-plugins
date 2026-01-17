#!/bin/bash
# Run all plugin tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================="
echo "  Autonomous-Dev Plugin Test Suite"
echo "======================================="
echo ""

PASSED=0
FAILED=0
TOTAL=0

for test_file in test-*.sh; do
    if [[ -f "$test_file" ]]; then
        ((TOTAL++)) || true
        echo "Running: $test_file"
        echo "---------------------------------------"
        if bash "$test_file"; then
            ((PASSED++)) || true
        else
            ((FAILED++)) || true
        fi
        echo ""
    fi
done

echo "======================================="
echo "  Test Results"
echo "======================================="
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
