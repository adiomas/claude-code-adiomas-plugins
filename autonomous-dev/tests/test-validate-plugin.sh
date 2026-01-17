#!/bin/bash
# Test: validate-plugin.sh functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Testing validate-plugin.sh ==="

# Test 1: Script exists and is executable
echo -n "Test 1: Script exists and is executable... "
if [[ -x "$PLUGIN_ROOT/scripts/validate-plugin.sh" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: Script runs without error
echo -n "Test 2: Script runs without error... "
if bash "$PLUGIN_ROOT/scripts/validate-plugin.sh" "$PLUGIN_ROOT" > /dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: Output contains expected sections
echo -n "Test 3: Output contains expected sections... "
OUTPUT=$(bash "$PLUGIN_ROOT/scripts/validate-plugin.sh" "$PLUGIN_ROOT" 2>&1)
if echo "$OUTPUT" | grep -q "Checking Plugin Manifest" && \
   echo "$OUTPUT" | grep -q "Checking Skills" && \
   echo "$OUTPUT" | grep -q "Checking Commands" && \
   echo "$OUTPUT" | grep -q "Checking Agents"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 4: Validation passes
echo -n "Test 4: Validation passes with 0 errors... "
if echo "$OUTPUT" | grep -q "Plugin validation PASSED"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

echo ""
echo "=== All validate-plugin.sh tests passed ==="
