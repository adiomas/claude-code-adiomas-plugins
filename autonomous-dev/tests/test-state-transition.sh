#!/bin/bash
# Test: state-transition.sh functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Testing state-transition.sh ==="

# Test 1: Script exists and is executable
echo -n "Test 1: Script exists and is executable... "
if [[ -x "$PLUGIN_ROOT/scripts/state-transition.sh" ]]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: Has shebang
echo -n "Test 2: Has proper shebang... "
if head -1 "$PLUGIN_ROOT/scripts/state-transition.sh" | grep -q "^#!/bin/bash"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: Has set -euo pipefail
echo -n "Test 3: Has set -euo pipefail... "
if grep -q "^set -euo pipefail" "$PLUGIN_ROOT/scripts/state-transition.sh"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 4: No bc usage (should use awk)
echo -n "Test 4: No bc usage... "
if ! grep -q '\bbc\b' "$PLUGIN_ROOT/scripts/state-transition.sh"; then
    echo "PASS"
else
    echo "FAIL - should use awk instead of bc"
    exit 1
fi

# Test 5: Help command works
echo -n "Test 5: Help command works... "
if bash "$PLUGIN_ROOT/scripts/state-transition.sh" help 2>&1 | grep -q "State Transition Engine"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

echo ""
echo "=== All state-transition.sh tests passed ==="
